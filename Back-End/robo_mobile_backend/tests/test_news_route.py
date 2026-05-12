from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from mobile_backend.api.schemas.news import AssetClassNewsResponse
from mobile_backend.services import news_service


@pytest.fixture
def client():
    # Import here so the router registration runs before TestClient binds.
    from mobile_backend.main import app
    news_service._CACHE.clear()
    return TestClient(app)


def _stub_response() -> AssetClassNewsResponse:
    return AssetClassNewsResponse(
        title="Test headline",
        link="https://example.com/test",
        published=datetime(2026, 5, 12, 14, 0, tzinfo=timezone.utc),
        source="Yahoo Finance",
    )


def test_get_news_returns_payload(client):
    with patch.object(news_service, "fetch_news", return_value=_stub_response()):
        response = client.get("/api/v1/news/asset-class", params={"cls": "us_growth"})
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Test headline"
    assert data["link"] == "https://example.com/test"
    assert data["source"] == "Yahoo Finance"


def test_get_news_returns_503_on_unavailable(client):
    def boom(_cls):
        raise news_service.NewsUnavailableError("rss down")
    with patch.object(news_service, "fetch_news", side_effect=boom):
        response = client.get("/api/v1/news/asset-class", params={"cls": "gold"})
    assert response.status_code == 503
    assert response.json()["detail"] == "news_unavailable"


def test_get_news_rejects_unknown_cls(client):
    response = client.get("/api/v1/news/asset-class", params={"cls": "bitcoin"})
    assert response.status_code == 422
