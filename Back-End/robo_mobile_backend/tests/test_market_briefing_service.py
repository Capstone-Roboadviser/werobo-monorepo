from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import patch

import pandas as pd
import pytest
from fastapi.testclient import TestClient

from mobile_backend.api.schemas.news import MarketArticleResponse
from mobile_backend.services import market_briefing_service


@pytest.fixture
def client():
    from mobile_backend.main import app

    return TestClient(app)


def _close_frame() -> pd.DataFrame:
    tickers = list(
        dict.fromkeys(
            [
                *market_briefing_service._INDEX_TICKERS.values(),
                *market_briefing_service._SECTOR_TICKERS.values(),
                *market_briefing_service._INDICATOR_TICKERS.values(),
            ]
        )
    )
    first = {ticker: 100.0 for ticker in tickers}
    second = {ticker: 101.0 for ticker in tickers}
    second["XLP"] = 98.0
    second["^VIX"] = 102.0
    second["^TNX"] = 100.25
    return pd.DataFrame(
        [first, second],
        index=pd.to_datetime(["2026-08-27", "2026-08-28"]),
    )


def test_market_briefing_uses_close_data_and_rule_fallback():
    market_briefing_service._CACHE = None
    article = MarketArticleResponse(
        title="US stocks close higher after session",
        link="https://example.com/market",
        published=datetime(2026, 8, 28, 21, 0, tzinfo=timezone.utc),
        source="Reuters",
    )
    with (
        patch.object(
            market_briefing_service,
            "_close_frame",
            return_value=_close_frame(),
        ),
        patch.object(
            market_briefing_service,
            "_fetch_articles",
            return_value=[article],
        ),
        patch.dict("os.environ", {}, clear=True),
    ):
        result = market_briefing_service.fetch_market_briefing(force_refresh=True)

    assert result.as_of == "2026-08-28"
    assert result.generation_mode == "rules"
    assert result.indices[0].chg_pct == 1.0
    assert result.breadth.sectors_up == 10
    assert result.sectors[-1].name == "필수소비재"
    assert result.sectors[-1].chg_pct == -2.0
    assert result.articles[0].source == "Reuters"
    assert "S&P 500" in result.summary


def test_market_briefing_cache_avoids_second_download():
    market_briefing_service._CACHE = None
    with (
        patch.object(
            market_briefing_service,
            "_close_frame",
            return_value=_close_frame(),
        ) as download,
        patch.object(market_briefing_service, "_fetch_articles", return_value=[]),
        patch.dict("os.environ", {}, clear=True),
    ):
        market_briefing_service.fetch_market_briefing()
        market_briefing_service.fetch_market_briefing()
    assert download.call_count == 1


def test_market_briefing_route_returns_payload(client):
    market_briefing_service._CACHE = None
    with (
        patch.object(
            market_briefing_service,
            "_close_frame",
            return_value=_close_frame(),
        ),
        patch.object(market_briefing_service, "_fetch_articles", return_value=[]),
        patch.dict("os.environ", {}, clear=True),
    ):
        response = client.get("/api/v1/news/market-briefing")
    assert response.status_code == 200
    assert response.json()["status_note"] == "미국 정규장 마감 종가 기준"
