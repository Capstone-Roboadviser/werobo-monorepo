from __future__ import annotations

from dataclasses import dataclass

import pandas as pd


@dataclass(frozen=True)
class RebalanceEvent:
    date: str
    total_value: float
    pre_weights: dict[str, float]
    post_weights: dict[str, float]
    trades: dict[str, float]


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
    time_series: list[RebalanceTimePoint]
    rebalance_events: list[RebalanceEvent]
    final_value: float
    total_return_pct: float
    no_rebalance_final_value: float
    no_rebalance_return_pct: float


def _quarter_end_dates(dates: pd.DatetimeIndex) -> set[pd.Timestamp]:
    """Return the last trading day of each calendar quarter present in the index."""
    quarter_ends: set[pd.Timestamp] = set()
    grouped = pd.Series(dates, index=dates).groupby(pd.Grouper(freq="QE"))
    for _, group in grouped:
        if not group.empty:
            last_trading_day = group.iloc[-1]
            quarter_ends.add(last_trading_day)
    return quarter_ends


def simulate_quarterly_rebalance(
    prices: pd.DataFrame,
    target_weights: dict[str, float],
    investment_amount: float,
) -> RebalanceResult:
    """Simulate quarterly rebalancing on a portfolio.

    Args:
        prices: DataFrame with DatetimeIndex rows, ticker columns, adjusted_close values.
                Must be sorted by date ascending with no NaNs.
        target_weights: ticker -> target weight (must sum to ~1.0).
        investment_amount: initial investment in currency units.
    """
    tickers = list(target_weights.keys())
    prices = prices[tickers].copy()

    quarter_ends = _quarter_end_dates(prices.index)

    # Initial holdings (number of shares per asset)
    first_prices = prices.iloc[0]
    holdings = {
        ticker: investment_amount * target_weights[ticker] / first_prices[ticker]
        for ticker in tickers
    }

    # Buy-and-hold holdings (never rebalanced)
    bh_holdings = holdings.copy()

    rebalance_events: list[RebalanceEvent] = []
    all_points: list[RebalanceTimePoint] = []

    for i in range(len(prices)):
        current_prices = prices.iloc[i]
        date = prices.index[i]
        date_str = date.strftime("%Y-%m-%d")

        # Current asset values (rebalanced portfolio)
        asset_values = {
            ticker: holdings[ticker] * current_prices[ticker]
            for ticker in tickers
        }
        total_value = sum(asset_values.values())

        # Record time point
        all_points.append(RebalanceTimePoint(
            date=date_str,
            total_value=round(total_value, 2),
            asset_values={t: round(v, 2) for t, v in asset_values.items()},
        ))

        # Check if this is a quarter-end rebalancing date (skip the very first day)
        if date in quarter_ends and i > 0:
            pre_weights = {
                ticker: asset_values[ticker] / total_value if total_value > 0 else 0.0
                for ticker in tickers
            }

            trades: dict[str, float] = {}
            for ticker in tickers:
                target_value = total_value * target_weights[ticker]
                trade_amount = target_value - asset_values[ticker]
                trades[ticker] = round(trade_amount, 2)

            # Execute rebalance: reset holdings to target weights at current total value
            for ticker in tickers:
                holdings[ticker] = total_value * target_weights[ticker] / current_prices[ticker]

            rebalance_events.append(RebalanceEvent(
                date=date_str,
                total_value=round(total_value, 2),
                pre_weights={t: round(w, 6) for t, w in pre_weights.items()},
                post_weights={t: round(w, 6) for t, w in target_weights.items()},
                trades=trades,
            ))

    # Final values
    last_prices = prices.iloc[-1]
    final_value = sum(holdings[t] * last_prices[t] for t in tickers)
    bh_final_value = sum(bh_holdings[t] * last_prices[t] for t in tickers)

    # Subsample time series to ~250 points
    step = max(1, len(all_points) // 250)
    sampled_indices = list(range(0, len(all_points), step))
    if sampled_indices[-1] != len(all_points) - 1:
        sampled_indices.append(len(all_points) - 1)
    sampled_points = [all_points[i] for i in sampled_indices]

    return RebalanceResult(
        start_date=prices.index[0].strftime("%Y-%m-%d"),
        end_date=prices.index[-1].strftime("%Y-%m-%d"),
        investment_amount=investment_amount,
        target_weights={t: round(w, 6) for t, w in target_weights.items()},
        time_series=sampled_points,
        rebalance_events=rebalance_events,
        final_value=round(final_value, 2),
        total_return_pct=round((final_value - investment_amount) / investment_amount * 100, 2),
        no_rebalance_final_value=round(bh_final_value, 2),
        no_rebalance_return_pct=round((bh_final_value - investment_amount) / investment_amount * 100, 2),
    )
