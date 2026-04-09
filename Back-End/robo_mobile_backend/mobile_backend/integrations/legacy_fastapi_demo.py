from __future__ import annotations

import logging

from mobile_backend.core.config import PROFILE_LABELS
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource

logger = logging.getLogger(__name__)


class LegacyFastapiDemoAdapter:
    """Adapter for the embedded portfolio calculation core.

    The mobile backend keeps its own copy of the calculation packages under the
    local `app/` package. This adapter reshapes that internal engine output into
    mobile-focused response contracts.
    """

    def __init__(self) -> None:
        self._load_legacy_modules()

    def _load_legacy_modules(self) -> None:
        from app.api.routes import portfolio as legacy_portfolio_routes
        from app.api.schemas.request import (
            ComparisonBacktestRequest as LegacyComparisonBacktestRequest,
            VolatilityHistoryRequest as LegacyVolatilityHistoryRequest,
        )
        from app.core.config import RISK_FREE_RATE
        from app.domain.enums import (
            InvestmentHorizon as LegacyInvestmentHorizon,
            RiskProfile as LegacyRiskProfile,
            SimulationDataSource as LegacySimulationDataSource,
        )
        from app.domain.models import UserProfile as LegacyUserProfile
        from app.engine.frontier import build_frontier_options, select_frontier_point_by_return
        from app.engine.math import portfolio_metrics_from_weights, risk_contributions
        from app.services.portfolio_service import PortfolioSimulationService

        self.legacy_portfolio_routes = legacy_portfolio_routes
        self.LegacyComparisonBacktestRequest = LegacyComparisonBacktestRequest
        self.LegacyVolatilityHistoryRequest = LegacyVolatilityHistoryRequest
        self.LegacyInvestmentHorizon = LegacyInvestmentHorizon
        self.LegacyRiskProfile = LegacyRiskProfile
        self.LegacySimulationDataSource = LegacySimulationDataSource
        self.LegacyUserProfile = LegacyUserProfile
        self.build_frontier_options = build_frontier_options
        self.select_frontier_point_by_return = select_frontier_point_by_return
        self.portfolio_metrics_from_weights = portfolio_metrics_from_weights
        self.risk_contributions = risk_contributions
        self.RISK_FREE_RATE = RISK_FREE_RATE
        self.portfolio_service = PortfolioSimulationService()

    def _to_legacy_data_source(self, value: SimulationDataSource):
        return self.LegacySimulationDataSource(value.value)

    def _to_legacy_horizon(self, value: InvestmentHorizon):
        return self.LegacyInvestmentHorizon(value.value)

    def _to_legacy_risk_profile(self, value: RiskProfile):
        return self.LegacyRiskProfile(value.value)

    def _build_legacy_user_profile(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ):
        return self.LegacyUserProfile(
            risk_profile=self._to_legacy_risk_profile(risk_profile),
            investment_horizon=self._to_legacy_horizon(investment_horizon),
            data_source=self._to_legacy_data_source(data_source),
        )

    def _build_context(
        self,
        *,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ):
        base_profile = self._build_legacy_user_profile(
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

    def _build_portfolio_snapshot_from_context(
        self,
        *,
        context,
        instrument_by_ticker,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        frontier_point=None,
        code_override: str | None = None,
        label_override: str | None = None,
    ) -> dict[str, object]:
        legacy_user_profile = self._build_legacy_user_profile(
            risk_profile=risk_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        point = frontier_point if frontier_point is not None else self._select_profile_option_point(context, risk_profile)
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

        portfolio_id = self.portfolio_service.mapping_service.build_portfolio_id(
            legacy_user_profile,
            target_volatility,
        )
        if context.selected_combination is not None:
            portfolio_id = f"stocks-{portfolio_id}"

        return {
            "code": code_override if code_override is not None else risk_profile.value,
            "label": label_override if label_override is not None else PROFILE_LABELS[risk_profile.value],
            "portfolio_id": portfolio_id,
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
        context, instrument_by_ticker = self._build_context_bundle(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )

        # Build the selected profile's portfolio
        selected_snapshot = self._build_portfolio_snapshot_from_context(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            risk_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )

        # Find ±10% return deviation variants on the efficient frontier
        selected_return = float(selected_snapshot["expected_return"])
        lower_target = selected_return * 0.9
        higher_target = selected_return * 1.1

        frontier_points = context.frontier_points
        lower_idx = self.select_frontier_point_by_return(frontier_points, lower_target)
        higher_idx = self.select_frontier_point_by_return(frontier_points, higher_target)

        logger.info(
            "±10%% variants: selected_return=%.4f, "
            "lower_target=%.4f (idx=%d, actual=%.4f), "
            "higher_target=%.4f (idx=%d, actual=%.4f)",
            selected_return,
            lower_target, lower_idx, frontier_points[lower_idx].expected_return,
            higher_target, higher_idx, frontier_points[higher_idx].expected_return,
        )

        lower_snapshot = self._build_portfolio_snapshot_from_context(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            risk_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            frontier_point=frontier_points[lower_idx],
            code_override="lower_return",
            label_override="낮은 수익률",
        )

        higher_snapshot = self._build_portfolio_snapshot_from_context(
            context=context,
            instrument_by_ticker=instrument_by_ticker,
            risk_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            frontier_point=frontier_points[higher_idx],
            code_override="higher_return",
            label_override="높은 수익률",
        )

        portfolios = [lower_snapshot, selected_snapshot, higher_snapshot]

        return {
            "resolved_profile": {
                "code": resolved_profile.value,
                "label": PROFILE_LABELS[resolved_profile.value],
                "propensity_score": propensity_score,
                "target_volatility": selected_snapshot["target_volatility"],
                "investment_horizon": investment_horizon.value,
            },
            "recommended_portfolio_code": resolved_profile.value,
            "data_source": data_source.value,
            "portfolios": portfolios,
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
        response = self.legacy_portfolio_routes.volatility_history(
            self.LegacyVolatilityHistoryRequest(
                weights=snapshot["stock_weights"],
                data_source=self._to_legacy_data_source(data_source),
                rolling_window=rolling_window,
            )
        )
        return {
            "portfolio_code": risk_profile.value,
            "portfolio_label": PROFILE_LABELS[risk_profile.value],
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

    def get_volatility_history_from_weights(
        self,
        *,
        weights: dict[str, float],
        data_source: SimulationDataSource,
        rolling_window: int,
    ) -> dict[str, object]:
        response = self.legacy_portfolio_routes.volatility_history(
            self.LegacyVolatilityHistoryRequest(
                weights=weights,
                data_source=self._to_legacy_data_source(data_source),
                rolling_window=rolling_window,
            )
        )
        return {
            "portfolio_code": "custom",
            "portfolio_label": "사용자 포트폴리오",
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
    ) -> dict[str, object]:
        response = self.legacy_portfolio_routes.comparison_backtest(
            self.LegacyComparisonBacktestRequest(
                data_source=self._to_legacy_data_source(data_source),
            )
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
