from __future__ import annotations

import time
from unittest.mock import MagicMock, patch

import pytest

from mobile_backend.api.schemas.news import NewsAssetClass
from mobile_backend.services import news_service


SAMPLE_RSS = """<?xml version='1.0'?>
<rss version='2.0'>
  <channel>
    <title>Yahoo Finance: VUG</title>
    <link>https://finance.yahoo.com</link>
    <item>
      <title>Growth stocks rally on earnings beat</title>
      <link>https://finance.yahoo.com/news/vug-rally</link>
      <pubDate>Mon, 12 May 2026 14:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Older headline</title>
      <link>https://finance.yahoo.com/news/older</link>
      <pubDate>Mon, 12 May 2026 09:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
"""


@pytest.fixture(autouse=True)
def clear_cache():
    news_service._CACHE.clear()
    yield
    news_service._CACHE.clear()


def _mock_response(body: str, status: int = 200) -> MagicMock:
    resp = MagicMock()
    resp.status_code = status
    resp.text = body
    resp.raise_for_status = MagicMock()
    return resp


def test_asset_class_to_ticker_mapping():
    assert news_service.ticker_for(NewsAssetClass.us_growth) == "VUG"
    assert news_service.ticker_for(NewsAssetClass.gold) == "GLD"
    assert news_service.ticker_for(NewsAssetClass.cash) == "SHV"
    assert news_service.ticker_for(NewsAssetClass.short_bond) == "BND"
    assert news_service.ticker_for(NewsAssetClass.infra_bond) == "TLT"
    assert news_service.ticker_for(NewsAssetClass.us_value) == "VTV"
    assert news_service.ticker_for(NewsAssetClass.new_growth) == "ARKK"


def test_fetch_news_returns_latest_item():
    with patch.object(news_service.httpx, "get", return_value=_mock_response(SAMPLE_RSS)):
        result = news_service.fetch_news(NewsAssetClass.us_growth)
    assert result.title == "Growth stocks rally on earnings beat"
    assert str(result.link) == "https://finance.yahoo.com/news/vug-rally"
    assert result.source == "Yahoo Finance"
    assert result.published.year == 2026
    assert result.published.month == 5


def test_cache_hit_avoids_network_within_ttl():
    call_count = {"n": 0}

    def fake_get(*_args, **_kwargs):
        call_count["n"] += 1
        return _mock_response(SAMPLE_RSS)

    with patch.object(news_service.httpx, "get", side_effect=fake_get):
        news_service.fetch_news(NewsAssetClass.us_growth)
        news_service.fetch_news(NewsAssetClass.us_growth)
    assert call_count["n"] == 1


def test_cache_expires_after_ttl():
    call_count = {"n": 0}

    def fake_get(*_args, **_kwargs):
        call_count["n"] += 1
        return _mock_response(SAMPLE_RSS)

    real_time = time.monotonic
    fake_now = real_time()

    with patch.object(news_service.httpx, "get", side_effect=fake_get), \
         patch.object(news_service.time, "monotonic", side_effect=lambda: fake_now):
        news_service.fetch_news(NewsAssetClass.us_growth)
        # Jump forward 6 minutes (TTL is 5 min).
        fake_now += 6 * 60
        news_service.fetch_news(NewsAssetClass.us_growth)
    assert call_count["n"] == 2


def test_fetch_news_raises_on_http_error():
    def boom(*_args, **_kwargs):
        import httpx as _httpx
        raise _httpx.HTTPError("connection refused")

    with patch.object(news_service.httpx, "get", side_effect=boom):
        with pytest.raises(news_service.NewsUnavailableError):
            news_service.fetch_news(NewsAssetClass.gold)


def test_fetch_news_raises_when_no_items():
    empty_rss = "<?xml version='1.0'?><rss><channel></channel></rss>"
    with patch.object(news_service.httpx, "get", return_value=_mock_response(empty_rss)):
        with pytest.raises(news_service.NewsUnavailableError):
            news_service.fetch_news(NewsAssetClass.gold)
