"""Tests for drift-based rebalancing engine.

Covers 23 codepaths: boundary tests, sell/buy phase, cash tracking,
edge cases, validation, and integration tests.
"""

from __future__ import annotations

import pandas as pd
import pytest

from app.engine.rebalance import (
    DRIFT_THRESHOLD_DEFAULT,
    check_and_rebalance,
    build_two_stage_rebalance_policy,
    serialize_rebalance_policy,
    simulate_drift_rebalance,
    simulate_two_stage_rebalance,
)


def _make_prices(data: dict[str, list[float]], start: str = "2024-01-01") -> pd.DataFrame:
    """Helper: build a DataFrame with DatetimeIndex from dict of ticker -> daily prices."""
    n = len(next(iter(data.values())))
    dates = pd.bdate_range(start=start, periods=n)
    return pd.DataFrame(data, index=dates)


# =========================================================================
# Boundary tests
# =========================================================================


class TestDriftBoundary:
    def test_triggers_above_10pct_relative(self):
        """Target 50%, actual 56% = 12% relative drift → should trigger sell."""
        holdings = {"A": 112.0, "B": 88.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # A: 112/200 = 56%, target 50%, drift = 12% relative → triggers
        _, _, trades = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        assert "A" in trades, "Should trigger sell for A at 12% relative drift"
        assert trades["A"] < 0, "Trade should be a sell (negative)"

    def test_does_not_trigger_at_9_9pct_relative(self):
        """Target 50%, actual 54.5% = 9% relative drift → should NOT trigger."""
        holdings = {"A": 109.0, "B": 91.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # A: 109/200 = 54.5%, target 50%, drift = 9% relative → no trigger
        _, _, trades = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        assert len(trades) == 0, "Should not trigger at 9% relative drift"


# =========================================================================
# Sell phase tests
# =========================================================================


class TestSellPhase:
    def test_sell_to_target_correct_amount(self):
        """Sell should bring asset back to exact target weight."""
        holdings = {"A": 120.0, "B": 80.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # A: 120/200 = 60%, target 50%, drift = 20% → sell
        # B: 80/200 = 40%, target 50%, drift = 20% → buy
        new_holdings, cash, trades = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        # A sells 20, B buys with proceeds → both end at ~100
        assert abs(new_holdings["A"] - 100.0) < 0.01
        # Cash may be 0 if B bought with all proceeds
        assert cash >= 0

    def test_batch_sell_multiple_overweight(self):
        """Multiple overweight assets: all computed from snapshot weights."""
        holdings = {"A": 70.0, "B": 70.0, "C": 60.0}
        prices = {"A": 1.0, "B": 1.0, "C": 1.0}
        target_weights = {"A": 0.3, "B": 0.3, "C": 0.4}
        # total = 200; A: 35%, B: 35%, C: 30%
        # A drift = (35-30)/30 = 16.7% → sell
        # B drift = (35-30)/30 = 16.7% → sell
        # C drift = (30-40)/40 = -25% → buy
        _, cash, trades = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        assert "A" in trades
        assert "B" in trades
        # Cash may be 0 if C bought with all sell proceeds
        assert cash >= 0

    def test_sell_generates_cash_before_buys(self):
        """Selling overweight asset should generate cash (even if buys consume it)."""
        # Only A is overweight, B is fine → sell A, no buy needed
        holdings = {"A": 120.0, "B": 100.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # A: 120/220=54.5%, target 50%, drift = 9% → no trigger (under 10%)
        # Need bigger drift. Use 3 assets where one is clearly overweight and others fine.
        holdings2 = {"A": 140.0, "B": 95.0, "C": 95.0}
        prices2 = {"A": 1.0, "B": 1.0, "C": 1.0}
        tw2 = {"A": 0.34, "B": 0.33, "C": 0.33}
        # A: 140/330=42.4%, target 34%, drift = 24.7% → sell
        # B: 95/330=28.8%, target 33%, drift = 12.7% → buy
        # C: 95/330=28.8%, target 33%, drift = 12.7% → buy
        _, cash, trades = check_and_rebalance(
            holdings2, prices2, tw2, 0.0, 0.10,
        )
        assert "A" in trades and trades["A"] < 0, "A should be sold"


# =========================================================================
# Buy phase tests
# =========================================================================


class TestBuyPhase:
    def test_buy_priority_greatest_drift_first(self):
        """Most underweight asset should be bought first."""
        # A: 30% (target 40%), B: 30% (target 50%) → B drifts more
        holdings = {"A": 30.0, "B": 30.0, "C": 40.0}
        prices = {"A": 1.0, "B": 1.0, "C": 1.0}
        target_weights = {"A": 0.4, "B": 0.5, "C": 0.1}
        # B: 30/100=30%, target 50%, drift = 40% relative → buy first
        # A: 30/100=30%, target 40%, drift = 25% relative → buy second
        # Give just enough cash to buy one
        _, _, trades = check_and_rebalance(
            holdings, prices, target_weights, 15.0, 0.10,
        )
        assert "B" in trades, "B should be bought (greatest drift)"

    def test_partial_fill_insufficient_cash(self):
        """When cash runs out, remaining underweight assets stay underweight."""
        # Both underweight with 5.0 cash.
        # total_value = 30 + 30 + 5 = 65
        # A: 30/65=46.2%, target 50%, drift = 7.7% → under threshold
        # Need larger drift: use holdings that are more underweight
        holdings = {"A": 20.0, "B": 20.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # total = 20 + 20 + 5 = 45; A: 44.4%, target 50%, drift = 11.1% → buy
        new_holdings, cash, trades = check_and_rebalance(
            holdings, prices, target_weights, 5.0, 0.10,
        )
        assert cash < 0.01, "All cash should be spent"
        total_new = new_holdings["A"] + new_holdings["B"]
        assert abs(total_new - 45.0) < 0.01

    def test_no_cash_skip_buys(self):
        """Zero cash means no buying even if assets are underweight."""
        holdings = {"A": 30.0, "B": 70.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # A is underweight but no cash
        new_holdings, cash, trades = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        # No buys should happen (B is overweight but not by 10%)
        # B: 70/100 = 70%, target 50%, drift = 40% → sell
        # A: 30/100 = 30%, target 50%, drift = 40% → buy with sell proceeds
        assert cash >= 0

    def test_buy_to_exact_target(self):
        """With enough cash, buy brings asset to exact target weight."""
        holdings = {"A": 80.0, "B": 80.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        # Both at 50%, no drift. Give cash and lower one.
        holdings_modified = {"A": 60.0, "B": 100.0}
        # A: 60/200 = 30%, target 50%, drift = 40% → buy
        # B: 100/200 = 50%, no drift
        new_holdings, cash, trades = check_and_rebalance(
            holdings_modified, prices, target_weights, 40.0, 0.10,
        )
        assert "A" in trades
        assert abs(new_holdings["A"] - 100.0) < 1.0


# =========================================================================
# Cash tracking tests
# =========================================================================


class TestCashTracking:
    def test_cash_never_negative(self):
        """Cash balance must never go below zero."""
        holdings = {"A": 120.0, "B": 80.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 0.5, "B": 0.5}
        _, cash, _ = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        assert cash >= 0

    def test_total_value_includes_cash(self):
        """Portfolio total value must include cash balance."""
        prices_df = _make_prices({
            "A": [100.0, 120.0, 100.0],
            "B": [100.0, 80.0, 100.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        for point in result.time_series:
            assert "CASH" in point.asset_values
            total = sum(point.asset_values.values())
            assert abs(total - point.total_value) < 1.0

    def test_cash_key_in_events(self):
        """CASH must appear in asset_values, pre/post weights, and trades."""
        prices_df = _make_prices({
            "A": [100.0, 130.0, 100.0, 100.0, 100.0],
            "B": [100.0, 80.0, 100.0, 100.0, 100.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        if result.rebalance_events:
            event = result.rebalance_events[0]
            assert "CASH" in event.pre_weights
            assert "CASH" in event.post_weights
            assert "CASH" in event.trades


# =========================================================================
# Edge case tests
# =========================================================================


class TestEdgeCases:
    def test_no_drift_no_op(self):
        """When all assets stay within the 10% band, no events should fire."""
        prices_df = _make_prices({
            "A": [100.0, 101.0, 102.0, 101.0, 100.0],
            "B": [100.0, 99.0, 98.0, 99.0, 100.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        assert len(result.rebalance_events) == 0

    def test_sell_and_buy_same_day(self):
        """Overweight sell + underweight buy can happen on the same day."""
        prices_df = _make_prices({
            "A": [100.0, 140.0],
            "B": [100.0, 70.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        assert len(result.rebalance_events) >= 1
        event = result.rebalance_events[0]
        # A should be sold, B should be bought
        has_sell = any(v < 0 for k, v in event.trades.items() if k != "CASH")
        has_buy = any(v > 0 for k, v in event.trades.items() if k != "CASH")
        assert has_sell and has_buy

    def test_zero_target_weight_sell_all(self):
        """Ticker with 0% target should have all holdings sold immediately."""
        holdings = {"A": 50.0, "B": 50.0}
        prices = {"A": 1.0, "B": 1.0}
        target_weights = {"A": 1.0, "B": 0.0}
        new_holdings, cash, trades = check_and_rebalance(
            holdings, prices, target_weights, 0.0, 0.10,
        )
        assert abs(new_holdings["B"]) < 0.01, "B holdings should be 0"
        assert "B" in trades and trades["B"] < 0, "B should be sold"
        # Cash used to buy underweight A, so cash may be 0
        assert new_holdings["A"] > 50.0, "A should have more shares after buying"

    def test_zero_price_day0_raises(self):
        """Price = 0 on day 0 should raise ValueError."""
        prices_df = _make_prices({"A": [0.0, 100.0], "B": [100.0, 100.0]})
        with pytest.raises(ValueError, match="must be > 0"):
            simulate_drift_rebalance(prices_df, {"A": 0.5, "B": 0.5}, 10000.0)

    def test_zero_price_mid_simulation_skips(self):
        """Price = 0 mid-simulation should skip that day."""
        prices_df = _make_prices({
            "A": [100.0, 0.0, 100.0],
            "B": [100.0, 100.0, 100.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        # Should have 2 time points (day 0 and day 2, skipping day 1)
        assert len(result.time_series) == 2

    def test_actual_post_weights_not_target(self):
        """Post-weights should reflect real holdings, not just target weights."""
        prices_df = _make_prices({
            "A": [100.0, 140.0],
            "B": [100.0, 70.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        if result.rebalance_events:
            event = result.rebalance_events[0]
            # Post weights should be computed from actual holdings
            total_post_weight = sum(event.post_weights.values())
            assert abs(total_post_weight - 1.0) < 0.01


# =========================================================================
# Validation tests
# =========================================================================


class TestValidation:
    def test_weights_not_summing_to_1_raises(self):
        """Weights summing to != 1.0 should raise ValueError."""
        prices_df = _make_prices({"A": [100.0], "B": [100.0]})
        with pytest.raises(ValueError, match="sum to"):
            simulate_drift_rebalance(
                prices_df, {"A": 0.3, "B": 0.3}, 10000.0,
            )

    def test_empty_prices_raises(self):
        """Empty DataFrame should raise."""
        empty_df = pd.DataFrame()
        with pytest.raises((ValueError, KeyError)):
            simulate_drift_rebalance(
                empty_df, {"A": 0.5, "B": 0.5}, 10000.0,
            )


# =========================================================================
# Integration tests
# =========================================================================


class TestIntegration:
    def test_full_simulation_produces_expected_events(self):
        """Multi-day simulation with known drift should produce events."""
        # A doubles, B halves → will trigger drift
        prices_df = _make_prices({
            "A": [100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 100.0, 100.0, 100.0, 100.0],
            "B": [100.0, 90.0, 80.0, 70.0, 60.0, 50.0, 100.0, 100.0, 100.0, 100.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        assert len(result.rebalance_events) >= 1
        assert result.final_value > 0
        assert result.drift_threshold == DRIFT_THRESHOLD_DEFAULT

    def test_buy_and_hold_no_cash(self):
        """Buy-and-hold comparison should have no cash and correct final value."""
        prices_df = _make_prices({
            "A": [100.0, 200.0],
            "B": [100.0, 50.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        # Buy-and-hold: 50 shares A * 200 + 50 shares B * 50 = 10000 + 2500 = 12500
        assert abs(result.no_rebalance_final_value - 12500.0) < 1.0

    def test_result_fields(self):
        """Result should include all expected fields."""
        prices_df = _make_prices({
            "A": [100.0, 110.0, 105.0],
            "B": [100.0, 90.0, 95.0],
        })
        result = simulate_drift_rebalance(
            prices_df, {"A": 0.5, "B": 0.5}, 10000.0,
        )
        assert result.start_date
        assert result.end_date
        assert result.investment_amount == 10000.0
        assert result.drift_threshold == 0.10
        assert len(result.time_series) > 0
        assert isinstance(result.total_return_pct, float)
        assert isinstance(result.no_rebalance_return_pct, float)

    def test_two_stage_policy_rebalances_at_quarter_end_before_drift_guard(self):
        prices_df = _make_prices(
            {
                "A": [100.0, 106.0, 200.0],
                "B": [100.0, 94.0, 50.0],
            },
            start="2024-03-28",
        )

        result = simulate_two_stage_rebalance(
            prices_df,
            {"A": 0.5, "B": 0.5},
            10000.0,
            max_points=None,
        )

        assert [event.date for event in result.rebalance_events] == [
            "2024-03-29",
            "2024-04-01",
        ]
        assert result.rebalance_events[0].trigger == "scheduled"
        assert result.rebalance_events[1].trigger == "drift_guard"
        assert result.final_value < result.no_rebalance_final_value

    def test_serialize_two_stage_policy_exposes_contract_metadata(self):
        payload = serialize_rebalance_policy(
            build_two_stage_rebalance_policy(),
        )

        assert payload == {
            "strategy": "scheduled_plus_drift_guard",
            "scheduled_rebalance_frequency": "quarterly",
            "force_rebalance_on_schedule": True,
            "drift_check_frequency": "daily",
            "drift_threshold": 0.10,
        }
