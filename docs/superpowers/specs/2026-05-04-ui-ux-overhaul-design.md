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

### 3.4 Efficient Frontier rework (PDF Section I.2.a-b + 2026-05-05 user notes)
**Aspect ratio:** 1:1 → **1:3 horizontal (3:1 width:height)**, with 1:2/1:4 as acceptable fallbacks if 3:1 looks cramped on iPhone Mini-class viewports
**Curve treatment:** **smooth idealized Bezier curve** — not precise data, the curve communicates concept ("정확한 위치보다는 시각적으로 이해 가능한 수준의 배치를 목표로 함")
**Asset positioning bug fix:** currently 인프라 채권 is incorrectly leftmost; **현금성자산 must be leftmost, 신성장주 rightmost**. All 7 asset class labels arranged in fixed defensive→aggressive order along the curve, ignoring raw (vol, return) coords
**Bubble removal:** **drop the bubble size-growth animation and the percentage labels on bubbles**. Fixed-radius bubbles only.
**Below the chart:** **stacked horizontal bar (`AssetWeightBar`)** replacing the percentage list. Bar segments resize live as the user drags. No labels, no % text — segments communicate proportion visually. Order matches `AssetClass` enum (defensive left → aggressive right) so the visual gradient maps to risk.
**Tonal coloring:** asset bubbles + bar segments use 5-tier orange palette
**Keep:** dot-drag, plain-language caption ("이 곡선은…"), page-swipe-disabled-during-drag

**Affected:**
- [`onboarding/widgets/efficient_frontier_chart.dart`](../../../Front-End/robo_mobile/lib/screens/onboarding/widgets/efficient_frontier_chart.dart) (1,108 lines — biggest refactor target)
- New widget: `asset_weight.dart` containing shared `AssetWeight` model + `AssetWeightBar` (frontier) + `AssetWeightList` (portfolio review)
- Add `AssetClass.koLabel` extension in `theme.dart`

### 3.5 포트폴리오 비중 확인 — new merged screen (PDF Section I.2.포트폴리오 비중 확인 + 2026-05-05 user notes)
Replaces the deleted `comparison_screen.dart` + `confirmation_screen.dart`.

**Layout (revised 2026-05-05 to vertical):**
- Top section: **donut on top (~240px diameter, full-size), asset list below (vertical stack)**. Side-by-side donut+list breaks on iPhone Mini-class viewports (375pt wide), so vertical wins.
- Tab section: 포트폴리오 비교 (default) / 변동성 (secondary)
- Time-series chart with 1주 / 3달 / 1년 / 5년 / 전체 selector — **default 3년**
- 변동성 tab: portfolio σ overlaid on market σ (dual-line)
- Pinch-to-zoom + horizontal drag on time-series
- Bottom CTA: 투자 확정 (primary button)

**New file:** `lib/screens/onboarding/portfolio_review_screen.dart` (~400 lines)

**Reused widgets:**
- `donut_chart.dart` — refactored for dynamic `segments` parameter; full-size on portfolio review (compact mode reserved for future home tab)
- `asset_weight.dart::AssetWeightList` — shared model with frontier's bar; this screen uses the list variant
- `portfolio_charts.dart` — extract the comparison-chart widget for reuse

### 3.6 Home tab dashboard rework — **DEFERRED (2026-05-05)**

> **🛑 Deferred from this MVP per user direction.** All notes under the 홈 section in the PDF are out of scope for this overhaul. The home tab keeps its existing structure and inherits only the Phase 1 theme reskin (orange/light surfaces, asset tonal palette).
>
> **Specifically deferred:** 현재 자산 amount removal, 입금 현황 card removal, real-time portfolio simulation graph, 포트폴리오 주요 이슈 알림 timeline, contribution tooltip on tap.
>
> **What ships in this MVP:** existing home tab layout, recolored. The `ContributionAnalysis` data model is added to `PortfolioState` (with the 신성장주 caveat flag) so the deferred rework can pick it up cleanly. The `AlertAnalytics` service is created and emits on alert-frequency change so we collect telemetry from launch.
>
> Re-scope in a follow-up project after MVP launch.

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

**Root-cause display (deferred with the home dashboard rework — model defined in this MVP for forward compat):**
- TOP-2 contribution: 비중 × 수익률 sorted descending
- 2σ-outlier badge: if any asset moved >2× its 60-day rolling σ
- 신성장주 path: if anomaly fires while data validation pending, show "데이터 정합성 검토 중" caveat
- For this MVP, `ContributionAnalysis` model (with `containsNewGrowth` flag) is added to `PortfolioState` but the tooltip widget isn't wired (Phase 4 deferred)

**Existing infrastructure to restyle (no behavior change):**
- [`home/digest_screen.dart`](../../../Front-End/robo_mobile/lib/screens/home/digest_screen.dart)
- [`home/insight_history_page.dart`](../../../Front-End/robo_mobile/lib/screens/home/insight_history_page.dart)
- [`home/insight_detail_page.dart`](../../../Front-End/robo_mobile/lib/screens/home/insight_detail_page.dart)
- [`home/widgets/digest_loading.dart`](../../../Front-End/robo_mobile/lib/screens/home/widgets/digest_loading.dart)
- [`home/widgets/driver_card.dart`](../../../Front-End/robo_mobile/lib/screens/home/widgets/driver_card.dart)

**Bottom-nav badge:** add unread-긴급-alert dot to 홈 tab in `home_shell.dart`.

**신성장주 inclusion (J in scope):** include in alert calculations from launch. Add a "데이터 정합성 검토 중" caveat in the contribution tooltip when the asset triggers an alert. Backend ticket separate.

**Post-launch tuning analytics:** create `AlertAnalytics` service (in `lib/services/alert_analytics.dart`) emitting σ-band / interaction telemetry. In this MVP, wired to `setAlertFrequency` (preference change). Additional emission points (alert shown, opened, dismissed) will be wired when the deferred home dashboard rework lands.

## 4. Migration approach — Option 1 (theme-first sweep)

Proven by the existing token centralization in `theme.dart`. Phases are independently shippable PRs.

| Phase | Scope | Est. effort |
|-------|-------|-------------|
| 1 | Theme tokens + asset palette refactor (atomic flip — entire app recolors) | 1-2 days |
| 2 | Efficient frontier rework (1:3 ratio + smooth idealized curve + asset position fix + bar replaces list + bubble effects removed) | 4-5 days |
| 3 | New 포트폴리오 비중 확인 screen (vertical donut+list) + delete old onboarding screens | 4-5 days |
| 4 | ~~Home tab dashboard rework~~ — **deferred (2026-05-05)** | — |
| 5 | Alert UI (settings selector + nav badge + analytics service + ContributionAnalysis model + restyle digest pages) | 2-3 days |
| 6 | Polish + integration testing + dark-mode verification | 2-3 days |
| | **Total** | **~13-18 days** (fits the 23-day MVP window with healthy buffer) |

Each phase ends with: `flutter analyze` clean, `flutter test` passing, manual verification on iPhone 17 Pro simulator. Phase 4 numbering is preserved in the plan for cross-reference clarity but is fully deferred — execution skips from end-of-Phase-3 to Phase 5.

## 5. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Asset palette change breaks existing chart consumers | Phase 1 ships with `assetTonalPalette` alongside old `chartPalette` initially; second sub-PR removes the alias |
| Onboarding cut breaks frontier-selection state propagation | Verify `OnboardingFrontierSelection` flow into the new `portfolio_review_screen` before deleting old screens |
| Frontier asset position fix breaks existing layout | Replace position computation entirely (defensive→aggressive enum order); raw (vol, return) coords ignored per user note "정확한 위치보다는 시각적으로 이해 가능한 수준" |
| 1:3 aspect cramped on iPhone Mini-class viewports | Spec allows 1:2 / 1:3 / 1:4 range; engineer picks the best fit during Phase 2 Step 3 verification |
| Tier-shared asset colors confuse users | 1px donut gap + asset name in legend; user-test in Phase 6 |
| Light-mode default contradicts the original guideline doc | Documented decision in DESIGN.md decisions log; revisit if user testing surfaces issues |
| Home dashboard deferral leaves alert tooltip incomplete | `ContributionAnalysis` model + `AlertAnalytics` service ship now so the deferred rework can pick up cleanly without rebuilding the data layer |

## 6. Acceptance criteria

- [ ] Every screen reachable from the new flow renders correctly in light + dark mode without sky-blue artifacts
- [ ] `flutter analyze` clean
- [ ] All existing widget tests still pass
- [ ] New flow: splash → welcome → login → frontier → 포트폴리오 비중 확인 → home (no detours through deleted screens)
- [ ] Frontier: **1:3 aspect**, smooth idealized curve, **7 asset bubbles in defensive→aggressive order** (현금성자산 leftmost, 신성장주 rightmost — bug fix verified), **no bubble grow animation, no % labels**, `AssetWeightBar` segments below resize live as dot drags
- [ ] 포트폴리오 비중 확인: **donut on top, asset list below (vertical)**, 비교 tab default, 변동성 tab dual-line, 3년 default range, pinch-zoom works
- [ ] Home tab: theme-reskinned only (full dashboard rework deferred to follow-up project)
- [ ] Settings: 알림 빈도 selector with 자주 / 보통 / 중요할 때만 visible and persistent across app restarts
- [ ] Bottom-nav 홈 tab shows unread-긴급-alert dot when unread 긴급 exists
- [ ] `ContributionAnalysis` model defined in `PortfolioState` with 신성장주 caveat flag (tooltip widget itself deferred)
- [ ] `AlertAnalytics` service present and emits on alert-frequency change
- [ ] No screen exposes raw σ to the user

## 7. References

- DESIGN.md (companion long-lived design system doc)
- PDF Section I.1 — core flow
- PDF Section I.2 — per-screen reworks
- PDF Section I.3 — typography + design concept (Hanwha Life / Hi-Bank reference)
- PDF Section II — alert system spec
