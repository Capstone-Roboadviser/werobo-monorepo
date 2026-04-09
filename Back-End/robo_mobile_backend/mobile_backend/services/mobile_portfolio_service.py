from __future__ import annotations

from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from mobile_backend.integrations.legacy_fastapi_demo import LegacyFastapiDemoAdapter
from mobile_backend.services.profile_service import ProfileService


class MobilePortfolioService:
    def __init__(self) -> None:
        self.profile_service = ProfileService()
        self.calculation_adapter = LegacyFastapiDemoAdapter()

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
        )

    def build_volatility_history(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
        rolling_window: int,
        weights: dict[str, float] | None = None,
    ) -> dict[str, object]:
        if weights is not None:
            return self.calculation_adapter.get_volatility_history_from_weights(
                weights=weights,
                data_source=data_source,
                rolling_window=rolling_window,
            )
        resolved_profile = self.profile_service.resolve_risk_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
        )
        return self.calculation_adapter.get_volatility_history(
            risk_profile=resolved_profile,
            investment_horizon=investment_horizon,
            data_source=data_source,
            rolling_window=rolling_window,
        )

    def build_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
    ) -> dict[str, object]:
        return self.calculation_adapter.get_comparison_backtest(
            data_source=data_source,
        )
