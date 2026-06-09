# Onboarding Overhaul — Design Spec

**Date:** 2026-06-09
**Status:** Approved (design direction confirmed; building via workflow)
**Source of truth:** Figma "Robo-advisor" frames `Onboarding - Step 1..8` (file `YoysPCATcd1J2fRULgLfMe`) + capstone report §4.1 (분산투자 당위성 구현) and §4.2 (WeRobo 핵심 서비스).
**App:** `Front-End/robo_mobile/` (Flutter, iOS primary).

---

## 1. Goal & scope

Replace the current educational onboarding (`StoryFlowScreen` 7-page `PageView` + `StoryCanvas` CustomPaint with risk gauge / event chips) with a new **7-logical-step** narrative that matches the Figma + report. The Figma has 8 "Onboarding - Step" frames; frames **3 and 4 are two states of one interactive step**, so the logical flow is 7 steps with an `N/7` counter (matching the design's counter).

**In scope:** the 7 educational onboarding steps, their visuals, motion, and the interactive step 3. **Out of scope:** the suitability survey (적합성 설문, §4.3), 기대수익/리스크 설정 (§4.4), backtesting (§4.5), home dashboard (§4.6), and the existing post-login interactive frontier / allocation / review flow (unchanged).

### Locked decisions
- **Fidelity:** match the design, refine in code — faithful layout/copy/colors/components, but adapt spacing/sizing to native Flutter and existing `WeRobo*` theme tokens; visuals drawn with `CustomPaint`, not pasted raster.
- **Exit:** step 7's `투자 시작하기` → `LoginScreen` (unchanged from today's routing).
- **Old code:** replace and remove `StoryFlowScreen` + `StoryCanvas` (+ their tests); audit and remove `risk_gauge.dart` / `page_indicator.dart` only if they become unused.
- **Motion:** polished entrance/transition animations + a real interactive step 3 (tappable asset chips). Light mode is the design target (and app default); build with theme tokens so dark mode stays coherent.

---

## 2. The seven steps

Every step shares chrome (see §3). Korean copy is verbatim from the report; English gloss in parentheses.

| # | Counter | Headline | Caption (gray, centered) | Button | Skip |
|---|---------|----------|--------------------------|--------|------|
| 1 | 1/7 | 시장에는 수많은 자산들이 있습니다. | — | 다음 | yes |
| 2 | 2/7 | 주식 몰빵 투자 정말 괜찮을까요? | 시장이 흔들리는 순간, 내 자산 전체가 함께 무너집니다.\n충격을 나누어 담을 '안전장치'가 없기 때문이죠. | 분산투자하면 어떻게 될까요? | yes |
| 3 | 3/7 | 분산투자만으로\n위험은 크게 줄어듭니다. → (after first asset) 흔들림은 최소로,\n자산은 꾸준히 우상향합니다. | 서로 다른 성격의 자산들에 분산투자 하는 것만으로도\n리스크를 효과적으로 방어하고 안정적인 수익을 낼 수 있습니다. | 자산을 추가해주세요 (disabled) → 계속하기 | yes |
| 4 | 4/7 | 하지만 무엇을, 얼마나, 어떻게\n구성해야 할까요? | 수만 가지의 자산 조합에서\n모든 조합의 수익률과 리스크를 계산하여\n최적의 비율을 찾는 것은 불가능에 가깝습니다. | WeRobo에게 맡겨요! | yes |
| 5 | 5/7 | 가장 완벽한 최적의 조합을\nWeRobo가 찾아냅니다. | 같은 위험이면 더 높은 수익을,\n같은 수익이면 더 낮은 위험인 최적의 조합을 제공합니다. | 다음 | yes |
| 6 | 6/7 | WeRobo는 시장에 대응하여\n알아서 운용전략을 바꿉니다. | 시시각각 변하는 세계 정세를 WeRobo가\n실시간으로 분석하여 최고의 전략으로 포트폴리오를 운용합니다. | 다음 | yes |
| 7 | 7/7 | 최적의 자산 배분에\n최고의 전략으로.\n보다 더 안정적이면서도\n더 높은 수익률을 제공하겠습니다. | — | 투자 시작하기 | **no** |

### Per-step visuals
1. **Asset scatter** — 4 labeled filled dots scattered in the central area: 주식 (red), 금 (yellow), 부동산 (green), 채권 (blue); ~22px circle + small gray label below each. Rough layout: 금 upper-center, 주식 left-mid, 부동산 right-mid, 채권 lower-center. Entrance: dots stagger fade + scale in.
2. **Volatility line** — one red volatile polyline across the central area with large sine-like swings (high amplitude), drawn left→right on entrance.
3. **Diversification (interactive)** — faint horizontal dashed gridlines; a faint dashed-red volatile reference line (the step-2 shape, low opacity); a bold navy portfolio line with small dot markers that starts somewhat wavy and tweens flatter + steadily rising as assets are added. Below: a `자산 추가하기` card with a row of 5 circular chips (colored dot + label): 국내 주식 (red), 미국 주식 (blue), 국채 (green), 금 (yellow), 리츠 (purple). Tapping a chip selects it (colored ring) and "adds" the asset → navy line animates flatter; the first add enables the button and swaps the headline. Counter stays `3/7`.
4. **Optimal-ratio donut** — a thick light-gray ring centered; center text `최적의 비율` (bold). Thin leader lines to `수익률?` (left), `리스크?` (right) and two `?` marks (top-right, bottom-left).
5. **Efficient frontier (display-only)** — Y axis `기대 수익` (높음 top / 낮음 bottom); X axis `위험 (변동성)` (낮음 left / 높음 right, right arrowhead). A cloud of small light-blue scattered dots; a bold navy frontier curve arcing lower-left → upper-right (concave), drawn on entrance, with a right arrowhead; a highlighted navy dot on the upper-mid of the curve with a pill tooltip `추천 포트폴리오`. Illustrative static data only — no API, no drag. May reuse curve math from `widgets/efficient_frontier_chart.dart` but none of its interactivity.
6. **AI management** — central rounded-square `AI` chip (navy/blue, subtle glow/pulse); dotted connector lines (dash-march animation) radiating to 4 small icons: top-left shield/globe, top-right oil barrel, bottom-left world-economy globe, bottom-right rising red chart. Flutter `Icons.*` approximations are acceptable (refine-in-code).
7. **Summary** — no visual; centered multi-line headline with key phrases (최적의 자산 배분, 최고의 전략, 더 높은 수익률) in navy and the rest near-black. No skip; full progress bar.

---

## 3. Shared chrome (the scaffold)

`SafeArea` over the theme surface background. Top to bottom:
- **Counter row:** `N/7` pinned top-right in the gray caption style.
- **Progress bar:** full-width thin (~6px) rounded track (light gray) with a navy fill = `(index+1)/7`, animated on step change.
- **Body:** a `PageView` hosting the active step's visual; the orchestrator drives an entrance `Animation<double>` (0→1) when a page becomes active.
- **Primary button:** full-width navy pill (24px side margins, ~48px tall), label + enabled from per-step state (see contract). Drives `nextPage()`; on the last step it finishes.
- **Skip:** underlined `건너뛰기` directly below the button, hidden on step 7.

Navigation: button-driven `nextPage()`; swipe-back allowed; swipe-forward locked on step 3 until an asset is added (so the gate can't be bypassed).

---

## 4. Architecture (per-step widget + shared scaffold)

```
lib/screens/onboarding/
  onboarding_flow_screen.dart        ← orchestrator (replaces story_flow_screen.dart)
  onboarding_step.dart               ← OnboardingStep config + interface types
  widgets/onboarding_progress_bar.dart
  steps/
    asset_scatter_view.dart          ← step 1
    volatility_line_view.dart        ← step 2
    diversification_view.dart        ← step 3 (interactive; folds Figma frames 3+4)
    optimal_ratio_donut_view.dart    ← step 4
    efficient_frontier_view.dart     ← step 5 (display-only)
    ai_management_view.dart          ← step 6
    summary_view.dart                ← step 7
```

**Delete:** `screens/onboarding/story_flow_screen.dart`, `screens/onboarding/widgets/story_canvas.dart`, and their tests (`test/screens/onboarding/story_flow_screen_test.dart`, any story-canvas helper tests).
**Audit then delete if unused anywhere else:** `widgets/risk_gauge.dart`, `widgets/page_indicator.dart`. **Keep** `donut_chart.dart`, `asset_weight.dart`, `efficient_frontier_chart.dart`, `frontier_selection_resolver.dart` — the post-login flow still uses them.

### Step interface contract (orchestrator ↔ step widget)
The orchestrator owns the chrome (progress, button, skip) and per-step button state. Each step view is a self-contained widget that receives:
- `Animation<double> entrance` — 0→1 when its page becomes active; the step fades/translates its visual in off this.
- For gated steps only (step 3): a `ValueNotifier<bool> readyNotifier` — the step sets `.value = true` when satisfied (first asset added). The orchestrator listens and recomputes the button (step 3: disabled `자산을 추가해주세요` → enabled `계속하기`) and unlocks forward swipe. Step 3 also exposes the headline-swap, which it owns internally (its own state) — the orchestrator only renders the chrome headline if we keep the headline in the scaffold; **decision:** the headline lives in the step body for steps whose headline changes (step 3), and in the scaffold for static steps. To keep it uniform, the **scaffold renders the headline from a `ValueListenable<List<String>>` per step**, defaulting to the static headline; step 3 updates it. (Foundation agent: pick the simplest version of this that compiles cleanly and document the exact signatures.)

`OnboardingStep` config holds: `headlineLines` (default), optional `caption`, default `buttonLabel`, `showSkip`, `interactive` flag, and a `bodyBuilder(context, entrance, readyNotifier)`. The orchestrator builds the ordered list of 7 steps.

**The foundation pass defines and owns the exact signatures, creates compiling stubs for all 7 step widgets (placeholder body), and returns the precise contract** (class names, file paths, constructor signatures, the entrance/readyNotifier mechanics, and the theme tokens to use) so the 7 step implementations conform exactly.

---

## 5. State, routing, persistence
- All onboarding state is **ephemeral and local** (current page, step-3 selected-chip set, animation controllers). **No new global state, no Riverpod, no backend calls.** Step-3 chip selections are illustrative only — nothing persisted or sent.
- On finish (step 7 CTA) or skip: call the existing `markStorySeen()` (keeps the `werobo.story_seen` SharedPreferences flag and the `kDebugMode || !hasSeenStory` debug-replay behavior), then `Navigator` to `LoginScreen` — exactly today's exit (mirror `StoryFlowScreen._exitToLogin`).
- `splash_screen.dart` routes to `OnboardingFlowScreen` instead of `StoryFlowScreen` (same decision point / transition).

---

## 6. Theming
Build to the light Figma using `WeRoboColors` / `WeRoboTypography` / `WeRoboSpacing` / `WeRoboMotion` tokens (no hardcoded hex where a token exists) so dark mode stays coherent. Headlines = bold heading token (navy/near-black); captions = gray body token; primary button = filled navy / disabled gray. Asset/chip colors align to the existing asset palette (주식·국내주식 red, 채권 blue / 미국주식 blue, 금 yellow, 부동산·국채 green, 리츠 purple). Reuse curves/durations from `WeRoboMotion`.

---

## 7. Testing
- `test/screens/onboarding/onboarding_flow_screen_test.dart`: button advances pages + increments counter; skip and final CTA both call `markStorySeen()` and route to `LoginScreen`; step-3 forward-gate (cannot advance until ready).
- `test/screens/onboarding/steps/diversification_view_test.dart`: tapping a chip flips `readyNotifier`/enables the button and swaps the headline.
- Light widget tests per step (renders headline/caption/button; skip hidden on step 7).
- Replaces the deleted `story_flow_screen_test.dart`.
- Gate: `cd Front-End/robo_mobile && flutter analyze` and `flutter test` clean.

---

## 8. Build plan (workflow)
1. **Foundation (1 agent):** create `onboarding_step.dart`, `onboarding_flow_screen.dart` (chrome + PageController + routing + markStorySeen), `widgets/onboarding_progress_bar.dart`, and compiling stubs for the 7 step widgets; rewire `splash_screen.dart`; delete old story files/tests; audit risk_gauge/page_indicator. Return the exact contract.
2. **Steps (7 agents, parallel):** each replaces one stub with the real widget + `CustomPainter` + entrance animation, and writes its widget test, conforming to the foundation contract. Step 3 is interactive. Agents only create/replace their own files; no shared edits; no `flutter` runs.
3. **Integrate + verify (1 agent):** run `flutter analyze` + `flutter test`, fix compile/integration issues across files, re-run until green (or report).
