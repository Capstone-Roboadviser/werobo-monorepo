from __future__ import annotations

import pytest
from pydantic import ValidationError

from mobile_backend.api.schemas.request import (
    ComparisonBacktestRequest,
    FrontierSelectionRequest,
    VolatilityHistoryRequest,
)


def test_frontier_selection_accepts_point_index_without_profile_bucket() -> None:
    request = FrontierSelectionRequest(
        investment_horizon="medium",
        data_source="managed_universe",
        selected_point_index=7,
    )

    assert request.propensity_score is None
    assert request.risk_profile is None
    assert request.target_volatility is None
    assert request.selected_point_index == 7


def test_volatility_history_accepts_continuous_selector_without_profile_bucket() -> None:
    request = VolatilityHistoryRequest(
        investment_horizon="medium",
        data_source="managed_universe",
        rolling_window=20,
        selected_point_index=3,
    )

    assert request.propensity_score is None
    assert request.risk_profile is None
    assert request.selected_point_index == 3


def test_comparison_backtest_requires_continuous_selector() -> None:
    with pytest.raises(ValidationError):
        ComparisonBacktestRequest(data_source="managed_universe")


def test_comparison_backtest_accepts_point_index_without_profile_bucket() -> None:
    request = ComparisonBacktestRequest(
        data_source="managed_universe",
        investment_horizon="medium",
        selected_point_index=11,
    )

    assert request.risk_profile is None
    assert request.selected_point_index == 11
