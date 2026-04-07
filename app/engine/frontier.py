from __future__ import annotations

import numpy as np

from app.domain.models import FrontierPoint


def select_frontier_point_index(frontier_points: list[FrontierPoint], target_volatility: float) -> int:
    if not frontier_points:
        raise RuntimeError("선택할 효율적 투자선 포인트가 없습니다.")
    return min(
        range(len(frontier_points)),
        key=lambda index: (
            abs(frontier_points[index].volatility - target_volatility),
            -frontier_points[index].expected_return,
        ),
    )


def build_frontier_options(
    frontier_points: list[FrontierPoint],
    labels: tuple[str, str, str] = ("안정형", "균형형", "성장형"),
) -> list[tuple[str, FrontierPoint]]:
    if not frontier_points:
        return []

    raw_indices = np.linspace(0, len(frontier_points) - 1, num=len(labels)).round().astype(int)
    indices: list[int] = []
    for index in raw_indices:
        int_index = int(index)
        if int_index not in indices:
            indices.append(int_index)
    while len(indices) < len(labels):
        indices.append(indices[-1])

    return [(label, frontier_points[index]) for label, index in zip(labels, indices)]
