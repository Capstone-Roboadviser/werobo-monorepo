from __future__ import annotations

from dataclasses import dataclass

import pandas as pd

from app.core.config import (
    FIXED_FIVE_PERCENT_ROLE_MARKET_RETURN_BASELINE,
    FIXED_FIVE_PERCENT_ROLE_MAX_POSITIVE_SPREAD,
    FIXED_FIVE_PERCENT_ROLE_SCENARIO_WEIGHTS,
    FIXED_FIVE_PERCENT_ROLE_SPREAD_CAPTURE_RATIO,
    FIXED_FIVE_PERCENT_ROLE_SPREAD_SCENARIOS,
)


@dataclass(frozen=True)
class SpreadScenario:
    p_success: float
    return_success: float
    p_fail: float
    return_fail: float


class FixedFivePercentRoleReturnService:
    """Conservative expected-return policy for the fixed 5% thematic basket role.

    This role intentionally does not extrapolate the basket's realized return
    series directly into optimizer expected returns. Instead it starts from a
    broad-equity market baseline and allows only a capped portion of the
    thematic basket's modeled excess spread to flow into the frontier.
    """

    RETURN_MODE = "conservative_market_spread_cap"

    def __init__(
        self,
        *,
        market_return_baseline: float = FIXED_FIVE_PERCENT_ROLE_MARKET_RETURN_BASELINE,
        spread_capture_ratio: float = FIXED_FIVE_PERCENT_ROLE_SPREAD_CAPTURE_RATIO,
        max_positive_spread: float = FIXED_FIVE_PERCENT_ROLE_MAX_POSITIVE_SPREAD,
        scenario_weights: dict[str, float] | None = None,
        spread_scenarios: dict[str, dict[str, float]] | None = None,
    ) -> None:
        self.market_return_baseline = float(market_return_baseline)
        self.spread_capture_ratio = float(spread_capture_ratio)
        self.max_positive_spread = float(max_positive_spread)
        self.scenario_weights = dict(
            FIXED_FIVE_PERCENT_ROLE_SCENARIO_WEIGHTS
            if scenario_weights is None
            else scenario_weights
        )
        raw_scenarios = (
            FIXED_FIVE_PERCENT_ROLE_SPREAD_SCENARIOS
            if spread_scenarios is None
            else spread_scenarios
        )
        self.spread_scenarios = {
            name: SpreadScenario(**payload)
            for name, payload in raw_scenarios.items()
        }
        self._validate_configuration()

    def conservative_expected_return(self) -> float:
        weighted_spread = 0.0
        for name, weight in self.scenario_weights.items():
            scenario = self.spread_scenarios[name]
            scenario_return = self._scenario_expected_return(scenario)
            weighted_spread += float(weight) * (
                float(scenario_return) - self.market_return_baseline
            )

        positive_spread = max(weighted_spread, 0.0)
        conservative_spread = min(
            positive_spread * self.spread_capture_ratio,
            self.max_positive_spread,
        )
        return self.market_return_baseline + conservative_spread

    def assign_expected_returns(
        self,
        expected_returns: pd.Series,
        *,
        target_codes: set[str],
    ) -> pd.Series:
        if expected_returns.empty or not target_codes:
            return expected_returns.astype(float)

        conservative_return = self.conservative_expected_return()
        updated = expected_returns.astype(float).copy()
        for code in target_codes:
            if code in updated.index:
                updated.loc[code] = conservative_return
        return updated.astype(float)

    def _validate_configuration(self) -> None:
        weight_total = float(sum(self.scenario_weights.values()))
        if abs(weight_total - 1.0) > 1e-8:
            raise ValueError("5% role scenario weights must sum to 1.")

        missing = set(self.scenario_weights) - set(self.spread_scenarios)
        if missing:
            missing_text = ", ".join(sorted(missing))
            raise ValueError(f"Missing 5% role spread scenarios: {missing_text}")

        for name, scenario in self.spread_scenarios.items():
            probability_total = float(scenario.p_success) + float(scenario.p_fail)
            if abs(probability_total - 1.0) > 1e-8:
                raise ValueError(
                    f"5% role scenario '{name}' must have success/fail probabilities summing to 1."
                )

    @staticmethod
    def _scenario_expected_return(scenario: SpreadScenario) -> float:
        return (
            float(scenario.p_success) * float(scenario.return_success)
            + float(scenario.p_fail) * float(scenario.return_fail)
        )
