# Home & Portfolio Tab Changes — Implementation Plan

Source spec: `Private & Shared 2/UIUX 수정 및 추가 사항 362f4ea247bb8069ada6c70516a5c432.html`

Five phases, smallest blast radius first. Each phase lands as one or more atomic commits.

---

## File map (likely scope)

- `Front-End/robo_mobile/lib/app/theme.dart` — color token updates
- `Front-End/robo_mobile/lib/screens/home/home_tab.dart` — daily digest replacement, single-screen fit
- `Front-End/robo_mobile/lib/screens/home/portfolio_tab.dart` — 3-tile grid restructure
- `Front-End/robo_mobile/lib/screens/home/widgets/` — new widgets for digest, tiles, sub-screens, notification bar
- `Front-End/robo_mobile/lib/screens/home/home_shell.dart` — global notification bar mount point
- `Front-End/robo_mobile/lib/app/portfolio_state.dart` — daily contributors helper if missing
- Currency formatters — wherever `₩` is rendered (34 occurrences across `lib/`)
- New sub-screens: `portfolio_report_page.dart`, `portfolio_comparison_page.dart`
- `assets/images/asset_icons/` — the 7 asset-class icons from the spec folder
- Tests: matching widget tests for each new component

---

## Phase A: Currency symbol + color tokens

Small, mechanical, low risk. Lands first as a confidence-building base.

### Task A.1: `₩` → `원` everywhere

Display convention: numeric value followed by space then `원`. Example: `+236,857 원 (+2.37%)`.

- [ ] Locate the central currency formatter(s) (likely in a util/format file or inline in widgets).
- [ ] If a centralized formatter exists, update it once. Otherwise update each call site.
- [ ] Verify negative values render as `-12,345 원` (no leading space issue).
- [ ] Verify zero renders as `0 원`.
- [ ] Verify the percent suffix still composes correctly: `+236,857 원 (+2.37%)`.
- [ ] Search the codebase: `grep -rn "₩" Front-End/robo_mobile/lib/` should return 0 after this task.
- [ ] Update any tests that pin the `₩` string.

### Task A.2: Gain/loss color tokens

- [ ] Confirm the gain (red) color in use today and switch to `#FF0200` (`dangerRed` token already exists — promote it or alias `accentGain` to it).
- [ ] Add a new loss-blue token if missing: `#267acf` (call it `accentLoss` or `lossBlue`).
- [ ] Audit gain/loss callers (numbers, indicators) and route them through the new tokens.
- [ ] Snapshot/golden check: a sample positive return renders as `#FF0200`, negative renders as `#267acf`.

**Phase A acceptance:** no `₩` left in source, all gain/loss numbers use the two new tokens, app builds and tests pass.

---

## Phase B: Home tab — daily digest + single-screen fit

### Task B.1: Replace "AI 요약" with daily digest line

Format target (working copy):

> 어제 대비 +0.84% • 강세: 미국성장주, 금

- [ ] Locate the AI summary widget on the home tab.
- [ ] Add a `topContributorsOverDay` helper on `PortfolioState` returning the **top 2** assets by absolute contribution over the prior 1-day window. (`topContributorOver30d` is the existing 30-day analogue.)
- [ ] Compute the day-over-day portfolio return % from the last two earnings-history points.
- [ ] Render: previous-day return (signed, colored) + two contributor labels.
- [ ] Edge cases: missing earnings history → hide the digest line (do not show "no data"); single contributor available → render just one.
- [ ] Widget test: with a fixture portfolio that gained yesterday on 미국성장주 and 금, the digest matches the target string above.

### Task B.2: Home fits one screen, no scroll

- [ ] On iPhone 17 Pro (the dev sim) inspect current home and identify what overflows.
- [ ] Shrink the projection/portfolio graph height so the entire home fits in the viewport.
- [ ] Verify on smaller devices (iPhone SE-class height) the page still fits or scrolls gracefully (no clipped CTAs).

**Phase B acceptance:** home tab on iPhone 17 Pro shows everything without scrolling; the digest line replaces AI 요약 and matches the format above.

---

## Phase C: Global notifications

### Task C.1: Pin notifications across all screens

- [ ] Locate current notification widget (likely on home).
- [ ] Move the bell + badge to a global mount point — top app bar inside `HomeShell` (or an Overlay) so it persists across tab switches.
- [ ] Verify the bell appears on home, portfolio, news, settings tabs.

### Task C.2: Read/unread visual states

- [ ] Notification model — add `bool isRead`.
- [ ] On tap → mark `isRead = true`, persist, refresh badge count.
- [ ] Unread row style: bold + colored background (match KakaoTalk example image).
- [ ] Read row style: normal weight, neutral background.
- [ ] Badge counts only unread.
- [ ] Test: tapping an unread row flips its style and decrements badge count.

**Phase C acceptance:** bell visible on every tab; tapping a notification visibly transitions it from unread to read; badge count reflects unread only.

---

## Phase D: Portfolio tab — 3-tile grid + 비중 strategy message

### Task D.1: New portfolio landing — 3-tile grid

- [ ] Replace `portfolio_tab.dart` root content with a grid of three large tiles: **리포트**, **비중**, **비교**.
- [ ] Above the grid: weekly + daily digest section using the icon + amount + 원 layout.
- [ ] Add asset-class icons under `assets/images/asset_icons/` from the spec folder. Register in `pubspec.yaml`.
- [ ] Tile tap → push a route to the relevant sub-screen (D.2 / E / E).

### Task D.2: 비중 sub-screen = existing portfolio screen + strategy message

- [ ] Move the current portfolio-allocation UI into a `PortfolioWeightsPage`.
- [ ] Add a one-line strategy message at the top. For MVP, hardcode a strategy-aware string keyed off the current portfolio's strategy (or a placeholder string per the spec example).
- [ ] Reachable via the 비중 tile from D.1.

**Phase D acceptance:** tapping the Portfolio nav tab opens the new grid + digest; tapping 비중 lands on the previous portfolio screen with the strategy message at top.

---

## Phase E: Portfolio sub-screens (리포트 + 비교)

### Task E.1: 리포트 sub-screen

- [ ] New `PortfolioReportPage` reachable from the 리포트 tile.
- [ ] Three drill-down sections: 월간 리포트, 주간 리포트, 일간 리포트.
- [ ] Each section: aggregate return, top mover, key event(s) for that timeframe.
- [ ] Match the layout sketch (`f7b095a4-069c-425e-b245-885954934c34.png`).

### Task E.2: 비교 sub-screen

- [ ] New `PortfolioComparisonPage` reachable from the 비교 tile.
- [ ] Render a comparison table: **my portfolio** vs **market** for the MVP metric set:
  - Sharpe ratio (샤프)
  - CAGR
  - Cumulative return (누적 수익률)
  - Max drawdown (MDD)
  - Volatility (변동성)
  - Alpha + Beta
- [ ] Stretch list (defer to follow-up): Sortino, Calmar, Treynor, Information ratio, Omega, VaR/CVaR, downside deviation, correlation, win rate, turnover.
- [ ] Source values from `portfolio_state.dart` / backend where available; placeholder + TODO for not-yet-computed metrics.

**Phase E acceptance:** both sub-screens reachable from the grid; 비교 shows at least the MVP metric set with real numbers.

---

## Task F: Manual QA + final analyze/test pass

- [ ] Full app smoke-test on iPhone 17 Pro simulator.
- [ ] Verify home, portfolio (all 3 sub-screens), notifications across all tabs.
- [ ] `flutter analyze` → zero issues.
- [ ] `flutter test` → pre-existing `portfolio_state_notifications_test` failure still pre-existing (unrelated to scope); no new failures.
- [ ] Commit, merge to main, push (with user confirmation).

---

## Out of scope (separate follow-ups)

- Backend changes needed for any not-yet-computed comparison metrics (file as backlog item, do not block frontend MVP).
- Notification persistence/server sync (read state is local-only for now).
- Localization beyond Korean.
- Tablet/large-screen layouts.
- The full long list of 비교 metrics beyond the MVP six.
- Tutorial overlays or user-help content (separate from the layout work here).
