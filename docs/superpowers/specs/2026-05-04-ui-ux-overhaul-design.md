# UI/UX Overhaul — Design Spec

**Date:** 2026-05-04
**Author:** brainstorming session with Eugene
**Source documents:**
- `/Users/eugenehong/Downloads/design_guidelines_en.md` (capstone design guidelines)
- `/Users/eugenehong/Downloads/0502_캡스톤_자산배분 RA_보고서.pdf` (Week 9 weekly report — UX/UI 수정 + 다이제스트 알림 기준)
- [`Front-End/robo_mobile/DESIGN.md`](../../../Front-End/robo_mobile/DESIGN.md) (updated companion — long-lived design system)

**Ship target:** 2026-05-28 MVP (24 days from spec date)

---

## 1. Goal

Reskin + targeted UX polish of the WeRobo Flutter mobile app. Replace the sky-blue / light-fintech aesthetic with a Neon Carrot orange / flat-monochromatic system per capstone guidelines, and execute the screen-level UX changes prescribed in the PDF (efficient frontier, portfolio detail, home dashboard). Cut the questionnaire-based onboarding. Ship a σ-based digest alert system end-to-end.

This is **Option B** (Reskin + targeted UX polish), not pure reskin (A) or full rethink (C).

## 2. Non-goals

- KIS brokerage integration (already MVP-out per `CLAUDE.md`)
- Backend/data-pipeline rewrite — alert σ math is its own track
- New features beyond the PDF scope (no community-tab redesign, no new comparison flows)
- iOS-only optimization tricks; design must hold on Android too
- Landscape mode

## 3. In-scope changes

### 3.1 Color & theme (Phase 1 — atomic)
- Primary: `#20A7DB` sky blue → **`#FE9337` Neon Carrot**
- Sub palette: 7-color rainbow chart palette → **5-tier monochromatic orange** (`#FE9337` / `#FF9F52` / `#FFAA69` / `#FFB57D` / `#FFC091`)
- **Default theme: dark → light.** Current `theme_state.dart:5` initializes `ThemeMode.dark`; flip to `ThemeMode.light`. Light surfaces use warm `#F4F2F0` background, `#1A1919` warm-black text.
- Dark mode: kept as user-toggleable secondary (warm-tinted dark variants — `#232020` cards on `#1A1919` background)
- Status colors retained (green `#059669`, yellow `#FBBF24`, red `#EF4444`)
- Focus ring orange-tinted at 30% alpha (was sky-blue-tinted)

**Affected files (Phase 1):**
- [`lib/app/theme.dart`](../../../Front-End/robo_mobile/lib/app/theme.dart) — `WeRoboColors`, `WeRoboThemeColors`, `WeRoboTypography` color references
- [`lib/app/theme_state.dart`](../../../Front-End/robo_mobile/lib/app/theme_state.dart) — flip `_mode` default from `ThemeMode.dark` to `ThemeMode.light`
- [`Front-End/robo_mobile/CLAUDE.md`](../../../Front-End/robo_mobile/CLAUDE.md) — design system snippet

### 3.2 Asset class → tonal palette mapping
Risk-ranked C1: defensive = lightest, aggressive = darkest.

| Tier | Hex | Asset class(es) |
|------|-----|-----------------|
| 5 | `#FFC091` | 현금성자산 |
| 4 | `#FFB57D` | 단기채권 |
| 3 | `#FFAA69` | 인프라채권, 금 |
| 2 | `#FF9F52` | 미국가치주 |
| 1 | `#FE9337` | 미국성장주, 신성장주 |

Tier-shared assets disambiguate via 1px donut segment gap and the asset name list. No second hue, no patterns.

**Affected:**
- `WeRoboColors.chartPalette` → `assetTonalPalette` (rename + remap)
- All chart consumers: `donut_chart.dart`, `vestor_pie_chart.dart`, `portfolio_charts.dart`, `efficient_frontier_chart.dart`, `return_bar_chart.dart`, `fan_chart_painter.dart`, `insight_transition_chart.dart`

### 3.3 Onboarding hard-cut (B1)
**Delete:**
- [`onboarding/result_screen.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/result_screen.dart) (397 lines)
- [`onboarding/comparison_screen.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/comparison_screen.dart) (688 lines)
- [`onboarding/confirmation_screen.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/confirmation_screen.dart) (422 lines)

**Simplify:**
- [`onboarding/onboarding_screen.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/onboarding_screen.dart) (906 lines → ~200 lines): keep page-1 (frontier interaction); strip the questionnaire wrapper, target-return picker, tax-bracket inputs, and 2-page `PageView` shell
- [`onboarding/loading_screen.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/loading_screen.dart): keep but verify it still triggers correctly with the simplified flow

**Keep untouched:**
- `splash_screen.dart`, `welcome_screen.dart`, `login_screen.dart`

**New flow:** splash → welcome → login → frontier (single page) → 포트폴리오 비중 확인 (new screen) → home

### 3.4 Efficient Frontier rework (PDF Section I.2.a-b)
**Aspect ratio:** 1:1 → 2:1 horizontal (slope legibility on mobile)
**Curve treatment:** smooth Bezier — replaces raw scatter ("인위적인 곡선 처리")
**Dual-channel data:** graph for "find optimal point" interaction only; **dynamic asset weight list below the graph** is canonical for exact percentages, with animated `AnimatedSwitcher` numeric updates as the user drags
**Tonal coloring:** asset chips/dots use 5-tier palette by character
**Keep:** dot-drag, plain-language caption ("이 곡선은…"), page-swipe-disabled-during-drag

**Affected:**
- [`onboarding/widgets/efficient_frontier_chart.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/widgets/efficient_frontier_chart.dart) (1,108 lines — biggest refactor target)
- New widget: `asset_weight_list.dart` (shared with portfolio detail)

### 3.5 포트폴리오 비중 확인 — new merged screen (PDF Section I.2.포트폴리오 비중 확인)
Replaces the deleted `comparison_screen.dart` + `confirmation_screen.dart`.

**Layout:**
- Top section: donut (left, ~40% width, ~180px diameter) + asset weight list (right, ~60%, scrollable)
- Tab section: 포트폴리오 비교 (default) / 변동성 (secondary)
- Time-series chart with 1주 / 3달 / 1년 / 5년 / 전체 selector — **default 3년**
- 변동성 tab: portfolio σ overlaid on market σ (dual-line)
- Pinch-to-zoom + horizontal drag on time-series
- Bottom CTA: 투자 확정 (primary button)

**New file:** `lib/screens/onboarding/portfolio_review_screen.dart` (~400 lines)

**Reused widgets:**
- `donut_chart.dart` — accepts new `compact: true` mode for left placement
- `asset_weight_list.dart` — shared with frontier
- `portfolio_charts.dart` — extract the comparison-chart widget for reuse

### 3.6 Home tab dashboard rework (PDF Section I.2.홈)
**Remove from [`home_tab.dart`](../../../Front-End/robo_mobile/lib/screens/home/home_tab.dart) (1,818 lines):**
- 현재 자산 amount header (₩-figure block)
- 입금 현황 card (최근 입금 / 예정 입금)
- +입금하기 button
- 정기 입금 button

**Add:**
- **Real-time portfolio simulation graph** at top — shows live 수익률 over time (not static asset balance). Reuse the time-series chart widget from portfolio detail.
- **포트폴리오 주요 이슈 알림 timeline** below graph — vertical feed of news / market warnings / algo signals. Each item: tonal dot (orange = active, gray = info) + timestamp + headline + expandable detail.
- **Contribution tooltip** on graph tap — elevated card showing TOP-2 contributing assets (asset + 비중 × 수익률 = ₩) plus 2σ-outlier badge if applicable.

**Keep:** 포트폴리오 구성 list (with %/₩ toggle), pie sector tap → ETF tickers, plain-language commentary, auto-rebalancing toggle.

**Affected:**
- [`home_tab.dart`](../../../Front-End/robo_mobile/lib/screens/home/home_tab.dart) — major rework
- New widget: `realtime_simulation_graph.dart`
- New widget: `issue_timeline.dart`
- New widget: `contribution_tooltip.dart`

### 3.7 Alert / Digest system (PDF Section II)

**Settings UI (new):**
- Add "알림 빈도" section to [`home/settings_tab.dart`](../../../Front-End/robo_mobile/lib/screens/home/settings_tab.dart)
- 3-segment selector (자주 받기 / 보통 / 중요할 때만), default 보통
- Internal mapping: 1.5σ / 2.0σ / 3.0σ (never displayed)
- Persist via existing `PortfolioState` or backend user-settings endpoint

**Backend trigger spec (informational — backend owns the math):**

| Level | σ trigger | Approx threshold | Cooldown |
|-------|-----------|-----------------|----------|
| 일반 | ±1.5σ | ±0.52% | 3일 |
| 주의 | ±3.0σ | ±1.05% | 1일 |
| 긴급 | ±5.0σ | ±1.75% | none |

Rolling 60-day σ window. Portfolio σ uses correlation matrix.

**Root-cause display (in contribution tooltip on home graph):**
- TOP-2 contribution: 비중 × 수익률 sorted descending
- 2σ-outlier badge: if any asset moved >2× its 60-day rolling σ
- 신성장주 path: if anomaly fires while data validation pending, show "데이터 정합성 검토 중" caveat

**Existing infrastructure to restyle (no behavior change):**
- [`home/digest_screen.dart`](../../../Front-End/robo_mobile/lib/screens/home/digest_screen.dart)
- [`home/insight_history_page.dart`](../../../Front-End/robo_mobile/lib/screens/home/insight_history_page.dart)
- [`home/insight_detail_page.dart`](../../../Front-End/robo_mobile/lib/screens/home/insight_detail_page.dart)
- [`home/widgets/digest_loading.dart`](../../../Front-End/robo_mobile/lib/screens/home/widgets/digest_loading.dart)
- [`home/widgets/driver_card.dart`](../../../Front-End/robo_mobile/lib/screens/home/widgets/driver_card.dart)

**Bottom-nav badge:** add unread-긴급-alert dot to 홈 tab in `home_shell.dart`.

**신성장주 inclusion (J in scope):** include in alert calculations from launch. Add a "데이터 정합성 검토 중" caveat in the contribution tooltip when the asset triggers an alert. Backend ticket separate.

**Post-launch tuning analytics:** record alert event payloads (σ band, opened?, dismissed?, acted-on?) for later threshold tuning. Add an `analytics_event` emit point in the alert handler.

## 4. Migration approach — Option 1 (theme-first sweep)

Proven by the existing token centralization in `theme.dart`. Phases are independently shippable PRs.

| Phase | Scope | Est. effort |
|-------|-------|-------------|
| 1 | Theme tokens + asset palette refactor (atomic flip — entire app recolors) | 1-2 days |
| 2 | Efficient frontier rework (2:1 ratio + smooth curve + asset list) | 3-4 days |
| 3 | New 포트폴리오 비중 확인 screen + delete old onboarding screens | 4-5 days |
| 4 | Home tab dashboard rework (remove banking widgets, add simulation + timeline + tooltip) | 4-5 days |
| 5 | Alert UI (settings selector + tooltip + nav badge + restyle digest pages) | 3-4 days |
| 6 | Polish + integration testing + dark-mode verification | 2-3 days |
| | **Total** | **~17-23 days** (fits 24-day MVP window with thin buffer) |

Each phase ends with: `flutter analyze` clean, `flutter test` passing, manual verification on iPhone 17 Pro simulator.

## 5. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Asset palette change breaks existing chart consumers | Phase 1 ships with `assetTonalPalette` alongside old `chartPalette` initially; second sub-PR removes the alias |
| Onboarding cut breaks frontier-selection state propagation | Verify `OnboardingFrontierSelection` flow into the new `portfolio_review_screen` before deleting old screens |
| Real-time simulation graph performance at 60fps | Pre-compute the simulation series; animate value display only (numbers ticking up, not full chart redraw) |
| 신성장주 alerts firing on bad data | Caveat copy + backend feature flag to suppress 신성장주 triggers if data validation incomplete |
| Tier-shared asset colors confuse users | 1px donut gap + asset name in legend; user-test in Phase 6 |
| Light-mode default contradicts the original guideline doc | Documented decision in DESIGN.md decisions log; revisit if user testing surfaces issues |
| 24-day window too tight if Phase 4 over-scopes | Phase 4 is the most variable — issue timeline can ship as a static skeleton in MVP, with backend feed wired post-launch |

## 6. Acceptance criteria

- [ ] Every screen reachable from the new flow renders correctly in light + dark mode without sky-blue artifacts
- [ ] `flutter analyze` clean
- [ ] All existing widget tests still pass
- [ ] New flow: splash → welcome → login → frontier → 포트폴리오 비중 확인 → home (no detours through deleted screens)
- [ ] Frontier: 2:1 aspect, smooth curve, asset list updates in real-time as dot drags, tonal coloring applied
- [ ] 포트폴리오 비중 확인: donut left + list right, 비교 tab default, 변동성 tab dual-line, 3년 default range, pinch-zoom works
- [ ] Home: no 총 자산 / 입금 현황 / +입금하기 / 정기 입금. Simulation graph at top. Issue timeline below. Tooltip on graph tap shows TOP-2 contribution + outlier badge.
- [ ] Settings: 알림 빈도 selector with 자주/보통/중요할 때만 visible and persistent across app restarts
- [ ] Bottom-nav 홈 tab shows unread-긴급-alert dot when unread 긴급 exists
- [ ] 신성장주 caveat copy renders correctly in tooltip
- [ ] No screen exposes raw σ to the user

## 7. References

- DESIGN.md (companion long-lived design system doc)
- PDF Section I.1 — core flow
- PDF Section I.2 — per-screen reworks
- PDF Section I.3 — typography + design concept (Hanwha Life / Hi-Bank reference)
- PDF Section II — alert system spec
