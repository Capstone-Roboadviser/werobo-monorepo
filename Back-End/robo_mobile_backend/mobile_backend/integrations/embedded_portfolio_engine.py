from __future__ import annotations

import pandas as pd

from app.services.managed_universe_service import ManagedUniverseService
from mobile_backend.core.config import PROFILE_LABELS
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource


class EmbeddedPortfolioEngineAdapter:
    """Adapter for the embedded portfolio calculation core.

    The mobile backend keeps its own copy of the calculation packages under the
    local `app/` package. This adapter reshapes that internal engine output into
    mobile-focused response contracts.
    """

    def __init__(self, managed_universe_service: ManagedUniverseService | None = None) -> None:
        self.managed_universe_service = managed_universe_service or ManagedUniverseService()
        self._load_calculation_modules()

    def _load_calculation_modules(self) -> None:
        from app.api.routes import portfolio as core_portfolio_routes
        from app.api.schemas.request import (
            ComparisonBacktestRequest as CoreComparisonBacktestRequest,
            VolatilityHistoryRequest as CoreVolatilityHistoryRequest,
        )
        from app.core.config import RISK_FREE_RATE
        from app.domain.enums import (
            InvestmentHorizon as CoreInvestmentHorizon,
            RiskProfile as CoreRiskProfile,
            SimulationDataSource as CoreSimulationDataSource,
        )
        from app.domain.models import UserProfile as CoreUserProfile
        from app.engine.comparison import build_comparison
        from app.engine.frontier import build_frontier_options, select_frontier_point_index
        from app.engine.math import portfolio_metrics_from_weights, risk_contributions
        from app.services.portfolio_service import PortfolioSimulationService

        self.core_portfolio_routes = core_portfolio_routes
        self.CoreComparisonBacktestRequest = CoreComparisonBacktestRequest
        self.CoreVolatilityHistoryRequest = CoreVolatilityHistoryRequest
        self.CoreInvestmentHorizon = CoreInvestmentHorizon
        self.CoreRiskProfile = CoreRiskProfile
        self.CoreSimulationDataSource = CoreSimulationDataSource
        self.CoreUserProfile = CoreUserProfile
        self.build_comparison = build_comparison
        self.build_frontier_options = build_frontier_options
        self.select_frontier_point_index = select_frontier_point_index
        self.portfolio_metrics_from_weights = portfolio_metrics_from_weights
        self.risk_contributions = risk_contributions
        self.RISK_FREE_RATE = RISK_FREE_RATE
        self.portfolio_service = PortfolioSimulationService()

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
    ):
        base_profile = self._build_core_user_profile(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        return self.portfolio_service._prepare_context(base_profile)

    def _build_context_bundle(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ):
        context = self._build_context(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        instrument_by_ticker = {
            instrument.ticker.upper(): instrument for instrument in context.instruments
        }
        return context, instrument_by_ticker

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

        optimization_weights = self.portfolio_service._weights_for_optimization(
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
        sector_allocations = self.portfolio_service._build_sector_allocations(
            stock_weights=point.weights,
            sector_risk_contributions=contribution_map,
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

    def _build_portfolio_snapshot_from_context(
        self,
        *,
        context,
        instrument_by_ticker,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        point = self._select_profile_option_point(context, risk_profile)
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
    ):
        profile_keys = (
            RiskProfile.CONSERVATIVE,
            RiskProfile.BALANCED,
            RiskProfile.GROWTH,
        )
        option_points = self.build_frontier_options(context.frontier_points)
        point_map = {
            profile: point
            for profile, (_, point) in zip(profile_keys, option_points)
        }
        point = point_map.get(risk_profile)
        if point is None:
            raise RuntimeError(f"{risk_profile.value} 대표 포트폴리오 포인트를 찾지 못했습니다.")
        return point

    def _build_representative_index_map(self, context) -> dict[RiskProfile, int]:
        profile_keys = (
            RiskProfile.CONSERVATIVE,
            RiskProfile.BALANCED,
            RiskProfile.GROWTH,
        )
        option_points = self.build_frontier_options(context.frontier_points)
        index_map: dict[RiskProfile, int] = {}
        for profile, (_, point) in zip(profile_keys, option_points):
            index_map[profile] = self.select_frontier_point_index(
                context.frontier_points,
                float(point.volatility),
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
        if sample_points is None:
            return list(range(total_point_count))
        if total_point_count <= sample_points:
            return list(range(total_point_count))

        sampled_indices = {
            int(round(position * (total_point_count - 1) / (sample_points - 1)))
            for position in range(sample_points)
        }
        sampled_indices.update(highlighted_indices)
        return sorted(sampled_indices)

    def _volatility_for_point(self, point) -> float:
        if isinstance(point, dict):
            return float(point["volatility"])
        return float(point.volatility)

    def _select_frontier_point_index(
        self,
        frontier_points: list[object],
        *,
        target_volatility: float | None,
        selected_point_index: int | None,
    ) -> int:
        if not frontier_points:
            raise ValueError("frontier 포인트가 비어 있습니다.")
        if selected_point_index is not None:
            index = int(selected_point_index)
            if index < 0 or index >= len(frontier_points):
                raise ValueError(
                    f"selected_point_index는 0 이상 {len(frontier_points) - 1} 이하이어야 합니다."
                )
            return index
        if target_volatility is None:
            raise ValueError("target_volatility 또는 selected_point_index 중 하나는 반드시 제공해야 합니다.")
        return min(
            range(len(frontier_points)),
            key=lambda idx: abs(self._volatility_for_point(frontier_points[idx]) - float(target_volatility)),
        )

    def _point_key(self, *, snapshot_id: object | None, selected_point_index: int) -> str:
        if snapshot_id is None:
            return f"live:{selected_point_index}"
        return f"snapshot-{int(snapshot_id)}:{selected_point_index}"

    def _get_managed_universe_snapshot_payload(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object] | None:
        if data_source != SimulationDataSource.MANAGED_UNIVERSE:
            return None
        if not self.managed_universe_service.is_configured():
            return None

        active_version = self.managed_universe_service.get_active_version()
        if active_version is None:
            return None

        instruments = self.managed_universe_service.get_instruments_for_version(active_version.version_id)
        if not instruments:
            return None

        price_window = self.managed_universe_service.get_price_window(active_version.version_id, instruments)
        if price_window is None:
            return None

        snapshot = self.managed_universe_service.repository.get_frontier_snapshot(
            version_id=active_version.version_id,
            data_source=data_source.value,
            investment_horizon=investment_horizon.value,
        )
        if snapshot is None:
            return None
        if snapshot.aligned_start_date != price_window.aligned_start_date:
            return None
        if snapshot.aligned_end_date != price_window.aligned_end_date:
            return None
        payload = dict(snapshot.payload)
        payload["_snapshot_id"] = snapshot.snapshot_id
        return payload

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
        resolved_target = float(frontier_points[representative_indices[resolved_profile]]["volatility"])
        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=resolved_target,
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
        sample_points: int,
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
        selected_point_index = self._select_frontier_point_index(
            frontier_points,
            target_volatility=target_volatility,
            selected_point_index=selected_point_index,
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
        selected_volatility = float(selected_point["volatility"])
        requested_volatility = selected_volatility if target_volatility is None else float(target_volatility)
        snapshot_id = snapshot_payload.get("_snapshot_id")
        return {
            "snapshot_id": snapshot_id,
            "point_key": self._point_key(
                snapshot_id=snapshot_id,
                selected_point_index=selected_point_index,
            ),
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=selected_volatility,
            ),
            "data_source": data_source.value,
            "requested_target_volatility": round(requested_volatility, 4),
            "selected_target_volatility": selected_volatility,
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
        representative_indices = self._build_representative_index_map(context)
        return {
            "is_stock_combination": context.selected_combination is not None,
            "total_point_count": len(context.frontier_points),
            "frontier_points": [
                {
                    "index": index,
                    "volatility": round(float(point.volatility), 4),
                    "expected_return": round(float(point.expected_return), 4),
                    "portfolio_data": {
                        key: value
                        for key, value in self._build_portfolio_data_from_point(
                            context=context,
                            instrument_by_ticker=instrument_by_ticker,
                            point=point,
                        ).items()
                    },
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
    ) -> dict[str, object]:
        snapshot_payload = self._get_managed_universe_snapshot_payload(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        if snapshot_payload is not None:
            return self._build_recommendation_from_snapshot(
                snapshot_payload=snapshot_payload,
                resolved_profile=resolved_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                propensity_score=propensity_score,
            )

        context, _ = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        representative_indices = self._build_representative_index_map(context)
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
    ) -> dict[str, object]:
        snapshot_payload = self._get_managed_universe_snapshot_payload(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        if snapshot_payload is not None:
            return self._build_frontier_preview_from_snapshot(
                snapshot_payload=snapshot_payload,
                resolved_profile=resolved_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                propensity_score=propensity_score,
                sample_points=sample_points,
            )

        context, _ = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        representative_indices = self._build_representative_index_map(context)
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
                target_volatility=context.frontier_points[recommended_index].volatility,
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
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
    ) -> dict[str, object]:
        snapshot_payload = self._get_managed_universe_snapshot_payload(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        if snapshot_payload is not None:
            return self._build_frontier_selection_from_snapshot(
                snapshot_payload=snapshot_payload,
                resolved_profile=resolved_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
                propensity_score=propensity_score,
                target_volatility=target_volatility,
                selected_point_index=selected_point_index,
            )

        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        selected_point_index = self._select_frontier_point_index(
            context.frontier_points,
            target_volatility=target_volatility,
            selected_point_index=selected_point_index,
        )
        representative_indices = self._build_representative_index_map(context)
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
        selected_volatility = float(context.frontier_points[selected_point_index].volatility)
        requested_volatility = selected_volatility if target_volatility is None else float(target_volatility)
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
                target_volatility=selected_volatility,
            ),
            "data_source": data_source.value,
            "requested_target_volatility": round(requested_volatility, 4),
            "selected_target_volatility": round(selected_volatility, 4),
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
        target_volatility: float | None = None,
        selected_point_index: int | None = None,
    ) -> dict[str, object]:
        snapshot_id = None
        selected_volatility = None
        stock_weights: dict[str, float] | None = None
        portfolio_code: str
        portfolio_label: str

        if target_volatility is not None or selected_point_index is not None:
            snapshot_payload = self._get_managed_universe_snapshot_payload(
                investment_horizon=investment_horizon,
                data_source=data_source,
            )
            if snapshot_payload is not None:
                frontier_points = list(snapshot_payload["frontier_points"])
                selected_point_index = self._select_frontier_point_index(
                    frontier_points,
                    target_volatility=target_volatility,
                    selected_point_index=selected_point_index,
                )
                selected_point = dict(frontier_points[selected_point_index])
                portfolio_data = dict(selected_point.get("portfolio_data", {}))
                raw_stock_weights = portfolio_data.get("stock_weights")
                if isinstance(raw_stock_weights, dict):
                    stock_weights = {
                        str(ticker).upper(): float(weight)
                        for ticker, weight in raw_stock_weights.items()
                    }
                    selected_volatility = float(selected_point["volatility"])
                    snapshot_id = snapshot_payload.get("_snapshot_id")

            if stock_weights is None:
                context, _ = self._build_context_bundle(
                    investment_horizon=investment_horizon,
                    data_source=data_source,
                )
                selected_point_index = self._select_frontier_point_index(
                    context.frontier_points,
                    target_volatility=target_volatility,
                    selected_point_index=selected_point_index,
                )
                selected_point = context.frontier_points[selected_point_index]
                stock_weights = {
                    str(ticker).upper(): float(weight)
                    for ticker, weight in selected_point.weights.items()
                }
                selected_volatility = float(selected_point.volatility)

            portfolio_code = "selected"
            portfolio_label = "선택 포트폴리오"
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
            stock_weights = snapshot["stock_weights"]
            portfolio_code = risk_profile.value
            portfolio_label = PROFILE_LABELS[risk_profile.value]

        response = self.core_portfolio_routes.volatility_history(
            self.CoreVolatilityHistoryRequest(
                weights=stock_weights,
                data_source=self._to_core_data_source(data_source),
                rolling_window=rolling_window,
            )
        )
        return {
            "snapshot_id": snapshot_id,
            "selected_point_index": selected_point_index,
            "selected_target_volatility": None
            if selected_volatility is None
            else round(float(selected_volatility), 4),
            "portfolio_code": portfolio_code,
            "portfolio_label": portfolio_label,
            "rolling_window": rolling_window,
            "earliest_data_date": response.earliest_data_date,
            "latest_data_date": response.latest_data_date,
            "points": [
                {
                    "date": point.date,
                    "volatility": point.volatility,
                }
                for point in response.points
            ],
        }

    def get_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
        investment_horizon: InvestmentHorizon,
        target_volatility: float | None,
        selected_point_index: int | None,
    ) -> dict[str, object]:
        selected = self._resolve_selected_frontier_point_data(
            investment_horizon=investment_horizon,
            data_source=data_source,
            target_volatility=target_volatility,
            selected_point_index=selected_point_index,
        )
        core_data_source = self._to_core_data_source(data_source)
        _, prices, _ = self.core_portfolio_routes._load_comparison_universe(core_data_source)
        prices = prices.copy()
        prices["date"] = pd.to_datetime(prices["date"]).dt.normalize()
        train_prices, test_prices, train_end_date, test_start_date = (
            self.core_portfolio_routes._split_prices_train_test(prices, split_ratio=0.9)
        )
        train_start_date = pd.Timestamp(train_prices["date"].min()).normalize()

        selected_weights = dict(selected["stock_weights"])
        selected_tickers = set(selected_weights)
        pivoted = (
            test_prices[test_prices["ticker"].astype(str).str.upper().isin(selected_tickers)]
            .pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last")
            .sort_index()
            .ffill()
            .dropna(how="any")
        )
        if pivoted.empty:
            raise RuntimeError("선택 포트폴리오 백테스트에 사용할 공통 가격 데이터를 만들지 못했습니다.")

        benchmark_series = self.core_portfolio_routes._fetch_benchmark_prices(
            test_start_date.strftime("%Y-%m-%d")
        )
        response = self.build_comparison(
            pivoted,
            {"selected": selected_weights},
            {"selected": float(selected["expected_return"])},
            benchmark_series,
            train_start_date=train_start_date.strftime("%Y-%m-%d"),
            train_end_date=train_end_date.strftime("%Y-%m-%d"),
            split_ratio=0.9,
        )
        return {
            "snapshot_id": selected["snapshot_id"],
            "selected_point_index": selected["selected_point_index"],
            "selected_target_volatility": round(float(selected["selected_target_volatility"]), 4),
            "train_start_date": response.train_start_date,
            "train_end_date": response.train_end_date,
            "test_start_date": response.test_start_date,
            "start_date": response.start_date,
            "end_date": response.end_date,
            "split_ratio": response.split_ratio,
            "rebalance_dates": response.rebalance_dates,
            "lines": [
                self._comparison_line_payload(line)
                for line in response.lines
            ],
        }

    def _resolve_selected_frontier_point_data(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        target_volatility: float | None,
        selected_point_index: int | None,
    ) -> dict[str, object]:
        snapshot_payload = self._get_managed_universe_snapshot_payload(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        if snapshot_payload is not None:
            frontier_points = list(snapshot_payload["frontier_points"])
            resolved_index = self._select_frontier_point_index(
                frontier_points,
                target_volatility=target_volatility,
                selected_point_index=selected_point_index,
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
        resolved_index = self._select_frontier_point_index(
            context.frontier_points,
            target_volatility=target_volatility,
            selected_point_index=selected_point_index,
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

    def _comparison_line_payload(self, line) -> dict[str, object]:
        key = str(line.key)
        label = str(line.label)
        color = str(line.color)
        if key == "selected":
            label = "선택 포트폴리오"
            color = "#20A7DB"
        elif key == "selected_expected":
            label = "선택 포트폴리오 기대수익"
            color = "#20A7DB"
        return {
            "key": key,
            "label": label,
            "color": color,
            "style": line.style,
            "points": [self._comparison_point_payload(point) for point in line.points],
        }

    def _comparison_point_payload(self, point) -> dict[str, object]:
        if isinstance(point, tuple):
            date, return_pct = point
        else:
            date = point.date
            return_pct = point.return_pct
        return {
            "date": date,
            "return_pct": return_pct,
        }
