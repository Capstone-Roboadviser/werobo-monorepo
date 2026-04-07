from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.optimize import minimize

from app.domain.models import FrontierPoint
from app.engine.constraints import ConstraintSet
from app.engine.math import portfolio_performance


class EfficientFrontierOptimizer:
    def __init__(self, random_seed: int = 11) -> None:
        self.random_seed = random_seed

    def build_frontier(
        self,
        expected_returns: pd.Series,
        covariance: pd.DataFrame,
        constraints: ConstraintSet,
        point_count: int,
    ) -> list[FrontierPoint]:
        ordered_returns = expected_returns.reindex(constraints.asset_codes)
        ordered_covariance = covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes)
        self._validate_covariance(ordered_covariance)

        min_volatility_result = minimize(
            lambda weights: portfolio_performance(weights, ordered_returns, ordered_covariance)[1],
            constraints.initial_weights,
            method="SLSQP",
            bounds=constraints.bounds,
            constraints=constraints.scipy_constraints,
        )
        max_return_result = minimize(
            lambda weights: -portfolio_performance(weights, ordered_returns, ordered_covariance)[0],
            constraints.initial_weights,
            method="SLSQP",
            bounds=constraints.bounds,
            constraints=constraints.scipy_constraints,
        )

        if not min_volatility_result.success or not max_return_result.success:
            raise RuntimeError("효율적 투자선 계산에 실패했습니다.")

        min_frontier_return = portfolio_performance(min_volatility_result.x, ordered_returns, ordered_covariance)[0]
        max_return = portfolio_performance(max_return_result.x, ordered_returns, ordered_covariance)[0]
        frontier_points: list[FrontierPoint] = []

        for target_return in np.linspace(min_frontier_return, max_return, point_count):
            result = minimize(
                lambda weights: portfolio_performance(weights, ordered_returns, ordered_covariance)[1],
                constraints.initial_weights,
                method="SLSQP",
                bounds=constraints.bounds,
                constraints=constraints.scipy_constraints
                + (
                    {
                        "type": "eq",
                        "fun": lambda weights, target_return=target_return: portfolio_performance(
                            weights,
                            ordered_returns,
                            ordered_covariance,
                        )[0]
                        - target_return,
                    },
                ),
            )
            if not result.success:
                continue

            expected_return, volatility = portfolio_performance(result.x, ordered_returns, ordered_covariance)
            frontier_points.append(
                FrontierPoint(
                    volatility=float(volatility),
                    expected_return=float(expected_return),
                    weights={code: float(weight) for code, weight in zip(constraints.asset_codes, result.x)},
                )
            )

        if not frontier_points:
            raise RuntimeError("효율적 투자선 포인트를 생성하지 못했습니다.")
        return self._clean_frontier(frontier_points)

    def maximize_sharpe(
        self,
        expected_returns: pd.Series,
        covariance: pd.DataFrame,
        constraints: ConstraintSet,
        risk_free_rate: float,
    ) -> FrontierPoint:
        ordered_returns = expected_returns.reindex(constraints.asset_codes)
        ordered_covariance = covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes)
        self._validate_covariance(ordered_covariance)

        result = minimize(
            lambda weights: self._negative_sharpe(weights, ordered_returns, ordered_covariance, risk_free_rate),
            constraints.initial_weights,
            method="SLSQP",
            bounds=constraints.bounds,
            constraints=constraints.scipy_constraints,
        )
        if not result.success:
            raise RuntimeError("최대 Sharpe 포트폴리오 계산에 실패했습니다.")

        expected_return, volatility = portfolio_performance(result.x, ordered_returns, ordered_covariance)
        return FrontierPoint(
            volatility=float(volatility),
            expected_return=float(expected_return),
            weights={code: float(weight) for code, weight in zip(constraints.asset_codes, result.x)},
        )

    def sample_random_portfolios(
        self,
        expected_returns: pd.Series,
        covariance: pd.DataFrame,
        constraints: ConstraintSet,
        sample_count: int,
    ) -> list[tuple[float, float, dict[str, float]]]:
        ordered_returns = expected_returns.reindex(constraints.asset_codes)
        ordered_covariance = covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes)
        lower_bounds = np.array([bound[0] for bound in constraints.bounds], dtype=float)
        upper_bounds = np.array([bound[1] for bound in constraints.bounds], dtype=float)
        remaining = 1 - lower_bounds.sum()

        rng = np.random.default_rng(self.random_seed)
        points: list[tuple[float, float, dict[str, float]]] = []
        attempts = 0

        while len(points) < sample_count and attempts < sample_count * 20:
            attempts += 1
            weights = lower_bounds + rng.dirichlet(np.ones(len(constraints.asset_codes))) * remaining
            if np.any(weights > upper_bounds + 1e-9):
                continue
            weights = weights / weights.sum()
            if not self._satisfies_constraints(weights, constraints):
                continue
            expected_return, volatility = portfolio_performance(weights, ordered_returns, ordered_covariance)
            weight_dict = {code: float(w) for code, w in zip(constraints.asset_codes, weights)}
            points.append((float(volatility), float(expected_return), weight_dict))

        return points

    def _validate_covariance(self, covariance: pd.DataFrame) -> None:
        if covariance.isna().any().any():
            raise RuntimeError("공분산 행렬에 결측치가 포함되어 있습니다.")

    def _satisfies_constraints(self, weights: np.ndarray, constraints: ConstraintSet) -> bool:
        for constraint in constraints.scipy_constraints:
            value = float(constraint["fun"](weights))
            if constraint["type"] == "eq" and abs(value) > 1e-6:
                return False
            if constraint["type"] == "ineq" and value < -1e-6:
                return False
        return True

    def _clean_frontier(self, frontier_points: list[FrontierPoint]) -> list[FrontierPoint]:
        """Drop numerically unstable points that fall below the upper frontier."""
        ordered_points = sorted(frontier_points, key=lambda point: point.volatility)
        cleaned_points: list[FrontierPoint] = []
        best_return = -float("inf")

        for point in ordered_points:
            if point.expected_return + 1e-6 < best_return:
                continue
            cleaned_points.append(point)
            best_return = max(best_return, point.expected_return)

        return cleaned_points

    def _negative_sharpe(
        self,
        weights: np.ndarray,
        expected_returns: pd.Series,
        covariance: pd.DataFrame,
        risk_free_rate: float,
    ) -> float:
        expected_return, volatility = portfolio_performance(weights, expected_returns, covariance)
        if volatility <= 0:
            return 1e6
        return -((expected_return - risk_free_rate) / volatility)
