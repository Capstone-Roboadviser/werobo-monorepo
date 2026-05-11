from datetime import datetime, timezone

import pytest

from mobile_backend.api.schemas.news import (
    AssetClassNewsResponse,
    NewsAssetClass,
)


def test_news_asset_class_enum_values():
    assert NewsAssetClass.cash.value == "cash"
    assert NewsAssetClass.short_bond.value == "short_bond"
    assert NewsAssetClass.infra_bond.value == "infra_bond"
    assert NewsAssetClass.gold.value == "gold"
    assert NewsAssetClass.us_value.value == "us_value"
    assert NewsAssetClass.us_growth.value == "us_growth"
    assert NewsAssetClass.new_growth.value == "new_growth"


def test_news_response_round_trip():
    response = AssetClassNewsResponse(
        title="S&P 500 closes at record high",
        link="https://example.com/article",
        published=datetime(2026, 5, 12, 14, 0, tzinfo=timezone.utc),
        source="Yahoo Finance",
    )
    payload = response.model_dump(mode="json")
    assert payload["title"] == "S&P 500 closes at record high"
    assert payload["link"] == "https://example.com/article"
    assert payload["source"] == "Yahoo Finance"
