from __future__ import annotations

from contextlib import contextmanager
from threading import Event
from types import SimpleNamespace

from fastapi import HTTPException
import pandas as pd
import pytest

from app.core.config import MINIMUM_HISTORY_ROWS
from mobile_backend.api.routes import admin_comparison as comparison_routes


@pytest.fixture(autouse=True)
def clear_route_caches() -> None:
    comparison_routes._basis_date_window_cache.clear()
    comparison_routes._frontier_cache.clear()
    comparison_routes._frontier_inflight.clear()


def test_comparison_basis_date_windows_exposes_valid_window(monkeypatch) -> None:
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
    monkeypatch.setattr(
        comparison_routes,
        "_basis_date_has_representative_history",
        lambda **kwargs: True,
    )

    response = comparison_routes.get_basis_date_windows(version_ids="7")
    window = response["windows"][0]["basis_date_window"]

    assert window["first_price_date"] == dates[0].strftime("%Y-%m-%d")
    assert window["last_price_date"] == dates[-1].strftime("%Y-%m-%d")
    assert window["min_basis_date"] == dates[MINIMUM_HISTORY_ROWS].strftime("%Y-%m-%d")
    assert window["max_basis_date"] == dates[-2].strftime("%Y-%m-%d")
    assert window["train_return_rows"] == MINIMUM_HISTORY_ROWS


def test_comparison_basis_date_windows_ignores_forward_filled_gaps(
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
    monkeypatch.setattr(
        comparison_routes,
        "_basis_date_has_representative_history",
        lambda **kwargs: True,
    )

    response = comparison_routes.get_basis_date_windows(version_ids="7")
    window = response["windows"][0]["basis_date_window"]
    raw_common_dates = [date for date in dates if date != missing_date]

    assert window["min_basis_date"] == raw_common_dates[
        MINIMUM_HISTORY_ROWS
    ].strftime("%Y-%m-%d")
    assert window["common_price_rows"] == len(raw_common_dates)


def test_comparison_basis_date_windows_omits_window_without_post_basis_data(
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

    response = comparison_routes.get_basis_date_windows(version_ids="7")

    assert response["windows"][0]["basis_date_window"] is None


def test_comparison_basis_date_windows_advances_basis_until_representative_history(
    monkeypatch,
) -> None:
    dates = pd.date_range("2020-01-02", periods=265, freq="B")
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
    first_buildable_date = dates[MINIMUM_HISTORY_ROWS + 3]

    def has_representative_history(**kwargs) -> bool:
        max_date = pd.to_datetime(kwargs["prices"]["date"]).max().normalize()
        return max_date >= first_buildable_date

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)
    monkeypatch.setattr(
        comparison_routes,
        "_basis_date_has_representative_history",
        has_representative_history,
    )

    response = comparison_routes.get_basis_date_windows(version_ids="7")
    window = response["windows"][0]["basis_date_window"]

    assert window["min_basis_date"] == first_buildable_date.strftime("%Y-%m-%d")


def test_comparison_basis_date_windows_uses_persistent_cache(monkeypatch) -> None:
    version = SimpleNamespace(
        version_id=7,
        version_name="test universe",
        is_active=True,
        notes=None,
    )
    cached_window = {
        "first_price_date": "2020-01-02",
        "last_price_date": "2020-12-30",
        "min_basis_date": "2020-12-18",
        "max_basis_date": "2020-12-29",
        "train_return_rows": MINIMUM_HISTORY_ROWS,
        "common_price_rows": 260,
    }
    fake_repository = SimpleNamespace(
        is_configured=lambda: True,
        get_admin_comparison_frontier_price_signature=lambda **kwargs: "price-signature",
        get_admin_comparison_basis_date_window_cache=lambda **kwargs: {
            "basis_date_window": cached_window,
        },
    )
    fake_service = SimpleNamespace(
        repository=fake_repository,
        list_versions=lambda: [version],
        list_assets=lambda: [],
        get_instruments_for_version=lambda version_id: pytest.fail(
            "persistent cache hit should skip expensive basis window calculation"
        ),
    )

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)

    response = comparison_routes.get_basis_date_windows(version_ids="7")

    assert response["windows"][0]["basis_date_window"] == cached_window


def test_frontier_rejects_when_price_refresh_is_running(monkeypatch) -> None:
    fake_repository = SimpleNamespace(
        is_configured=lambda: True,
        get_running_refresh_job=lambda version_id: SimpleNamespace(job_id=123),
    )
    fake_service = SimpleNamespace(repository=fake_repository)
    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)

    with pytest.raises(HTTPException) as exc_info:
        comparison_routes.get_frontier(comparison_routes.FrontierRequest(version_id=7))

    assert exc_info.value.status_code == 409
    assert "refresh_job_id=123" in exc_info.value.detail


def test_frontier_rejects_duplicate_inflight_calculation_after_wait(
    monkeypatch,
) -> None:
    fake_repository = SimpleNamespace(is_configured=lambda: False)
    fake_service = SimpleNamespace(repository=fake_repository)
    payload = comparison_routes.FrontierRequest(version_id=7)

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)
    monkeypatch.setattr(comparison_routes, "_FRONTIER_INFLIGHT_WAIT_SECONDS", 0)
    monkeypatch.setattr(
        comparison_routes,
        "_get_frontier_price_signature",
        lambda request: "price-signature",
    )

    cache_key = comparison_routes._frontier_cache_key(
        payload,
        price_signature="price-signature",
    )
    comparison_routes._frontier_inflight[cache_key] = (0.0, Event())

    with pytest.raises(HTTPException) as exc_info:
        comparison_routes.get_frontier(payload)

    assert exc_info.value.status_code == 409
    assert "이미 진행 중" in exc_info.value.detail


def test_frontier_rejects_when_distributed_lock_is_busy(monkeypatch) -> None:
    @contextmanager
    def busy_lock(lock_name: str):
        yield False

    fake_repository = SimpleNamespace(
        is_configured=lambda: True,
        get_running_refresh_job=lambda version_id: None,
        get_admin_comparison_frontier_price_signature=lambda **kwargs: "price-signature",
        get_admin_comparison_frontier_cache=lambda **kwargs: None,
        admin_comparison_frontier_calculation_lock=busy_lock,
    )
    fake_service = SimpleNamespace(repository=fake_repository)

    monkeypatch.setattr(comparison_routes, "managed_universe_service", fake_service)

    with pytest.raises(HTTPException) as exc_info:
        comparison_routes.get_frontier(comparison_routes.FrontierRequest(version_id=7))

    assert exc_info.value.status_code == 409
    assert "이미 진행 중" in exc_info.value.detail
