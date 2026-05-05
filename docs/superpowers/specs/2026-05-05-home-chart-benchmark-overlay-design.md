# Home Chart — Benchmark Overlay & Drag Context Card — Design Spec

**Date:** 2026-05-05
**Author:** brainstorming session with Eugene
**Touches:**
- [`lib/screens/home/home_tab.dart`](../../../Front-End/robo_mobile/lib/screens/home/home_tab.dart) — primary
- [`lib/app/portfolio_state.dart`](../../../Front-End/robo_mobile/lib/app/portfolio_state.dart) — earnings-history state
- [`lib/models/mock_earnings_data.dart`](../../../Front-End/robo_mobile/lib/models/mock_earnings_data.dart) — fallback synthesizer
- [`test/screens/home/home_tab_test.dart`](../../../Front-End/robo_mobile/test/screens/home/home_tab_test.dart) — widget tests

**Ship target:** part of MVP (2026-05-28)

---

## 1. Goal

Bring three benchmark series (시장, 채권 수익률, 연 기대수익률) onto the home portfolio chart so users can read their portfolio's performance against external comparators without leaving the home tab. Add a minimal floating context card on drag that surfaces day-over-day percent moves for the portfolio, the market, and the day's top-two-driving asset groups. Remove the cost-basis "deposit" line and its label.

The home chart's identity stays: hero number in KRW, single dominant orange portfolio line, drag-to-explore interaction. The new content slots into the existing visual frame without changing its character.

## 2. Non-goals

- Refactoring the comparison chart in [`portfolio_charts.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/widgets/portfolio_charts.dart). Its off-system cool grays (`#64748B`, `#999999`) are flagged for a separate task — not fixed here
- Pinch-zoom or horizontal pan on the home chart — `_PortfolioHeroChart` keeps its single-pointer pan-to-crosshair gesture
- Reusing `_MultiLineChartPainter` from the comparison chart. The home painter keeps its glow-dot pulse, fading-segment-after-touch, and gradient-transition polish; mild duplication is intentional
- Backend deployment of `/portfolio/earnings-history` (out of scope for the frontend change)

## 3. Visual design

### 3.1 Chart lines (4 series, all in % return space)

| Series | Color | Stroke | Style |
|---|---|---|---|
| 포트폴리오 | `WeRoboColors.primary` (#FE9337) | 2px | solid |
| 시장 | `tc.textSecondary` (#6B6B6B) | 1.5px | solid |
| 연 기대수익률 | `WeRoboColors.primary` @ 50% alpha | 1.5px | dashed (6/10) |
| 채권 수익률 | `tc.textTertiary` (#8E8E8E) @ 70% alpha | 1.5px | dashed (6/10) |

All four lines rebased to **0% at the start of the visible range**. Range chip change rebases.

Y-axis: numeric labels removed. The 4 horizontal grid lines drawn by the existing painter at `gridColor` @ 0.15 alpha are dimmed to 0.08 — a near-invisible reference for spatial grounding without reading as a labeled axis. (Explicit design call: "no Y axis" interpreted as "no labeled axis," not "no horizontal reference at all" — a 320px-tall chart with zero references reads rudderless.)

The hero number and performance badge stay in KRW. The chart shows shape only; the card surfaces percent values on demand.

### 3.2 Removed elements

- Cost-basis (원금) line drawing in `_PortfolioValuePainter`
- The `'— ₩X 총 입금'` Text widget below the performance badge
- `_allCostBasis` getter and `crosshairCost` plumbing (the `displayInvested` derived value goes with them, since its only consumer is the deleted text)

### 3.3 Legend

A single 10px caption row below the range chips. Four entries, each is a 12×2px stroke sample + label, separated by 12px. Solid samples render as a filled bar; dashed samples render with a 6/3 dash pattern in the sample.

```
· 포트폴리오    · 시장    ┄ 연 기대수익률    ┄ 채권
```

Style follows the comparison chart's Wrap legend ([`portfolio_charts.dart:1031-1058`](../../../Front-End/robo_mobile/lib/screens/onboarding/widgets/portfolio_charts.dart:1031)) but using the system colors above and adding a dashed-sample renderer.

### 3.4 Floating context card

Container:
- Width auto-sized to content (~140px typical), height ~80px
- Anchor: crosshair x, 16px above the orange portfolio dot — flips below if it would clip the chart top
- Horizontal clamp: `x ∈ [8, chartWidth - cardWidth - 8]`
- Fill: `tc.surface` @ 96% opacity
- Border: 0.5px hairline `tc.border` @ 60% alpha
- Radius: 8px · Padding: 10×8px · No shadow

Layout (4 rows + date header):

```
4월 15일                          ← 10px GothicA1, textTertiary

포트폴리오            +0.45%
시장                  +0.21%
                                  ← 6px gap (no rule, no divider)
미국가치주            +1.20%
신성장주              +0.85%
```

- Labels: 11px NotoSansKR w400, `tc.textSecondary` — uniform across all 4 rows
- Values: 12px IBMPlexSans w500, **tabular numerals** so columns align; sign character always rendered
- Sign drives color: positive → `tc.accent` (#059669), negative → `WeRoboColors.error` (#EF4444)
- No ▲/▼ arrows. Direction is encoded twice already (sign + color)

Asset row selection: sort all asset groups by their day-over-day % at the dragged date; if portfolio Δ ≥ 0 take top 2 gainers, if portfolio Δ < 0 take top 2 losers. Result: rows 3–4 always share the day's "story" color with row 1.

Animation: fade in 100ms on pan start, fade out 150ms on pan end. No slide, no scale.

### 3.5 What stays unchanged

- Hero label `현재 자산`, KRW value, count-up animation
- Performance badge (▲/▼ KRW + %)
- Vertical crosshair, glow dot pulse, date label at top
- Range chips and 미래 → ProjectionScreen navigation
- Glow + pulse on touch start
- Pan gesture handlers on the chart container

## 4. Architecture

### 4.1 Data flow

```
PortfolioState
├── accountHistory ──────────────┐
├── comparisonLines ──────────────┤
│      .benchmark_avg → 시장 line │
│      .treasury → 채권 endpoints │
├── expectedReturn → 연 기대수익률 │
└── _earningsHistory ─────────────┤
       MobileEarningsHistoryResponse
       (NEW — fetched by HomeTab,
        mock fallback on error)
                                  │
                                  ▼
                   HomeTab → _PortfolioHeroChart
                                  │
                                  ▼
                _HomePerformancePainter (4 lines, % space)
                + _DragContextCard (Positioned in Stack)
```

### 4.2 PortfolioState changes

Add:

- `MobileEarningsHistoryResponse? _earningsHistory`
- `MobileEarningsHistoryResponse? get earningsHistory`
- `void setEarningsHistory(MobileEarningsHistoryResponse? value)` — notifies listeners
- `Map<String, double> dayOverDayAssetReturns(DateTime date)` — looks up `_earningsHistory.points` for the date and the prior available date, computes per-asset % change. Returns empty map if either point is missing

The selector is on `PortfolioState` rather than in the home tab so it can be unit-tested independently of widget tree.

### 4.3 HomeTab changes

`_HomeTabState`:
- In `didChangeDependencies` (or a dedicated method called from there), if `state.earningsHistory == null`, call `MobileBackendApi.fetchEarningsHistory(...)` for the current portfolio. On success → `state.setEarningsHistory(response)`. On error → fall back to `MockEarningsData.dailyAssetEarnings(state.type.riskCode)` and store via `setEarningsHistory`. Guarded by a one-shot flag to avoid duplicate fetches

`_PortfolioHeroChart` / `_PortfolioHeroChartState`:
- Replace `_allCostBasis` with helper `_pctSeries(List<ChartPoint> krw)` that rebases KRW history to % return relative to first visible point
- New helpers `_marketPctSeries`, `_treasuryEndpoints`, `_expectedReturnEndpoints` reading from `comparisonLines` + `expectedReturn`
- Painter renamed `_PortfolioValuePainter` → `_HomePerformancePainter`; signature changes from `valuePts/costPts` to a `lines: List<ChartLine>` parameter (matching the comparison chart's vocabulary). Painter handles dashed strokes via a small `_drawDashedPath` helper (same dash pattern 6/10 as comparison chart)
- Build tree wraps the `CustomPaint` in a `Stack`. `Positioned` child renders `_DragContextCard` when `_touchIndex != null && _touchIndex! >= 1` (skip first index — no prev day)
- Legend `Wrap` rendered below the range chips row

`_DragContextCard` (new private widget in `home_tab.dart`):
- Constructor takes `date`, `portfolioPct`, `marketPct`, `assetRows: List<({String name, double pct})>` (top-2)
- Renders the 4-row layout described in §3.4
- Stateless — animation handled by `AnimatedOpacity` driven from parent `_touchIndex` state

### 4.4 Mock fallback

`MockEarningsData.dailyAssetEarnings({required String riskCode, double baseInvestment = 100000000})` → `List<MobileEarningsPoint>`:
- For each day from `2025-03-03` to today (matching `dailyCumulativePoints`)
- For each asset in `summaryFor(riskCode)`, generate a daily return with deterministic seeded noise around the asset's expected daily return (`returnPct / 252` annualized), with a per-asset volatility scale (defensive assets lower, growth higher)
- Compose `MobileEarningsPoint(date, totalEarnings, totalReturnPct, assetEarnings)` per day
- Deterministic: same `riskCode` produces identical output across runs

### 4.5 What we don't reuse

- `_MultiLineChartPainter` from `portfolio_charts.dart` — kept separate to preserve the home painter's distinctive polish (glow dot, fading segment, gradient transition)
- The comparison chart's tooltip — that's canvas-painted via `TextPainter`; the home card is a real Flutter widget for cleaner Korean type rendering and `AnimatedOpacity` reuse

## 5. Edge cases

| Case | Behavior |
|---|---|
| Drag at first visible data point (`_touchIndex == 0`) | Card hidden. Crosshair + dot still render. User moves 1px and card joins them |
| Portfolio Δ exactly 0 at touched date | Treat as positive — show top 2 gainers (defensive) |
| Asset earnings map missing for the touched date | Hide asset rows; keep portfolio + 시장 rows |
| Comparison lines empty (no backtest yet) | Don't render 시장 / 채권 lines; card omits the 시장 row |
| Expected return null | Don't render the 연 기대수익률 line |
| Fewer than 2 asset groups (defensive portfolio) | Render whatever exists (1 row possible) |
| Earnings history fetch fails | Silent — fall back to `MockEarningsData.dailyAssetEarnings`. No error UI |
| User changes range while card is showing | Card dismisses with the touch reset (existing behavior — `setState(() => _touchIndex = null)` on range select) |
| Empty `accountHistory` (cold-start, no account yet) | Existing fallback chain stays: backtest points → `MockEarningsData.dailyCumulativePoints`. The new % conversion runs on whichever non-empty source wins |

## 6. Error handling

- API fetch wrapped in try/catch. On exception or empty response, fall through to mock fallback. Log via `dart:developer` (no `print()`)
- Day-over-day computation guards against missing prior-date entry; returns empty map rather than throwing
- All numeric formatting goes through existing `_formatCurrency` / new `_formatSignedPercent` (sign always rendered, 2 decimal places)

## 7. Testing

Widget tests in [`test/screens/home/home_tab_test.dart`](../../../Front-End/robo_mobile/test/screens/home/home_tab_test.dart):

- Hero chart renders without `'총 입금'` label
- Hero chart renders 4 distinct line strokes (count `Path` paint calls or assert via golden, choice during impl)
- Legend Wrap shows all 4 entries
- Pan to a non-zero index reveals the floating card with the expected portfolio + market values
- Pan to index 0 keeps the card hidden
- All-positive day shows green portfolio + green asset rows (top gainers)
- All-negative day shows red portfolio + red asset rows (top losers)
- API fetch failure path renders the card with mock fallback values

Unit tests:
- `PortfolioState.dayOverDayAssetReturns(date)` returns expected diffs for known fixture earnings history
- `MockEarningsData.dailyAssetEarnings(riskCode)` is deterministic (same input → same output across runs)
- Top-2 selector helper picks the correct 2 by sign

Manual QA on iOS simulator (iPhone 17 Pro):
- Drag the chart at multiple ranges (1주 / 3달 / 1년 / 5년 / 전체)
- Card position flips above/below the dot near chart top
- Card x clamps near both edges
- Range switch cleanly dismisses the card

## 8. Out-of-scope follow-ups

- Bring the comparison chart's gray palette onto the warm-tinted system (`#64748B` → `tc.textSecondary`, `#999999` → `tc.textTertiary`). Quick win, separate PR
- Backend deployment of `/portfolio/earnings-history`. When it lands, the mock-fallback branch is dead code and can be removed
- Optional: add a "tap to dismiss" affordance for the card (currently dismissal happens only via pan-end / pan-cancel)
