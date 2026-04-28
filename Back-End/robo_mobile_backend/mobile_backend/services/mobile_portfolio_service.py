from __future__ import annotations

from datetime import date

from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from mobile_backend.integrations.embedded_portfolio_engine import EmbeddedPortfolioEngineAdapter
from mobile_backend.services.profile_service import ProfileService


class MobilePortfolioService:
    def __init__(self) -> None:
        self.profile_service = ProfileService()
        self.calculation_adapter = EmbeddedPortfolioEngineAdapter()

    def resolve_profile(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
    ) -> dict[str, object]:
        return self.profile_service.build_resolved_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
            investment_horizon=investment_horizon,
        )

    def build_recommendation(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        as_of_date: date | None,
    ) -> dict[str, object]:
        resolved_profile = self.profile_service.resolve_risk_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
        )
        return self.calculation_adapter.build_recommendation(
            resolved_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            propensity_score=propensity_score,
            as_of_date=as_of_date,
        )

    def build_frontier_preview(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        sample_points: int,
        as_of_date: date | None,
    ) -> dict[str, object]:
        resolved_profile = self.profile_service.resolve_risk_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
        )
        return self.calculation_adapter.build_frontier_preview(
            resolved_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            propensity_score=propensity_score,
            sample_points=sample_points,
            as_of_date=as_of_date,
        )

    def build_frontier_selection(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        target_volatility: float | None,
        point_index: int | None,
        as_of_date: date | None,
    ) -> dict[str, object]:
        resolved_profile = self.profile_service.resolve_risk_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
        )
        return self.calculation_adapter.build_frontier_selection(
            resolved_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            propensity_score=propensity_score,
            target_volatility=target_volatility,
            point_index=point_index,
            as_of_date=as_of_date,
        )

    def build_volatility_history(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        rolling_window: int,
        stock_weights: dict[str, float] | None,
    ) -> dict[str, object]:
        resolved_profile = self.profile_service.resolve_risk_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
        )
        return self.calculation_adapter.get_volatility_history(
            risk_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            rolling_window=rolling_window,
            stock_weights=stock_weights,
        )

    def build_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
        stock_weights: dict[str, float] | None = None,
        portfolio_code: str | None = None,
        start_date: str | None = None,
    ) -> dict[str, object]:
        return self.calculation_adapter.get_comparison_backtest(
            data_source=data_source,
            stock_weights=stock_weights,
            portfolio_code=portfolio_code,
            start_date=start_date,
        )
