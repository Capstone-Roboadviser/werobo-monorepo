from __future__ import annotations

import numpy as np
import pandas as pd

from app.domain.models import PortfolioMetrics


def portfolio_metrics_from_weights(
    weights: dict[str, float],
    expected_returns: pd.Series,
    covariance: pd.DataFrame,
    risk_free_rate: float,
) -> PortfolioMetrics:
    ordered_weights = pd.Series(weights, dtype=float).reindex(expected_returns.index).fillna(0.0)
    portfolio_return = float(np.dot(ordered_weights.values, expected_returns.values))
    portfolio_volatility = float(np.sqrt(ordered_weights.values.T @ covariance.values @ ordered_weights.values))
    sharpe_ratio = (portfolio_return - risk_free_rate) / portfolio_volatility if portfolio_volatility > 0 else 0.0
    return PortfolioMetrics(
        expected_return=portfolio_return,
        volatility=portfolio_volatility,
        sharpe_ratio=sharpe_ratio,
    )


def portfolio_performance(
    weights: np.ndarray,
    expected_returns: pd.Series,
    covariance: pd.DataFrame,
) -> tuple[float, float]:
    portfolio_return = float(np.dot(expected_returns.values, weights))
    portfolio_volatility = float(np.sqrt(weights.T @ covariance.values @ weights))
    return portfolio_return, portfolio_volatility


def risk_contributions(
    weights: dict[str, float],
    covariance: pd.DataFrame,
) -> dict[str, float]:
    ordered_weights = pd.Series(weights, dtype=float).reindex(covariance.index).fillna(0.0)
    portfolio_volatility = float(np.sqrt(ordered_weights.values.T @ covariance.values @ ordered_weights.values))
    if portfolio_volatility <= 0:
        return {code: 0.0 for code in ordered_weights.index}

    marginal_contribution = covariance.values @ ordered_weights.values / portfolio_volatility
    contribution = ordered_weights.values * marginal_contribution
    contribution_sum = float(contribution.sum())
    if contribution_sum == 0:
        return {code: 0.0 for code in ordered_weights.index}
    normalized = contribution / contribution_sum
    return {code: float(value) for code, value in zip(ordered_weights.index, normalized)}
