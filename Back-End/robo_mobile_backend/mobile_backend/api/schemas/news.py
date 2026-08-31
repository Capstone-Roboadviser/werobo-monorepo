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
