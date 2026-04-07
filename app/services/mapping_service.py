from __future__ import annotations

from app.core.config import (
    DEFAULT_TARGET_VOLATILITY,
    HORIZON_VOLATILITY_ADJUSTMENT,
    TARGET_VOLATILITY_MAX,
    TARGET_VOLATILITY_MIN,
    TARGET_VOLATILITY_STEP,
)
from app.domain.models import UserProfile


class ProfileMappingService:
    @staticmethod
    def snap_target_volatility(value: float) -> float:
        snapped = TARGET_VOLATILITY_MIN + round((value - TARGET_VOLATILITY_MIN) / TARGET_VOLATILITY_STEP) * TARGET_VOLATILITY_STEP
        return float(min(max(snapped, TARGET_VOLATILITY_MIN), TARGET_VOLATILITY_MAX))

    def resolve_target_volatility(self, user_profile: UserProfile) -> float:
        if user_profile.target_volatility is not None:
            return self.snap_target_volatility(float(user_profile.target_volatility))

        base = DEFAULT_TARGET_VOLATILITY[user_profile.risk_profile]
        adjustment = HORIZON_VOLATILITY_ADJUSTMENT[user_profile.investment_horizon]
        return self.snap_target_volatility(base + adjustment)

    def build_portfolio_id(self, user_profile: UserProfile, target_volatility: float) -> str:
        compact_target = f"{int(round(target_volatility * 1000)):03d}"
        return f"{user_profile.risk_profile.value}-{user_profile.investment_horizon.value}-{compact_target}"
