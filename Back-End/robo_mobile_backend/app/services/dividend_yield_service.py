from __future__ import annotations

from dataclasses import dataclass

import pandas as pd
import yfinance as yf


@dataclass(frozen=True)
class DividendYieldEstimate:
    ticker: str
    annualized_dividend: float
    annual_yield: float
    payments_per_year: int
    frequency_label: str
    last_payment_date: str | None


class DividendYieldService:
    """Infers a forward dividend yield from recent cash dividend history.

    The optimizer already uses adjusted prices for realized return history.
    This service adds an explicit dividend carry overlay to expected returns for
    roles that opt into it.
    """

    STALE_DIVIDEND_MULTIPLIER = 1.75
    MAX_RECENT_PAYMENTS = 8

    def __init__(self) -> None:
        self._cache: dict[str, DividendYieldEstimate] = {}

    def get_annual_yield(self, ticker: str) -> float:
        return float(self.estimate_for_ticker(ticker).annual_yield)

    def estimate_for_ticker(self, ticker: str) -> DividendYieldEstimate:
        normalized = str(ticker).strip().upper()
        cached = self._cache.get(normalized)
        if cached is not None:
            return cached

        estimate = self._fetch_estimate(normalized)
        self._cache[normalized] = estimate
        return estimate

    def _fetch_estimate(self, ticker: str) -> DividendYieldEstimate:
        try:
            instrument = yf.Ticker(ticker)
            dividends = self._load_dividends(instrument)
            latest_price = self._load_latest_price(instrument)
        except Exception:  # pragma: no cover - network/data-source dependent
            return DividendYieldEstimate(
                ticker=ticker,
                annualized_dividend=0.0,
                annual_yield=0.0,
                payments_per_year=0,
                frequency_label="unknown",
                last_payment_date=None,
            )

        if dividends.empty or latest_price is None or latest_price <= 0:
            return DividendYieldEstimate(
                ticker=ticker,
                annualized_dividend=0.0,
                annual_yield=0.0,
                payments_per_year=0,
                frequency_label="none",
                last_payment_date=None if dividends.empty else dividends.index[-1].strftime("%Y-%m-%d"),
            )

        payments_per_year, frequency_label = self._infer_dividend_frequency(dividends)
        if payments_per_year <= 0:
            return DividendYieldEstimate(
                ticker=ticker,
                annualized_dividend=0.0,
                annual_yield=0.0,
                payments_per_year=0,
                frequency_label="none",
                last_payment_date=dividends.index[-1].strftime("%Y-%m-%d"),
            )

        latest_payment_date = dividends.index[-1]
        expected_interval_days = max(int(round(365 / payments_per_year)), 1)
        staleness_days = int((pd.Timestamp.utcnow().tz_localize(None) - latest_payment_date).days)
        if staleness_days > int(expected_interval_days * self.STALE_DIVIDEND_MULTIPLIER):
            return DividendYieldEstimate(
                ticker=ticker,
                annualized_dividend=0.0,
                annual_yield=0.0,
                payments_per_year=payments_per_year,
                frequency_label=f"{frequency_label}_stale",
                last_payment_date=latest_payment_date.strftime("%Y-%m-%d"),
            )

        recent_payments = dividends.tail(min(self.MAX_RECENT_PAYMENTS, max(payments_per_year, 1)))
        if len(recent_payments) >= payments_per_year:
            annualized_dividend = float(recent_payments.tail(payments_per_year).sum())
        else:
            annualized_dividend = float(recent_payments.mean()) * float(payments_per_year)

        annual_yield = 0.0 if latest_price <= 0 else max(annualized_dividend / latest_price, 0.0)
        return DividendYieldEstimate(
            ticker=ticker,
            annualized_dividend=annualized_dividend,
            annual_yield=float(annual_yield),
            payments_per_year=payments_per_year,
            frequency_label=frequency_label,
            last_payment_date=latest_payment_date.strftime("%Y-%m-%d"),
        )

    def _load_dividends(self, instrument: yf.Ticker) -> pd.Series:
        dividends = instrument.dividends
        if dividends is None or len(dividends) == 0:
            return pd.Series(dtype=float)

        series = pd.Series(dividends, dtype=float).dropna()
        series = series[series > 0]
        if series.empty:
            return pd.Series(dtype=float)

        series.index = pd.to_datetime(series.index, errors="coerce")
        series = series[~series.index.isna()]
        if getattr(series.index, "tz", None) is not None:
            series.index = series.index.tz_localize(None)
        return series.sort_index()

    def _load_latest_price(self, instrument: yf.Ticker) -> float | None:
        latest_price: float | None = None
        try:
            fast_info = instrument.fast_info
            if fast_info is not None:
                for key in ("lastPrice", "regularMarketPreviousClose", "previousClose"):
                    value = fast_info.get(key) if isinstance(fast_info, dict) else getattr(fast_info, key, None)
                    if value is not None and pd.notna(value):
                        latest_price = float(value)
                        break
        except Exception:
            latest_price = None

        if latest_price is not None and latest_price > 0:
            return latest_price

        try:
            history = instrument.history(period="1mo", auto_adjust=False, actions=False)
            if history is None or history.empty:
                return None
            close_col = "Adj Close" if "Adj Close" in history.columns else "Close"
            values = pd.to_numeric(history[close_col], errors="coerce").dropna()
            if values.empty:
                return None
            return float(values.iloc[-1])
        except Exception:
            return None

    def _infer_dividend_frequency(self, dividends: pd.Series) -> tuple[int, str]:
        recent = dividends.tail(self.MAX_RECENT_PAYMENTS)
        if len(recent) < 2:
            return 1, "annual"

        intervals = recent.index.to_series().diff().dropna().dt.days.astype(float)
        if intervals.empty:
            return 1, "annual"
        median_days = float(intervals.median())

        if median_days <= 45:
            return 12, "monthly"
        if median_days <= 80:
            return 6, "bi_monthly"
        if median_days <= 120:
            return 4, "quarterly"
        if median_days <= 220:
            return 2, "semiannual"
        return 1, "annual"
