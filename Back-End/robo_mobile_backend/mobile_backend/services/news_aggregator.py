"""Fetch financial news headlines from free sources for portfolio digest context."""
from __future__ import annotations

import logging
from concurrent.futures import ThreadPoolExecutor, as_completed

logger = logging.getLogger(__name__)

NEWS_TIMEOUT_SECONDS = 3


def fetch_news_for_tickers(
    tickers: list[str],
    max_headlines_per_ticker: int = 3,
) -> dict[str, list[str]]:
    """Fetch news headlines for tickers from Yahoo Finance and Google News RSS.

    Returns dict mapping ticker -> list of headline strings.
    Gracefully returns empty results on any failure.
    """
    results: dict[str, list[str]] = {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {}
        for ticker in tickers[:6]:
            futures[pool.submit(_fetch_for_ticker, ticker, max_headlines_per_ticker)] = ticker
        for future in as_completed(futures, timeout=NEWS_TIMEOUT_SECONDS + 1):
            ticker = futures[future]
            try:
                headlines = future.result(timeout=0.1)
                if headlines:
                    results[ticker] = headlines
            except Exception:
                logger.debug("news fetch failed for %s", ticker, exc_info=True)
    return results


def _fetch_for_ticker(ticker: str, max_headlines: int) -> list[str]:
    """Fetch from Yahoo Finance then Google News RSS, merge and deduplicate."""
    headlines: list[str] = []
    headlines.extend(_fetch_yahoo(ticker, max_headlines))
    headlines.extend(_fetch_google_rss(ticker, max_headlines))
    seen = set()
    unique = []
    for h in headlines:
        normalized = h.strip().lower()
        if normalized not in seen:
            seen.add(normalized)
            unique.append(h.strip())
    return unique[:max_headlines]


def _fetch_yahoo(ticker: str, max_headlines: int) -> list[str]:
    try:
        import yfinance as yf

        t = yf.Ticker(ticker)
        news = t.news or []
        headlines = []
        for item in news[:max_headlines]:
            title = ""
            if isinstance(item, dict):
                title = item.get("title", "")
                if not title:
                    content = item.get("content", {})
                    if isinstance(content, dict):
                        title = content.get("title", "")
            if title:
                headlines.append(title)
        return headlines
    except Exception:
        logger.debug("yfinance failed for %s", ticker, exc_info=True)
        return []


def _fetch_google_rss(ticker: str, max_headlines: int) -> list[str]:
    try:
        import feedparser

        url = f"https://news.google.com/rss/search?q={ticker}+stock&hl=en-US&gl=US&ceid=US:en"
        feed = feedparser.parse(url)
        headlines = []
        for entry in (feed.entries or [])[:max_headlines]:
            title = entry.get("title", "")
            if title:
                headlines.append(title)
        return headlines
    except Exception:
        logger.debug("google rss failed for %s", ticker, exc_info=True)
        return []


def get_sources_used(news: dict[str, list[str]]) -> list[str]:
    """Return list of source names that contributed headlines."""
    sources = set()
    if news:
        sources.add("Yahoo Finance")
        sources.add("Google News")
    return sorted(sources)
