from __future__ import annotations

from datetime import date

import pandas as pd

from app.domain.enums import PriceRefreshMode
from app.domain.models import (
    ManagedPriceRefreshJob,
    ManagedPriceStats,
    ManagedUniversePriceWindow,
    ManagedUniverseVersion,
    StockInstrument,
)
from app.services.price_refresh_service import PriceRefreshService


class FakeManagedUniverseRepository:
    def __init__(self) -> None:
        self.latest_price_dates_requests: list[list[str]] = []
        self.created_jobs: list[dict[str, object]] = []
        self.recorded_items: list[dict[str, object]] = []
        self.upserted_tickers: list[str] = []
        self.price_stats_requests: list[dict[str, object]] = []

    def get_instruments_for_version(self, version_id: int) -> list[StockInstrument]:
        assert version_id == 1
        return [
            StockInstrument(
                ticker="QQQ",
                name="Invesco QQQ Trust",
                sector_code="us_growth",
                sector_name="미국 성장주",
                market="NASDAQ",
                currency="USD",
            ),
            StockInstrument(
                ticker="BND",
                name="Vanguard Total Bond Market ETF",
                sector_code="bond",
                sector_name="채권",
                market="NASDAQ",
                currency="USD",
            ),
        ]

    def get_latest_price_dates(self, tickers: list[str]) -> dict[str, str]:
        self.latest_price_dates_requests.append(list(tickers))
        return {
            "QQQ": "2026-04-13",
            "BND": "2026-04-13",
            "OLD": "2026-04-13",
        }

    def create_refresh_job(
        self,
        *,
        version_id: int,
        refresh_mode: PriceRefreshMode,
        ticker_count: int,
    ) -> ManagedPriceRefreshJob:
        self.created_jobs.append(
            {
                "version_id": version_id,
                "refresh_mode": refresh_mode,
                "ticker_count": ticker_count,
            }
        )
        return ManagedPriceRefreshJob(
            job_id=1,
            version_id=version_id,
            version_name="active-v1",
            refresh_mode=refresh_mode,
            status="running",
            ticker_count=ticker_count,
            success_count=0,
            failure_count=0,
            message=None,
            created_at="2026-04-14T00:00:00Z",
            started_at="2026-04-14T00:00:00Z",
            finished_at=None,
        )

    def upsert_prices(self, frame: pd.DataFrame, *, source: str) -> int:
        assert source == "yfinance"
        self.upserted_tickers.append(str(frame["ticker"].iloc[0]))
        return len(frame)

    def record_refresh_job_item(
        self,
        *,
        job_id: int,
        ticker: str,
        status: str,
        rows_upserted: int = 0,
        error_message: str | None = None,
    ) -> None:
        self.recorded_items.append(
            {
                "job_id": job_id,
                "ticker": ticker,
                "status": status,
                "rows_upserted": rows_upserted,
                "error_message": error_message,
            }
        )

    def finish_refresh_job(
        self,
        *,
        job_id: int,
        status: str,
        message: str | None = None,
    ) -> ManagedPriceRefreshJob:
        return ManagedPriceRefreshJob(
            job_id=job_id,
            version_id=1,
            version_name="active-v1",
            refresh_mode=PriceRefreshMode.INCREMENTAL,
            status=status,
            ticker_count=3,
            success_count=3,
            failure_count=0,
            message=message,
            created_at="2026-04-14T00:00:00Z",
            started_at="2026-04-14T00:00:00Z",
            finished_at="2026-04-14T00:01:00Z",
        )

    def get_price_stats(
        self,
        tickers: list[str],
        *,
        start_date: str | None = None,
        end_date: str | None = None,
    ) -> ManagedPriceStats:
        self.price_stats_requests.append(
            {
                "tickers": list(tickers),
                "start_date": start_date,
                "end_date": end_date,
            }
        )
        return ManagedPriceStats(
            total_rows=100,
            ticker_count=len(tickers),
            min_date=start_date,
            max_date=end_date,
        )


class FakeManagedUniverseService:
    def __init__(self) -> None:
        self.repository = FakeManagedUniverseRepository()
        self.initialized = False

    def is_configured(self) -> bool:
        return True

    def initialize_storage(self) -> None:
        self.initialized = True

    def get_active_version(self) -> ManagedUniverseVersion:
        return ManagedUniverseVersion(
            version_id=1,
            version_name="active-v1",
            source_type="admin_input",
            notes=None,
            is_active=True,
            created_at="2026-04-14T00:00:00Z",
            instrument_count=2,
        )

    def get_price_window(
        self,
        version_id: int,
        instruments: list[StockInstrument],
    ) -> ManagedUniversePriceWindow:
        assert version_id == 1
        assert [instrument.ticker for instrument in instruments] == ["QQQ", "BND"]
        return ManagedUniversePriceWindow(
            version_id=version_id,
            aligned_start_date="2024-01-01",
            aligned_end_date="2026-04-14",
            youngest_ticker="QQQ",
            youngest_start_date="2024-01-01",
            ticker_count=len(instruments),
        )


class StubPriceRefreshService(PriceRefreshService):
    def _fetch_ticker_history(self, ticker: str, start_date: date) -> pd.DataFrame:
        return pd.DataFrame(
            [
                {
                    "date": pd.Timestamp("2026-04-14"),
                    "ticker": ticker,
                    "adjusted_close": 100.0,
                }
            ]
        )


def test_refresh_prices_includes_managed_account_holdings() -> None:
    managed_universe_service = FakeManagedUniverseService()
    service = StubPriceRefreshService(
        managed_universe_service,
        extra_ticker_provider=lambda version: ["old", "QQQ"] if version.is_active else [],
    )

    result = service.refresh_prices(refresh_mode=PriceRefreshMode.INCREMENTAL)

    assert managed_universe_service.initialized is True
    assert managed_universe_service.repository.created_jobs == [
        {
            "version_id": 1,
            "refresh_mode": PriceRefreshMode.INCREMENTAL,
            "ticker_count": 3,
        }
    ]
    assert managed_universe_service.repository.latest_price_dates_requests == [
        ["BND", "OLD", "QQQ"]
    ]
    assert managed_universe_service.repository.upserted_tickers == ["BND", "OLD", "QQQ"]
    assert [item["ticker"] for item in managed_universe_service.repository.recorded_items] == [
        "BND",
        "OLD",
        "QQQ",
    ]
    assert managed_universe_service.repository.price_stats_requests == [
        {
            "tickers": ["QQQ", "BND"],
            "start_date": "2024-01-01",
            "end_date": "2026-04-14",
        }
    ]
    assert result.job.status == "success"
    assert result.job.ticker_count == 3
    assert result.price_stats.ticker_count == 2
