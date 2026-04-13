from __future__ import annotations

from app.domain.models import ManagedComparisonBacktestSnapshotBuildStatus
from app.services.managed_universe_service import ManagedUniverseService
from mobile_backend.domain.enums import SimulationDataSource
from mobile_backend.integrations.embedded_portfolio_engine import EmbeddedPortfolioEngineAdapter


class ComparisonBacktestSnapshotService:
    """Materializes managed-universe comparison backtest responses for mobile reuse."""

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
    ) -> ManagedComparisonBacktestSnapshotBuildStatus:
        if not self.managed_universe_service.is_configured():
            return ManagedComparisonBacktestSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="DATABASE_URL이 없어 comparison backtest snapshot을 저장하지 않았습니다.",
            )

        self.managed_universe_service.initialize_storage()
        version = (
            self.managed_universe_service.get_version(version_id)
            if version_id is not None
            else self.managed_universe_service.get_active_version()
        )
        if version is None:
            return ManagedComparisonBacktestSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="active 유니버스 버전이 없어 comparison backtest snapshot을 만들지 않았습니다.",
            )

        instruments = self.managed_universe_service.get_instruments_for_version(version.version_id)
        if not instruments:
            self.managed_universe_service.repository.delete_comparison_backtest_snapshots(version.version_id)
            return ManagedComparisonBacktestSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="버전에 종목이 없어 comparison backtest snapshot을 만들지 않았습니다.",
            )

        price_window = self.managed_universe_service.get_price_window(version.version_id, instruments)
        if price_window is None or price_window.aligned_end_date is None:
            self.managed_universe_service.repository.delete_comparison_backtest_snapshots(version.version_id)
            return ManagedComparisonBacktestSnapshotBuildStatus(
                status="skipped",
                snapshot_count=0,
                message="공통 가격 구간이 없어 comparison backtest snapshot을 만들지 않았습니다.",
            )

        try:
            payload = self.calculation_adapter.build_materialized_comparison_backtest(
                data_source=SimulationDataSource.MANAGED_UNIVERSE,
            )
            line_count = len(list(payload.get("lines", [])))
            self.managed_universe_service.repository.upsert_comparison_backtest_snapshot(
                version_id=version.version_id,
                data_source=SimulationDataSource.MANAGED_UNIVERSE.value,
                aligned_start_date=price_window.aligned_start_date,
                aligned_end_date=price_window.aligned_end_date,
                line_count=line_count,
                payload=payload,
                source_refresh_job_id=source_refresh_job_id,
            )
            return ManagedComparisonBacktestSnapshotBuildStatus(
                status="success",
                snapshot_count=1,
                line_count=line_count,
                message=f"comparison backtest snapshot 갱신 완료 ({line_count} lines)",
            )
        except Exception:
            return ManagedComparisonBacktestSnapshotBuildStatus(
                status="failed",
                snapshot_count=0,
                message="comparison backtest snapshot 갱신에 실패했습니다.",
            )
