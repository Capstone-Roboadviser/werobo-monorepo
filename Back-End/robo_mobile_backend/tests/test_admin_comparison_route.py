from __future__ import annotations

from types import SimpleNamespace

import pandas as pd

from app.core.config import MINIMUM_HISTORY_ROWS
from mobile_backend.api.routes import admin_comparison as comparison_routes


def test_comparison_catalog_exposes_valid_basis_date_window(monkeypatch) -> None:
    dates = pd.date_range("2020-01-02", periods=260, freq="B")
    prices = pd.DataFrame(
        [
            {"date": date, "ticker": ticker, "adjusted_close": 100.0 + idx}
            for idx, date in enumerate(dates)
            for ticker in ("AAA", "BBB")
        ]
    )
    version = SimpleNamespace(
        version_id=7,
        version_name="test universe",
        is_active=True,
        notes=None,
    )
    fake_service = SimpleNamespace(
        list_assets=lambda: [],
        list_versions=lambda: [version],
        get_instruments_for_version=lambda version_id: [
            SimpleNamespace(ticker="AAA"),
            SimpleNamespace(ticker="BBB"),
        ],
        load_prices_for_instruments=lambda instruments, **kwargs: prices,
    )

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)

    response = comparison_routes.get_comparison_catalog()
    window = response["versions"][0]["basis_date_window"]

    assert window["first_price_date"] == dates[0].strftime("%Y-%m-%d")
    assert window["last_price_date"] == dates[-1].strftime("%Y-%m-%d")
    assert window["min_basis_date"] == dates[MINIMUM_HISTORY_ROWS].strftime("%Y-%m-%d")
    assert window["max_basis_date"] == dates[-2].strftime("%Y-%m-%d")
    assert window["train_return_rows"] == MINIMUM_HISTORY_ROWS


def test_comparison_catalog_basis_window_ignores_forward_filled_gaps(
    monkeypatch,
) -> None:
    dates = pd.date_range("2020-01-02", periods=260, freq="B")
    missing_date = dates[10]
    prices = pd.DataFrame(
        [
            {"date": date, "ticker": ticker, "adjusted_close": 100.0 + idx}
            for idx, date in enumerate(dates)
            for ticker in ("AAA", "BBB")
            if not (ticker == "BBB" and date == missing_date)
        ]
    )
    version = SimpleNamespace(
        version_id=7,
        version_name="test universe",
        is_active=True,
        notes=None,
    )
    fake_service = SimpleNamespace(
        list_assets=lambda: [],
        list_versions=lambda: [version],
        get_instruments_for_version=lambda version_id: [
            SimpleNamespace(ticker="AAA"),
            SimpleNamespace(ticker="BBB"),
        ],
        load_prices_for_instruments=lambda instruments, **kwargs: prices,
    )

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)

    response = comparison_routes.get_comparison_catalog()
    window = response["versions"][0]["basis_date_window"]
    raw_common_dates = [date for date in dates if date != missing_date]

    assert window["min_basis_date"] == raw_common_dates[
        MINIMUM_HISTORY_ROWS
    ].strftime("%Y-%m-%d")
    assert window["common_price_rows"] == len(raw_common_dates)


def test_comparison_catalog_omits_basis_window_without_post_basis_data(
    monkeypatch,
) -> None:
    dates = pd.date_range("2020-01-02", periods=MINIMUM_HISTORY_ROWS + 1, freq="B")
    prices = pd.DataFrame(
        [
            {"date": date, "ticker": ticker, "adjusted_close": 100.0 + idx}
            for idx, date in enumerate(dates)
            for ticker in ("AAA", "BBB")
        ]
    )
    version = SimpleNamespace(
        version_id=7,
        version_name="test universe",
        is_active=True,
        notes=None,
    )
    fake_service = SimpleNamespace(
        list_assets=lambda: [],
        list_versions=lambda: [version],
        get_instruments_for_version=lambda version_id: [
            SimpleNamespace(ticker="AAA"),
            SimpleNamespace(ticker="BBB"),
        ],
        load_prices_for_instruments=lambda instruments, **kwargs: prices,
    )

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)

    response = comparison_routes.get_comparison_catalog()

    assert response["versions"][0]["basis_date_window"] is None
