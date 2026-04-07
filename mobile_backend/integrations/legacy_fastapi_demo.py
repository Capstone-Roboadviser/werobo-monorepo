from __future__ import annotations

from mobile_backend.core.config import PROFILE_LABELS
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource


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
        from app.engine.frontier import select_frontier_point_index
        from app.engine.math import portfolio_metrics_from_weights, risk_contributions
        from app.services.portfolio_service import PortfolioSimulationService

        self.legacy_portfolio_routes = legacy_portfolio_routes
        self.LegacyComparisonBacktestRequest = LegacyComparisonBacktestRequest
        self.LegacyVolatilityHistoryRequest = LegacyVolatilityHistoryRequest
        self.LegacyInvestmentHorizon = LegacyInvestmentHorizon
        self.LegacyRiskProfile = LegacyRiskProfile
        self.LegacySimulationDataSource = LegacySimulationDataSource
        self.LegacyUserProfile = LegacyUserProfile
        self.select_frontier_point_index = select_frontier_point_index
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

    def _build_portfolio_snapshot(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        context = self._build_context(
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        legacy_user_profile = self._build_legacy_user_profile(
            risk_profile=risk_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
        )
        target_volatility = self.portfolio_service.mapping_service.resolve_target_volatility(
            legacy_user_profile
        )
        point_index = self.select_frontier_point_index(
            context.frontier_points,
            target_volatility,
        )
        point = context.frontier_points[point_index]

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

        instrument_by_ticker = {
            instrument.ticker.upper(): instrument for instrument in context.instruments
        }
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
            "code": risk_profile.value,
            "label": PROFILE_LABELS[risk_profile.value],
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

    def build_recommendation(
        self,
        *,
        resolved_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        propensity_score: float | None,
    ) -> dict[str, object]:
        portfolios = [
            self._build_portfolio_snapshot(
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
            "resolved_profile": {
                "code": resolved_profile.value,
                "label": PROFILE_LABELS[resolved_profile.value],
                "propensity_score": propensity_score,
                "target_volatility": resolved_target,
                "investment_horizon": investment_horizon.value,
            },
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

    def get_volatility_history(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        rolling_window: int,
    ) -> dict[str, object]:
        snapshot = self._build_portfolio_snapshot(
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
