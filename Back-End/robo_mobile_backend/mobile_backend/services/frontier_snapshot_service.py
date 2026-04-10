from __future__ import annotations

from app.domain.models import ManagedFrontierSnapshotBuildStatus
from app.services.managed_universe_service import ManagedUniverseService
from mobile_backend.domain.enums import InvestmentHorizon, SimulationDataSource
from mobile_backend.integrations.embedded_portfolio_engine import EmbeddedPortfolioEngineAdapter


class FrontierSnapshotService:
    """Materializes managed-universe frontier responses so mobile reads can skip recomputation."""

    def __init__(
        self,
        *,
        managed_universe_service: ManagedUniverseService | None = None,
        calculation_adapter: EmbeddedPortfolioEngineAdapter | None = None,
    ) -> None:
        self.managed_universe_service = managed_universe_service or ManagedUniverseService()
        self.calculation_adapter = calculation_adapter or EmbeddedPortfolioEngineAdapter(
            managed_universe_service=self.managed_universe_service
        )

    def rebuild_managed_universe_snapshots(
        self,
        *,
        version_id: int | None = None,
        source_refresh_job_id: int | None = None,
    ) -> ManagedFrontierSnapshotBuildStatus:
        if not self.managed_universe_service.is_configured():
            return ManagedFrontierSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="DATABASE_URL이 없어 frontier snapshot을 저장하지 않았습니다.",
            )

        self.managed_universe_service.initialize_storage()
        version = (
            self.managed_universe_service.get_version(version_id)
            if version_id is not None
            else self.managed_universe_service.get_active_version()
        )
        if version is None:
            return ManagedFrontierSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="active 유니버스 버전이 없어 frontier snapshot을 만들지 않았습니다.",
            )

        instruments = self.managed_universe_service.get_instruments_for_version(version.version_id)
        if not instruments:
            self.managed_universe_service.repository.delete_frontier_snapshots(version.version_id)
            return ManagedFrontierSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="버전에 종목이 없어 frontier snapshot을 만들지 않았습니다.",
            )

        price_window = self.managed_universe_service.get_price_window(version.version_id, instruments)
        if price_window is None or price_window.aligned_end_date is None:
            self.managed_universe_service.repository.delete_frontier_snapshots(version.version_id)
            return ManagedFrontierSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="공통 가격 구간이 없어 frontier snapshot을 만들지 않았습니다.",
            )

        built_horizons: list[str] = []
        failed_horizons: list[str] = []
        for horizon in InvestmentHorizon:
            try:
                payload = self.calculation_adapter.build_materialized_frontier_snapshot(
                    investment_horizon=horizon,
                    data_source=SimulationDataSource.MANAGED_UNIVERSE,
                )
                self.managed_universe_service.repository.upsert_frontier_snapshot(
                    version_id=version.version_id,
                    data_source=SimulationDataSource.MANAGED_UNIVERSE.value,
                    investment_horizon=horizon.value,
                    aligned_start_date=price_window.aligned_start_date,
                    aligned_end_date=price_window.aligned_end_date,
                    total_point_count=int(payload["total_point_count"]),
                    payload=payload,
                    source_refresh_job_id=source_refresh_job_id,
                )
                built_horizons.append(horizon.value)
            except Exception:
                failed_horizons.append(horizon.value)

        if built_horizons and failed_horizons:
            return ManagedFrontierSnapshotBuildStatus(
                status="partial_success",
                snapshot_count=len(built_horizons),
                horizons=built_horizons,
                failed_horizons=failed_horizons,
                message=f"frontier snapshot {len(built_horizons)}개 horizon 갱신, {len(failed_horizons)}개 실패",
            )
        if built_horizons:
            return ManagedFrontierSnapshotBuildStatus(
                status="success",
                snapshot_count=len(built_horizons),
                horizons=built_horizons,
                message=f"frontier snapshot {len(built_horizons)}개 horizon 갱신 완료",
            )
        return ManagedFrontierSnapshotBuildStatus(
            status="failed",
            snapshot_count=0,
            failed_horizons=failed_horizons,
            message="frontier snapshot 갱신에 실패했습니다.",
        )
