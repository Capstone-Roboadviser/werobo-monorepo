from __future__ import annotations

from datetime import date

import logging

from app.engine.rebalance import build_two_stage_rebalance_policy, serialize_rebalance_policy
from app.services.managed_universe_service import ManagedUniverseService
from mobile_backend.core.config import (
    MOBILE_REQUIRE_MANAGED_UNIVERSE_SNAPSHOTS,
    PROFILE_LABELS,
)
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from mobile_backend.services.profile_service import ProfileService

logger = logging.getLogger(__name__)


class EmbeddedPortfolioEngineAdapter:
    """Adapter for the embedded portfolio calculation core.

    The mobile backend keeps its own copy of the calculation packages under the
    local `app/` package. This adapter reshapes that internal engine output into
    mobile-focused response contracts.
    """

    FRONTIER_SNAPSHOT_SCHEMA_VERSION = 3
    REQUIRE_MANAGED_UNIVERSE_SNAPSHOTS = MOBILE_REQUIRE_MANAGED_UNIVERSE_SNAPSHOTS
    COMPARISON_BACKTEST_POLICY = serialize_rebalance_policy(
        build_two_stage_rebalance_policy()
    )

    def __init__(self, managed_universe_service: ManagedUniverseService | None = None) -> None:
        self.managed_universe_service = managed_universe_service or ManagedUniverseService()
        self.profile_service = ProfileService()
        self._load_calculation_modules()

    def _load_calculation_modules(self) -> None:
        from app.core.config import RISK_FREE_RATE
        from app.domain.enums import (
            InvestmentHorizon as CoreInvestmentHorizon,
            RiskProfile as CoreRiskProfile,
            SimulationDataSource as CoreSimulationDataSource,
        )
        from app.domain.models import UserProfile as CoreUserProfile
        from app.engine.frontier import build_frontier_options, select_frontier_point_index
        from app.engine.math import portfolio_metrics_from_weights, risk_contributions
        from app.services.portfolio_analytics_service import PortfolioAnalyticsService
        from app.services.portfolio_service import PortfolioSimulationService

        self.CoreInvestmentHorizon = CoreInvestmentHorizon
        self.CoreRiskProfile = CoreRiskProfile
        self.CoreSimulationDataSource = CoreSimulationDataSource
        self.CoreUserProfile = CoreUserProfile
        self.build_frontier_options = build_frontier_options
        self.select_frontier_point_index = select_frontier_point_index
        self.portfolio_metrics_from_weights = portfolio_metrics_from_weights
        self.risk_contributions = risk_contributions
        self.RISK_FREE_RATE = RISK_FREE_RATE
        self.portfolio_service = PortfolioSimulationService()
        self.portfolio_analytics_service = PortfolioAnalyticsService(
            portfolio_service=self.portfolio_service,
        )

    def _to_core_data_source(self, value: SimulationDataSource):
        return self.CoreSimulationDataSource(value.value)

    def _to_core_horizon(self, value: InvestmentHorizon):
        return self.CoreInvestmentHorizon(value.value)

    def _to_core_risk_profile(self, value: RiskProfile):
        return self.CoreRiskProfile(value.value)

    def _build_core_user_profile(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ):
        return self.CoreUserProfile(
            risk_profile=self._to_core_risk_profile(risk_profile),
            investment_horizon=self._to_core_horizon(investment_horizon),
            data_source=self._to_core_data_source(data_source),
        )

    def _build_context(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        as_of_date: date | None = None,
    ):
        return self.portfolio_service.build_engine_context(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )

    def _build_context_bundle(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        as_of_date: date | None = None,
    ):
        context = self._build_context(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        instrument_by_ticker = {
            instrument.ticker.upper(): instrument for instrument in context.instruments
        }
        return context, instrument_by_ticker

    @staticmethod
    def _serialize_as_of_date(as_of_date: date | None) -> str | None:
        return None if as_of_date is None else as_of_date.isoformat()

    def _build_portfolio_id(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        target_volatility: float,
        is_stock_combination: bool,
    ) -> str:
        core_user_profile = self._build_core_user_profile(
            risk_profile=risk_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        portfolio_id = self.portfolio_service.mapping_service.build_portfolio_id(
            core_user_profile,
            target_volatility,
        )
        if is_stock_combination:
            portfolio_id = f"stocks-{portfolio_id}"
        return portfolio_id

    def _build_portfolio_data_from_point(
        self,
        *,
        context,
        instrument_by_ticker,
        point,
    ) -> dict[str, object]:
        target_volatility = float(point.volatility)

        optimization_weights = self.portfolio_service.weights_for_optimization(
            point.weights,
            context.instruments,
        )
        metrics = self.portfolio_metrics_from_weights(
            optimization_weights,
            context.expected_returns,
            context.covariance,
            self.RISK_FREE_RATE,
        )
        contribution_map = self.risk_contributions(
            optimization_weights,
            context.covariance,
        )
        sector_allocations = self.portfolio_service.build_sector_allocations(
            stock_weights=point.weights,
            sector_risk_contributions=self.portfolio_service.aggregate_sector_risk_contributions(
                contribution_map,
                context.instruments,
            ),
            assets=context.assets,
            instruments=context.instruments,
        )

        stock_allocations = []
        for ticker, weight in sorted(point.weights.items(), key=lambda item: item[1], reverse=True):
            instrument = instrument_by_ticker.get(str(ticker).upper())
            stock_allocations.append(
                {
                    "ticker": str(ticker).upper(),
                    "name": instrument.name if instrument is not None else str(ticker).upper(),
                    "sector_code": instrument.sector_code if instrument is not None else "unknown",
                    "sector_name": instrument.sector_name if instrument is not None else "기타",
                    "weight": round(float(weight), 4),
                }
            )
        return {
            "target_volatility": round(float(target_volatility), 4),
            "expected_return": round(float(metrics.expected_return), 4),
            "volatility": round(float(metrics.volatility), 4),
            "sharpe_ratio": round(float(metrics.sharpe_ratio), 4),
            "sector_allocations": [
                {
                    "asset_code": item.asset_code,
                    "asset_name": item.asset_name,
                    "weight": round(float(item.weight), 4),
                    "risk_contribution": round(float(item.risk_contribution), 4),
                }
                for item in sector_allocations
            ],
            "stock_allocations": stock_allocations,
            "stock_weights": {str(k).upper(): float(v) for k, v in point.weights.items()},
        }

    def _build_portfolio_snapshot_from_point(
        self,
        *,
        context,
        instrument_by_ticker,
        point,
        portfolio_code: str,
        portfolio_label: str,
        portfolio_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        portfolio_data = self._build_portfolio_data_from_point(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            point=point,
        )
        return {
            "code": portfolio_code,
            "label": portfolio_label,
            "portfolio_id": self._build_portfolio_id(
                risk_profile=portfolio_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                target_volatility=float(portfolio_data["target_volatility"]),
                is_stock_combination=context.selected_combination is not None,
            ),
            **portfolio_data,
        }

    def _resolve_profile_target_volatility(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
    ) -> float:
        return float(
            self.profile_service.resolve_target_volatility(
                risk_profile=risk_profile,
                investment_horizon=investment_horizon,
            )
        )

    def _build_portfolio_snapshot_from_context(
        self,
        *,
        context,
        instrument_by_ticker,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        point = self._select_profile_option_point(
            context,
            risk_profile,
            investment_horizon=investment_horizon,
        )
        return self._build_portfolio_snapshot_from_point(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            point=point,
            portfolio_code=risk_profile.value,
            portfolio_label=PROFILE_LABELS[risk_profile.value],
            portfolio_profile=risk_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )

    def _select_profile_option_point(
        self,
        context,
        risk_profile: RiskProfile,
        *,
        investment_horizon: InvestmentHorizon,
    ):
        target_volatility = self._resolve_profile_target_volatility(
            risk_profile=risk_profile,
            investment_horizon=investment_horizon,
        )
        selected_index = self.select_frontier_point_index(
            context.frontier_points,
            target_volatility,
        )
        return context.frontier_points[selected_index]

    def _build_representative_index_map(
        self,
        context,
        *,
        investment_horizon: InvestmentHorizon,
    ) -> dict[RiskProfile, int]:
        index_map: dict[RiskProfile, int] = {}
        for profile in (
            RiskProfile.CONSERVATIVE,
            RiskProfile.BALANCED,
            RiskProfile.GROWTH,
        ):
            target_volatility = self._resolve_profile_target_volatility(
                risk_profile=profile,
                investment_horizon=investment_horizon,
            )
            index_map[profile] = self.select_frontier_point_index(
                context.frontier_points,
                target_volatility,
            )
        return index_map

    def _build_resolved_profile_payload(
        self,
        *,
        resolved_profile: RiskProfile,
        propensity_score: float | None,
        investment_horizon: InvestmentHorizon,
        target_volatility: float,
    ) -> dict[str, object]:
        return {
            "code": resolved_profile.value,
            "label": PROFILE_LABELS[resolved_profile.value],
            "propensity_score": propensity_score,
            "target_volatility": round(float(target_volatility), 4),
            "investment_horizon": investment_horizon.value,
        }

    def _build_preview_indices(
        self,
        *,
        total_point_count: int,
        sample_points: int | None,
        highlighted_indices: set[int],
    ) -> list[int]:
        if total_point_count <= 0:
            return []
        if sample_points is None or total_point_count <= sample_points:
            return list(range(total_point_count))

        sampled_indices = {
            int(round(position * (total_point_count - 1) / (sample_points - 1)))
            for position in range(sample_points)
        }
        sampled_indices.update(highlighted_indices)
        return sorted(sampled_indices)

    def _resolve_selected_point_index(
        self,
        *,
        total_point_count: int,
        point_index: int | None,
        target_volatility: float | None,
        frontier_points=None,
    ) -> int:
        if total_point_count <= 0:
            raise RuntimeError("frontier 포인트가 비어 있습니다.")
        if point_index is not None:
            if point_index < 0 or point_index >= total_point_count:
                raise ValueError(f"selected_point_index는 0 이상 {total_point_count - 1} 이하여야 합니다.")
            return point_index
        if target_volatility is None:
            raise ValueError("target_volatility 또는 selected_point_index 중 하나는 반드시 제공해야 합니다.")
        if frontier_points is None:
            raise RuntimeError("target_volatility 기반 선택에는 frontier_points가 필요합니다.")
        if frontier_points and isinstance(frontier_points[0], dict):
            return min(
                range(total_point_count),
                key=lambda idx: abs(float(frontier_points[idx]["volatility"]) - target_volatility),
            )
        return self.select_frontier_point_index(
            frontier_points,
            target_volatility,
        )

    def _point_key(
        self,
        *,
        snapshot_id: int | None,
        selected_point_index: int,
    ) -> str:
        if snapshot_id is None:
            return f"live:{selected_point_index}"
        return f"snapshot-{snapshot_id}:{selected_point_index}"

    def _log_managed_universe_snapshot_lookup(
        self,
        *,
        operation: str,
        investment_horizon: InvestmentHorizon | None,
        status: str,
        lookup: dict[str, object],
    ) -> None:
        fields = [
            f"operation={operation}",
            f"status={status}",
            "dataSource=managed_universe",
        ]
        if investment_horizon is not None:
            fields.append(f"horizon={investment_horizon.value}")
        for key in (
            "reason",
            "as_of_date",
            "version_id",
            "version_name",
            "aligned_start_date",
            "aligned_end_date",
            "snapshot_aligned_start_date",
            "snapshot_aligned_end_date",
            "snapshot_point_count",
            "snapshot_line_count",
            "snapshot_updated_at",
        ):
            value = lookup.get(key)
            if value is None or value == "":
                continue
            fields.append(f"{key}={value}")
        logger.info("[WeRobo.Cache] %s", " ".join(fields))

    def _get_managed_universe_snapshot_payload(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> tuple[dict[str, object] | None, dict[str, object]]:
        if data_source != SimulationDataSource.MANAGED_UNIVERSE:
            return None, {"reason": "non_managed_universe"}
        if not self.managed_universe_service.is_configured():
            return None, {"reason": "database_not_configured"}

        active_version = self.managed_universe_service.get_active_version()
        if active_version is None:
            return None, {"reason": "active_version_missing"}

        lookup: dict[str, object] = {
            "version_id": active_version.version_id,
            "version_name": active_version.version_name,
        }

        instruments = self.managed_universe_service.get_instruments_for_version(active_version.version_id)
        if not instruments:
            lookup["reason"] = "active_version_has_no_instruments"
            return None, lookup

        price_window = self.managed_universe_service.get_price_window(active_version.version_id, instruments)
        if price_window is None:
            lookup["reason"] = "price_window_missing"
            return None, lookup
        lookup["aligned_start_date"] = price_window.aligned_start_date
        lookup["aligned_end_date"] = price_window.aligned_end_date

        snapshot = self.managed_universe_service.repository.get_frontier_snapshot(
            version_id=active_version.version_id,
            data_source=data_source.value,
            investment_horizon=investment_horizon.value,
        )
        if snapshot is None:
            lookup["reason"] = "frontier_snapshot_missing"
            return None, lookup
        lookup["snapshot_aligned_start_date"] = snapshot.aligned_start_date
        lookup["snapshot_aligned_end_date"] = snapshot.aligned_end_date
        lookup["snapshot_point_count"] = snapshot.total_point_count
        lookup["snapshot_updated_at"] = snapshot.updated_at
        schema_version = int(snapshot.payload.get("schema_version", 0))
        lookup["snapshot_schema_version"] = schema_version
        if snapshot.aligned_start_date != price_window.aligned_start_date:
            lookup["reason"] = "aligned_start_date_mismatch"
            return None, lookup
        if snapshot.aligned_end_date != price_window.aligned_end_date:
            lookup["reason"] = "aligned_end_date_mismatch"
            return None, lookup
        if schema_version != self.FRONTIER_SNAPSHOT_SCHEMA_VERSION:
            lookup["reason"] = "frontier_snapshot_schema_mismatch"
            return None, lookup
        lookup["reason"] = "frontier_snapshot_reused"
        payload = dict(snapshot.payload)
        payload["_snapshot_id"] = snapshot.snapshot_id
        return payload, lookup

    def _resolve_managed_universe_snapshot_lookup(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        as_of_date: date | None = None,
    ) -> tuple[dict[str, object] | None, dict[str, object]]:
        if as_of_date is not None:
            return None, {"reason": "historical_as_of_date_requested", "as_of_date": as_of_date.isoformat()}
        snapshot_lookup = self._get_managed_universe_snapshot_payload(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        if (
            isinstance(snapshot_lookup, tuple)
            and len(snapshot_lookup) == 2
            and isinstance(snapshot_lookup[1], dict)
        ):
            return snapshot_lookup
        if snapshot_lookup is None:
            return None, {"reason": "frontier_snapshot_missing"}
        return snapshot_lookup, {"reason": "frontier_snapshot_reused"}

    def _get_managed_universe_comparison_backtest_snapshot_payload(
        self,
        *,
        data_source: SimulationDataSource,
    ) -> tuple[dict[str, object] | None, dict[str, object]]:
        if data_source != SimulationDataSource.MANAGED_UNIVERSE:
            return None, {"reason": "non_managed_universe"}
        if not self.managed_universe_service.is_configured():
            return None, {"reason": "database_not_configured"}

        active_version = self.managed_universe_service.get_active_version()
        if active_version is None:
            return None, {"reason": "active_version_missing"}

        lookup: dict[str, object] = {
            "version_id": active_version.version_id,
            "version_name": active_version.version_name,
        }

        instruments = self.managed_universe_service.get_instruments_for_version(active_version.version_id)
        if not instruments:
            lookup["reason"] = "active_version_has_no_instruments"
            return None, lookup

        price_window = self.managed_universe_service.get_price_window(active_version.version_id, instruments)
        if price_window is None:
            lookup["reason"] = "price_window_missing"
            return None, lookup
        lookup["aligned_start_date"] = price_window.aligned_start_date
        lookup["aligned_end_date"] = price_window.aligned_end_date

        snapshot = self.managed_universe_service.repository.get_comparison_backtest_snapshot(
            version_id=active_version.version_id,
            data_source=data_source.value,
        )
        if snapshot is None:
            lookup["reason"] = "comparison_backtest_snapshot_missing"
            return None, lookup
        lookup["snapshot_aligned_start_date"] = snapshot.aligned_start_date
        lookup["snapshot_aligned_end_date"] = snapshot.aligned_end_date
        lookup["snapshot_line_count"] = snapshot.line_count
        lookup["snapshot_updated_at"] = snapshot.updated_at
        if snapshot.aligned_start_date != price_window.aligned_start_date:
            lookup["reason"] = "aligned_start_date_mismatch"
            return None, lookup
        if snapshot.aligned_end_date != price_window.aligned_end_date:
            lookup["reason"] = "aligned_end_date_mismatch"
            return None, lookup
        if not self._comparison_backtest_snapshot_has_required_lines(snapshot.payload):
            lookup["reason"] = "comparison_backtest_snapshot_missing_required_lines"
            return None, lookup
        lookup["reason"] = "comparison_backtest_snapshot_reused"
        return snapshot.payload, lookup

    def _resolve_managed_universe_comparison_backtest_snapshot_lookup(
        self,
        *,
        data_source: SimulationDataSource,
    ) -> tuple[dict[str, object] | None, dict[str, object]]:
        snapshot_lookup = self._get_managed_universe_comparison_backtest_snapshot_payload(
            data_source=data_source,
        )
        if (
            isinstance(snapshot_lookup, tuple)
            and len(snapshot_lookup) == 2
            and isinstance(snapshot_lookup[1], dict)
        ):
            return snapshot_lookup
        if snapshot_lookup is None:
            return None, {"reason": "comparison_backtest_snapshot_missing"}
        return snapshot_lookup, {"reason": "comparison_backtest_snapshot_reused"}

    def _comparison_backtest_snapshot_has_required_lines(
        self,
        snapshot_payload: dict[str, object],
    ) -> bool:
        raw_lines = snapshot_payload.get("lines", [])
        if not isinstance(raw_lines, list):
            return False
        line_keys = {
            str(line.get("key"))
            for line in raw_lines
            if isinstance(line, dict) and line.get("key") is not None
        }
        return {"benchmark_avg", "treasury"}.issubset(line_keys)

    def _raise_if_managed_universe_snapshot_required(
        self,
        *,
        snapshot_name: str,
        lookup: dict[str, object],
        data_source: SimulationDataSource,
        as_of_date: date | None = None,
    ) -> None:
        if data_source != SimulationDataSource.MANAGED_UNIVERSE:
            return
        if as_of_date is not None:
            return
        if not self.REQUIRE_MANAGED_UNIVERSE_SNAPSHOTS:
            return

        reason = str(lookup.get("reason") or "snapshot_unavailable")
        if reason in {"frontier_snapshot_missing", "comparison_backtest_snapshot_missing"}:
            guidance = "admin 가격 refresh를 먼저 실행해주세요."
        elif reason in {
            "aligned_start_date_mismatch",
            "aligned_end_date_mismatch",
            "frontier_snapshot_schema_mismatch",
            "comparison_backtest_snapshot_missing_required_lines",
        }:
            guidance = "admin 가격 refresh를 다시 실행해주세요."
        else:
            guidance = "관리자 유니버스 설정과 refresh 상태를 점검해주세요."

        raise RuntimeError(
            f"관리자 유니버스 {snapshot_name} snapshot이 준비되지 않았습니다. "
            f"{guidance} (reason={reason})"
        )

    def _build_snapshot_portfolio_response(
        self,
        *,
        portfolio_data: dict[str, object],
        portfolio_code: str,
        portfolio_label: str,
        portfolio_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        is_stock_combination: bool,
    ) -> dict[str, object]:
        return {
            "code": portfolio_code,
            "label": portfolio_label,
            "portfolio_id": self._build_portfolio_id(
                risk_profile=portfolio_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                target_volatility=float(portfolio_data["target_volatility"]),
                is_stock_combination=is_stock_combination,
            ),
            "target_volatility": portfolio_data["target_volatility"],
            "expected_return": portfolio_data["expected_return"],
            "volatility": portfolio_data["volatility"],
            "sharpe_ratio": portfolio_data["sharpe_ratio"],
            "sector_allocations": list(portfolio_data["sector_allocations"]),
            "stock_allocations": list(portfolio_data["stock_allocations"]),
        }

    def _build_recommendation_from_snapshot(
        self,
        *,
        snapshot_payload: dict[str, object],
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
    ) -> dict[str, object]:
        frontier_points = list(snapshot_payload["frontier_points"])
        representative_indices = {
            RiskProfile(code): int(index)
            for code, index in dict(snapshot_payload["representative_indices"]).items()
        }
        resolved_index = representative_indices[resolved_profile]
        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=float(frontier_points[resolved_index]["volatility"]),
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "portfolios": [],
        }

    def _build_frontier_preview_from_snapshot(
        self,
        *,
        snapshot_payload: dict[str, object],
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
        sample_points: int | None,
    ) -> dict[str, object]:
        frontier_points = list(snapshot_payload["frontier_points"])
        representative_indices = {
            RiskProfile(code): int(index)
            for code, index in dict(snapshot_payload["representative_indices"]).items()
        }
        representative_index_lookup = {
            index: profile for profile, index in representative_indices.items()
        }
        recommended_index = representative_indices[resolved_profile]
        preview_indices = self._build_preview_indices(
            total_point_count=len(frontier_points),
            sample_points=sample_points,
            highlighted_indices=set(representative_indices.values()),
        )
        return {
            "snapshot_id": snapshot_payload.get("_snapshot_id"),
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=float(frontier_points[recommended_index]["volatility"]),
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "total_point_count": len(frontier_points),
            "min_volatility": float(frontier_points[0]["volatility"]),
            "max_volatility": float(frontier_points[-1]["volatility"]),
            "points": [
                {
                    "index": int(frontier_points[index]["index"]),
                    "volatility": float(frontier_points[index]["volatility"]),
                    "expected_return": float(frontier_points[index]["expected_return"]),
                    "is_recommended": index == recommended_index,
                    "representative_code": None
                    if representative_index_lookup.get(index) is None
                    else representative_index_lookup[index].value,
                    "representative_label": None
                    if representative_index_lookup.get(index) is None
                    else PROFILE_LABELS[representative_index_lookup[index].value],
                    "sector_allocations": list(
                        dict(frontier_points[index].get("portfolio_data", {})).get(
                            "sector_allocations",
                            [],
                        )
                    ),
                }
                for index in preview_indices
            ],
        }

    def _build_frontier_selection_from_snapshot(
        self,
        *,
        snapshot_payload: dict[str, object],
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
        target_volatility: float | None,
        selected_point_index: int | None,
    ) -> dict[str, object]:
        frontier_points = list(snapshot_payload["frontier_points"])
        representative_indices = {
            RiskProfile(code): int(index)
            for code, index in dict(snapshot_payload["representative_indices"]).items()
        }
        selected_point_index = self._resolve_selected_point_index(
            total_point_count=len(frontier_points),
            point_index=selected_point_index,
            target_volatility=target_volatility,
            frontier_points=frontier_points,
        )
        representative_profile = min(
            representative_indices,
            key=lambda profile: abs(
                float(frontier_points[representative_indices[profile]]["volatility"])
                - float(frontier_points[selected_point_index]["volatility"])
            ),
        )
        selected_point = dict(frontier_points[selected_point_index])
        portfolio = self._build_snapshot_portfolio_response(
            portfolio_data=dict(selected_point["portfolio_data"]),
            portfolio_code="selected",
            portfolio_label="선택 포트폴리오",
            portfolio_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            is_stock_combination=bool(snapshot_payload.get("is_stock_combination")),
        )
        snapshot_id = snapshot_payload.get("_snapshot_id")
        return {
            "snapshot_id": snapshot_id,
            "point_key": self._point_key(
                snapshot_id=None if snapshot_id is None else int(snapshot_id),
                selected_point_index=selected_point_index,
            ),
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=float(selected_point["volatility"]),
            ),
            "data_source": data_source.value,
            "requested_target_volatility": round(
                float(target_volatility)
                if target_volatility is not None
                else float(selected_point["volatility"]),
                4,
            ),
            "selected_target_volatility": float(selected_point["volatility"]),
            "selected_point_index": selected_point_index,
            "total_point_count": len(frontier_points),
            "representative_code": representative_profile.value,
            "representative_label": PROFILE_LABELS[representative_profile.value],
            "portfolio": portfolio,
        }

    def build_materialized_frontier_snapshot(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        representative_indices = self._build_representative_index_map(
            context,
            investment_horizon=investment_horizon,
        )
        return {
            "schema_version": self.FRONTIER_SNAPSHOT_SCHEMA_VERSION,
            "is_stock_combination": context.selected_combination is not None,
            "total_point_count": len(context.frontier_points),
            "frontier_points": [
                {
                    "index": index,
                    "volatility": round(float(point.volatility), 4),
                    "expected_return": round(float(point.expected_return), 4),
                    "portfolio_data": self._build_portfolio_data_from_point(
                        context=context,
                        instrument_by_ticker=instrument_by_ticker,
                        point=point,
                    ),
                }
                for index, point in enumerate(context.frontier_points)
            ],
            "representative_indices": {
                profile.value: index for profile, index in representative_indices.items()
            },
            "representative_portfolios": {
                profile.value: {
                    key: value
                    for key, value in self._build_portfolio_snapshot_from_context(
                        context=context,
                        instrument_by_ticker=instrument_by_ticker,
                        risk_profile=profile,
                        investment_horizon=investment_horizon,
                        data_source=data_source,
                    ).items()
                    if key != "stock_weights"
                }
                for profile in (
                    RiskProfile.CONSERVATIVE,
                    RiskProfile.BALANCED,
                    RiskProfile.GROWTH,
                )
            },
        }

    def _build_portfolio_snapshot(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        return self._build_portfolio_snapshot_from_context(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            risk_profile=risk_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )

    def build_recommendation(
        self,
        *,
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
        as_of_date: date | None = None,
    ) -> dict[str, object]:
        snapshot_payload, snapshot_lookup = self._resolve_managed_universe_snapshot_lookup(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        if snapshot_payload is not None:
            if data_source == SimulationDataSource.MANAGED_UNIVERSE:
                self._log_managed_universe_snapshot_lookup(
                    operation="recommendation",
                    investment_horizon=investment_horizon,
                    status="hit",
                    lookup=snapshot_lookup,
                )
            return self._build_recommendation_from_snapshot(
                snapshot_payload=snapshot_payload,
                resolved_profile=resolved_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                propensity_score=propensity_score,
            )
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            self._log_managed_universe_snapshot_lookup(
                operation="recommendation",
                investment_horizon=investment_horizon,
                status="miss",
                lookup=snapshot_lookup,
            )
            self._raise_if_managed_universe_snapshot_required(
                snapshot_name="frontier",
                lookup=snapshot_lookup,
                data_source=data_source,
                as_of_date=as_of_date,
            )

        context, _ = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        representative_indices = self._build_representative_index_map(
            context,
            investment_horizon=investment_horizon,
        )
        resolved_target = context.frontier_points[representative_indices[resolved_profile]].volatility

        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=resolved_target,
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "as_of_date": self._serialize_as_of_date(as_of_date),
            "portfolios": [],
        }

    def build_frontier_preview(
        self,
        *,
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
        sample_points: int | None,
        as_of_date: date | None = None,
    ) -> dict[str, object]:
        snapshot_payload, snapshot_lookup = self._resolve_managed_universe_snapshot_lookup(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        if snapshot_payload is not None:
            if data_source == SimulationDataSource.MANAGED_UNIVERSE:
                self._log_managed_universe_snapshot_lookup(
                    operation="frontier_preview",
                    investment_horizon=investment_horizon,
                    status="hit",
                    lookup=snapshot_lookup,
                )
            return self._build_frontier_preview_from_snapshot(
                snapshot_payload=snapshot_payload,
                resolved_profile=resolved_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                propensity_score=propensity_score,
                sample_points=sample_points,
            )
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            self._log_managed_universe_snapshot_lookup(
                operation="frontier_preview",
                investment_horizon=investment_horizon,
                status="miss",
                lookup=snapshot_lookup,
            )
            self._raise_if_managed_universe_snapshot_required(
                snapshot_name="frontier",
                lookup=snapshot_lookup,
                data_source=data_source,
                as_of_date=as_of_date,
            )

        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        representative_indices = self._build_representative_index_map(
            context,
            investment_horizon=investment_horizon,
        )
        recommended_index = representative_indices[resolved_profile]
        representative_index_lookup = {
            index: profile for profile, index in representative_indices.items()
        }
        preview_indices = self._build_preview_indices(
            total_point_count=len(context.frontier_points),
            sample_points=sample_points,
            highlighted_indices=set(representative_indices.values()),
        )

        return {
            "snapshot_id": None,
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=self._resolve_profile_target_volatility(
                    risk_profile=resolved_profile,
                    investment_horizon=investment_horizon,
                ),
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "as_of_date": self._serialize_as_of_date(as_of_date),
            "total_point_count": len(context.frontier_points),
            "min_volatility": round(float(context.frontier_points[0].volatility), 4),
            "max_volatility": round(float(context.frontier_points[-1].volatility), 4),
            "points": [
                {
                    "index": index,
                    "volatility": round(float(context.frontier_points[index].volatility), 4),
                    "expected_return": round(float(context.frontier_points[index].expected_return), 4),
                    "is_recommended": index == recommended_index,
                    "representative_code": None
                    if representative_index_lookup.get(index) is None
                    else representative_index_lookup[index].value,
                    "representative_label": None
                    if representative_index_lookup.get(index) is None
                    else PROFILE_LABELS[representative_index_lookup[index].value],
                    "sector_allocations": list(
                        self._build_portfolio_data_from_point(
                            context=context,
                            instrument_by_ticker=instrument_by_ticker,
                            point=context.frontier_points[index],
                        )["sector_allocations"]
                    ),
                }
                for index in preview_indices
            ],
        }

    def build_frontier_selection(
        self,
        *,
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
        target_volatility: float | None,
        selected_point_index: int | None = None,
        point_index: int | None = None,
        as_of_date: date | None = None,
    ) -> dict[str, object]:
        requested_point_index = selected_point_index if selected_point_index is not None else point_index
        snapshot_payload, snapshot_lookup = self._resolve_managed_universe_snapshot_lookup(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        if snapshot_payload is not None:
            if data_source == SimulationDataSource.MANAGED_UNIVERSE:
                self._log_managed_universe_snapshot_lookup(
                    operation="frontier_selection",
                    investment_horizon=investment_horizon,
                    status="hit",
                    lookup=snapshot_lookup,
                )
            return self._build_frontier_selection_from_snapshot(
                snapshot_payload=snapshot_payload,
                resolved_profile=resolved_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                propensity_score=propensity_score,
                target_volatility=target_volatility,
                selected_point_index=requested_point_index,
            )
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            self._log_managed_universe_snapshot_lookup(
                operation="frontier_selection",
                investment_horizon=investment_horizon,
                status="miss",
                lookup=snapshot_lookup,
            )
            self._raise_if_managed_universe_snapshot_required(
                snapshot_name="frontier",
                lookup=snapshot_lookup,
                data_source=data_source,
                as_of_date=as_of_date,
            )

        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
            as_of_date=as_of_date,
        )
        selected_point_index = self._resolve_selected_point_index(
            total_point_count=len(context.frontier_points),
            point_index=requested_point_index,
            target_volatility=target_volatility,
            frontier_points=context.frontier_points,
        )
        representative_indices = self._build_representative_index_map(
            context,
            investment_horizon=investment_horizon,
        )
        representative_profile = min(
            representative_indices,
            key=lambda profile: abs(
                context.frontier_points[representative_indices[profile]].volatility
                - context.frontier_points[selected_point_index].volatility
            ),
        )
        snapshot = self._build_portfolio_snapshot_from_point(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            point=context.frontier_points[selected_point_index],
            portfolio_code="selected",
            portfolio_label="선택 포트폴리오",
            portfolio_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        return {
            "snapshot_id": None,
            "point_key": self._point_key(
                snapshot_id=None,
                selected_point_index=selected_point_index,
            ),
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=self._resolve_profile_target_volatility(
                    risk_profile=resolved_profile,
                    investment_horizon=investment_horizon,
                ),
            ),
            "data_source": data_source.value,
            "as_of_date": self._serialize_as_of_date(as_of_date),
            "requested_target_volatility": round(
                float(target_volatility)
                if target_volatility is not None
                else float(context.frontier_points[selected_point_index].volatility),
                4,
            ),
            "selected_target_volatility": round(
                float(context.frontier_points[selected_point_index].volatility),
                4,
            ),
            "selected_point_index": selected_point_index,
            "total_point_count": len(context.frontier_points),
            "representative_code": representative_profile.value,
            "representative_label": PROFILE_LABELS[representative_profile.value],
            "portfolio": {
                key: value
                for key, value in snapshot.items()
                if key != "stock_weights"
            },
        }

    def get_volatility_history(
        self,
        *,
        risk_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        rolling_window: int,
        stock_weights: dict[str, float] | None = None,
        target_volatility: float | None = None,
        selected_point_index: int | None = None,
    ) -> dict[str, object]:
        snapshot_id = None
        selected_volatility = None
        if stock_weights:
            snapshot = {
                "stock_weights": {
                    str(ticker).upper(): float(weight)
                    for ticker, weight in stock_weights.items()
                    if float(weight) > 0
                },
                "code": "selected",
                "label": "선택 포트폴리오",
            }
            if not snapshot["stock_weights"]:
                raise ValueError("stock_weights에 0보다 큰 비중이 하나 이상 있어야 합니다.")
        elif target_volatility is not None or selected_point_index is not None:
            selected = self._resolve_selected_frontier_point_data(
                investment_horizon=investment_horizon,
                data_source=data_source,
                target_volatility=target_volatility,
                selected_point_index=selected_point_index,
            )
            snapshot_id = selected["snapshot_id"]
            selected_point_index = selected["selected_point_index"]
            selected_volatility = selected["selected_target_volatility"]
            snapshot = {
                "stock_weights": selected["stock_weights"],
                "code": "selected",
                "label": "선택 포트폴리오",
            }
        else:
            if risk_profile is None:
                raise ValueError("risk_profile 또는 frontier selector가 필요합니다.")
            context, instrument_by_ticker = self._build_context_bundle(
                investment_horizon=investment_horizon,
                data_source=data_source,
            )
            snapshot = self._build_portfolio_snapshot_from_context(
                context=context,
                instrument_by_ticker=instrument_by_ticker,
                risk_profile=risk_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
            )
        response = self.portfolio_analytics_service.build_volatility_history(
            weights=snapshot["stock_weights"],
            data_source=self._to_core_data_source(data_source),
            rolling_window=rolling_window,
        )

        portfolio_dates = {point.date for point in response.points}
        portfolio_points = [
            {"date": point.date, "volatility": point.value}
            for point in response.points
        ]

        # Compute equal-weight (1/N) benchmark volatility, isolated
        # so failures don't break the main response.
        benchmark_points: list[dict[str, object]] | None = None
        try:
            tickers = list(snapshot["stock_weights"].keys())
            equal_weights = {t: 1.0 / len(tickers) for t in tickers}
            bench_response = self.portfolio_analytics_service.build_volatility_history(
                weights=equal_weights,
                data_source=self._to_core_data_source(data_source),
                rolling_window=rolling_window,
            )
            # Inner join on dates: only include dates present in both
            benchmark_points = [
                {"date": point.date, "volatility": point.value}
                for point in bench_response.points
                if point.date in portfolio_dates
            ]
        except Exception:
            benchmark_points = None

        return {
            "snapshot_id": snapshot_id,
            "selected_point_index": selected_point_index,
            "selected_target_volatility": None
            if selected_volatility is None
            else round(float(selected_volatility), 4),
            "portfolio_code": str(snapshot.get("code", risk_profile.value if risk_profile else "selected")),
            "portfolio_label": str(snapshot.get("label", PROFILE_LABELS[risk_profile.value] if risk_profile else "선택 포트폴리오")),
            "rolling_window": rolling_window,
            "earliest_data_date": response.earliest_data_date,
            "latest_data_date": response.latest_data_date,
            "points": portfolio_points,
            "benchmark_points": benchmark_points,
        }

    def get_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
        investment_horizon: InvestmentHorizon | None = None,
        target_volatility: float | None = None,
        selected_point_index: int | None = None,
        stock_weights: dict[str, float] | None = None,
        portfolio_code: str | None = None,
        start_date: str | None = None,
    ) -> dict[str, object]:
        selected_metadata: dict[str, object] = {}
        if not stock_weights and (target_volatility is not None or selected_point_index is not None):
            if investment_horizon is None:
                raise ValueError("selected frontier point 백테스트에는 investment_horizon이 필요합니다.")
            selected = self._resolve_selected_frontier_point_data(
                investment_horizon=investment_horizon,
                data_source=data_source,
                target_volatility=target_volatility,
                selected_point_index=selected_point_index,
            )
            stock_weights = selected["stock_weights"]
            portfolio_code = portfolio_code or "selected"
            selected_metadata = {
                "snapshot_id": selected["snapshot_id"],
                "selected_point_index": selected["selected_point_index"],
                "selected_target_volatility": round(float(selected["selected_target_volatility"]), 4),
            }

        if stock_weights:
            normalized_weights = {
                str(ticker).upper(): float(weight)
                for ticker, weight in stock_weights.items()
                if float(weight) > 0
            }
            if not normalized_weights:
                raise ValueError("stock_weights에 0보다 큰 비중이 하나 이상 있어야 합니다.")
            if data_source == SimulationDataSource.MANAGED_UNIVERSE:
                self._log_managed_universe_snapshot_lookup(
                    operation="comparison_backtest",
                    investment_horizon=None,
                    status="bypass",
                    lookup={
                        "reason": "selected_stock_weights",
                    },
                )
            response = self.build_materialized_comparison_backtest(
                data_source=data_source,
                stock_weights=normalized_weights,
                portfolio_code=portfolio_code,
                start_date=start_date,
            )
            return {**selected_metadata, **response}

        if start_date is not None:
            return self.build_materialized_comparison_backtest(
                data_source=data_source,
                start_date=start_date,
            )

        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            snapshot_payload, snapshot_lookup = self._resolve_managed_universe_comparison_backtest_snapshot_lookup(
                data_source=data_source,
            )
            if snapshot_payload is not None:
                self._log_managed_universe_snapshot_lookup(
                    operation="comparison_backtest",
                    investment_horizon=None,
                    status="hit",
                    lookup=snapshot_lookup,
                )
                return self._build_comparison_backtest_from_snapshot(
                    snapshot_payload=snapshot_payload,
                )
            self._log_managed_universe_snapshot_lookup(
                operation="comparison_backtest",
                investment_horizon=None,
                status="miss",
                lookup=snapshot_lookup,
            )
            self._raise_if_managed_universe_snapshot_required(
                snapshot_name="comparison backtest",
                lookup=snapshot_lookup,
                data_source=data_source,
            )
        return self.build_materialized_comparison_backtest(
            data_source=data_source,
        )

    def _resolve_selected_frontier_point_data(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        target_volatility: float | None,
        selected_point_index: int | None,
    ) -> dict[str, object]:
        snapshot_payload, _ = self._get_managed_universe_snapshot_payload(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        if snapshot_payload is not None:
            frontier_points = list(snapshot_payload["frontier_points"])
            resolved_index = self._resolve_selected_point_index(
                total_point_count=len(frontier_points),
                point_index=selected_point_index,
                target_volatility=target_volatility,
                frontier_points=frontier_points,
            )
            selected_point = dict(frontier_points[resolved_index])
            portfolio_data = dict(selected_point.get("portfolio_data", {}))
            raw_stock_weights = portfolio_data.get("stock_weights")
            if isinstance(raw_stock_weights, dict):
                return {
                    "snapshot_id": snapshot_payload.get("_snapshot_id"),
                    "selected_point_index": resolved_index,
                    "selected_target_volatility": float(selected_point["volatility"]),
                    "expected_return": float(
                        selected_point.get(
                            "expected_return",
                            portfolio_data.get("expected_return", 0.0),
                        )
                    ),
                    "stock_weights": {
                        str(ticker).upper(): float(weight)
                        for ticker, weight in raw_stock_weights.items()
                    },
                }

        context, _ = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        resolved_index = self._resolve_selected_point_index(
            total_point_count=len(context.frontier_points),
            point_index=selected_point_index,
            target_volatility=target_volatility,
            frontier_points=context.frontier_points,
        )
        selected_point = context.frontier_points[resolved_index]
        return {
            "snapshot_id": None,
            "selected_point_index": resolved_index,
            "selected_target_volatility": float(selected_point.volatility),
            "expected_return": float(selected_point.expected_return),
            "stock_weights": {
                str(ticker).upper(): float(weight)
                for ticker, weight in selected_point.weights.items()
            },
        }

    def build_materialized_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
        stock_weights: dict[str, float] | None = None,
        portfolio_code: str | None = None,
        start_date: str | None = None,
    ) -> dict[str, object]:
        response = self.portfolio_analytics_service.build_comparison_backtest(
            data_source=self._to_core_data_source(data_source),
            stock_weights=stock_weights,
            portfolio_code=portfolio_code,
            start_date=start_date,
        )
        return {
            "train_start_date": response.train_start_date,
            "train_end_date": response.train_end_date,
            "test_start_date": response.test_start_date,
            "start_date": response.start_date,
            "end_date": response.end_date,
            "split_ratio": response.split_ratio,
            "rebalance_dates": response.rebalance_dates,
            "rebalance_policy": dict(self.COMPARISON_BACKTEST_POLICY),
            "lines": [
                {
                    "key": line.key,
                    "label": line.label,
                    "color": line.color,
                    "style": line.style,
                    "points": [
                        self._serialize_comparison_point(point)
                        for point in line.points
                    ],
                }
                for line in response.lines
            ],
        }

    def _build_comparison_backtest_from_snapshot(
        self,
        *,
        snapshot_payload: dict[str, object],
    ) -> dict[str, object]:
        raw_policy = snapshot_payload.get("rebalance_policy")
        rebalance_policy = (
            dict(raw_policy)
            if isinstance(raw_policy, dict)
            else dict(self.COMPARISON_BACKTEST_POLICY)
        )
        return {
            "train_start_date": str(snapshot_payload["train_start_date"]),
            "train_end_date": str(snapshot_payload["train_end_date"]),
            "test_start_date": str(snapshot_payload["test_start_date"]),
            "start_date": str(snapshot_payload["start_date"]),
            "end_date": str(snapshot_payload["end_date"]),
            "split_ratio": float(snapshot_payload["split_ratio"]),
            "rebalance_dates": list(snapshot_payload.get("rebalance_dates", [])),
            "rebalance_policy": rebalance_policy,
            "lines": [
                {
                    "key": str(line["key"]),
                    "label": str(line["label"]),
                    "color": str(line["color"]),
                    "style": str(line["style"]),
                    "points": [
                        {
                            "date": str(point["date"]),
                            "return_pct": float(point["return_pct"]),
                        }
                        for point in list(line.get("points", []))
                    ],
                }
                for line in list(snapshot_payload.get("lines", []))
            ],
        }

    @staticmethod
    def _serialize_comparison_point(point: object) -> dict[str, object]:
        if hasattr(point, "date") and hasattr(point, "return_pct"):
            return {
                "date": getattr(point, "date"),
                "return_pct": getattr(point, "return_pct"),
            }
        if isinstance(point, (tuple, list)) and len(point) == 2:
            return {
                "date": point[0],
                "return_pct": point[1],
            }
        raise TypeError(f"Unsupported comparison point type: {type(point).__name__}")
