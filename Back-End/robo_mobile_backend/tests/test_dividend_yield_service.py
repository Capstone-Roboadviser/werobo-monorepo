from __future__ import annotations

import unittest
from unittest.mock import patch

from app.domain.models import DividendYieldEstimate
from app.services.dividend_yield_service import DividendYieldService
from app.services.portfolio_analytics_service import PortfolioAnalyticsService


class FakeDividendYieldRepository:
    def __init__(self, estimates: dict[str, DividendYieldEstimate] | None = None) -> None:
        self.estimates = {ticker.upper(): estimate for ticker, estimate in (estimates or {}).items()}

    def is_configured(self) -> bool:
        return True

    def get_dividend_yield_estimate(self, ticker: str) -> DividendYieldEstimate | None:
        return self.estimates.get(str(ticker).strip().upper())


class FakeLiveDividendYieldProvider:
    def __init__(self, estimate: DividendYieldEstimate | None = None) -> None:
        self.estimate = estimate or DividendYieldEstimate(
            ticker="BND",
            annualized_dividend=1.0,
            annual_yield=0.01,
            payments_per_year=4,
            frequency_label="quarterly",
            last_payment_date="2026-03-31",
            source="yfinance",
        )
        self.calls: list[str] = []

    def fetch_estimate(self, ticker: str) -> DividendYieldEstimate:
        normalized = str(ticker).strip().upper()
        self.calls.append(normalized)
        return DividendYieldEstimate(
            ticker=normalized,
            annualized_dividend=self.estimate.annualized_dividend,
            annual_yield=self.estimate.annual_yield,
            payments_per_year=self.estimate.payments_per_year,
            frequency_label=self.estimate.frequency_label,
            last_payment_date=self.estimate.last_payment_date,
            source=self.estimate.source,
        )


class DividendYieldServiceTests(unittest.TestCase):
    def test_dividend_yield_service_prefers_stored_estimate(self) -> None:
        repository = FakeDividendYieldRepository(
            estimates={
                "BND": DividendYieldEstimate(
                    ticker="BND",
                    annualized_dividend=2.4,
                    annual_yield=0.024,
                    payments_per_year=4,
                    frequency_label="quarterly",
                    last_payment_date="2026-03-31",
                    source="stored_refresh",
                    updated_at="2026-04-14T00:00:00Z",
                )
            }
        )
        live_provider = FakeLiveDividendYieldProvider()
        service = DividendYieldService(
            repository=repository,
            allow_live_fallback=False,
            live_provider=live_provider,
        )

        estimate = service.estimate_for_ticker("BND")

        self.assertEqual(estimate.annual_yield, 0.024)
        self.assertEqual(estimate.source, "stored_refresh")
        self.assertEqual(live_provider.calls, [])

    def test_dividend_yield_service_returns_zero_when_live_fetch_disabled_and_store_missing(self) -> None:
        repository = FakeDividendYieldRepository()
        live_provider = FakeLiveDividendYieldProvider()
        service = DividendYieldService(
            repository=repository,
            allow_live_fallback=False,
            live_provider=live_provider,
        )

        estimate = service.estimate_for_ticker("BND1")

        self.assertEqual(estimate.ticker, "BND1")
        self.assertEqual(estimate.annual_yield, 0.0)
        self.assertEqual(estimate.frequency_label, "disabled")
        self.assertEqual(live_provider.calls, [])

    def test_portfolio_analytics_service_skips_benchmark_fetch_when_live_fetch_disabled(self) -> None:
        service = PortfolioAnalyticsService()

        with patch("app.services.portfolio_analytics_service.ENABLE_LIVE_MARKET_DATA_FETCH", False):
            benchmarks = service._fetch_benchmark_prices("2024-01-01")

        self.assertEqual(benchmarks, {})


if __name__ == "__main__":
    unittest.main()
