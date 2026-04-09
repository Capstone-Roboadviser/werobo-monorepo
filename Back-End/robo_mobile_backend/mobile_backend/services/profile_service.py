from __future__ import annotations

from app.core.config import (
    DEFAULT_TARGET_VOLATILITY as CORE_DEFAULT_TARGET_VOLATILITY,
    HORIZON_VOLATILITY_ADJUSTMENT as CORE_HORIZON_VOLATILITY_ADJUSTMENT,
    TARGET_VOLATILITY_MAX,
    TARGET_VOLATILITY_MIN,
    TARGET_VOLATILITY_STEP,
)
from mobile_backend.core.config import PROFILE_LABELS
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile

DEFAULT_TARGET_VOLATILITY = {
    RiskProfile(key.value): value
    for key, value in CORE_DEFAULT_TARGET_VOLATILITY.items()
}

HORIZON_VOLATILITY_ADJUSTMENT = {
    InvestmentHorizon(key.value): value
    for key, value in CORE_HORIZON_VOLATILITY_ADJUSTMENT.items()
}


class ProfileService:
    @staticmethod
    def snap_target_volatility(value: float) -> float:
        snapped = TARGET_VOLATILITY_MIN + round((value - TARGET_VOLATILITY_MIN) / TARGET_VOLATILITY_STEP) * TARGET_VOLATILITY_STEP
        return float(min(max(snapped, TARGET_VOLATILITY_MIN), TARGET_VOLATILITY_MAX))

    @staticmethod
    def resolve_risk_profile(
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
    ) -> RiskProfile:
        if explicit_profile is not None:
            return explicit_profile
        if propensity_score is None:
            raise ValueError("propensity_score 또는 risk_profile 중 하나는 반드시 제공해야 합니다.")
        if propensity_score <= 33.33:
            return RiskProfile.CONSERVATIVE
        if propensity_score <= 66.67:
            return RiskProfile.BALANCED
        return RiskProfile.GROWTH

    def resolve_target_volatility(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
    ) -> float:
        base = DEFAULT_TARGET_VOLATILITY[risk_profile]
        adjustment = HORIZON_VOLATILITY_ADJUSTMENT[investment_horizon]
        return self.snap_target_volatility(base + adjustment)

    def build_resolved_profile(
        self,
        *,
        propensity_score: float | None,
        explicit_profile: RiskProfile | None,
        investment_horizon: InvestmentHorizon,
    ) -> dict[str, str | float | None]:
        risk_profile = self.resolve_risk_profile(
            propensity_score=propensity_score,
            explicit_profile=explicit_profile,
        )
        return {
            "code": risk_profile.value,
            "label": PROFILE_LABELS[risk_profile.value],
            "propensity_score": propensity_score,
            "target_volatility": self.resolve_target_volatility(
                risk_profile=risk_profile,
                investment_horizon=investment_horizon,
            ),
            "investment_horizon": investment_horizon.value,
        }
