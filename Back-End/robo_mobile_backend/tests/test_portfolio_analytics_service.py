from __future__ import annotations

import pandas as pd

from app.core.config import MINIMUM_HISTORY_ROWS
from app.domain.models import AssetClass, StockInstrument
from app.services.portfolio_analytics_service import PortfolioAnalyticsService


def _asset(code: str, name: str) -> AssetClass:
    return AssetClass(
        code=code,
        name=name,
        category="demo",
        description="",
        color="#000000",
        min_weight=0.0,
        max_weight=0.3,
        role_key="single_representative",
        role_name="",
        role_description="",
        selection_mode="single_representative",
        weighting_mode="single",
        return_mode="black_litterman",
    )


def test_build_equal_weight_asset_benchmark_line_averages_asset_classes() -> None:
    service = PortfolioAnalyticsService()
    date_index = pd.to_datetime(["2026-03-01", "2026-03-02", "2026-03-03"])
    prices = pd.DataFrame(
        [
            {"date": "2026-03-01", "ticker": "AAA", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "AAA", "adjusted_close": 110.0},
            {"date": "2026-03-03", "ticker": "AAA", "adjusted_close": 120.0},
            {"date": "2026-03-01", "ticker": "BBB", "adjusted_close": 200.0},
            {"date": "2026-03-02", "ticker": "BBB", "adjusted_close": 210.0},
            {"date": "2026-03-03", "ticker": "BBB", "adjusted_close": 220.0},
        ]
    )
    instruments = [
        StockInstrument(
            ticker="AAA",
            name="Asset A",
            sector_code="us_value",
            sector_name="미국 가치주",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
        StockInstrument(
            ticker="BBB",
            name="Asset B",
            sector_code="gold",
            sector_name="금",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
    ]
    assets = [
        _asset("us_value", "미국 가치주"),
        _asset("gold", "금"),
    ]

    line = service._build_equal_weight_asset_benchmark_line(
        assets=assets,
        instruments=instruments,
        prices=prices,
        date_index=date_index,
    )

    assert line is not None
    assert line.key == "benchmark_avg"
    assert line.points[0] == ("2026-03-01", 0.0)
    assert line.points[1] == ("2026-03-02", 7.5)
    assert line.points[2] == ("2026-03-03", 15.0)


def test_build_equal_weight_asset_benchmark_line_requires_all_asset_classes() -> None:
    service = PortfolioAnalyticsService()
    date_index = pd.to_datetime(["2026-03-01", "2026-03-02"])
    prices = pd.DataFrame(
        [
            {"date": "2026-03-01", "ticker": "AAA", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "AAA", "adjusted_close": 110.0},
        ]
    )
    instruments = [
        StockInstrument(
            ticker="AAA",
            name="Asset A",
            sector_code="us_value",
            sector_name="미국 가치주",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
    ]

    line = service._build_equal_weight_asset_benchmark_line(
        assets=[_asset("us_value", "미국 가치주"), _asset("gold", "금")],
        instruments=instruments,
        prices=prices,
        date_index=date_index,
    )

    assert line is None


def test_build_fixed_bond_line_is_linear() -> None:
    service = PortfolioAnalyticsService()
    date_index = pd.to_datetime(["2026-03-01", "2026-09-01", "2027-03-01"])

    line = service._build_fixed_bond_line(
        date_index=date_index,
        annual_yield=0.02,
    )

    assert line is not None
    assert line.key == "treasury"
    assert line.points[0] == ("2026-03-01", 0.0)
    assert 1.99 <= line.points[-1][1] <= 2.01


def test_split_prices_train_test_respects_requested_start_date() -> None:
    service = PortfolioAnalyticsService()
    dates = pd.bdate_range("2024-01-01", periods=400)
    prices = pd.DataFrame(
        {
            "date": dates,
            "ticker": ["AAA"] * len(dates),
            "adjusted_close": [100.0 + float(index) for index, _ in enumerate(dates)],
        }
    )
    requested_start_date = dates[320].strftime("%Y-%m-%d")

    train_prices, test_prices, train_end_date, test_start_date, split_ratio = service._split_prices_train_test(
        prices,
        split_ratio=0.9,
        requested_start_date=requested_start_date,
    )

    assert train_end_date == dates[319]
    assert test_start_date == dates[320]
    assert pd.Timestamp(train_prices["date"].max()).normalize() == dates[319]
    assert pd.Timestamp(test_prices["date"].min()).normalize() == dates[320]
    assert split_ratio == 320 / len(dates)


def test_split_prices_train_test_clamps_requested_start_to_minimum_history() -> None:
    service = PortfolioAnalyticsService()
    dates = pd.bdate_range("2024-01-01", periods=400)
    prices = pd.DataFrame(
        {
            "date": dates,
            "ticker": ["AAA"] * len(dates),
            "adjusted_close": [100.0 + float(index) for index, _ in enumerate(dates)],
        }
    )

    _, _, train_end_date, test_start_date, split_ratio = service._split_prices_train_test(
        prices,
        split_ratio=0.9,
        requested_start_date=dates[10].strftime("%Y-%m-%d"),
    )

    assert train_end_date == dates[MINIMUM_HISTORY_ROWS - 1]
    assert test_start_date == dates[MINIMUM_HISTORY_ROWS]
    assert split_ratio == MINIMUM_HISTORY_ROWS / len(dates)
