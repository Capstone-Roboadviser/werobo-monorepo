from __future__ import annotations

import math
from types import SimpleNamespace

import pandas as pd

from app.domain.models import AssetClass, StockInstrument
from mobile_backend.services.usmv_overlay_comparison_service import (
    UsmvOverlayComparisonService,
)


def _asset(code: str, name: str, color: str, max_weight: float = 0.8) -> AssetClass:
    return AssetClass(
        code=code,
        name=name,
        category="test",
        description=name,
        color=color,
        min_weight=0.0,
        max_weight=max_weight,
        role_key=code,
        role_name=name,
        role_description=name,
        selection_mode="test",
        weighting_mode="test",
        return_mode="historical",
    )


def _instrument(ticker: str, asset: AssetClass) -> StockInstrument:
    return StockInstrument(
        ticker=ticker,
        name=ticker,
        sector_code=asset.code,
        sector_name=asset.name,
        market="US",
        currency="USD",
    )


def _prices(dates: pd.DatetimeIndex) -> pd.DataFrame:
    rows: list[dict[str, object]] = []
    specs = {
        "AAA": (0.00020, 0.004, 0.0),
        "BBB": (0.00055, 0.010, 1.7),
        "CCC": (0.00032, 0.006, 3.1),
    }
    for ticker, (drift, wave, phase) in specs.items():
        value = 100.0
        for index, day in enumerate(dates):
            if index > 0:
                value *= 1.0 + drift + wave * math.sin(index / 9.0 + phase) / 100.0
            rows.append(
                {
                    "date": day,
                    "ticker": ticker,
                    "adjusted_close": value,
                }
            )
    return pd.DataFrame(rows)


def _overlay_csv(path, dates: pd.DatetimeIndex) -> None:
    value = 100.0
    rows = []
    for index, day in enumerate(dates):
        if index > 0:
            value *= 1.0 + 0.00075 + 0.003 * math.cos(index / 13.0) / 100.0
        rows.append(
            {
                "date": day.strftime("%Y-%m-%d"),
                "portfolio_USMV_overlay": round(value, 6),
                "portfolio_cash_baseline": 100.0,
                "SPY": round(100.0 * (1.0005 ** index), 6),
                "USMV": round(100.0 * (1.00035 ** index), 6),
            }
        )
    pd.DataFrame(rows).to_csv(path, index=False)


def test_overlay_impact_builds_baseline_and_augmented_frontiers(tmp_path) -> None:
    dates = pd.date_range("2023-01-03", periods=270, freq="B")
    assets = [
        _asset("defensive", "방어형", "#14b8a6"),
        _asset("growth", "성장형", "#f97316"),
        _asset("income", "인컴", "#8b5cf6"),
    ]
    instruments = [
        _instrument("AAA", assets[0]),
        _instrument("BBB", assets[1]),
        _instrument("CCC", assets[2]),
    ]
    prices = _prices(dates)
    overlay_path = tmp_path / "daily_performance_normalized.csv"
    _overlay_csv(overlay_path, dates)

    fake_managed_universe_service = SimpleNamespace(
        get_assets_for_version=lambda version_id: assets,
        get_instruments_for_version=lambda version_id: instruments,
        load_prices_for_instruments=lambda loaded, version_id: prices,
    )
    service = UsmvOverlayComparisonService(
        managed_universe_service=fake_managed_universe_service,
        csv_path=overlay_path,
    )

    result = service.build_overlay_impact(
        version_id=7,
        sample_points=11,
        overlay_max_weight=0.3,
    )

    assert result["version_id"] == 7
    assert result["overlay"]["code"] == "usmv_overlay"
    assert result["overlay"]["max_weight"] == 0.3
    assert len(result["baseline"]["frontier_points"]) >= 3
    assert len(result["with_overlay"]["frontier_points"]) >= 3
    assert result["period"]["start_date"] == "2023-01-04"
    assert result["period"]["end_date"] == dates[-1].strftime("%Y-%m-%d")

    augmented_weights = [
        point["weights"].get("usmv_overlay", 0)
        for point in result["with_overlay"]["frontier_points"]
    ]
    assert max(augmented_weights) > 0
    assert max(augmented_weights) <= 0.300001

    balanced = result["matched_points"]["balanced"]
    assert balanced["baseline"]["volatility"] > 0
    assert balanced["with_overlay"]["volatility"] > 0
    assert balanced["with_overlay"]["overlay_weight"] >= 0
    assert "delta_expected_return" in balanced

    line_keys = {line["key"] for line in result["performance_lines"]}
    assert {"baseline_balanced", "with_overlay_balanced", "overlay"}.issubset(
        line_keys
    )
