from __future__ import annotations

import pandas as pd

from app.domain.enums import SimulationDataSource
from app.domain.models import AssetClass, StockInstrument
from app.services.portfolio_analytics_service import PortfolioAnalyticsService


def _asset(
    code: str,
    name: str,
    *,
    role_key: str = "single_representative",
    weighting_mode: str = "single",
    return_mode: str = "black_litterman",
) -> AssetClass:
    return AssetClass(
        code=code,
        name=name,
        category="demo",
        description="",
        color="#000000",
        min_weight=0.0,
        max_weight=0.3,
        role_key=role_key,
        role_name="",
        role_description="",
        selection_mode="single_representative",
        weighting_mode=weighting_mode,
        return_mode=return_mode,
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


def test_build_equal_weight_asset_benchmark_line_caps_fixed_five_percent_role_upside() -> None:
    service = PortfolioAnalyticsService()
    date_index = pd.to_datetime(["2026-03-01", "2026-03-02", "2026-03-03"])
    prices = pd.DataFrame(
        [
            {"date": "2026-03-01", "ticker": "AAA", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "AAA", "adjusted_close": 200.0},
            {"date": "2026-03-03", "ticker": "AAA", "adjusted_close": 400.0},
            {"date": "2026-03-01", "ticker": "BBB", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "BBB", "adjusted_close": 100.0},
            {"date": "2026-03-03", "ticker": "BBB", "adjusted_close": 100.0},
        ]
    )
    instruments = [
        StockInstrument(
            ticker="AAA",
            name="Thematic",
            sector_code="new_growth",
            sector_name="신성장주",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
        StockInstrument(
            ticker="BBB",
            name="Gold",
            sector_code="gold",
            sector_name="금",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
    ]
    assets = [
        _asset(
            "new_growth",
            "신성장주",
            role_key="fixed_five_percent_equal_weight",
            weighting_mode="equal_weight_fixed_total_5pct",
            return_mode=(
                service.portfolio_service.fixed_five_percent_role_return_service.RETURN_MODE
            ),
        ),
        _asset("gold", "금"),
    ]

    line = service._build_equal_weight_asset_benchmark_line(
        assets=assets,
        instruments=instruments,
        prices=prices,
        date_index=date_index,
    )

    conservative_path = service._build_conservative_cap_path(date_index=date_index)
    expected_points = [
        (
            date.strftime("%Y-%m-%d"),
            round((((float(capped_value) + 1.0) / 2.0) - 1.0) * 100, 4),
        )
        for date, capped_value in conservative_path.items()
    ]

    assert line is not None
    assert line.points == expected_points


def test_build_equal_weight_asset_benchmark_line_keeps_fixed_five_percent_role_drawdown() -> None:
    service = PortfolioAnalyticsService()
    date_index = pd.to_datetime(["2026-03-01", "2026-03-02", "2026-03-03"])
    prices = pd.DataFrame(
        [
            {"date": "2026-03-01", "ticker": "AAA", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "AAA", "adjusted_close": 90.0},
            {"date": "2026-03-03", "ticker": "AAA", "adjusted_close": 80.0},
            {"date": "2026-03-01", "ticker": "BBB", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "BBB", "adjusted_close": 100.0},
            {"date": "2026-03-03", "ticker": "BBB", "adjusted_close": 100.0},
        ]
    )
    instruments = [
        StockInstrument(
            ticker="AAA",
            name="Thematic",
            sector_code="new_growth",
            sector_name="신성장주",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
        StockInstrument(
            ticker="BBB",
            name="Gold",
            sector_code="gold",
            sector_name="금",
            market="USA",
            currency="USD",
            base_weight=1.0,
        ),
    ]
    assets = [
        _asset(
            "new_growth",
            "신성장주",
            role_key="fixed_five_percent_equal_weight",
            weighting_mode="equal_weight_fixed_total_5pct",
            return_mode=(
                service.portfolio_service.fixed_five_percent_role_return_service.RETURN_MODE
            ),
        ),
        _asset("gold", "금"),
    ]

    line = service._build_equal_weight_asset_benchmark_line(
        assets=assets,
        instruments=instruments,
        prices=prices,
        date_index=date_index,
    )

    assert line is not None
    assert line.points == [
        ("2026-03-01", 0.0),
        ("2026-03-02", -5.0),
        ("2026-03-03", -10.0),
    ]


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


def test_build_comparison_backtest_uses_current_fixed_stock_weights() -> None:
    service = PortfolioAnalyticsService()
    dates = pd.to_datetime(["2026-03-01", "2026-03-02", "2026-03-03"])
    prices = pd.DataFrame(
        [
            {"date": "2026-03-01", "ticker": "AAA", "adjusted_close": 100.0},
            {"date": "2026-03-02", "ticker": "AAA", "adjusted_close": 110.0},
            {"date": "2026-03-03", "ticker": "AAA", "adjusted_close": 120.0},
            {"date": "2026-03-01", "ticker": "BBB", "adjusted_close": 200.0},
            {"date": "2026-03-02", "ticker": "BBB", "adjusted_close": 220.0},
            {"date": "2026-03-03", "ticker": "BBB", "adjusted_close": 240.0},
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
    service._load_comparison_assets = lambda data_source: assets
    service._load_comparison_universe = lambda data_source: (instruments, prices, "demo")
    service._fetch_benchmark_prices = lambda start_date: {}

    result = service.build_comparison_backtest(
        data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        stock_weights={"AAA": 0.6, "BBB": 0.4},
        portfolio_code="balanced",
    )

    assert result.split_ratio == 1.0
    assert result.start_date == "2026-03-01"
    assert result.train_start_date == "2026-03-01"
    assert result.train_end_date == "2026-03-01"
    assert [line.key for line in result.lines] == ["balanced", "benchmark_avg", "treasury"]
    assert result.lines[0].points[0] == ("2026-03-01", 0.0)
