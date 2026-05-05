from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Mapping

import pandas as pd

logger = logging.getLogger(__name__)

DRIFT_THRESHOLD_DEFAULT = 0.10  # 10% relative drift
SCHEDULED_REBALANCE_FREQUENCY_QUARTERLY = "quarterly"
DRIFT_CHECK_FREQUENCY_DAILY = "daily"
REBALANCE_TRIGGER_DRIFT_GUARD = "drift_guard"
REBALANCE_TRIGGER_SCHEDULED = "scheduled"
REBALANCE_STRATEGY_SCHEDULED_PLUS_DRIFT_GUARD = "scheduled_plus_drift_guard"
REBALANCE_STRATEGY_DRIFT_GUARD_ONLY = "drift_guard_only"


@dataclass(frozen=True)
class RebalancePolicy:
    scheduled_frequency: str | None = None
    force_rebalance_on_schedule: bool = False
    drift_threshold: float | None = DRIFT_THRESHOLD_DEFAULT


@dataclass(frozen=True)
class RebalanceEvent:
    date: str
    total_value: float
    pre_weights: dict[str, float]
    post_weights: dict[str, float]
    trades: dict[str, float]
    trigger: str = REBALANCE_TRIGGER_DRIFT_GUARD


@dataclass(frozen=True)
class RebalanceTimePoint:
    date: str
    total_value: float
    asset_values: dict[str, float]


@dataclass(frozen=True)
class RebalanceResult:
    start_date: str
    end_date: str
    investment_amount: float
    target_weights: dict[str, float]
    drift_threshold: float
    time_series: list[RebalanceTimePoint]
    rebalance_events: list[RebalanceEvent]
    final_value: float
    total_return_pct: float
    no_rebalance_final_value: float
    no_rebalance_return_pct: float


def build_two_stage_rebalance_policy(
    drift_threshold: float = DRIFT_THRESHOLD_DEFAULT,
) -> RebalancePolicy:
    return RebalancePolicy(
        scheduled_frequency=SCHEDULED_REBALANCE_FREQUENCY_QUARTERLY,
        force_rebalance_on_schedule=True,
        drift_threshold=drift_threshold,
    )


def serialize_rebalance_policy(policy: RebalancePolicy) -> dict[str, object]:
    if policy.scheduled_frequency is not None:
        strategy = REBALANCE_STRATEGY_SCHEDULED_PLUS_DRIFT_GUARD
    else:
        strategy = REBALANCE_STRATEGY_DRIFT_GUARD_ONLY

    return {
        "strategy": strategy,
        "scheduled_rebalance_frequency": policy.scheduled_frequency,
        "force_rebalance_on_schedule": policy.force_rebalance_on_schedule,
        "drift_check_frequency": (
            DRIFT_CHECK_FREQUENCY_DAILY
            if policy.drift_threshold is not None
            else None
        ),
        "drift_threshold": policy.drift_threshold,
    }


def _quarter_end_dates(dates: pd.DatetimeIndex) -> set[pd.Timestamp]:
    """Return the last trading day of each calendar quarter present in the index."""
    quarter_ends: set[pd.Timestamp] = set()
    grouped = pd.Series(dates, index=dates).groupby(pd.Grouper(freq="QE"))
    max_date = dates.max().normalize()
    for quarter_end, group in grouped:
        if not group.empty:
            quarter_end_date = pd.Timestamp(quarter_end).normalize()
            if quarter_end_date > max_date:
                continue
            last_trading_day = group.iloc[-1]
            quarter_ends.add(last_trading_day)
    return quarter_ends


def _resolve_scheduled_rebalance_dates(
    dates: pd.DatetimeIndex,
    frequency: str | None,
) -> set[pd.Timestamp]:
    if frequency is None:
        return set()
    if frequency == SCHEDULED_REBALANCE_FREQUENCY_QUARTERLY:
        return _quarter_end_dates(dates)
    raise ValueError(f"Unsupported scheduled rebalance frequency: {frequency}")


def _normalize_cash_flows(
    cash_flows: Mapping[str, float] | None,
) -> dict[str, float]:
    if not cash_flows:
        return {}

    normalized: dict[str, float] = {}
    for raw_date, raw_amount in cash_flows.items():
        date_key = pd.Timestamp(raw_date).strftime("%Y-%m-%d")
        amount = float(raw_amount)
        if amount == 0:
            continue
        normalized[date_key] = normalized.get(date_key, 0.0) + amount
    return normalized


def check_and_rebalance(
    holdings: dict[str, float],
    prices: dict[str, float],
    target_weights: dict[str, float],
    cash_balance: float,
    drift_threshold: float,
) -> tuple[dict[str, float], float, dict[str, float]]:
    """Check drift and execute rebalance for one trading day.

    Shared function used by both simulate_drift_rebalance() and comparison backtest.

    Args:
        holdings: ticker -> number of shares held.
        prices: ticker -> price on this day.
        target_weights: ticker -> target weight (must sum to ~1.0).
        cash_balance: current cash balance.
        drift_threshold: relative drift threshold (e.g. 0.10 for 10%).

    Returns:
        (updated_holdings, updated_cash_balance, trades)
        trades is a dict of ticker -> trade amount (positive=buy, negative=sell).
        Empty dict if no rebalancing occurred.
    """
    tickers = list(target_weights.keys())

    # Compute total value including cash
    total_value = sum(holdings[t] * prices[t] for t in tickers) + cash_balance
    if total_value <= 0:
        return holdings, cash_balance, {}

    # Current weights
    current_weights = {t: holdings[t] * prices[t] / total_value for t in tickers}

    # --- SELL phase (batch: compute all from snapshot weights) ---
    sells: dict[str, float] = {}
    for t in tickers:
        tw = target_weights[t]
        cw = current_weights[t]
        if tw == 0:
            # Zero-target: sell all holdings immediately
            if holdings[t] > 0 and prices[t] > 0:
                sell_value = holdings[t] * prices[t]
                sells[t] = sell_value
        elif tw > 0 and cw > tw * (1 + drift_threshold):
            # Overweight: sell excess to target weight
            excess_value = (cw - tw) * total_value
            sells[t] = excess_value

    # Execute sells
    trades: dict[str, float] = {}
    for t, amount in sells.items():
        if prices[t] <= 0:
            continue
        shares_sold = amount / prices[t]
        holdings[t] -= shares_sold
        cash_balance += amount
        trades[t] = round(-amount, 2)

    # --- BUY phase (priority: greatest relative drift first) ---
    underweight: list[tuple[str, float]] = []
    for t in tickers:
        tw = target_weights[t]
        cw = current_weights[t]
        if tw > 0 and cw < tw * (1 - drift_threshold):
            relative_drift = (tw - cw) / tw
            underweight.append((t, relative_drift))

    underweight.sort(key=lambda x: x[1], reverse=True)

    for t, _ in underweight:
        if cash_balance <= 0:
            break
        tw = target_weights[t]
        deficit_value = (tw - current_weights[t]) * total_value
        buy_amount = min(deficit_value, cash_balance)
        if prices[t] <= 0 or buy_amount <= 0:
            continue
        shares_bought = buy_amount / prices[t]
        holdings[t] += shares_bought
        cash_balance -= buy_amount
        trades[t] = round(buy_amount, 2)

    assert cash_balance >= -0.01, f"Cash balance went negative: {cash_balance}"
    cash_balance = max(cash_balance, 0.0)

    return holdings, cash_balance, trades


def simulate_rebalance_path(
    prices: pd.DataFrame,
    target_weights: dict[str, float],
    investment_amount: float,
    *,
    policy: RebalancePolicy,
    cash_flows: Mapping[str, float] | None = None,
    max_points: int | None = 250,
) -> RebalanceResult:
    if prices.empty:
        raise ValueError("Price history is empty.")

    total_weight = sum(target_weights.values())
    if abs(total_weight - 1.0) > 0.01:
        raise ValueError(
            f"Target weights must sum to ~1.0, got {total_weight:.4f}"
        )

    tickers = list(target_weights.keys())
    prices = prices[tickers].copy()
    scheduled_dates = _resolve_scheduled_rebalance_dates(
        prices.index,
        policy.scheduled_frequency,
    )
    normalized_cash_flows = _normalize_cash_flows(cash_flows)

    first_prices = prices.iloc[0]
    holdings: dict[str, float] = {}
    for ticker in tickers:
        p = first_prices[ticker]
        if p <= 0:
            raise ValueError(f"Initial price for {ticker} is {p}, must be > 0")
        holdings[ticker] = investment_amount * target_weights[ticker] / p

    cash_balance = 0.0
    bh_holdings = holdings.copy()
    cumulative_investment = investment_amount

    rebalance_events: list[RebalanceEvent] = []
    all_points: list[RebalanceTimePoint] = []

    for i in range(len(prices)):
        current_prices = prices.iloc[i]
        date = prices.index[i]
        date_str = date.strftime("%Y-%m-%d")

        if any(current_prices[t] <= 0 for t in tickers):
            continue

        flow_amount = normalized_cash_flows.get(date_str, 0.0)
        if i > 0 and flow_amount > 0:
            for ticker in tickers:
                shares_added = flow_amount * target_weights[ticker] / float(current_prices[ticker])
                holdings[ticker] += shares_added
                bh_holdings[ticker] += shares_added
            cumulative_investment += flow_amount

        asset_values = {
            ticker: holdings[ticker] * current_prices[ticker]
            for ticker in tickers
        }
        asset_values["CASH"] = cash_balance
        total_value = sum(asset_values.values())

        all_points.append(RebalanceTimePoint(
            date=date_str,
            total_value=round(total_value, 2),
            asset_values={t: round(v, 2) for t, v in asset_values.items()},
        ))

        if i == 0:
            continue

        price_dict = {t: float(current_prices[t]) for t in tickers}
        pre_weights = {
            t: asset_values[t] / total_value if total_value > 0 else 0.0
            for t in tickers
        }
        pre_weights["CASH"] = cash_balance / total_value if total_value > 0 else 0.0

        trades: dict[str, float] = {}
        trigger: str | None = None

        if date in scheduled_dates and policy.force_rebalance_on_schedule:
            holdings, cash_balance, trades = check_and_rebalance(
                holdings,
                price_dict,
                target_weights,
                cash_balance,
                0.0,
            )
            trigger = REBALANCE_TRIGGER_SCHEDULED
        elif policy.drift_threshold is not None:
            holdings, cash_balance, trades = check_and_rebalance(
                holdings,
                price_dict,
                target_weights,
                cash_balance,
                policy.drift_threshold,
            )
            trigger = REBALANCE_TRIGGER_DRIFT_GUARD

        if trades:
            post_asset_values = {
                t: holdings[t] * current_prices[t] for t in tickers
            }
            post_asset_values["CASH"] = cash_balance
            post_total = sum(post_asset_values.values())
            post_weights = {
                t: post_asset_values[t] / post_total if post_total > 0 else 0.0
                for t in list(tickers) + ["CASH"]
            }
            trades["CASH"] = round(
                cash_balance - (pre_weights["CASH"] * total_value),
                2,
            )
            rebalance_events.append(RebalanceEvent(
                date=date_str,
                total_value=round(total_value, 2),
                pre_weights={t: round(w, 6) for t, w in pre_weights.items()},
                post_weights={t: round(w, 6) for t, w in post_weights.items()},
                trades=trades,
                trigger=trigger or REBALANCE_TRIGGER_DRIFT_GUARD,
            ))

    last_prices = prices.iloc[-1]
    final_value = sum(holdings[t] * last_prices[t] for t in tickers) + cash_balance
    bh_final_value = sum(bh_holdings[t] * last_prices[t] for t in tickers)

    if max_points is None or len(all_points) <= max_points:
        sampled_points = all_points
    else:
        step = max(1, len(all_points) // max_points)
        sampled_indices = list(range(0, len(all_points), step))
        if sampled_indices and sampled_indices[-1] != len(all_points) - 1:
            sampled_indices.append(len(all_points) - 1)
        sampled_points = [all_points[i] for i in sampled_indices]

    logger.info(
        "Rebalance path: %d events, final cash: %.2f",
        len(rebalance_events), cash_balance,
    )

    base_investment = max(cumulative_investment, 0.01)
    return RebalanceResult(
        start_date=prices.index[0].strftime("%Y-%m-%d"),
        end_date=prices.index[-1].strftime("%Y-%m-%d"),
        investment_amount=investment_amount,
        target_weights={t: round(w, 6) for t, w in target_weights.items()},
        drift_threshold=policy.drift_threshold or 0.0,
        time_series=sampled_points,
        rebalance_events=rebalance_events,
        final_value=round(final_value, 2),
        total_return_pct=round((final_value - base_investment) / base_investment * 100, 2),
        no_rebalance_final_value=round(bh_final_value, 2),
        no_rebalance_return_pct=round((bh_final_value - base_investment) / base_investment * 100, 2),
    )


def simulate_drift_rebalance(
    prices: pd.DataFrame,
    target_weights: dict[str, float],
    investment_amount: float,
    drift_threshold: float = DRIFT_THRESHOLD_DEFAULT,
) -> RebalanceResult:
    """Simulate drift-based rebalancing on a portfolio.

    Checks drift every trading day. When any asset drifts more than
    drift_threshold (relative) from its target weight, sells overweight
    assets to cash and buys underweight assets using cash (prioritizing
    greatest drift first).

    Args:
        prices: DataFrame with DatetimeIndex rows, ticker columns, adjusted_close values.
                Must be sorted by date ascending with no NaNs.
        target_weights: ticker -> target weight (must sum to ~1.0).
        investment_amount: initial investment in currency units.
        drift_threshold: relative drift threshold (default 0.10 = 10%).
    """
    return simulate_rebalance_path(
        prices,
        target_weights,
        investment_amount,
        policy=RebalancePolicy(drift_threshold=drift_threshold),
    )


def simulate_two_stage_rebalance(
    prices: pd.DataFrame,
    target_weights: dict[str, float],
    investment_amount: float,
    *,
    drift_threshold: float = DRIFT_THRESHOLD_DEFAULT,
    cash_flows: Mapping[str, float] | None = None,
    max_points: int | None = 250,
) -> RebalanceResult:
    return simulate_rebalance_path(
        prices,
        target_weights,
        investment_amount,
        policy=build_two_stage_rebalance_policy(drift_threshold),
        cash_flows=cash_flows,
        max_points=max_points,
    )
