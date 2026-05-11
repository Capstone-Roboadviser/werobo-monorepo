"""Asset-class news service backed by Yahoo Finance RSS.

Single in-memory cache keyed by ticker with a 5-minute TTL. Per-process is
fine — Railway runs a single instance for MVP.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

import feedparser
import httpx

from mobile_backend.api.schemas.news import (
    AssetClassNewsResponse,
    NewsAssetClass,
)

logger = logging.getLogger(__name__)

_TTL_SECONDS = 5 * 60
_TIMEOUT_SECONDS = 6.0
_CACHE: dict[str, tuple[float, AssetClassNewsResponse]] = {}

_TICKER_BY_CLASS: dict[NewsAssetClass, str] = {
    NewsAssetClass.cash: "SHV",
    NewsAssetClass.short_bond: "BND",
    NewsAssetClass.infra_bond: "TLT",
    NewsAssetClass.gold: "GLD",
    NewsAssetClass.us_value: "VTV",
    NewsAssetClass.us_growth: "VUG",
    NewsAssetClass.new_growth: "ARKK",
}


class NewsUnavailableError(Exception):
    """RSS feed could not be fetched or had no items."""


def ticker_for(cls: NewsAssetClass) -> str:
    return _TICKER_BY_CLASS[cls]


def fetch_news(cls: NewsAssetClass) -> AssetClassNewsResponse:
    ticker = ticker_for(cls)
    cached = _CACHE.get(ticker)
    if cached is not None:
        cached_at, payload = cached
        if time.monotonic() - cached_at < _TTL_SECONDS:
            return payload

    url = (
        f"https://feeds.finance.yahoo.com/rss/2.0/headline"
        f"?s={ticker}&region=US&lang=en-US"
    )
    try:
        response = httpx.get(url, timeout=_TIMEOUT_SECONDS)
        response.raise_for_status()
    except httpx.HTTPError as exc:
        logger.warning("news_service: rss fetch failed for %s: %s", ticker, exc)
        raise NewsUnavailableError(str(exc)) from exc

    parsed = feedparser.parse(response.text)
    entries = parsed.entries or []
    if not entries:
        raise NewsUnavailableError(f"no entries for {ticker}")

    head = entries[0]
    title = (head.get("title") or "").strip()
    link = (head.get("link") or "").strip()
    if not title or not link:
        raise NewsUnavailableError(f"missing title or link for {ticker}")

    published_raw = head.get("published") or head.get("updated")
    try:
        published = parsedate_to_datetime(published_raw) if published_raw else datetime.now(timezone.utc)
    except (TypeError, ValueError):
        published = datetime.now(timezone.utc)
    if published.tzinfo is None:
        published = published.replace(tzinfo=timezone.utc)

    payload = AssetClassNewsResponse(
        title=title,
        link=link,
        published=published,
        source="Yahoo Finance",
    )
    _CACHE[ticker] = (time.monotonic(), payload)
    return payload
