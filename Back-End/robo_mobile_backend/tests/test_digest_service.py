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


class LowVolatilityStockDataRepository:
    def load_stock_prices(self, path: str) -> pd.DataFrame:
        end_date = datetime.now(timezone.utc).date() - timedelta(days=1)
        dates = pd.bdate_range(end=end_date, periods=90)
        price = 100.0
        rows = []
        for index, day in enumerate(dates):
            if index > 0:
                daily_return = 0.004 if index >= len(dates) - 5 else (0.0005 if index % 2 == 0 else -0.0002)
                price *= 1 + daily_return
            rows.append(
                {
                    "date": day,
                    "ticker": "AAA",
                    "adjusted_close": price,
                }
            )
        return pd.DataFrame(rows)


def test_below_threshold_returns_unavailable_sentinel(
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
    monkeypatch.setattr(digest_module, "get_sources_used", lambda news: [])

    news_calls: list[list[str]] = []
    narrative_calls: list[dict] = []
    monkeypatch.setattr(
        digest_module,
        "fetch_news_for_tickers",
        lambda tickers: news_calls.append(list(tickers)) or {},
    )
    monkeypatch.setattr(
        digest_module,
        "generate_narrative",
        lambda **kwargs: narrative_calls.append(kwargs) or None,
    )

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

    # 60/40 with +10/-10 yields +2% total — below the ±5% threshold.
    assert service.universe_repo.load_prices_calls == 0  # demo source still used
    assert digest["available"] is False
    assert digest["drivers"] == []
    assert digest["detractors"] == []
    assert digest["has_narrative"] is False
    assert digest["narrative_ko"] is None
    assert digest["sources_used"] == []
    assert news_calls == []  # below-threshold path skips news fetch
    assert narrative_calls == []  # below-threshold path skips LLM
    assert digest["total_return_pct"] == 2.0


def test_low_volatility_portfolio_surfaces_digest_below_fixed_5pct(
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

    monkeypatch.setattr(digest_module, "StockDataRepository", LowVolatilityStockDataRepository)
    monkeypatch.setattr(digest_module, "fetch_news_for_tickers", lambda tickers: {})
    monkeypatch.setattr(digest_module, "get_sources_used", lambda news: [])
    monkeypatch.setattr(digest_module, "generate_narrative", lambda **kwargs: None)

    digest = service.generate(
        {
            "id": 1,
            "data_source": "stock_combination_demo",
            "portfolio_label": "안정형",
            "stock_allocations": [
                {
                    "ticker": "AAA",
                    "name": "Low Vol Asset",
                    "sector_code": "cash_like",
                    "sector_name": "현금성 자산",
                    "weight": 1.0,
                },
            ],
        }
    )

    assert 1.0 < digest["total_return_pct"] < 5.0
    assert digest["available"] is True
    assert digest["drivers"][0]["ticker"] == "AAA"
    assert digest["trigger_sigma_multiple"] >= 2.0
    assert digest["trigger_threshold_pct"] < 5.0


def test_above_positive_threshold_keeps_drivers_only(
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

    # 80/20 with +10/-10 yields +6% total — above the +5% threshold.
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
                    "weight": 0.8,
                },
                {
                    "ticker": "BBB",
                    "name": "Beta Bond",
                    "sector_code": "bond",
                    "sector_name": "채권",
                    "weight": 0.2,
                },
            ],
        }
    )

    assert digest["available"] is True
    assert digest["total_return_pct"] == 6.0
    assert len(digest["drivers"]) == 1
    assert digest["drivers"][0]["ticker"] == "AAA"
    assert digest["detractors"] == []


def test_above_negative_threshold_keeps_detractors_only(
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

    # 20/80 with +10/-10 yields -6% total — below the -5% threshold.
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
                    "weight": 0.2,
                },
                {
                    "ticker": "BBB",
                    "name": "Beta Bond",
                    "sector_code": "bond",
                    "sector_name": "채권",
                    "weight": 0.8,
                },
            ],
        }
    )

    assert digest["available"] is True
    assert digest["total_return_pct"] == -6.0
    assert digest["drivers"] == []
    assert len(digest["detractors"]) == 1
    assert digest["detractors"][0]["ticker"] == "BBB"


def test_boundary_exactly_positive_5pct_is_available(
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

    # 75/25 with +10/-10 yields exactly +5.0% total.
    digest = service.generate(
        {
            "id": 1,
            "data_source": "stock_combination_demo",
            "portfolio_label": "균형형",
            "stock_allocations": [
                {"ticker": "AAA", "name": "Alpha Asset", "sector_code": "us_growth",
                 "sector_name": "미국 성장주", "weight": 0.75},
                {"ticker": "BBB", "name": "Beta Bond", "sector_code": "bond",
                 "sector_name": "채권", "weight": 0.25},
            ],
        }
    )

    assert digest["total_return_pct"] == 5.0
    assert digest["available"] is True
    assert len(digest["drivers"]) == 1
    assert digest["detractors"] == []


def test_boundary_exactly_negative_5pct_is_available(
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

    # 25/75 with +10/-10 yields exactly -5.0% total.
    digest = service.generate(
        {
            "id": 1,
            "data_source": "stock_combination_demo",
            "portfolio_label": "균형형",
            "stock_allocations": [
                {"ticker": "AAA", "name": "Alpha Asset", "sector_code": "us_growth",
                 "sector_name": "미국 성장주", "weight": 0.25},
                {"ticker": "BBB", "name": "Beta Bond", "sector_code": "bond",
                 "sector_name": "채권", "weight": 0.75},
            ],
        }
    )

    assert digest["total_return_pct"] == -5.0
    assert digest["available"] is True
    assert digest["drivers"] == []
    assert len(digest["detractors"]) == 1


def test_build_user_prompt_omits_drivers_header_when_empty() -> None:
    prompt = digest_module._build_user_prompt(
        total_return_pct=-6.0,
        total_return_won=-600_000,
        portfolio_type="균형형",
        drivers=[],
        detractors=[
            {
                "ticker": "BBB",
                "name_ko": "채권",
                "weight_pct": 80.0,
                "return_pct": -10.0,
                "contribution_won": -800_000,
            }
        ],
        news={},
    )
    assert "상승 기여 종목:" not in prompt
    assert "하락 기여 종목:" in prompt
    assert "BBB" in prompt
    assert "\n\n\n" not in prompt  # no double blank lines
    assert "위 데이터를 바탕으로:" in prompt


def test_below_threshold_cache_hit_returns_sentinel(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A cached unavailable sentinel must short-circuit, not trigger regeneration."""
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

    # Pre-seed the cache with an unavailable sentinel.
    sentinel = {
        "digest_date": "2026-04-29",
        "period_start": "2026-04-22",
        "period_end": "2026-04-29",
        "total_return_pct": 2.0,
        "total_return_won": 200_000,
        "available": False,
        "narrative_ko": None,
        "has_narrative": False,
        "drivers": [],
        "detractors": [],
        "sources_used": [],
        "disclaimer": "...",
        "generated_at": "2026-04-29T00:00:00Z",
        "degradation_level": 0,
        "benchmark_7asset_return_pct": None,
        "benchmark_bond_return_pct": None,
    }
    service.digest_repo.cache(1, sentinel)

    # Spy: assert these are NOT called on a cache hit.
    stock_repo_calls = []
    monkeypatch.setattr(
        digest_module,
        "StockDataRepository",
        lambda *a, **kw: stock_repo_calls.append(1) or FakeStockDataRepository(),
    )
    news_calls: list[list[str]] = []
    narrative_calls: list[dict] = []
    monkeypatch.setattr(
        digest_module,
        "fetch_news_for_tickers",
        lambda tickers: news_calls.append(list(tickers)) or {},
    )
    monkeypatch.setattr(
        digest_module,
        "generate_narrative",
        lambda **kwargs: narrative_calls.append(kwargs) or None,
    )

    result = service.generate(
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

    assert result == sentinel
    assert stock_repo_calls == []  # no price load
    assert news_calls == []
    assert narrative_calls == []


def test_build_user_prompt_omits_detractors_header_when_empty() -> None:
    prompt = digest_module._build_user_prompt(
        total_return_pct=6.0,
        total_return_won=600_000,
        portfolio_type="균형형",
        drivers=[
            {
                "ticker": "AAA",
                "name_ko": "미국 성장주",
                "weight_pct": 80.0,
                "return_pct": 10.0,
                "contribution_won": 800_000,
            }
        ],
        detractors=[],
        news={},
    )
    assert "상승 기여 종목:" in prompt
    assert "하락 기여 종목:" not in prompt
    assert "AAA" in prompt
    assert "\n\n\n" not in prompt  # no double blank lines
    assert "위 데이터를 바탕으로:" in prompt
