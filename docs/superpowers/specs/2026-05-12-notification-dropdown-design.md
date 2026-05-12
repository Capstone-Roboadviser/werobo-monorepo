# Notification Dropdown — Design Spec

**Date:** 2026-05-12
**Status:** Approved (pending user spec review)
**Owner:** honge6090

## Problem

The home tab's bell icon currently pushes to a full-page `ActivityHubPage`. Eugene wants a top-anchored dropdown panel instead, populated by **real data** across 5 categories (no dummy strings). A first pass landed a floating modal with dummy content; this spec replaces both.

## Visual reference

The user-supplied reference (Pinto's "오늘 핀트 소식" panel) shows:
- Panel anchored at the top of the screen, status bar visible above
- Full-width with small side margin, bottom corners rounded
- Centered title, X close button on the right
- Each row: tinted circular icon, category caption, bold title, chevron

## UI

### Anchoring & motion

- The dropdown is a top-anchored sheet, not a centered modal.
- Position: `Align(alignment: Alignment.topCenter)`, `SafeArea(top: true, bottom: false)`. Status bar remains visible above the sheet.
- Side margin: 8 px each side. Bottom corners rounded 20 px. Top corners flat (sheet rides up against the safe-area top so the slide reads as "pulled down").
- Animation: `Tween<Offset>(begin: Offset(0, -1), end: Offset.zero)` over `WeRoboMotion.medium` (250 ms) with `WeRoboMotion.enter` curve. Combined with a fade for the backdrop.
- Backdrop: solid `black @ 32%` (no blur — keeps it cheap on older devices).
- Dismiss: tap outside, X button, or system back.

### Row layout

Identical to the v1 design (icon-tint circle + caption + bold title + chevron). Asset-tint mapping per row:

| Row | Icon | Tint |
|---|---|---|
| 월간 요약 | calendar.png | #3B82F6 |
| 기여도 알림 | contribution-alarm.png | #10B981 |
| 알고리즘 시그널 | algorithm-signal.png | #8B5CF6 |
| 시장 변동성 경고 | change-alert.png | #F59E0B |
| 자산군별 뉴스 | asset-news.png | #1E3A8A |

### Empty-state rule

Rows with no current data are **hidden**. The dropdown renders 1–5 rows depending on what's available. If all 5 are empty, show a single muted line "오늘은 새로운 알림이 없어요" inside the sheet (no row icons).

## Data sources

All 5 rows source from real data. No string is hardcoded except category labels, icons, and the empty-state copy.

### 1. 월간 요약 (Monthly summary)

- **Source:** client-side aggregation. Walk the existing daily portfolio-value series in `PortfolioState` (the same series the hero chart reads from `state.portfolioValueHistory` / equivalent — confirm exact field name during implementation). Compute simple return = `(value_today / value_30d_ago) - 1`.
- **Hide if:** fewer than 20 daily points exist in the trailing 30d window (insufficient data).
- **Copy:** `지난 30일 포트폴리오 {+X.X%|−X.X%}` (one decimal place). Sign and color follow `_gainColor` / `_lossColor`.

### 2. 기여도 알림 (Contribution alert)

- **Source:** `ContributionAnalysis` (already at `portfolio_state.dart:41`). Compute trailing-30d contribution = `weight × asset_return` per asset, pick the top contributor by absolute value.
- **Hide if:** no asset contributes ≥ 0.5% to the portfolio over the window.
- **Copy:** `이번 달 {assetName}이 수익의 {N}%를 기여했어요`. `assetName` is the Korean asset class label; `N` is rounded to integer percent.

### 3. 알고리즘 시그널 (Algorithm signal)

- **Source:** `state.insights` (existing). This row **is** the rebalancing notification — renamed and reframed as a signal.
- **Selection:** most recent `RebalanceInsight` (already sorted in state). Hide if `isRead == true` AND the insight is older than 30 days (no longer fresh enough to surface as a signal).
- **Copy:** category caption stays "알고리즘 시그널". Title is `{MM/DD} 리밸런싱 시그널 감지` when `RebalanceInsight.trigger` is null or unrecognized; otherwise map known trigger codes to Korean copy:
  - `scheduled` → "정기 리밸런싱 시그널"
  - `drift` → "비중 드리프트 감지"
  - `threshold` → "임계치 초과 감지"
  - any other non-null value → use the raw string (forward-compat).
- **Tap:** for v1, dismiss the sheet (no navigation). Follow-up can wire to `InsightDetailPage`.

### 4. 시장 변동성 경고 (Market volatility warning)

- **Source:** `fetchVolatilityHistory()` (already exists; returns per-asset historical vol).
- **Trigger:** if any asset's most recent daily vol > **1.5×** its trailing-30d average, raise an alert for the highest-ratio asset.
- **Hide if:** no asset exceeds threshold, or vol history fetch fails.
- **Copy:** `{assetName} 변동성 {+X%} 주의 구간이에요` where X is the percentage above the 30d average, rounded.

### 5. 자산군별 뉴스 (Asset-class news)

- **Source:** NEW backend endpoint `GET /news/asset-class?cls={enum_name}`.
- **Frontend behavior:** request news for the user's **top-weighted asset class** only (one network call per dropdown open).
- **Backend behavior:** translate enum → ticker, fetch Yahoo Finance RSS for that ticker, parse with `feedparser`, return the latest article. Module-level dict cache keyed by ticker, 5-minute TTL.
- **Asset → ticker map** (lives in backend, single source of truth):
  - `현금성자산 → SHV`
  - `단기채권 → BND`
  - `인프라채권 → TLT`
  - `금 → GLD`
  - `미국가치주 → VTV`
  - `미국성장주 → VUG`
  - `신성장주 → ARKK`
- **Response shape:** `{ "title": str, "link": str, "published": str (ISO 8601), "source": str }`. On RSS-fetch failure, return HTTP 503 — frontend hides the row.
- **Copy:** title is the raw RSS headline (English is fine — these are US-market headlines).
- **Tap:** opens `link` in the device's external browser via `launchUrl`. `url_launcher` is not currently in `pubspec.yaml` and will be added (`url_launcher: ^6.x`).

## Backend changes

### New file: `Back-End/robo_mobile_backend/app/routes/news.py`

```python
# Skeleton signature
@router.get("/news/asset-class")
async def get_asset_class_news(cls: AssetClassEnum) -> AssetNewsResponse:
    ...
```

- Uses `httpx.AsyncClient` for the RSS fetch.
- Uses `feedparser` for parsing (new dep — add to `pyproject.toml` / `requirements.txt`).
- Cache: module-level `dict[str, tuple[float, AssetNewsResponse]]`. 5-min TTL. Per-process is fine — Railway single-instance for MVP.
- Errors: any RSS or network failure raises `HTTPException(503, "news_unavailable")`.

### Route registration

Mount `news.router` from the existing `main.py` or `__init__.py` (wherever routers are wired). One-line change.

### Tests

- `tests/test_news.py`:
  - happy path: mock `httpx` returning a sample RSS body, assert parsed shape
  - cache hit: second call within 5 min doesn't re-hit the network
  - failure: `httpx` raises → 503
- No new fixtures needed beyond `httpx.Mock`.

## Frontend changes

### Files touched

- `lib/screens/home/home_tab.dart` — replace existing `_NotificationsSheet` / `_NotificationRow` / `_dummyNotifications` block with the new top-anchored, data-driven version.
- `lib/services/mobile_backend_api.dart` — add `fetchAssetClassNews(AssetClass cls)` returning a new `AssetClassNewsResponse` model.
- `lib/models/mobile_backend_models.dart` — add `AssetClassNewsResponse`.
- `lib/app/portfolio_state.dart` — add derived getters: `monthlyReturnPercent`, `topContributorOver30d`, `volatilityAlert` (each returns nullable). These keep aggregation logic out of the widget tree.
- `pubspec.yaml` — add `url_launcher` if not already present.

### File-size note

`home_tab.dart` is already 3400+ lines. The new notification widgets stay inline for symmetry with the existing pattern, but if the diff pushes the file over 3600 we extract `lib/screens/home/widgets/notifications_sheet.dart` as a follow-up. Not blocking for this spec.

## Error handling

- News fetch fails → row hidden silently. No toast, no log line to the user.
- Volatility history fetch fails → row hidden silently.
- Monthly aggregation: if data is insufficient, row hidden.
- Contribution: if no asset clears the 0.5% bar, row hidden.
- Algorithm signal: never errors at the network layer (data is local). If `state.insights` is empty, row hidden.

If all 5 rows hide simultaneously, the dropdown shows the empty-state line.

## Testing

- Widget test for `_NotificationsSheet` at three states: 0 rows (empty), 3 rows (partial), 5 rows (all present). Snapshot the row order — must match the spec table.
- Widget test asserts the sheet uses `SafeArea(top: true)` and is `Align(alignment: Alignment.topCenter)`.
- Backend test as listed above.

## Out of scope

- Read/unread tracking for the 4 new categories. Only algorithm signal carries `isRead` (inherited from rebalance insight).
- Push notifications.
- Korean-language news source (Yahoo English is fine for MVP).
- Caching the news response on the device.
- Pull-to-refresh inside the dropdown.

## Rollout

Single PR. No feature flag — the dropdown is the only entry point for the bell icon, so the change is atomic.
