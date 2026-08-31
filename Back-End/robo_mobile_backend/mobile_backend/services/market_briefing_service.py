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
    WeeklyCalendarItemResponse,
    WeeklyEconomySignalResponse,
    WeeklyEventResponse,
    WeeklyGlossaryItemResponse,
    WeeklyMarketReportResponse,
    WeeklySectorFlowResponse,
)

logger = logging.getLogger(__name__)

_CACHE_TTL_SECONDS = 30 * 60
_NEWS_TIMEOUT_SECONDS = 8.0
_LLM_TIMEOUT_SECONDS = 30
_GEMINI_MODEL = "gemini-2.5-flash"
_CACHE: tuple[float, MarketBriefingResponse] | None = None
_WEEKLY_CACHE: tuple[float, WeeklyMarketReportResponse] | None = None

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


def _fetch_articles(
    query: str = "US+stock+market+when:2d",
    limit: int = 8,
) -> list[MarketArticleResponse]:
    url = (
        "https://news.google.com/rss/search?"
        f"q={query}&hl=en-US&gl=US&ceid=US:en"
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
        if len(articles) == limit:
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


def _weekly_close_frame(tickers: list[str]) -> pd.DataFrame:
    raw = yf.download(
        tickers=tickers,
        period="1y",
        interval="1d",
        auto_adjust=True,
        progress=False,
        group_by="column",
        threads=True,
    )
    if raw.empty or "Close" not in raw:
        raise MarketBriefingUnavailableError("weekly_prices_unavailable")
    close = raw["Close"]
    if isinstance(close, pd.Series):
        close = close.to_frame(name=tickers[0])
    close.index = pd.to_datetime(close.index)
    cutoff = _completed_session_cutoff()
    close = close[[idx.date() <= cutoff for idx in close.index]]
    if len(close) < 10:
        raise MarketBriefingUnavailableError("weekly_history_insufficient")
    return close


def _return_for_sessions(series: pd.Series, sessions: int) -> float:
    clean = series.dropna()
    if len(clean) <= sessions:
        return 0.0
    return _change_pct(float(clean.iloc[-sessions - 1]), float(clean.iloc[-1]))


def _return_since(series: pd.Series, start: pd.Timestamp) -> float:
    clean = series.dropna()
    window = clean[clean.index >= start]
    if len(window) < 2:
        return 0.0
    return _change_pct(float(window.iloc[0]), float(window.iloc[-1]))


def _weekly_rule_events(
    weekly_sectors: list[dict],
    articles: list[MarketArticleResponse],
) -> list[WeeklyEventResponse]:
    ranked = sorted(weekly_sectors, key=lambda item: abs(item["weekly_pct"]), reverse=True)
    events: list[WeeklyEventResponse] = []
    for rank, item in enumerate(ranked[:5], start=1):
        direction = "올랐습니다" if item["weekly_pct"] >= 0 else "내렸습니다"
        events.append(
            WeeklyEventResponse(
                rank=rank,
                title=f"{item['name']} 업종 — 이번 주 {item['weekly_pct']:+.2f}%",
                what_happened=(
                    f"{item['etf']}의 미국 마감 종가는 최근 5거래일 동안 "
                    f"{abs(item['weekly_pct']):.2f}% {direction}"
                ),
                why="가격 데이터만으로 원인을 단정할 수 없어 확인하지 못했습니다.",
                meaning=(
                    "한 업종의 움직임만으로 미국 주식시장 전체의 방향을 판단할 수는 없습니다."
                ),
                source_titles=[],
            )
        )
    if articles and events:
        events[0].source_titles = [article.title for article in articles[:2]]
    return events


def _weekly_allowed_percentages(
    indices: list[dict], sectors: list[dict]
) -> set[str]:
    values = [item["weekly_pct"] for item in [*indices, *sectors]]
    values.extend(item["recent_six_month_pct"] for item in sectors)
    values.extend(item["ytd_pct"] for item in sectors)
    allowed: set[str] = set()
    for value in values:
        allowed.add(f"{abs(value):.1f}")
        allowed.add(f"{abs(value):.2f}")
    return allowed


def _generate_weekly_events(
    indices: list[dict],
    sectors: list[dict],
    articles: list[MarketArticleResponse],
) -> tuple[str, list[WeeklyEventResponse], list[str], str]:
    sp = next(item for item in indices if item["name"] == "S&P 500")
    top = max(sectors, key=lambda item: item["weekly_pct"])
    bottom = min(sectors, key=lambda item: item["weekly_pct"])
    fallback_one_line = (
        f"S&P 500은 이번 주 {sp['weekly_pct']:+.2f}% 움직였습니다. "
        f"{top['name']} 업종이 가장 많이 올랐고, {bottom['name']} 업종의 등락률이 가장 낮았습니다."
    )
    fallback_events = _weekly_rule_events(sectors, articles)
    fallback_other = [article.title for article in articles[5:8]]
    api_key = os.environ.get("GOOGLE_API_KEY", "")
    if not api_key:
        return fallback_one_line, fallback_events, fallback_other, "rules"

    facts = {
        "indices": indices,
        "sectors": [
            {
                "name": item["name"],
                "etf": item["etf"],
                "weekly_pct": item["weekly_pct"],
            }
            for item in sectors
        ],
        "headlines": [
            {"title": article.title, "source": article.source}
            for article in articles
        ],
    }
    prompt = f"""
아래 검증된 미국 마감 수치와 뉴스 제목만 사용해 초보자용 주간 시장 리포트 일부를 작성하세요.

규칙:
- one_line은 이번 주 핵심을 2문장으로 씁니다.
- events는 영향이 큰 순서로 정확히 5개입니다.
- 각 event는 title, what_happened, why, meaning, source_titles를 포함합니다.
- what_happened는 확인된 사실, why는 제목에서 직접 확인되는 배경만 씁니다.
- meaning은 시장 전체를 이해하는 교육적 설명이며 개인 자산·매매 권유를 넣지 않습니다.
- 입력에 없는 숫자·날짜·회사 실적 수치를 만들지 않습니다.
- 원인을 확인할 수 없으면 '원인을 확인하지 못했습니다'라고 씁니다.
- source_titles는 입력 headline title을 글자 그대로만 사용합니다.
- 전망, 매수·매도 권유, '유망', '견조한' 같은 평가어를 쓰지 않습니다.
- 합쇼체로 쓰고 전문용어는 쉽게 풉니다.
- other_items는 event에 포함되지 않은 제목을 최대 3개로 요약합니다.
- JSON만 반환합니다:
{{"one_line":"...","events":[{{"title":"...","what_happened":"...","why":"...","meaning":"...","source_titles":["..."]}}],"other_items":["..."]}}

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
        one_line = str(payload.get("one_line") or "").strip()
        raw_events = payload.get("events") or []
        valid_titles = {article.title for article in articles}
        combined = one_line + " " + " ".join(
            " ".join(
                str(item.get(key, ""))
                for key in ("title", "what_happened", "why", "meaning")
            )
            for item in raw_events
        )
        used_numbers = set(re.findall(r"(?<!\d)(\d+(?:\.\d+)?)%", combined))
        if (
            not one_line
            or len(raw_events) != 5
            or not used_numbers.issubset(_weekly_allowed_percentages(indices, sectors))
        ):
            raise ValueError("weekly copy failed validation")
        events: list[WeeklyEventResponse] = []
        for rank, item in enumerate(raw_events, start=1):
            source_titles = [
                str(title)
                for title in item.get("source_titles", [])
                if str(title) in valid_titles
            ]
            event = WeeklyEventResponse(
                rank=rank,
                title=str(item.get("title") or "").strip(),
                what_happened=str(item.get("what_happened") or "").strip(),
                why=str(item.get("why") or "").strip(),
                meaning=str(item.get("meaning") or "").strip(),
                source_titles=source_titles,
            )
            if not all((event.title, event.what_happened, event.why, event.meaning)):
                raise ValueError("weekly event is incomplete")
            events.append(event)
        other_items = [
            str(item).strip() for item in (payload.get("other_items") or [])[:3]
            if str(item).strip()
        ]
        return one_line, events, other_items, "gemini"
    except Exception:
        logger.warning("weekly report generation degraded to rules", exc_info=True)
        return fallback_one_line, fallback_events, fallback_other, "rules"


def fetch_weekly_market_report(
    force_refresh: bool = False,
) -> WeeklyMarketReportResponse:
    global _WEEKLY_CACHE
    if not force_refresh and _WEEKLY_CACHE is not None:
        cached_at, cached = _WEEKLY_CACHE
        if time.monotonic() - cached_at < _CACHE_TTL_SECONDS:
            return cached

    tickers = list(
        dict.fromkeys(
            [*_INDEX_TICKERS.values(), *_SECTOR_TICKERS.values(), *_INDICATOR_TICKERS.values()]
        )
    )
    close = _weekly_close_frame(tickers)
    period_end = close.index[-1]
    period_start = close.index[-6] if len(close) >= 6 else close.index[0]
    year_start = pd.Timestamp(year=period_end.year, month=1, day=1)
    six_month_start = period_end - pd.DateOffset(months=6)

    indices: list[dict] = []
    for name, ticker in _INDEX_TICKERS.items():
        indices.append(
            {
                "name": name,
                "weekly_pct": _return_for_sessions(close[ticker], 5),
            }
        )

    sector_data: list[dict] = []
    for name, ticker in _SECTOR_TICKERS.items():
        series = close[ticker]
        sector_data.append(
            {
                "name": name,
                "etf": ticker,
                "weekly_pct": _return_for_sessions(series, 5),
                "recent_six_month_pct": _return_since(series, six_month_start),
                "ytd_pct": _return_since(series, year_start),
            }
        )

    articles = _fetch_articles("US+stock+market+economy+when:10d", limit=16)
    one_line, events, other_items, generation_mode = _generate_weekly_events(
        indices, sector_data, articles
    )

    ranked_six_month = sorted(
        sector_data, key=lambda item: item["recent_six_month_pct"], reverse=True
    )
    sector_flows: list[WeeklySectorFlowResponse] = []
    for item in ranked_six_month:
        if item["weekly_pct"] > 0.5:
            note = "이번 주에도 상승했습니다."
        elif item["weekly_pct"] < -0.5:
            note = "이번 주에는 하락했습니다."
        else:
            note = "이번 주에는 큰 변화가 없었습니다."
        sector_flows.append(
            WeeklySectorFlowResponse(
                name=item["name"],
                etf=item["etf"],
                recent_six_month_pct=item["recent_six_month_pct"],
                ytd_pct=item["ytd_pct"],
                note=note,
            )
        )

    top_flow, bottom_flow = ranked_six_month[0], ranked_six_month[-1]
    flow_summary = (
        f"최근 6개월 가격 흐름은 {top_flow['name']} 업종이 가장 높고, "
        f"{bottom_flow['name']} 업종이 가장 낮았습니다. 이는 실제 자금 유입액이 아니라 "
        "업종 ETF의 마감 가격 흐름입니다."
    )

    vix = close["^VIX"].dropna()
    rate = close["^TNX"].dropna()
    sp_weekly = next(item["weekly_pct"] for item in indices if item["name"] == "S&P 500")
    sectors_up = sum(item["weekly_pct"] > 0 for item in sector_data)
    economy_signals = [
        WeeklyEconomySignalResponse(
            signal="green" if float(vix.iloc[-1]) < 20 else "yellow" if float(vix.iloc[-1]) < 30 else "red",
            indicator=f"변동성지수(VIX) {float(vix.iloc[-1]):.2f}",
            meaning="20 아래는 시장 불안이 비교적 낮고, 30 이상은 불안이 큰 구간입니다.",
        ),
        WeeklyEconomySignalResponse(
            signal="yellow" if float(rate.iloc[-1]) < 5 else "red",
            indicator=f"미국 10년 국채 금리 {float(rate.iloc[-1]):.2f}%",
            meaning="장기 금리는 주택담보대출과 기업 자금 조달 비용에 영향을 줍니다.",
        ),
        WeeklyEconomySignalResponse(
            signal="green" if sp_weekly > 0 else "red",
            indicator=f"S&P 500 주간 {sp_weekly:+.2f}%",
            meaning="미국 대형주 전체의 최근 5거래일 가격 흐름입니다.",
        ),
        WeeklyEconomySignalResponse(
            signal="green" if sectors_up >= 7 else "yellow" if sectors_up >= 4 else "red",
            indicator=f"상승 업종 {sectors_up}/11개",
            meaning="상승이 일부 업종에만 집중됐는지 확인하는 폭 지표입니다.",
        ),
    ]
    economy_summary = (
        f"이번 주에는 11개 업종 중 {sectors_up}개가 올랐습니다. "
        "신호등은 예측이 아니라 같은 기준으로 현재 상태를 정리한 표시입니다."
    )

    payload = WeeklyMarketReportResponse(
        period_start=period_start.strftime("%Y-%m-%d"),
        period_end=period_end.strftime("%Y-%m-%d"),
        generated_at=datetime.now(timezone.utc),
        title="이번 주 시장, 5분 요약",
        introduction=(
            "숫자와 출처를 확인한 내용만 담았습니다. 확인하지 못한 원인은 모른다고 적고, "
            "앞으로 오를지 내릴지는 말하지 않습니다."
        ),
        one_line=one_line,
        events=events,
        other_items=other_items,
        sector_flows=sector_flows,
        flow_summary=flow_summary,
        economy_signals=economy_signals,
        economy_summary=economy_summary,
        calendar=[],
        glossary=[
            WeeklyGlossaryItemResponse(
                term="연준(Fed)",
                description="미국 중앙은행입니다. 미국 기준금리를 정합니다.",
            ),
            WeeklyGlossaryItemResponse(
                term="국채 금리",
                description="미국 정부가 돈을 빌릴 때 내는 이자이며 여러 시장 금리의 기준입니다.",
            ),
            WeeklyGlossaryItemResponse(
                term="VIX(공포지수)",
                description="주식시장이 예상하는 단기 변동성입니다. 숫자가 높을수록 불안이 큰 구간입니다.",
            ),
        ],
        sources=articles,
        disclaimer=(
            "정보 제공 목적이며 투자 권유가 아닙니다. 가격 데이터는 미국 마감 종가 기준이며, "
            "출처가 확인되지 않은 내용은 작성하지 않습니다."
        ),
        generation_mode=generation_mode,
    )
    _WEEKLY_CACHE = (time.monotonic(), payload)
    return payload
