from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, HttpUrl


# Public API enum for the news endpoint. Values are kept short and distinct
# from the internal sector codes (e.g. ``cash_equivalents``) because the
# news service never crosses paths with portfolio sector logic.
class NewsAssetClass(str, Enum):
    cash = "cash"
    short_bond = "short_bond"
    infra_bond = "infra_bond"
    gold = "gold"
    us_value = "us_value"
    us_growth = "us_growth"
    new_growth = "new_growth"


class AssetClassNewsResponse(BaseModel):
    title: str
    link: HttpUrl
    published: datetime
    source: str


class MarketIndexResponse(BaseModel):
    name: str
    close: float
    chg_pct: float


class MarketSectorResponse(BaseModel):
    name: str
    etf: str
    chg_pct: float


class MarketBreadthResponse(BaseModel):
    sectors_up: int
    sectors_total: int
    market_tone: str


class MarketIndicatorResponse(BaseModel):
    name: str
    level: str
    chg: str | None = None


class MarketArticleResponse(BaseModel):
    title: str
    link: HttpUrl
    published: datetime
    source: str


class MarketBriefingItemResponse(BaseModel):
    title: str
    body: str
    source_titles: list[str] = Field(default_factory=list)


class MarketBriefingResponse(BaseModel):
    as_of: str
    generated_at: datetime
    status_note: str
    summary: str
    indices: list[MarketIndexResponse]
    breadth: MarketBreadthResponse
    sectors: list[MarketSectorResponse]
    indicators: list[MarketIndicatorResponse]
    briefing: list[MarketBriefingItemResponse]
    articles: list[MarketArticleResponse]
    generation_mode: str


class WeeklyEventResponse(BaseModel):
    rank: int
    title: str
    what_happened: str
    why: str
    meaning: str
    source_titles: list[str] = Field(default_factory=list)


class WeeklyKeyFigureResponse(BaseModel):
    value: str
    label: str


class WeeklySectorFlowResponse(BaseModel):
    name: str
    etf: str
    recent_six_month_pct: float
    ytd_pct: float
    recent_six_month_label: str | None = None
    ytd_label: str | None = None
    note: str


class WeeklyEconomySignalResponse(BaseModel):
    signal: str
    indicator: str
    level: str
    meaning: str


class WeeklyCalendarItemResponse(BaseModel):
    when_kst: str
    what: str
    why: str


class WeeklyGlossaryItemResponse(BaseModel):
    term: str
    description: str


class WeeklyMarketReportResponse(BaseModel):
    period_start: str
    period_end: str
    generated_at: datetime
    title: str
    introduction: str
    one_line: str
    key_figures: list[WeeklyKeyFigureResponse]
    editorial_note: str
    events: list[WeeklyEventResponse]
    other_items: list[str]
    sector_flows: list[WeeklySectorFlowResponse]
    flow_summary: str
    economy_signals: list[WeeklyEconomySignalResponse]
    economy_summary: str
    calendar: list[WeeklyCalendarItemResponse]
    glossary: list[WeeklyGlossaryItemResponse]
    sources: list[MarketArticleResponse]
    skill_sources: list[str]
    disclaimer: str
    generation_mode: str
