from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, HttpUrl


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
