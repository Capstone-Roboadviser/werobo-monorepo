from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pandas as pd
import pytest

from mobile_backend.services import digest_service as digest_module


class FakeAccountRepository:
    def __init__(self, snapshots: list[dict[str, object]]) -> None:
        self.snapshots = snapshots

    def list_snapshots(self, account_id: int) -> list[dict[str, object]]:
        assert account_id == 1
        return list(self.snapshots)


class FakeDigestRepository:
    def __init__(self) -> None:
        self.cached: dict[int, dict[str, object]] = {}

    def get_cached(self, account_id: int) -> dict | None:
        return self.cached.get(account_id)

    def cache(self, account_id: int, digest: dict) -> None:
        self.cached[account_id] = dict(digest)


class FakeUniverseRepository:
    def __init__(self) -> None:
        self.load_prices_calls = 0

    def load_prices_for_tickers(
        self,
        tickers: list[str],
        *,
        start_date: str | None = None,
        end_date: str | None = None,
    ) -> pd.DataFrame:
        self.load_prices_calls += 1
        return pd.DataFrame(columns=["date", "ticker", "adjusted_close"])

    def get_active_instruments(self) -> list[object]:
        return []


class FakeStockDataRepository:
    def load_stock_prices(self, path: str) -> pd.DataFrame:
        end_date = datetime.now(timezone.utc).date() - timedelta(days=1)
        start_date = end_date - timedelta(days=5)
        return pd.DataFrame(
            [
                {
                    "date": pd.Timestamp(start_date),
                    "ticker": "AAA",
                    "adjusted_close": 100.0,
                },
                {
                    "date": pd.Timestamp(end_date),
                    "ticker": "AAA",
                    "adjusted_close": 110.0,
                },
                {
                    "date": pd.Timestamp(start_date),
                    "ticker": "BBB",
                    "adjusted_close": 100.0,
                },
                {
                    "date": pd.Timestamp(end_date),
                    "ticker": "BBB",
                    "adjusted_close": 90.0,
                },
            ]
        )


def test_generate_digest_uses_demo_price_source_for_demo_accounts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    service = digest_module.DigestService()
    service.account_repo = FakeAccountRepository(
        snapshots=[
            {
                "snapshot_date": (datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat(),
                "portfolio_value": 10_000_000,
            }
        ]
    )
    service.digest_repo = FakeDigestRepository()
    service.universe_repo = FakeUniverseRepository()

    monkeypatch.setattr(digest_module, "StockDataRepository", FakeStockDataRepository)
    monkeypatch.setattr(digest_module, "fetch_news_for_tickers", lambda tickers: {})
    monkeypatch.setattr(digest_module, "get_sources_used", lambda news: [])
    monkeypatch.setattr(digest_module, "generate_narrative", lambda **kwargs: None)

    digest = service.generate(
        {
            "id": 1,
            "data_source": "stock_combination_demo",
            "portfolio_label": "균형형",
            "stock_allocations": [
                {
                    "ticker": "AAA",
                    "name": "Alpha Asset",
                    "sector_code": "us_growth",
                    "sector_name": "미국 성장주",
                    "weight": 0.6,
                },
                {
                    "ticker": "BBB",
                    "name": "Beta Bond",
                    "sector_code": "bond",
                    "sector_name": "채권",
                    "weight": 0.4,
                },
            ],
        }
    )

    assert service.universe_repo.load_prices_calls == 0
    assert digest["digest_date"]
    assert digest["drivers"][0]["ticker"] == "AAA"
    assert digest["detractors"][0]["ticker"] == "BBB"
    assert digest["has_narrative"] is False
