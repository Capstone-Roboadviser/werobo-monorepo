# Notification Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the home tab's full-page `ActivityHubPage` push with a top-anchored dropdown panel that surfaces real data across five categories (월간 요약, 기여도, 알고리즘 시그널, 시장 변동성, 자산군별 뉴스).

**Architecture:** Backend adds one new `/api/v1/news/asset-class` endpoint backed by Yahoo Finance RSS with a 5-min in-memory cache. Frontend replaces the dummy `_NotificationsSheet` widget with a top-anchored sheet driven by three sync getters on `PortfolioState` (monthly return, top contributor, algorithm signal) plus two async fetches on open (volatility history, news). Rows hide silently if their source has no data this period.

**Tech Stack:** FastAPI · httpx · feedparser · Flutter · url_launcher.

**Spec:** [`docs/superpowers/specs/2026-05-12-notification-dropdown-design.md`](../specs/2026-05-12-notification-dropdown-design.md)

**Spec amendment:** `MobileVolatilityHistoryResponse` is portfolio-level, not per-asset. The volatility row compares portfolio's most-recent volatility against its own trailing-30d average. Copy is "포트폴리오 변동성 +X% 주의 구간이에요" instead of "{assetName} 변동성 ...".

---

## File map

**Backend (new):**
- `Back-End/robo_mobile_backend/mobile_backend/api/schemas/news.py` — `AssetClassNewsResponse` pydantic model + `NewsAssetClass` enum.
- `Back-End/robo_mobile_backend/mobile_backend/services/news_service.py` — RSS fetch + parse + in-memory cache.
- `Back-End/robo_mobile_backend/mobile_backend/api/routes/news.py` — single GET route.
- `Back-End/robo_mobile_backend/tests/test_news_service.py` — unit tests for cache + parser.
- `Back-End/robo_mobile_backend/tests/test_news_route.py` — endpoint tests.

**Backend (modify):**
- `Back-End/robo_mobile_backend/mobile_backend/api/router.py` — register news router.

**Frontend (new):**
- _(none — the existing `_NotificationsSheet` block in `home_tab.dart` is rewritten in place. The spec calls out the option to extract if the file exceeds 3600 lines after the edits; expected to stay under that bar.)_

**Frontend (modify):**
- `Front-End/robo_mobile/pubspec.yaml` — add `url_launcher: ^6.3.1`.
- `Front-End/robo_mobile/lib/models/mobile_backend_models.dart` — add `MobileAssetClassNewsResponse` (~30 lines, after `MobileVolatilityHistoryResponse`).
- `Front-End/robo_mobile/lib/services/mobile_backend_api.dart` — add `fetchAssetClassNews(AssetClass cls)`.
- `Front-End/robo_mobile/lib/app/portfolio_state.dart` — add three getters: `trailingMonthReturn`, `topContributorOver30d`, `portfolioVolatilitySpike`.
- `Front-End/robo_mobile/lib/screens/home/home_tab.dart` — replace the `_showNotificationsSheet` + `_NotificationsSheet` + `_NotificationRow` + `_dummyNotifications` block (~200 lines today) with the new data-driven version.

---

## Task 1: Backend — news schema

**Files:**
- Create: `Back-End/robo_mobile_backend/mobile_backend/api/schemas/news.py`

- [ ] **Step 1: Write the failing test**

Create `Back-End/robo_mobile_backend/tests/test_news_schema.py`:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Back-End/robo_mobile_backend && pytest tests/test_news_schema.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'mobile_backend.api.schemas.news'`.

- [ ] **Step 3: Write minimal implementation**

Create `Back-End/robo_mobile_backend/mobile_backend/api/schemas/news.py`:

```python
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Back-End/robo_mobile_backend && pytest tests/test_news_schema.py -v`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Back-End/robo_mobile_backend/mobile_backend/api/schemas/news.py \
        Back-End/robo_mobile_backend/tests/test_news_schema.py
git commit -m "backend: add news asset-class schema"
```

---

## Task 2: Backend — news service (RSS fetch + cache)

**Files:**
- Create: `Back-End/robo_mobile_backend/mobile_backend/services/news_service.py`
- Test: `Back-End/robo_mobile_backend/tests/test_news_service.py`

- [ ] **Step 1: Write the failing test**

Create `Back-End/robo_mobile_backend/tests/test_news_service.py`:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Back-End/robo_mobile_backend && pytest tests/test_news_service.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'mobile_backend.services.news_service'`.

- [ ] **Step 3: Write minimal implementation**

Create `Back-End/robo_mobile_backend/mobile_backend/services/news_service.py`:

```python
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Back-End/robo_mobile_backend && pytest tests/test_news_service.py -v`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Back-End/robo_mobile_backend/mobile_backend/services/news_service.py \
        Back-End/robo_mobile_backend/tests/test_news_service.py
git commit -m "backend: add news service with rss fetch and 5m cache"
```

---

## Task 3: Backend — news route + wire into router

**Files:**
- Create: `Back-End/robo_mobile_backend/mobile_backend/api/routes/news.py`
- Modify: `Back-End/robo_mobile_backend/mobile_backend/api/router.py`
- Test: `Back-End/robo_mobile_backend/tests/test_news_route.py`

- [ ] **Step 1: Write the failing test**

Create `Back-End/robo_mobile_backend/tests/test_news_route.py`:

```python
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


def test_get_news_rejects_unknown_cls(client):
    response = client.get("/api/v1/news/asset-class", params={"cls": "bitcoin"})
    assert response.status_code == 422
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Back-End/robo_mobile_backend && pytest tests/test_news_route.py -v`
Expected: FAIL with 404 (route not registered yet).

- [ ] **Step 3: Write minimal implementation**

Create `Back-End/robo_mobile_backend/mobile_backend/api/routes/news.py`:

```python
from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query

from mobile_backend.api.schemas.news import (
    AssetClassNewsResponse,
    NewsAssetClass,
)
from mobile_backend.services import news_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/news", tags=["mobile"])


@router.get(
    "/asset-class",
    response_model=AssetClassNewsResponse,
    summary="자산군별 최신 뉴스 1건 조회",
    description=(
        "Yahoo Finance RSS에서 자산군 대표 ETF의 최신 헤드라인 1건을 반환합니다. "
        "서버 측 5분 캐시를 사용합니다."
    ),
)
def get_asset_class_news(
    cls: NewsAssetClass = Query(..., description="자산군 enum 값"),
) -> AssetClassNewsResponse:
    try:
        return news_service.fetch_news(cls)
    except news_service.NewsUnavailableError as exc:
        raise HTTPException(status_code=503, detail="news_unavailable") from exc
```

Modify `Back-End/robo_mobile_backend/mobile_backend/api/router.py`:

```python
from fastapi import APIRouter

from mobile_backend.api.routes.admin import router as admin_router
from mobile_backend.api.routes.admin_comparison import router as admin_comparison_router
from mobile_backend.api.routes.admin_web import router as admin_web_router
from mobile_backend.api.routes.account import router as account_router
from mobile_backend.api.routes.auth import router as auth_router
from mobile_backend.api.routes.digest import router as digest_router
from mobile_backend.api.routes.health import router as health_router
from mobile_backend.api.routes.insights import router as insights_router
from mobile_backend.api.routes.mobile import router as mobile_router
from mobile_backend.api.routes.news import router as news_router


api_router = APIRouter()
api_router.include_router(admin_web_router)
api_router.include_router(admin_router)
api_router.include_router(admin_comparison_router)
api_router.include_router(auth_router)
api_router.include_router(account_router)
api_router.include_router(digest_router)
api_router.include_router(insights_router)
api_router.include_router(news_router)
api_router.include_router(health_router)
api_router.include_router(mobile_router)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Back-End/robo_mobile_backend && pytest tests/test_news_route.py -v`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Back-End/robo_mobile_backend/mobile_backend/api/routes/news.py \
        Back-End/robo_mobile_backend/mobile_backend/api/router.py \
        Back-End/robo_mobile_backend/tests/test_news_route.py
git commit -m "backend: expose GET /api/v1/news/asset-class"
```

---

## Task 4: Frontend — news model + API client method + url_launcher dep

**Files:**
- Modify: `Front-End/robo_mobile/pubspec.yaml`
- Modify: `Front-End/robo_mobile/lib/models/mobile_backend_models.dart` (append after `MobileVolatilityHistoryResponse`)
- Modify: `Front-End/robo_mobile/lib/services/mobile_backend_api.dart`

- [ ] **Step 1: Write the failing test**

Create `Front-End/robo_mobile/test/models/asset_class_news_response_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

void main() {
  test('MobileAssetClassNewsResponse parses JSON', () {
    final json = {
      'title': 'Growth stocks rally on earnings beat',
      'link': 'https://finance.yahoo.com/news/vug-rally',
      'published': '2026-05-12T14:00:00+00:00',
      'source': 'Yahoo Finance',
    };
    final parsed = MobileAssetClassNewsResponse.fromJson(json);
    expect(parsed.title, 'Growth stocks rally on earnings beat');
    expect(parsed.link, 'https://finance.yahoo.com/news/vug-rally');
    expect(parsed.published.year, 2026);
    expect(parsed.source, 'Yahoo Finance');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Front-End/robo_mobile && flutter test test/models/asset_class_news_response_test.dart`
Expected: FAIL with "MobileAssetClassNewsResponse isn't defined".

- [ ] **Step 3: Write minimal implementation**

Append to `Front-End/robo_mobile/lib/models/mobile_backend_models.dart` (immediately after the `MobileVolatilityHistoryResponse` class, before `class MobileReturnPoint`):

```dart
class MobileAssetClassNewsResponse {
  final String title;
  final String link;
  final DateTime published;
  final String source;

  const MobileAssetClassNewsResponse({
    required this.title,
    required this.link,
    required this.published,
    required this.source,
  });

  factory MobileAssetClassNewsResponse.fromJson(Map<String, dynamic> json) {
    return MobileAssetClassNewsResponse(
      title: json['title']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      published: _parseDate(json['published']),
      source: json['source']?.toString() ?? '',
    );
  }
}
```

Modify `Front-End/robo_mobile/pubspec.yaml` — under `dependencies:`, add the `url_launcher` line directly after the `shared_preferences` line:

```yaml
  shared_preferences: ^2.5.3
  url_launcher: ^6.3.1
```

Modify `Front-End/robo_mobile/lib/services/mobile_backend_api.dart` — add the new method near `fetchVolatilityHistory` (after the existing rebalance-insight methods). The file already has a private `_get<T>` helper (around line 657) that handles `baseUrl + /api/v1/` prefixing, JSON parsing, and `MobileBackendException` mapping. Use it:

```dart
  Future<MobileAssetClassNewsResponse> fetchAssetClassNews(
    AssetClass cls,
  ) {
    final clsParam = _assetClassToApi(cls);
    return _get<MobileAssetClassNewsResponse>(
      path: '/news/asset-class?cls=$clsParam',
      parser: MobileAssetClassNewsResponse.fromJson,
      timeout: _defaultTimeout,
    );
  }

  String _assetClassToApi(AssetClass cls) {
    switch (cls) {
      case AssetClass.cash:
        return 'cash';
      case AssetClass.shortBond:
        return 'short_bond';
      case AssetClass.infraBond:
        return 'infra_bond';
      case AssetClass.gold:
        return 'gold';
      case AssetClass.usValue:
        return 'us_value';
      case AssetClass.usGrowth:
        return 'us_growth';
      case AssetClass.newGrowth:
        return 'new_growth';
    }
  }
```

Add the import at the top of the file if not already present: `import '../app/theme.dart';` (this is where `AssetClass` lives).

- [ ] **Step 4: Run flutter pub get and re-run the test**

Run: `cd Front-End/robo_mobile && flutter pub get && flutter test test/models/asset_class_news_response_test.dart`
Expected: PASS.

- [ ] **Step 5: Smoke-test analyze**

Run: `cd Front-End/robo_mobile && flutter analyze lib/services/mobile_backend_api.dart lib/models/mobile_backend_models.dart`
Expected: `No issues found`.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/pubspec.yaml \
        Front-End/robo_mobile/pubspec.lock \
        Front-End/robo_mobile/lib/models/mobile_backend_models.dart \
        Front-End/robo_mobile/lib/services/mobile_backend_api.dart \
        Front-End/robo_mobile/test/models/asset_class_news_response_test.dart
git commit -m "frontend: add asset-class news model and api client"
```

---

## Task 5: Frontend — PortfolioState derived getters

**Files:**
- Modify: `Front-End/robo_mobile/lib/app/portfolio_state.dart`
- Test: `Front-End/robo_mobile/test/app/portfolio_state_notifications_test.dart`

Adds three pure getters that derive notification inputs from data already in state. No new fetches.

- [ ] **Step 1: Write the failing tests**

Create `Front-End/robo_mobile/test/app/portfolio_state_notifications_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

MobileAccountDashboard _dashboardWith(List<MobileAccountHistoryPoint> history) {
  return MobileAccountDashboard(
    hasAccount: true,
    summary: null,
    history: history,
    recentActivity: const [],
  );
}

MobileAccountHistoryPoint _point(DateTime d, double value) {
  return MobileAccountHistoryPoint(
    date: d,
    portfolioValue: value,
    investedAmount: value,
    profitLoss: 0,
    profitLossPct: 0,
  );
}

void main() {
  group('trailingMonthReturn', () {
    test('returns positive percent when value rose over 30 days', () {
      final state = PortfolioState();
      final now = DateTime(2026, 5, 12);
      final history = [
        for (int i = 30; i >= 0; i--)
          _point(now.subtract(Duration(days: i)), 100.0 + (30 - i) * 0.5),
      ];
      state.debugSetAccountDashboard(_dashboardWith(history));
      // Value moved from 100 to 115 → +15%.
      expect(state.trailingMonthReturn, closeTo(0.15, 0.001));
    });

    test('returns null when fewer than 20 points in window', () {
      final state = PortfolioState();
      final now = DateTime(2026, 5, 12);
      final history = [
        for (int i = 10; i >= 0; i--)
          _point(now.subtract(Duration(days: i)), 100.0),
      ];
      state.debugSetAccountDashboard(_dashboardWith(history));
      expect(state.trailingMonthReturn, isNull);
    });
  });

  group('topContributorOver30d', () {
    test('returns null when earnings history is missing', () {
      final state = PortfolioState();
      expect(state.topContributorOver30d, isNull);
    });
    // Full earnings-history fixture covered by widget-level smoke later.
  });

  group('portfolioVolatilitySpike', () {
    test('returns null when no volatility history set', () {
      final state = PortfolioState();
      expect(state.portfolioVolatilitySpike, isNull);
    });

    test('returns spike when last point exceeds 1.5x trailing-30d avg', () {
      final state = PortfolioState();
      final today = DateTime(2026, 5, 12);
      final points = <MobileVolatilityPoint>[
        for (int i = 30; i >= 1; i--)
          MobileVolatilityPoint(
            date: today.subtract(Duration(days: i)),
            volatility: 0.10,
          ),
        MobileVolatilityPoint(date: today, volatility: 0.20),
      ];
      state.debugSetVolatilityHistory(MobileVolatilityHistoryResponse(
        portfolioCode: 'X',
        portfolioLabel: 'X',
        rollingWindow: 20,
        earliestDataDate: today.subtract(const Duration(days: 30)),
        latestDataDate: today,
        points: points,
      ));
      final spike = state.portfolioVolatilitySpike;
      expect(spike, isNotNull);
      expect(spike!.percentAboveAverage, closeTo(1.0, 0.01));
    });

    test('returns null when last point is below threshold', () {
      final state = PortfolioState();
      final today = DateTime(2026, 5, 12);
      final points = <MobileVolatilityPoint>[
        for (int i = 30; i >= 1; i--)
          MobileVolatilityPoint(
            date: today.subtract(Duration(days: i)),
            volatility: 0.10,
          ),
        MobileVolatilityPoint(date: today, volatility: 0.12),
      ];
      state.debugSetVolatilityHistory(MobileVolatilityHistoryResponse(
        portfolioCode: 'X',
        portfolioLabel: 'X',
        rollingWindow: 20,
        earliestDataDate: today.subtract(const Duration(days: 30)),
        latestDataDate: today,
        points: points,
      ));
      expect(state.portfolioVolatilitySpike, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Front-End/robo_mobile && flutter test test/app/portfolio_state_notifications_test.dart`
Expected: FAIL — getters and `debugSet*` helpers don't exist yet.

- [ ] **Step 3: Write minimal implementation**

In `Front-End/robo_mobile/lib/app/portfolio_state.dart`:

Add near the top of the file (after the existing `ContributionEntry` class):

```dart
class VolatilitySpike {
  final double currentVolatility;
  final double averageVolatility;
  final double percentAboveAverage; // (current / avg) - 1
  const VolatilitySpike({
    required this.currentVolatility,
    required this.averageVolatility,
    required this.percentAboveAverage,
  });
}
```

Add a private field for volatility history (near the existing `_earningsHistory` declaration):

```dart
  MobileVolatilityHistoryResponse? _portfolioVolatility;
```

Add the three getters (near the other notification-related getters around line 130-145):

```dart
  /// Trailing-30-day portfolio return as a fraction (e.g. 0.042 = +4.2%).
  /// Returns null when fewer than 20 daily points exist in the window.
  double? get trailingMonthReturn {
    final history = accountHistory;
    if (history.length < 20) return null;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));
    final window = history.where((p) => !p.date.isBefore(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (window.length < 20) return null;
    final start = window.first.portfolioValue;
    final end = window.last.portfolioValue;
    if (start <= 0) return null;
    return (end / start) - 1.0;
  }

  /// Top contributor by |weight × cumulative return| over the last 30 days.
  /// Returns null when earnings history is unavailable or no asset clears the
  /// 0.5% absolute-contribution threshold.
  ContributionEntry? get topContributorOver30d {
    final history = _earningsHistory;
    final portfolio = selectedPortfolio;
    if (history == null || portfolio == null) return null;
    if (history.points.length < 2) return null;

    final weights = <AssetClass, double>{};
    for (final alloc in portfolio.sectorAllocations) {
      final cls = _sectorToAssetClass(alloc.sectorCode);
      if (cls == null) continue;
      weights[cls] = (weights[cls] ?? 0.0) + alloc.weight;
    }
    if (weights.isEmpty) return null;

    final start = history.points.first;
    final end = history.points.last;
    final cutoff = end.date.subtract(const Duration(days: 30));
    final startWindow = history.points.lastWhere(
      (p) => !p.date.isAfter(cutoff),
      orElse: () => start,
    );

    ContributionEntry? best;
    weights.forEach((cls, weight) {
      final code = _assetClassToEarningsCode(cls);
      if (code == null) return;
      final endValue = end.assetEarnings[code];
      final startValue = startWindow.assetEarnings[code];
      if (endValue == null || startValue == null || startValue == 0) return;
      final assetReturn = (endValue / startValue) - 1.0;
      final impact = weight * assetReturn;
      if (impact.abs() < 0.005) return; // 0.5% threshold
      final entry = ContributionEntry(
        cls: cls,
        label: cls.koLabel,
        weight: weight,
        assetReturn: assetReturn,
        krwImpact: impact,
      );
      if (best == null || impact.abs() > best!.krwImpact.abs()) {
        best = entry;
      }
    });
    return best;
  }

  /// Portfolio volatility spike: most-recent point ≥ 1.5× trailing-30d avg.
  /// Returns null when no spike, no data, or insufficient history.
  VolatilitySpike? get portfolioVolatilitySpike {
    final vol = _portfolioVolatility;
    if (vol == null || vol.points.length < 21) return null;
    final sorted = [...vol.points]..sort((a, b) => a.date.compareTo(b.date));
    final current = sorted.last.volatility;
    final cutoff = sorted.last.date.subtract(const Duration(days: 30));
    final window = sorted
        .where((p) => !p.date.isBefore(cutoff) && p.date.isBefore(sorted.last.date))
        .toList();
    if (window.length < 20) return null;
    final avg = window.map((p) => p.volatility).reduce((a, b) => a + b) /
        window.length;
    if (avg <= 0) return null;
    final ratio = current / avg;
    if (ratio < 1.5) return null;
    return VolatilitySpike(
      currentVolatility: current,
      averageVolatility: avg,
      percentAboveAverage: ratio - 1.0,
    );
  }

  /// Public setter for the dropdown's on-open volatility fetch.
  void setPortfolioVolatilityHistory(
    MobileVolatilityHistoryResponse? value,
  ) {
    _portfolioVolatility = value;
    notifyListeners();
  }

  // ─── Internal helpers ─────────────────────────────────────

  AssetClass? _sectorToAssetClass(String sectorCode) {
    switch (sectorCode) {
      case '현금성자산':
        return AssetClass.cash;
      case '단기채권':
        return AssetClass.shortBond;
      case '인프라채권':
        return AssetClass.infraBond;
      case '금':
        return AssetClass.gold;
      case '미국가치주':
        return AssetClass.usValue;
      case '미국성장주':
        return AssetClass.usGrowth;
      case '신성장주':
        return AssetClass.newGrowth;
      default:
        return null;
    }
  }

  String? _assetClassToEarningsCode(AssetClass cls) {
    // Earnings history keys match the sector Korean labels in MVP fixtures.
    return cls.koLabel;
  }
```

At the bottom of `PortfolioState`, add the two debug setters (used only by tests — not by production code paths):

```dart
  @visibleForTesting
  void debugSetAccountDashboard(MobileAccountDashboard dashboard) {
    _accountDashboard = dashboard;
    notifyListeners();
  }

  @visibleForTesting
  void debugSetVolatilityHistory(MobileVolatilityHistoryResponse value) {
    _portfolioVolatility = value;
    notifyListeners();
  }
```

Add the import if not already present: `import 'package:flutter/foundation.dart';`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Front-End/robo_mobile && flutter test test/app/portfolio_state_notifications_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Run full analyze**

Run: `cd Front-End/robo_mobile && flutter analyze`
Expected: `No issues found`.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/app/portfolio_state.dart \
        Front-End/robo_mobile/test/app/portfolio_state_notifications_test.dart
git commit -m "frontend: add portfolio-state getters for notification rows"
```

---

## Task 6: Frontend — top-anchored sheet shell (UI only, no real data yet)

Replaces the existing floating modal with the top-anchored sheet. Rows still render dummy strings — the wiring lands in Task 7 and Task 8.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart` (rewrite the block from `// ─── Notification dropdown sheet ────────────────────────────` through the end of `_NotificationRow`)

- [ ] **Step 1: Write the failing test**

Create `Front-End/robo_mobile/test/screens/home/notifications_sheet_layout_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/portfolio_state.dart';

// Test target: import the public showNotificationsSheet helper which the home
// tab will call. The sheet itself stays private inside home_tab.dart, but the
// helper is package-public so widget tests can drive it.
import 'package:robo_mobile/screens/home/home_tab.dart' show showNotificationsSheet;

void main() {
  testWidgets('sheet is top-anchored and shows the title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PortfolioStateProvider(
          state: PortfolioState(),
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showNotificationsSheet(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 알림'), findsOneWidget);

    // Sheet content sits in the top half of the screen.
    final titleBox = tester.getRect(find.text('오늘의 알림'));
    final screenHeight =
        tester.binding.window.physicalSize.height /
            tester.binding.window.devicePixelRatio;
    expect(titleBox.top < screenHeight / 2, isTrue,
        reason: 'expected sheet to be anchored at the top half');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Front-End/robo_mobile && flutter test test/screens/home/notifications_sheet_layout_test.dart`
Expected: FAIL — `showNotificationsSheet` is private (currently `_showNotificationsSheet`).

- [ ] **Step 3: Rewrite the notification block**

In `Front-End/robo_mobile/lib/screens/home/home_tab.dart`, replace the entire block (the current `void _showNotificationsSheet(BuildContext context)` function plus `_NotificationItem`, `_dummyNotifications`, `_NotificationsSheet`, and `_NotificationRow`) with the following:

```dart
// ─── Notification dropdown sheet ────────────────────────────

/// Public entry point so widget tests can drive the sheet without going
/// through the bell icon's GestureDetector.
void showNotificationsSheet(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '알림 닫기',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: WeRoboMotion.medium,
    pageBuilder: (_, __, ___) => const _NotificationsSheet(),
    transitionBuilder: (_, anim, __, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: WeRoboMotion.enter));
      return SlideTransition(position: slide, child: child);
    },
  );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  // Rows render in this order. Task 7 wires the first three; Task 8 wires the
  // last two (async).
  static const _rowOrder = <_NotificationKind>[
    _NotificationKind.monthlySummary,
    _NotificationKind.contribution,
    _NotificationKind.algorithmSignal,
    _NotificationKind.volatilityAlert,
    _NotificationKind.assetNews,
  ];

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);

    // Placeholder rows until Task 7 / Task 8 ship.
    final placeholderRows = _rowOrder
        .map((k) => _NotificationRow(
              kind: k,
              category: _categoryLabel(k),
              title: '(데이터 연결 예정)',
              onTap: () => Navigator.of(context).pop(),
            ))
        .toList();

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '오늘의 알림',
                            textAlign: TextAlign.center,
                            style: WeRoboTypography.heading3.themed(context),
                          ),
                        ),
                        Pressable(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tc.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: tc.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: tc.card),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: placeholderRows.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: tc.card,
                      indent: 20,
                      endIndent: 20,
                    ),
                    itemBuilder: (_, i) => placeholderRows[i],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _NotificationKind {
  monthlySummary,
  contribution,
  algorithmSignal,
  volatilityAlert,
  assetNews,
}

String _categoryLabel(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.monthlySummary:
      return '월간 요약';
    case _NotificationKind.contribution:
      return '기여도 알림';
    case _NotificationKind.algorithmSignal:
      return '알고리즘 시그널';
    case _NotificationKind.volatilityAlert:
      return '시장 변동성 경고';
    case _NotificationKind.assetNews:
      return '자산군별 뉴스';
  }
}

String _iconAsset(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.monthlySummary:
      return 'assets/icons/calendar.png';
    case _NotificationKind.contribution:
      return 'assets/icons/contribution-alarm.png';
    case _NotificationKind.algorithmSignal:
      return 'assets/icons/algorithm-signal.png';
    case _NotificationKind.volatilityAlert:
      return 'assets/icons/change-alert.png';
    case _NotificationKind.assetNews:
      return 'assets/icons/asset-news.png';
  }
}

Color _iconTint(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.monthlySummary:
      return const Color(0xFF3B82F6);
    case _NotificationKind.contribution:
      return const Color(0xFF10B981);
    case _NotificationKind.algorithmSignal:
      return const Color(0xFF8B5CF6);
    case _NotificationKind.volatilityAlert:
      return const Color(0xFFF59E0B);
    case _NotificationKind.assetNews:
      return const Color(0xFF1E3A8A);
  }
}

class _NotificationRow extends StatelessWidget {
  final _NotificationKind kind;
  final String category;
  final String title;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.kind,
    required this.category,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final tint = _iconTint(kind);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(_iconAsset(kind), fit: BoxFit.contain),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category,
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tc.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
```

Also update the bell button to call the new public helper:

```dart
class _NotificationIconButton extends StatelessWidget {
  final bool hasUnread;
  const _NotificationIconButton({this.hasUnread = false});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: () => showNotificationsSheet(context),
      child: Icon(
        hasUnread
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded,
        size: 24,
        color: tc.textSecondary,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Front-End/robo_mobile && flutter test test/screens/home/notifications_sheet_layout_test.dart`
Expected: PASS.

- [ ] **Step 5: Full analyze**

Run: `cd Front-End/robo_mobile && flutter analyze`
Expected: `No issues found`.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart \
        Front-End/robo_mobile/test/screens/home/notifications_sheet_layout_test.dart
git commit -m "frontend: top-anchored notification sheet shell (placeholder rows)"
```

---

## Task 7: Frontend — wire sync rows (monthly, contribution, algorithm signal)

Replaces the three placeholder rows that source from `PortfolioState` synchronously. The two async rows still render placeholders until Task 8.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart` (the `_NotificationsSheetState.build` method only)
- Test: `Front-End/robo_mobile/test/screens/home/notifications_sheet_rows_test.dart`

- [ ] **Step 1: Write the failing test**

Create `Front-End/robo_mobile/test/screens/home/notifications_sheet_rows_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/models/rebalance_insight.dart';
import 'package:robo_mobile/screens/home/home_tab.dart' show showNotificationsSheet;

MobileAccountDashboard _dashboardWith(List<MobileAccountHistoryPoint> history) {
  return MobileAccountDashboard(
    hasAccount: true,
    summary: null,
    history: history,
    recentActivity: const [],
  );
}

void main() {
  testWidgets('monthly summary row shows trailing-30d percent', (tester) async {
    final state = PortfolioState();
    final now = DateTime.now();
    final history = [
      for (int i = 30; i >= 0; i--)
        MobileAccountHistoryPoint(
          date: now.subtract(Duration(days: i)),
          portfolioValue: 100.0 + (30 - i) * 0.5,
          investedAmount: 100,
          profitLoss: 0,
          profitLossPct: 0,
        ),
    ];
    state.debugSetAccountDashboard(_dashboardWith(history));

    await tester.pumpWidget(MaterialApp(
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('지난 30일'), findsOneWidget);
    expect(find.textContaining('15.0%'), findsOneWidget);
  });

  testWidgets('monthly summary row hidden when insufficient history',
      (tester) async {
    final state = PortfolioState();
    state.debugSetAccountDashboard(_dashboardWith(const []));

    await tester.pumpWidget(MaterialApp(
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('월간 요약'), findsNothing);
  });

  testWidgets('algorithm signal row shows latest insight trigger',
      (tester) async {
    final state = PortfolioState();
    state.debugSetInsights([
      RebalanceInsight(
        id: 1,
        rebalanceDate: '2026-05-10',
        allocations: const [],
        tradeDetails: const [],
        trigger: 'drift',
        tradeCount: 1,
        cashBefore: 0,
        cashFromSales: 0,
        cashToBuys: 0,
        cashAfter: 0,
        netCashChange: 0,
        explanationText: 'test',
        isRead: false,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('알고리즘 시그널'), findsOneWidget);
    expect(find.textContaining('비중 드리프트'), findsOneWidget);
  });
}
```

`debugSetInsights` doesn't exist yet — add it next to the other debug setters in Task 5's file:

```dart
  @visibleForTesting
  void debugSetInsights(List<RebalanceInsight> insights) {
    _insights = insights;
    notifyListeners();
  }
```

(Add this in Step 3 below as part of the same commit if it wasn't done in Task 5.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Front-End/robo_mobile && flutter test test/screens/home/notifications_sheet_rows_test.dart`
Expected: FAIL — rows still render placeholders.

- [ ] **Step 3: Replace placeholder rows with real data**

In `home_tab.dart`, replace the body of `_NotificationsSheetState.build` so that the rows derive from `PortfolioState`. The complete replacement:

```dart
  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);

    final rows = <Widget>[];

    // 1. Monthly summary.
    final monthly = state.trailingMonthReturn;
    if (monthly != null) {
      final sign = monthly >= 0 ? '+' : '−';
      final pct = (monthly.abs() * 100).toStringAsFixed(1);
      rows.add(_NotificationRow(
        kind: _NotificationKind.monthlySummary,
        category: _categoryLabel(_NotificationKind.monthlySummary),
        title: '지난 30일 포트폴리오 $sign$pct%',
        onTap: () => Navigator.of(context).pop(),
      ));
    }

    // 2. Contribution.
    final contributor = state.topContributorOver30d;
    if (contributor != null) {
      final pct = (contributor.weight * contributor.assetReturn * 100)
          .abs()
          .round();
      rows.add(_NotificationRow(
        kind: _NotificationKind.contribution,
        category: _categoryLabel(_NotificationKind.contribution),
        title: '이번 달 ${contributor.label}이 수익의 $pct%를 기여했어요',
        onTap: () => Navigator.of(context).pop(),
      ));
    }

    // 3. Algorithm signal — sources from existing rebalance insights.
    final insightRow = _buildAlgorithmSignalRow(state, context);
    if (insightRow != null) rows.add(insightRow);

    // 4-5. Volatility and news land in Task 8.
    rows.add(_NotificationRow(
      kind: _NotificationKind.volatilityAlert,
      category: _categoryLabel(_NotificationKind.volatilityAlert),
      title: '(데이터 연결 예정)',
      onTap: () => Navigator.of(context).pop(),
    ));
    rows.add(_NotificationRow(
      kind: _NotificationKind.assetNews,
      category: _categoryLabel(_NotificationKind.assetNews),
      title: '(데이터 연결 예정)',
      onTap: () => Navigator.of(context).pop(),
    ));

    final body = rows.isEmpty
        ? <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Text(
                '오늘은 새로운 알림이 없어요',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textTertiary,
                ),
              ),
            ),
          ]
        : <Widget>[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: tc.card,
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (_, i) => rows[i],
            ),
          ];

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '오늘의 알림',
                            textAlign: TextAlign.center,
                            style: WeRoboTypography.heading3.themed(context),
                          ),
                        ),
                        Pressable(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tc.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: tc.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: tc.card),
                  ...body,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _NotificationRow? _buildAlgorithmSignalRow(
    PortfolioState state,
    BuildContext context,
  ) {
    final insights = state.insights;
    if (insights.isEmpty) return null;
    final latest = insights.first;
    final created = DateTime.tryParse(latest.createdAt);
    final ageDays = created == null
        ? 0
        : DateTime.now().difference(created).inDays;
    if (latest.isRead && ageDays > 30) return null;

    final dateLabel = latest.rebalanceDate.length >= 10
        ? latest.rebalanceDate.substring(5).replaceAll('-', '/')
        : latest.rebalanceDate;
    final triggerLabel = _triggerLabel(latest.trigger);
    return _NotificationRow(
      kind: _NotificationKind.algorithmSignal,
      category: _categoryLabel(_NotificationKind.algorithmSignal),
      title: '$dateLabel $triggerLabel',
      onTap: () => Navigator.of(context).pop(),
    );
  }

  String _triggerLabel(String? trigger) {
    switch (trigger) {
      case 'scheduled':
        return '정기 리밸런싱 시그널';
      case 'drift':
        return '비중 드리프트 감지';
      case 'threshold':
        return '임계치 초과 감지';
      case null:
        return '리밸런싱 시그널 감지';
      default:
        return trigger;
    }
  }
```

If `debugSetInsights` was not added in Task 5, add it now to `portfolio_state.dart`:

```dart
  @visibleForTesting
  void debugSetInsights(List<RebalanceInsight> insights) {
    _insights = insights;
    notifyListeners();
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Front-End/robo_mobile && flutter test test/screens/home/notifications_sheet_rows_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run full analyze + all tests**

Run: `cd Front-End/robo_mobile && flutter analyze && flutter test`
Expected: `No issues found.` then green test suite.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart \
        Front-End/robo_mobile/lib/app/portfolio_state.dart \
        Front-End/robo_mobile/test/screens/home/notifications_sheet_rows_test.dart
git commit -m "frontend: wire monthly/contribution/algorithm-signal rows to real data"
```

---

## Task 8: Frontend — wire async rows (volatility + news)

Adds an in-sheet async loader. On sheet open, kicks off two parallel fetches:
- portfolio volatility history (cached into `state.setPortfolioVolatilityHistory`)
- asset-class news for the user's top-weighted asset class (held in local sheet state)

Each async row hides if its fetch fails, returns no data, or its derived computation says "no alert".

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart` (`_NotificationsSheetState`)
- Test: `Front-End/robo_mobile/test/screens/home/notifications_sheet_async_test.dart`

- [ ] **Step 1: Write the failing test**

Create `Front-End/robo_mobile/test/screens/home/notifications_sheet_async_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/home_tab.dart'
    show showNotificationsSheet, debugSetNotificationsApiOverride;

class _FakeApi {
  MobileVolatilityHistoryResponse? volReturn;
  Object? volError;
  MobileAssetClassNewsResponse? newsReturn;
  Object? newsError;

  Future<MobileVolatilityHistoryResponse> fetchVolatility() async {
    if (volError != null) throw volError!;
    return volReturn!;
  }

  Future<MobileAssetClassNewsResponse> fetchNews(AssetClass cls) async {
    if (newsError != null) throw newsError!;
    return newsReturn!;
  }
}

void main() {
  tearDown(() => debugSetNotificationsApiOverride(null));

  testWidgets('volatility row appears when spike detected', (tester) async {
    final api = _FakeApi();
    final today = DateTime(2026, 5, 12);
    api.volReturn = MobileVolatilityHistoryResponse(
      portfolioCode: 'X',
      portfolioLabel: 'X',
      rollingWindow: 20,
      earliestDataDate: today.subtract(const Duration(days: 30)),
      latestDataDate: today,
      points: [
        for (int i = 30; i >= 1; i--)
          MobileVolatilityPoint(
            date: today.subtract(Duration(days: i)),
            volatility: 0.10,
          ),
        MobileVolatilityPoint(date: today, volatility: 0.20),
      ],
    );
    api.newsError = Exception('skip');

    debugSetNotificationsApiOverride((
      fetchVolatility: api.fetchVolatility,
      fetchNews: api.fetchNews,
    ));

    final state = PortfolioState();
    await tester.pumpWidget(MaterialApp(
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('시장 변동성 경고'), findsOneWidget);
    expect(find.textContaining('변동성'), findsWidgets);
  });

  testWidgets('news row hides on fetch error', (tester) async {
    final api = _FakeApi();
    api.volError = Exception('skip');
    api.newsError = Exception('rss down');

    debugSetNotificationsApiOverride((
      fetchVolatility: api.fetchVolatility,
      fetchNews: api.fetchNews,
    ));

    final state = PortfolioState();
    await tester.pumpWidget(MaterialApp(
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('자산군별 뉴스'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Front-End/robo_mobile && flutter test test/screens/home/notifications_sheet_async_test.dart`
Expected: FAIL — `debugSetNotificationsApiOverride` and async wiring don't exist.

- [ ] **Step 3: Add the async wiring**

In `home_tab.dart`, near the top of the notification-sheet block, add a typedef + an override hook (so tests can inject fake fetchers):

```dart
typedef _NotificationsFetchers = ({
  Future<MobileVolatilityHistoryResponse> Function() fetchVolatility,
  Future<MobileAssetClassNewsResponse> Function(AssetClass cls) fetchNews,
});

_NotificationsFetchers? _notificationsApiOverride;

@visibleForTesting
void debugSetNotificationsApiOverride(_NotificationsFetchers? override) {
  _notificationsApiOverride = override;
}
```

Replace `_NotificationsSheetState` with the following async-aware version (rows from Task 7 remain; volatility + news are filled in from `_state` fields):

```dart
class _NotificationsSheetState extends State<_NotificationsSheet> {
  MobileAssetClassNewsResponse? _news;
  bool _newsErrored = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAsync());
  }

  Future<void> _loadAsync() async {
    final state = PortfolioStateProvider.of(context);
    final override = _notificationsApiOverride;
    final fetchVolatility = override?.fetchVolatility ??
        () {
          // Mirror the production call in portfolio_tab.dart so the same
          // dataset is returned (the response is portfolio-wide, keyed by
          // risk profile + horizon).
          final portfolio = state.selectedPortfolio;
          final riskProfile = portfolio?.code ?? state.type.riskCode;
          return MobileBackendApi.instance.fetchVolatilityHistory(
            riskProfile: riskProfile,
            stockWeights: portfolio?.stockWeights,
          );
        };
    final topAsset = _topWeightedAssetClass(state);
    final fetchNews = override?.fetchNews ??
        (AssetClass cls) =>
            MobileBackendApi.instance.fetchAssetClassNews(cls);

    final results = await Future.wait<Object?>([
      _safe(() async {
        final vol = await fetchVolatility();
        if (!mounted) return null;
        state.setPortfolioVolatilityHistory(vol);
        return null;
      }),
      topAsset == null
          ? Future.value(null)
          : _safe(() async {
              final news = await fetchNews(topAsset);
              if (!mounted) return null;
              setState(() {
                _news = news;
              });
              return null;
            }, onError: () {
              if (!mounted) return;
              setState(() => _newsErrored = true);
            }),
    ]);
    if (!mounted) return;
    setState(() {
      _ready = true;
    });
    // Suppress unused-var lint.
    if (results.isEmpty) return;
  }

  Future<T?> _safe<T>(Future<T> Function() body, {VoidCallback? onError}) async {
    try {
      return await body();
    } catch (_) {
      onError?.call();
      return null;
    }
  }

  AssetClass? _topWeightedAssetClass(PortfolioState state) {
    final portfolio = state.selectedPortfolio;
    if (portfolio == null) return null;
    final weights = <AssetClass, double>{};
    for (final alloc in portfolio.sectorAllocations) {
      final cls = _sectorCodeToAssetClass(alloc.sectorCode);
      if (cls == null) continue;
      weights[cls] = (weights[cls] ?? 0.0) + alloc.weight;
    }
    if (weights.isEmpty) return null;
    final sorted = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  AssetClass? _sectorCodeToAssetClass(String sectorCode) {
    switch (sectorCode) {
      case '현금성자산':
        return AssetClass.cash;
      case '단기채권':
        return AssetClass.shortBond;
      case '인프라채권':
        return AssetClass.infraBond;
      case '금':
        return AssetClass.gold;
      case '미국가치주':
        return AssetClass.usValue;
      case '미국성장주':
        return AssetClass.usGrowth;
      case '신성장주':
        return AssetClass.newGrowth;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // … keep the existing Task 7 build body, BUT replace the two placeholder
    // rows (volatilityAlert + assetNews) with the real-data versions below.
    // (Full replacement code shown next so the engineer copies the whole
    // method intact.)
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);

    final rows = <Widget>[];

    final monthly = state.trailingMonthReturn;
    if (monthly != null) {
      final sign = monthly >= 0 ? '+' : '−';
      final pct = (monthly.abs() * 100).toStringAsFixed(1);
      rows.add(_NotificationRow(
        kind: _NotificationKind.monthlySummary,
        category: _categoryLabel(_NotificationKind.monthlySummary),
        title: '지난 30일 포트폴리오 $sign$pct%',
        onTap: () => Navigator.of(context).pop(),
      ));
    }

    final contributor = state.topContributorOver30d;
    if (contributor != null) {
      final pct = (contributor.weight * contributor.assetReturn * 100)
          .abs()
          .round();
      rows.add(_NotificationRow(
        kind: _NotificationKind.contribution,
        category: _categoryLabel(_NotificationKind.contribution),
        title: '이번 달 ${contributor.label}이 수익의 $pct%를 기여했어요',
        onTap: () => Navigator.of(context).pop(),
      ));
    }

    final algoRow = _buildAlgorithmSignalRow(state, context);
    if (algoRow != null) rows.add(algoRow);

    // Volatility row — appears only after _ready and only if a spike is found.
    final spike = state.portfolioVolatilitySpike;
    if (_ready && spike != null) {
      final pct = (spike.percentAboveAverage * 100).round();
      rows.add(_NotificationRow(
        kind: _NotificationKind.volatilityAlert,
        category: _categoryLabel(_NotificationKind.volatilityAlert),
        title: '포트폴리오 변동성 +$pct% 주의 구간이에요',
        onTap: () => Navigator.of(context).pop(),
      ));
    }

    // News row — appears only after _ready, when fetch succeeded.
    if (_ready && _news != null && !_newsErrored) {
      rows.add(_NotificationRow(
        kind: _NotificationKind.assetNews,
        category: _categoryLabel(_NotificationKind.assetNews),
        title: _news!.title,
        onTap: () => _openNewsLink(_news!.link),
      ));
    }

    final body = rows.isEmpty && _ready
        ? <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Text(
                '오늘은 새로운 알림이 없어요',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textTertiary,
                ),
              ),
            ),
          ]
        : <Widget>[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: tc.card,
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (_, i) => rows[i],
            ),
          ];

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: tc.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '오늘의 알림',
                            textAlign: TextAlign.center,
                            style: WeRoboTypography.heading3.themed(context),
                          ),
                        ),
                        Pressable(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: tc.card,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: tc.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: tc.card),
                  ...body,
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNewsLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted) Navigator.of(context).pop();
  }
}
```

Add this import at the top of `home_tab.dart` (alongside the existing imports):

```dart
import 'package:url_launcher/url_launcher.dart';
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Front-End/robo_mobile && flutter test test/screens/home/notifications_sheet_async_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Run full analyze + all tests**

Run: `cd Front-End/robo_mobile && flutter analyze && flutter test`
Expected: `No issues found.` then green test suite.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart \
        Front-End/robo_mobile/test/screens/home/notifications_sheet_async_test.dart
git commit -m "frontend: wire volatility and news rows via async fetch"
```

---

## Task 9: Manual smoke test on iOS simulator

Final verification. No new code unless a regression turns up.

- [ ] **Step 1: Launch the app**

Run: `cd Front-End/robo_mobile && flutter run -d E59D10D1-D076-4149-9AC9-ABFB4855F165`

Boot the iPhone 17 Pro simulator first if not already running:
`xcrun simctl boot E59D10D1-D076-4149-9AC9-ABFB4855F165 && open -a Simulator`

- [ ] **Step 2: Reach the home tab**

Log in (test credentials if any, or sign up a throwaway account). Wait for the home tab to render.

- [ ] **Step 3: Tap the bell + verify**

Tap the notification bell icon (top right of home). Verify:
- Sheet slides DOWN from the very top (the slide motion is visible — no fade-only).
- Status bar (time, signal) remains readable above the sheet.
- Bottom corners are rounded; the top edge sits flush against the safe area.
- Title "오늘의 알림" is centered, X button on right.
- At least one row renders (algorithm signal should — fixtures include rebalance insights).

Take screenshot: `xcrun simctl io E59D10D1-D076-4149-9AC9-ABFB4855F165 screenshot /tmp/notifications-sheet.png`

- [ ] **Step 4: Tap dismiss**

Tap the X button. Sheet should slide back up.

- [ ] **Step 5: Tap outside (re-open and dismiss via barrier)**

Re-open the sheet, tap the dimmed area below it. Sheet dismisses.

- [ ] **Step 6: Tap a news row (if present)**

If a news row rendered, tap it. The system browser should open with the article URL. (Skip this step if no news row appeared — that's a valid empty-state.)

---

## Final cleanup

After all tasks complete:

- [ ] Confirm `home_tab.dart` line count stayed under 3600. If not, schedule a follow-up to extract `lib/screens/home/widgets/notifications_sheet.dart`.
- [ ] Confirm `feedparser` is in `requirements.txt` (already present per current state).
- [ ] Run `flutter test` and the backend `pytest` one more time to catch flakes.
- [ ] Push the branch.
