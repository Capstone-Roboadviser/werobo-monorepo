from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np

from app.domain.models import AssetClass


@dataclass(frozen=True)
class ConstraintSet:
    asset_codes: list[str]
    bounds: tuple[tuple[float, float], ...]
    scipy_constraints: tuple[dict[str, Any], ...]
    initial_weights: np.ndarray


def average_pairwise_correlation(weights: np.ndarray, correlation_matrix: np.ndarray) -> float:
    squared_weight_sum = float(np.sum(np.square(weights)))
    denominator = 1.0 - squared_weight_sum
    if denominator <= 1e-12:
        return 1.0
    numerator = float(weights.T @ correlation_matrix @ weights) - squared_weight_sum
    return numerator / denominator


def build_average_correlation_constraint(
    correlation_matrix: np.ndarray,
    max_average_correlation: float,
) -> dict[str, Any]:
    return {
        "type": "ineq",
        "fun": lambda weights, correlation_matrix=correlation_matrix, max_average_correlation=max_average_correlation: (
            max_average_correlation - average_pairwise_correlation(weights, correlation_matrix)
        ),
    }


class ConstraintEngine:
    def build(self, assets: list[AssetClass]) -> ConstraintSet:
        asset_codes = [asset.code for asset in assets]
        lower_bounds = np.array([asset.min_weight for asset in assets], dtype=float)
        upper_bounds = np.array([asset.max_weight for asset in assets], dtype=float)
        return self.build_for_codes(asset_codes, lower_bounds=lower_bounds, upper_bounds=upper_bounds)

    def build_for_codes(
        self,
        asset_codes: list[str],
        *,
        lower_bounds: np.ndarray | None = None,
        upper_bounds: np.ndarray | None = None,
        extra_constraints: tuple[dict[str, Any], ...] = (),
    ) -> ConstraintSet:
        if lower_bounds is None:
            lower_bounds = np.zeros(len(asset_codes), dtype=float)
        if upper_bounds is None:
            upper_bounds = np.ones(len(asset_codes), dtype=float)

        if lower_bounds.sum() > 1 + 1e-9:
            raise RuntimeError("최소 비중 합이 1을 초과해 제약조건이 성립하지 않습니다.")

        headroom = upper_bounds - lower_bounds
        remaining = 1 - lower_bounds.sum()
        if remaining > headroom.sum() + 1e-9:
            raise RuntimeError("최대 비중 제약으로 인해 전체 비중 합을 1로 맞출 수 없습니다.")

        initial_weights = lower_bounds.copy()
        if remaining > 0 and headroom.sum() > 0:
            initial_weights += (headroom / headroom.sum()) * remaining

        bounds = tuple((float(lower), float(upper)) for lower, upper in zip(lower_bounds, upper_bounds))
        scipy_constraints = ({"type": "eq", "fun": lambda weights: np.sum(weights) - 1.0},) + extra_constraints
        return ConstraintSet(
            asset_codes=asset_codes,
            bounds=bounds,
            scipy_constraints=scipy_constraints,
            initial_weights=initial_weights,
        )
