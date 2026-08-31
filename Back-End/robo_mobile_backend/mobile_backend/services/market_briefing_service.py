"""Objective US market-close briefing for the ALFIN news page.

Prices are always computed from daily closes. News headlines provide context,
never the return figures. Gemini is optional and is only allowed to rewrite
the supplied facts; deterministic copy is returned when it is unavailable.
"""

from __future__ import annotations

import json
import logging
import os
import re
import time
from datetime import datetime, time as wall_time, timezone
from email.utils import parsedate_to_datetime
from zoneinfo import ZoneInfo

import feedparser
import httpx
import pandas as pd
import yfinance as yf

from mobile_backend.api.schemas.news import (
    MarketArticleResponse,
    MarketBriefingItemResponse,
    MarketBriefingResponse,
    MarketBreadthResponse,
    MarketIndexResponse,
    MarketIndicatorResponse,
    MarketSectorResponse,
)

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 30 * 60
_NEWS_TIMEOUT_SECONDS = 8.0
_LLM_TIMEOUT_SECONDS = 30
_GEMINI_MODEL = "gemini-2.5-flash"
_CACHE: tuple[float, MarketBriefingResponse] | None = None

_INDEX_TICKERS = {
    "S&P 500": "^GSPC",
    "나스닥": "^IXIC",
    "다우존스": "^DJI",
}
_SECTOR_TICKERS = {
    "기술": "XLK",
    "에너지": "XLE",
    "금융": "XLF",
    "유틸리티": "XLU",
    "기초소재": "XLB",
    "산업재": "XLI",
    "부동산": "XLRE",
    "커뮤니케이션": "XLC",
    "경기소비재": "XLY",
    "헬스케어": "XLV",
    "필수소비재": "XLP",
}
_INDICATOR_TICKERS = {
    "변동성지수(VIX)": "^VIX",
    "미국 10년 국채 금리": "^TNX",
}
_TRUSTED_SOURCES = {
    "Reuters",
    "Associated Press",
    "AP News",
    "Bloomberg",
    "CNBC",
    "Financial Times",
    "The Wall Street Journal",
    "MarketWatch",
    "Yahoo Finance",
}


class MarketBriefingUnavailableError(Exception):
    """A completed market snapshot could not be built."""


def _completed_session_cutoff(now_et: datetime | None = None):
    now_et = now_et or datetime.now(ZoneInfo("America/New_York"))
    cutoff = now_et.date()
    if now_et.weekday() >= 5 or now_et.time() < wall_time(16, 15):
        cutoff = cutoff.fromordinal(cutoff.toordinal() - 1)
    while cutoff.weekday() >= 5:
        cutoff = cutoff.fromordinal(cutoff.toordinal() - 1)
    return cutoff


def _close_frame(tickers: list[str]) -> pd.DataFrame:
    raw = yf.download(
        tickers=tickers,
        period="10d",
        interval="1d",
        auto_adjust=True,
        progress=False,
        group_by="column",
        threads=True,
    )
    if raw.empty or "Close" not in raw:
        raise MarketBriefingUnavailableError("market_close_unavailable")
    close = raw["Close"]
    if isinstance(close, pd.Series):
        close = close.to_frame(name=tickers[0])
    close.index = pd.to_datetime(close.index)
    cutoff = _completed_session_cutoff()
    close = close[[idx.date() <= cutoff for idx in close.index]]
    if close.empty:
        raise MarketBriefingUnavailableError("completed_session_unavailable")
    return close


def _last_pair(close: pd.DataFrame, ticker: str) -> tuple[float, float, str]:
    if ticker not in close.columns:
        raise MarketBriefingUnavailableError(f"missing_ticker:{ticker}")
    series = close[ticker].dropna()
    if len(series) < 2:
        raise MarketBriefingUnavailableError(f"insufficient_prices:{ticker}")
    previous = float(series.iloc[-2])
    current = float(series.iloc[-1])
    return previous, current, series.index[-1].strftime("%Y-%m-%d")


def _change_pct(previous: float, current: float) -> float:
    if previous == 0:
        return 0.0
    return round((current / previous - 1) * 100, 2)


def _extract_source(entry) -> str:
    source = entry.get("source") or {}
    title = source.get("title") if isinstance(source, dict) else None
    if title:
        return str(title).strip()
    headline = str(entry.get("title") or "")
    if " - " in headline:
        return headline.rsplit(" - ", 1)[-1].strip()
    return "Google News"


def _fetch_articles() -> list[MarketArticleResponse]:
    url = (
        "https://news.google.com/rss/search?"
        "q=US+stock+market+when:2d&hl=en-US&gl=US&ceid=US:en"
    )
    try:
        response = httpx.get(url, timeout=_NEWS_TIMEOUT_SECONDS)
        response.raise_for_status()
        entries = feedparser.parse(response.text).entries or []
    except (httpx.HTTPError, ValueError):
        logger.warning("market briefing news fetch failed", exc_info=True)
        return []

    articles: list[MarketArticleResponse] = []
    seen: set[str] = set()
    for entry in entries:
        title = str(entry.get("title") or "").strip()
        link = str(entry.get("link") or "").strip()
        source = _extract_source(entry)
        if not title or not link or title in seen:
            continue
        if source not in _TRUSTED_SOURCES and len(articles) >= 4:
            continue
        published_raw = entry.get("published") or entry.get("updated")
        try:
            published = (
                parsedate_to_datetime(published_raw)
                if published_raw
                else datetime.now(timezone.utc)
            )
        except (TypeError, ValueError):
            published = datetime.now(timezone.utc)
        if published.tzinfo is None:
            published = published.replace(tzinfo=timezone.utc)
        try:
            article = MarketArticleResponse(
                title=title,
                link=link,
                published=published,
                source=source,
            )
        except ValueError:
            continue
        articles.append(article)
        seen.add(title)
        if len(articles) == 8:
            break
    return articles


def _rule_copy(
    indices: list[MarketIndexResponse],
    sectors: list[MarketSectorResponse],
    articles: list[MarketArticleResponse],
) -> tuple[str, list[MarketBriefingItemResponse]]:
    sp = next(item for item in indices if item.name == "S&P 500")
    ranked = sorted(sectors, key=lambda item: item.chg_pct, reverse=True)
    top, bottom = ranked[0], ranked[-1]
    up_count = sum(item.chg_pct > 0 for item in sectors)
    direction = "상승" if sp.chg_pct > 0 else "하락" if sp.chg_pct < 0 else "보합"
    summary = (
        f"S&P 500은 전 거래일보다 {abs(sp.chg_pct):.2f}% {direction}했습니다. "
        f"11개 업종 중 {up_count}개가 올랐고, {top.name} 업종의 등락률이 가장 높았습니다."
    )
    briefing = [
        MarketBriefingItemResponse(
            title=f"{top.name} {top.chg_pct:+.2f}% · 가장 많이 오른 업종",
            body="업종 등락률은 미국 마감 종가 기준입니다. 기사 수치를 섞지 않았습니다.",
        ),
        MarketBriefingItemResponse(
            title=f"{bottom.name} {bottom.chg_pct:+.2f}% · 가장 많이 내린 업종",
            body="확인된 가격 움직임만 표시하며, 원인이 확인되지 않으면 단정하지 않습니다.",
        ),
    ]
    if articles:
        briefing.append(
            MarketBriefingItemResponse(
                title="마감 이후 확인된 주요 보도",
                body="아래 원문 제목과 출처를 함께 확인할 수 있습니다.",
                source_titles=[article.title for article in articles[:3]],
            )
        )
    return summary, briefing


def _allowed_percentages(
    indices: list[MarketIndexResponse], sectors: list[MarketSectorResponse]
) -> set[str]:
    values = [item.chg_pct for item in [*indices, *sectors]]
    allowed: set[str] = set()
    for value in values:
        allowed.add(f"{abs(value):.1f}")
        allowed.add(f"{abs(value):.2f}")
    return allowed


def _generate_copy(
    indices: list[MarketIndexResponse],
    sectors: list[MarketSectorResponse],
    articles: list[MarketArticleResponse],
) -> tuple[str, list[MarketBriefingItemResponse], str]:
    fallback_summary, fallback_items = _rule_copy(indices, sectors, articles)
    api_key = os.environ.get("GOOGLE_API_KEY", "")
    if not api_key:
        return fallback_summary, fallback_items, "rules"

    facts = {
        "indices": [item.model_dump() for item in indices],
        "sectors": [item.model_dump() for item in sectors],
        "headlines": [
            {"title": item.title, "source": item.source} for item in articles
        ],
    }
    prompt = f"""
아래 미국 마감 데이터와 뉴스 제목만 사용해 한국어 객관적 시황 브리핑을 작성하세요.

규칙:
- 숫자는 입력된 종가 등락률만 사용합니다. 기사 속 숫자는 사용하지 않습니다.
- 매수·매도 권유, 전망, 평가어를 쓰지 않습니다.
- 뉴스 제목이 직접 뒷받침하지 않는 인과관계를 만들지 않습니다.
- 이유를 확인할 수 없으면 '원인을 확인하지 못했습니다'라고 씁니다.
- 합쇼체로 씁니다. summary는 2문장, briefing은 최대 3개입니다.
- source_titles에는 입력 headlines의 title을 글자 그대로만 넣습니다.
- JSON만 반환합니다:
  {{"summary":"...","briefing":[{{"title":"...","body":"...","source_titles":["..."]}}]}}

입력:
{json.dumps(facts, ensure_ascii=False)}
""".strip()
    try:
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(_GEMINI_MODEL)
        response = model.generate_content(
            prompt,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
            request_options={"timeout": _LLM_TIMEOUT_SECONDS},
        )
        payload = json.loads(response.text)
        summary = str(payload.get("summary") or "").strip()
        raw_items = payload.get("briefing") or []
        valid_titles = {item.title for item in articles}
        combined = summary + " " + " ".join(
            f"{item.get('title', '')} {item.get('body', '')}" for item in raw_items
        )
        used_numbers = set(re.findall(r"(?<!\d)(\d+(?:\.\d+)?)%", combined))
        if not summary or not used_numbers.issubset(_allowed_percentages(indices, sectors)):
            raise ValueError("generated copy introduced unsupported percentages")
        briefing: list[MarketBriefingItemResponse] = []
        for item in raw_items[:3]:
            source_titles = [
                str(title)
                for title in item.get("source_titles", [])
                if str(title) in valid_titles
            ]
            briefing.append(
                MarketBriefingItemResponse(
                    title=str(item.get("title") or "").strip(),
                    body=str(item.get("body") or "").strip(),
                    source_titles=source_titles,
                )
            )
        if not briefing or any(not item.title or not item.body for item in briefing):
            raise ValueError("generated copy is incomplete")
        return summary, briefing, "gemini"
    except Exception:
        logger.warning("market briefing generation degraded to rules", exc_info=True)
        return fallback_summary, fallback_items, "rules"


def fetch_market_briefing(force_refresh: bool = False) -> MarketBriefingResponse:
    global _CACHE
    if not force_refresh and _CACHE is not None:
        cached_at, cached = _CACHE
        if time.monotonic() - cached_at < _CACHE_TTL_SECONDS:
            return cached

    tickers = list(
        dict.fromkeys(
            [*_INDEX_TICKERS.values(), *_SECTOR_TICKERS.values(), *_INDICATOR_TICKERS.values()]
        )
    )
    close = _close_frame(tickers)

    indices: list[MarketIndexResponse] = []
    as_of = ""
    for name, ticker in _INDEX_TICKERS.items():
        previous, current, date = _last_pair(close, ticker)
        indices.append(
            MarketIndexResponse(
                name=name,
                close=round(current, 2),
                chg_pct=_change_pct(previous, current),
            )
        )
        if name == "S&P 500":
            as_of = date

    sectors: list[MarketSectorResponse] = []
    for name, ticker in _SECTOR_TICKERS.items():
        previous, current, _ = _last_pair(close, ticker)
        sectors.append(
            MarketSectorResponse(
                name=name,
                etf=ticker,
                chg_pct=_change_pct(previous, current),
            )
        )
    sectors.sort(key=lambda item: item.chg_pct, reverse=True)

    indicators: list[MarketIndicatorResponse] = []
    vix_previous, vix_current, _ = _last_pair(close, "^VIX")
    indicators.append(
        MarketIndicatorResponse(
            name="변동성지수(VIX)",
            level=f"{vix_current:.2f}",
            chg=f"{_change_pct(vix_previous, vix_current):+.2f}%",
        )
    )
    rate_previous, rate_current, _ = _last_pair(close, "^TNX")
    indicators.append(
        MarketIndicatorResponse(
            name="미국 10년 국채 금리",
            level=f"{rate_current:.2f}%",
            chg=f"{rate_current - rate_previous:+.2f}%p",
        )
    )

    articles = _fetch_articles()
    summary, briefing, generation_mode = _generate_copy(indices, sectors, articles)
    sectors_up = sum(item.chg_pct > 0 for item in sectors)
    if sectors_up >= 8:
        market_tone = "상승 업종 우세"
    elif sectors_up <= 3:
        market_tone = "하락 업종 우세"
    else:
        market_tone = "업종별 혼조"
    payload = MarketBriefingResponse(
        as_of=as_of,
        generated_at=datetime.now(timezone.utc),
        status_note="미국 정규장 마감 종가 기준",
        summary=summary,
        indices=indices,
        breadth=MarketBreadthResponse(
            sectors_up=sectors_up,
            sectors_total=len(sectors),
            market_tone=market_tone,
        ),
        sectors=sectors,
        indicators=indicators,
        briefing=briefing,
        articles=articles,
        generation_mode=generation_mode,
    )
    _CACHE = (time.monotonic(), payload)
    return payload
