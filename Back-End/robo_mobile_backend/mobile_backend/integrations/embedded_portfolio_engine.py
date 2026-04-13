from __future__ import annotations

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
    ):
        return self.portfolio_service.build_engine_context(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )

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
        sample_points: int,
        highlighted_indices: set[int],
    ) -> list[int]:
        if total_point_count <= 0:
            return []
        if total_point_count <= sample_points:
            return list(range(total_point_count))

        sampled_indices = {
            int(round(position * (total_point_count - 1) / (sample_points - 1)))
            for position in range(sample_points)
        }
        sampled_indices.update(highlighted_indices)
        return sorted(sampled_indices)

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
        return snapshot.payload

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
        representative_portfolios = dict(snapshot_payload["representative_portfolios"])
        resolved_target = float(representative_portfolios[resolved_profile.value]["target_volatility"])
        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=resolved_target,
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "portfolios": [
                dict(representative_portfolios[profile.value])
                for profile in (
                    RiskProfile.CONSERVATIVE,
                    RiskProfile.BALANCED,
                    RiskProfile.GROWTH,
                )
            ],
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
        target_volatility: float,
    ) -> dict[str, object]:
        frontier_points = list(snapshot_payload["frontier_points"])
        representative_indices = {
            RiskProfile(code): int(index)
            for code, index in dict(snapshot_payload["representative_indices"]).items()
        }
        selected_point_index = min(
            range(len(frontier_points)),
            key=lambda idx: abs(float(frontier_points[idx]["volatility"]) - target_volatility),
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
        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=float(
                    dict(snapshot_payload["representative_portfolios"])[resolved_profile.value]["target_volatility"]
                ),
            ),
            "data_source": data_source.value,
            "requested_target_volatility": round(float(target_volatility), 4),
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
                        if key != "stock_weights"
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

        # Recommendation cards share the same universe/context. Only the target
        # volatility selection changes per risk profile, so reuse the context once.
        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        portfolios = [
            self._build_portfolio_snapshot_from_context(
                context=context,
                instrument_by_ticker=instrument_by_ticker,
                risk_profile=profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
            )
            for profile in (
                RiskProfile.CONSERVATIVE,
                RiskProfile.BALANCED,
                RiskProfile.GROWTH,
            )
        ]

        resolved_target = next(
            portfolio["target_volatility"]
            for portfolio in portfolios
            if portfolio["code"] == resolved_profile.value
        )

        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=resolved_target,
            ),
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "portfolios": [
                {
                    key: value
                    for key, value in portfolio.items()
                    if key != "stock_weights"
                }
                for portfolio in portfolios
            ],
        }

    def build_frontier_preview(
        self,
        *,
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
        sample_points: int,
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
        target_volatility: float,
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
            )

        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        selected_point_index = self.select_frontier_point_index(
            context.frontier_points,
            target_volatility,
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
        return {
            "resolved_profile": self._build_resolved_profile_payload(
                resolved_profile=resolved_profile,
                propensity_score=propensity_score,
                investment_horizon=investment_horizon,
                target_volatility=context.frontier_points[representative_indices[resolved_profile]].volatility,
            ),
            "data_source": data_source.value,
            "requested_target_volatility": round(float(target_volatility), 4),
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
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        rolling_window: int,
    ) -> dict[str, object]:
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
            "portfolio_code": risk_profile.value,
            "portfolio_label": PROFILE_LABELS[risk_profile.value],
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
    ) -> dict[str, object]:
        response = self.portfolio_analytics_service.build_comparison_backtest(
            data_source=self._to_core_data_source(data_source),
        )
        return {
            "train_start_date": response.train_start_date,
            "train_end_date": response.train_end_date,
            "test_start_date": response.test_start_date,
            "start_date": response.start_date,
            "end_date": response.end_date,
            "split_ratio": response.split_ratio,
            "rebalance_dates": response.rebalance_dates,
            "lines": [
                {
                    "key": line.key,
                    "label": line.label,
                    "color": line.color,
                    "style": line.style,
                    "points": [
                        {
                            "date": point.date,
                            "return_pct": point.return_pct,
                        }
                        for point in line.points
                    ],
                }
                for line in response.lines
            ],
        }
