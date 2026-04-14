from __future__ import annotations

import pandas as pd

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
