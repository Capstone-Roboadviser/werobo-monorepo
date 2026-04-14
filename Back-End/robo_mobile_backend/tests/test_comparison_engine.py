from __future__ import annotations

import pandas as pd

from app.engine.comparison import build_comparison


def test_build_comparison_preserves_sub_percent_daily_moves() -> None:
    prices = pd.DataFrame(
        {
            "AAA": [100.0, 100.12, 100.24, 100.36],
        },
        index=pd.to_datetime(["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05"]),
    )

    result = build_comparison(
        prices,
        portfolios={"balanced": {"AAA": 1.0}},
        expected_returns={},
        train_start_date="2026-01-01",
        train_end_date="2026-03-01",
    )

    balanced_line = next(line for line in result.lines if line.key == "balanced")

    assert balanced_line.points[0] == ("2026-03-02", 0.0)
    assert abs(balanced_line.points[1][1] - 0.12) < 0.001
    assert abs(balanced_line.points[2][1] - 0.24) < 0.001
