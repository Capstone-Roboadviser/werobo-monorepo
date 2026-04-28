from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from app.engine.rebalance import DRIFT_THRESHOLD_DEFAULT, simulate_two_stage_rebalance


@dataclass(frozen=True)
class ComparisonLine:
    key: str
    label: str
    color: str
    style: str  # "solid" or "dashed"
    points: list[tuple[str, float]]  # (date, cumulative_return_pct)


@dataclass(frozen=True)
class ComparisonResult:
    train_start_date: str
    train_end_date: str
    test_start_date: str
    start_date: str
    end_date: str
    split_ratio: float
    rebalance_dates: list[str]
    lines: list[ComparisonLine]


_PROFILE_COLORS = {
    "conservative": "#0d9488",
    "balanced": "#3b82f6",
    "growth": "#8b5cf6",
}

_PROFILE_LABELS = {
    "conservative": "안정형",
    "balanced": "균형형",
    "growth": "성장형",
}

# Comparison backtests only need relative return paths, but the rebalance engine
# rounds time-series total_value to cents. Using a 1.0 base investment quantizes
# the comparison lines into 1% jumps, so keep the simulation notional large.
_COMPARISON_SIMULATION_BASE_INVESTMENT = 1_000_000.0


def build_comparison(
    prices: pd.DataFrame,
    portfolios: dict[str, dict[str, float]],
    expected_returns: dict[str, float],
    benchmark_series: dict[str, pd.Series] | None = None,
    extra_lines: list[ComparisonLine] | None = None,
    *,
    train_start_date: str,
    train_end_date: str,
    split_ratio: float = 0.9,
    rebalance_enabled: bool = True,
    max_sample_points: int | None = 250,
) -> ComparisonResult:
    """Build comparison backtest data.

    Args:
        prices: DatetimeIndex rows, ticker columns, adjusted close values. Sorted, ffilled.
        portfolios: {profile_name: {ticker: weight}} for each portfolio type.
        expected_returns: {profile_name: annualized_expected_return} (e.g. 0.08 for 8%).
        benchmark_series: {name: price_series} with same date index, e.g. {"S&P 500": series}.
    """
    dates = prices.index
    rebalance_date_set: set[str] = set()

    lines: list[ComparisonLine] = []

    # --- Portfolio lines (with drift-based rebalancing) ---
    for profile_name, weights in portfolios.items():
        tickers = list(weights.keys())
        available = [t for t in tickers if t in prices.columns]
        if not available:
            continue
        w = {t: weights[t] for t in available}
        total_w = sum(w.values())
        w = {t: v / total_w for t, v in w.items()}

        if rebalance_enabled:
            simulation = simulate_two_stage_rebalance(
                prices[available].copy(),
                w,
                _COMPARISON_SIMULATION_BASE_INVESTMENT,
                drift_threshold=DRIFT_THRESHOLD_DEFAULT,
                max_points=None,
            )
            rebalance_date_set.update(event.date for event in simulation.rebalance_events)
            return_points = [
                (
                    point.date,
                    round(
                        (point.total_value - simulation.investment_amount)
                        / simulation.investment_amount
                        * 100,
                        4,
                    ),
                )
                for point in simulation.time_series
            ]
        else:
            aligned_prices = prices[available].astype(float).copy()
            base_prices = aligned_prices.iloc[0].replace(0, np.nan)
            relative_prices = aligned_prices.divide(base_prices).replace(
                [np.inf, -np.inf],
                np.nan,
            )
            portfolio_path = (
                relative_prices.mul(pd.Series(w), axis=1).sum(axis=1).dropna()
            )
            return_points = [
                (
                    date.strftime("%Y-%m-%d"),
                    round((float(value) - 1.0) * 100, 4),
                )
                for date, value in portfolio_path.items()
            ]

        color = _PROFILE_COLORS.get(profile_name, "#64748B")
        label = _PROFILE_LABELS.get(profile_name, profile_name)
        lines.append(
            ComparisonLine(
                key=profile_name,
                label=label,
                color=color,
                style="solid",
                points=return_points,
            )
        )

    rebalance_dates: list[str] = sorted(rebalance_date_set)

    # --- Expected return trajectory lines ---
    for profile_name, annual_er in expected_returns.items():
        if profile_name not in portfolios:
            continue
        color = _PROFILE_COLORS.get(profile_name, "#64748B")
        label = _PROFILE_LABELS.get(profile_name, profile_name) + " 기대수익"

        start_date = dates[0]
        expected_points: list[tuple[str, float]] = []
        for i in range(len(dates)):
            days_elapsed = (dates[i] - start_date).days
            years_elapsed = days_elapsed / 365.25
            cumulative_return = ((1 + annual_er) ** years_elapsed - 1) * 100
            expected_points.append(
                (dates[i].strftime("%Y-%m-%d"), round(cumulative_return, 4))
            )

        lines.append(
            ComparisonLine(
                key=f"{profile_name}_expected",
                label=label,
                color=color,
                style="dashed",
                points=expected_points,
            )
        )

    # --- Benchmark lines ---
    benchmark_configs = {
        "sp500": {"label": "S&P 500", "color": "#ef4444"},
        "treasury": {"label": "10년 국채", "color": "#78716c"},
    }
    if benchmark_series:
        for bm_key, bm_prices in benchmark_series.items():
            if bm_prices.empty:
                continue
            cfg = benchmark_configs.get(bm_key, {"label": bm_key, "color": "#64748B"})
            aligned = bm_prices.reindex(dates).ffill().bfill()
            if aligned.empty or aligned.iloc[0] == 0:
                continue
            base = aligned.iloc[0]
            bm_points: list[tuple[str, float]] = []
            for i in range(len(dates)):
                ret = (aligned.iloc[i] - base) / base * 100
                bm_points.append((dates[i].strftime("%Y-%m-%d"), round(float(ret), 4)))
            lines.append(
                ComparisonLine(
                    key=bm_key,
                    label=cfg["label"],
                    color=cfg["color"],
                    style="solid",
                    points=bm_points,
                )
            )

    if extra_lines:
        lines.extend(extra_lines)

    sampled_lines = lines
    if (
        max_sample_points is not None
        and max_sample_points > 0
        and len(dates) > max_sample_points
    ):
        n = len(dates)
        step = max(1, n // max_sample_points)
        sampled_indices = list(range(0, n, step))
        if sampled_indices[-1] != n - 1:
            sampled_indices.append(n - 1)

        sampled_lines = []
        for line in lines:
            sampled_pts = [
                line.points[i] for i in sampled_indices if i < len(line.points)
            ]
            sampled_lines.append(
                ComparisonLine(
                    key=line.key,
                    label=line.label,
                    color=line.color,
                    style=line.style,
                    points=sampled_pts,
                )
            )

    return ComparisonResult(
        train_start_date=train_start_date,
        train_end_date=train_end_date,
        test_start_date=dates[0].strftime("%Y-%m-%d"),
        start_date=dates[0].strftime("%Y-%m-%d"),
        end_date=dates[-1].strftime("%Y-%m-%d"),
        split_ratio=split_ratio,
        rebalance_dates=rebalance_dates,
        lines=sampled_lines,
    )
