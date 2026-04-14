from __future__ import annotations

from collections.abc import Callable, Iterable
from datetime import date, datetime, timedelta, timezone

import pandas as pd
import yfinance as yf

from app.domain.enums import PriceRefreshMode
from app.domain.models import ManagedPriceRefreshResult, ManagedUniverseVersion, StockInstrument
from app.services.dividend_yield_service import LiveDividendYieldProvider
from app.services.managed_universe_service import ManagedUniverseService


class PriceRefreshService:
    """Fetches market prices for managed-universe and held-account tickers."""

    def __init__(
        self,
        managed_universe_service: ManagedUniverseService | None = None,
        *,
        extra_ticker_provider: Callable[[ManagedUniverseVersion], Iterable[str]] | None = None,
        dividend_yield_provider: LiveDividendYieldProvider | None = None,
    ) -> None:
        self.managed_universe_service = managed_universe_service or ManagedUniverseService()
        self.extra_ticker_provider = extra_ticker_provider
        self.dividend_yield_provider = dividend_yield_provider or LiveDividendYieldProvider()

    def refresh_prices(
        self,
        *,
        version_id: int | None = None,
        refresh_mode: PriceRefreshMode = PriceRefreshMode.INCREMENTAL,
        full_lookback_years: int = 5,
    ) -> ManagedPriceRefreshResult:
        if not self.managed_universe_service.is_configured():
            raise RuntimeError("DATABASE_URL이 설정되지 않아 가격 갱신을 실행할 수 없습니다.")
        self.managed_universe_service.initialize_storage()
        version = self._resolve_version(version_id)
        instruments = self.managed_universe_service.repository.get_instruments_for_version(version.version_id)
        if not instruments:
            raise RuntimeError("가격 데이터를 갱신할 종목이 없습니다.")
        refresh_tickers = self._build_refresh_tickers(
            version=version,
            instruments=instruments,
        )

        latest_dates = (
            self.managed_universe_service.repository.get_latest_price_dates(refresh_tickers)
            if refresh_mode == PriceRefreshMode.INCREMENTAL
            else {}
        )
        job = self.managed_universe_service.repository.create_refresh_job(
            version_id=version.version_id,
            refresh_mode=refresh_mode,
            ticker_count=len(refresh_tickers),
        )

        success_count = 0
        failure_count = 0
        for ticker in refresh_tickers:
            try:
                start_date = self._resolve_start_date(
                    ticker=ticker,
                    refresh_mode=refresh_mode,
                    latest_dates=latest_dates,
                    full_lookback_years=full_lookback_years,
                )
                frame = self._fetch_ticker_history(ticker, start_date)
                rows_upserted = self.managed_universe_service.repository.upsert_prices(frame, source="yfinance")
                self._refresh_dividend_yield_estimate(ticker)
                self.managed_universe_service.repository.record_refresh_job_item(
                    job_id=job.job_id,
                    ticker=ticker,
                    status="success",
                    rows_upserted=rows_upserted,
                )
                success_count += 1
            except Exception as exc:  # pragma: no cover - network/data-source dependent
                self.managed_universe_service.repository.record_refresh_job_item(
                    job_id=job.job_id,
                    ticker=ticker,
                    status="failed",
                    error_message=str(exc),
                )
                failure_count += 1

        if success_count and failure_count:
            status = "partial_success"
            message = f"{success_count}개 종목 갱신 성공, {failure_count}개 실패"
        elif success_count:
            status = "success"
            message = f"{success_count}개 종목 갱신 성공"
        else:
            status = "failed"
            message = "모든 종목 갱신 실패"

        finished_job = self.managed_universe_service.repository.finish_refresh_job(
            job_id=job.job_id,
            status=status,
            message=message,
        )
        price_window = self.managed_universe_service.get_price_window(
            version.version_id,
            instruments,
        )
        price_stats = self.managed_universe_service.repository.get_price_stats(
            [instrument.ticker for instrument in instruments],
            start_date=None if price_window is None else price_window.aligned_start_date,
            end_date=None if price_window is None else price_window.aligned_end_date,
        )
        return ManagedPriceRefreshResult(
            job=finished_job,
            price_stats=price_stats,
            price_window=price_window,
        )

    def get_latest_job(self, version_id: int | None = None):
        if not self.managed_universe_service.is_configured():
            return None
        return self.managed_universe_service.repository.get_latest_refresh_job(version_id)

    def _resolve_version(self, version_id: int | None) -> ManagedUniverseVersion:
        if version_id is not None:
            version = self.managed_universe_service.repository.get_version(version_id)
            if version is None:
                raise RuntimeError(f"유니버스 버전 {version_id}를 찾을 수 없습니다.")
            return version

        version = self.managed_universe_service.get_active_version()
        if version is None:
            raise RuntimeError("활성화된 관리자 유니버스 버전이 없습니다.")
        return version

    def _resolve_start_date(
        self,
        *,
        ticker: str,
        refresh_mode: PriceRefreshMode,
        latest_dates: dict[str, str],
        full_lookback_years: int,
    ) -> date:
        if refresh_mode == PriceRefreshMode.FULL:
            return (datetime.now(timezone.utc) - timedelta(days=365 * full_lookback_years)).date()

        latest = latest_dates.get(ticker)
        if latest:
            return (datetime.fromisoformat(latest) - timedelta(days=7)).date()
        return (datetime.now(timezone.utc) - timedelta(days=365 * full_lookback_years)).date()

    def _build_refresh_tickers(
        self,
        *,
        version: ManagedUniverseVersion,
        instruments: list[StockInstrument],
    ) -> list[str]:
        tickers = {
            str(instrument.ticker).strip().upper()
            for instrument in instruments
            if str(instrument.ticker).strip()
        }
        if self.extra_ticker_provider is not None:
            for raw_ticker in self.extra_ticker_provider(version):
                ticker = str(raw_ticker).strip().upper()
                if ticker:
                    tickers.add(ticker)
        return sorted(tickers)

    def _refresh_dividend_yield_estimate(self, ticker: str) -> None:
        try:
            estimate = self.dividend_yield_provider.fetch_estimate(ticker)
            self.managed_universe_service.repository.upsert_dividend_yield_estimate(estimate)
        except Exception:
            # Dividend metadata should not block price refresh success.
            return

    def _fetch_ticker_history(self, ticker: str, start_date: date) -> pd.DataFrame:
        frame = yf.download(
            tickers=ticker,
            start=start_date.isoformat(),
            progress=False,
            auto_adjust=False,
            actions=False,
            threads=False,
        )
        if frame.empty:
            raise RuntimeError(f"{ticker} 가격 데이터를 가져오지 못했습니다.")

        working = frame.reset_index()
        date_column, price_column = self._resolve_history_columns(working, ticker)
        result = working[[date_column, price_column]].copy()
        result.columns = ["date", "adjusted_close"]
        result["ticker"] = ticker
        result["date"] = pd.to_datetime(result["date"], errors="coerce")
        result["adjusted_close"] = pd.to_numeric(result["adjusted_close"], errors="coerce")
        result = result.dropna(subset=["date", "adjusted_close"])
        if result.empty:
            raise RuntimeError(f"{ticker} 유효 가격 행이 없습니다.")
        return result[["date", "ticker", "adjusted_close"]]

    def _resolve_history_columns(self, working: pd.DataFrame, ticker: str) -> tuple[object, object]:
        columns = list(working.columns)
        ticker_upper = ticker.upper()

        date_column = next(
            (
                column
                for column in columns
                if self._column_matches(column, {"date", "datetime"})
            ),
            columns[0] if columns else None,
        )
        if date_column is None:
            raise RuntimeError(f"{ticker} 데이터에서 날짜 컬럼을 찾지 못했습니다.")

        price_column = next(
            (
                column
                for column in columns
                if self._column_matches(column, {"adj close", "adjclose"})
            ),
            None,
        )
        if price_column is None:
            price_column = next(
                (
                    column
                    for column in columns
                    if self._column_matches(column, {"close"})
                    and not self._column_matches(column, {"adj close", "adjclose"})
                ),
                None,
            )
        if price_column is None:
            price_column = next(
                (
                    column
                    for column in columns
                    if isinstance(column, tuple)
                    and any(str(part).upper() == ticker_upper for part in column)
                    and any(str(part).lower() in {"adj close", "adjclose", "close"} for part in column)
                ),
                None,
            )

        if price_column is None:
            available = [self._column_debug_name(column) for column in columns]
            raise RuntimeError(
                f"{ticker} 데이터에서 adjusted close/close 컬럼을 찾지 못했습니다. columns={available}"
            )

        return date_column, price_column

    def _column_matches(self, column: object, candidates: set[str]) -> bool:
        parts = [str(part).strip().lower() for part in (column if isinstance(column, tuple) else (column,))]
        return any(part in candidates for part in parts)

    def _column_debug_name(self, column: object) -> str:
        if isinstance(column, tuple):
            return " | ".join(str(part) for part in column if str(part))
        return str(column)
