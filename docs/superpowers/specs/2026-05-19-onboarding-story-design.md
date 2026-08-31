# Onboarding Story Flow — Design Spec

**Date:** 2026-05-19
**Status:** Approved (pending user spec review)
**Owner:** honge6090

## Problem

User testing (5 testers, recorded in Notion "UIUX 수정 및 추가 사항") surfaced a consistent pattern: users do not understand why to use this app or what it does before being asked to interact with an efficient frontier picker. Direct quotes:

- 성OO: "이 앱을 써야 하는 이유를 잘 모르겠다."
- 김OO: "Efficient frontier 그래프가 무엇을 의미하는지 잘 모르겠다."
- 최OO: "설명을 듣지 않고 앱을 써봤을 때 이게 투자앱인지도 잘 모르겠음."

The current onboarding starts at the frontier picker, which assumes the user already understands diversification, the EF curve, and what an "optimal portfolio" is. This spec adds a 7-page story preamble that establishes the value proposition before the existing frontier picker. The existing onboarding screens are not modified.

## Visual reference

Mockups in the Notion page (`UIUX 수정 및 추가 사항`):

- `image.png` — story pages 1–4 (assets exist → diversification reduces risk → optimization is hard)
- `image 2.png` — story pages 5–7 (ALFIN finds the optimum → AI adapts → CTA)
- `image 1.png` — iStock gauge reference for the risk dial concept (semicircle, red→yellow→green; emoji faces are NOT carried over — ALFIN-cohesive only)

## Scope

This spec covers the 7-page story prepended before the existing onboarding flow, plus a reusable `RiskGauge` widget. Home and Portfolio changes from the same Notion page are out of scope and handled by separate specs.

## Architecture

### New files

- `Front-End/robo_mobile/lib/screens/onboarding/story_flow_screen.dart` — host screen
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart` — scroll-driven visual layer
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_gauge.dart` — semicircle gauge widget
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_pages/` — seven small text-only page widgets (`page_1_assets.dart` … `page_7_cta.dart`)

### Modified files

- `Front-End/robo_mobile/lib/app/portfolio_state.dart` — add `bool hasSeenStory` getter + `markStorySeen()` writer, backed by `SharedPreferences` under key `werobo.has_seen_story`.
- `Front-End/robo_mobile/lib/screens/onboarding/splash_screen.dart` — extend routing.

### Routing flow

```
Splash
  ├─ canAutoEnterHome     → HomeShell
  ├─ !hasSeenStory        → StoryFlowScreen
  │                          └─ (complete OR skip) → LoginScreen → existing OnboardingScreen
  └─ else                 → LoginScreen → existing OnboardingScreen
```

Both Skip and the final CTA call `markStorySeen()` and then `Navigator.pushReplacement` to `LoginScreen`. The story is never re-shown on the same device.

Rationale for placement before login: user testing showed the value-prop gap exists pre-signup. Per-device gating via SharedPreferences is sufficient; no backend state needed.

## Pages

All Korean text is taken verbatim from the mockups.

| # | Headline (top) | Canvas state | Description (bottom) |
|---|---|---|---|
| 1 | 시장에는 수많은 자산들이 있습니다. | 4 colored dots scattered (red, blue, yellow, green) at fixed positions | — |
| 2 | 여러 자산에 분산투자 하는 것만으로 투자는 안전해집니다. | RiskGauge needle at 40; below it a single solid red circle | 서로 다른 성격의 자산들에 분산투자 하는 것만으로도 시장의 리스크를 효과적으로 방어하고 안정적인 수익을 낼 수 있습니다. |
| 3 | (same as page 2) | RiskGauge needle drops to 30; circle has split into a 2-slice pie (red + green) | (same as page 2) |
| 4 | 하지만, 무엇을 얼마나 어떻게 구성해야 할까요? | Same pie, with `??` marks orbiting/pulsing | 수만 가지의 자산 조합 속에서 나에게 딱 맞는 최적의 비율을 찾는 것은 불가능에 가깝습니다. |
| 5 | 가장 완벽한 최적의 조합을 ALFIN이 찾아냅니다. | EF curve draws in; same 4 dots reappear along the curve | 같은 위험 대비 가장 높은 수익률을 낼 수 있는 자산 조합을 이은 선. ALFIN의 알고리즘은 당신의 자산 조합을 이 곡선 위 최적의 지점에 안착시킵니다. |
| 6 | 최적의 자산 조합에 더하여, ALFIN은 시장에 대응하여 알아서 전략을 바꿉니다. | 4 event chips fade in: 유가 변동 / 관세 전쟁 / 인플레이션 / 전쟁 | 시시각각 변하는 세계 정세를 AI가 실시간으로 분석하여 최적의 전략으로 당신의 포트폴리오를 운용합니다. |
| 7 | 최적의 자산 배분으로, 최선의 전략으로, 보다 안정적이면서 높은 수익률을 ALFIN이 제공하겠습니다. | Empty canvas (text only) | `[ 투자 시작하기 ]` CTA button, centered |

### Fixed story constants

- **4 illustrative dot colors**: red, blue, yellow, green. Not mapped to the real 7 asset classes — the real palette appears only after login on the existing frontier picker.
- **Risk values**: 40 (page 2), 30 (page 3). Hardcoded; not computed.
- **Page 6 event chips**: 유가 변동 / 관세 전쟁 / 인플레이션 / 전쟁. Static text.
- **Page 5 EF curve**: 4 dots positioned along a hardcoded curve. No backend call.
- **CTA copy**: `투자 시작하기` verbatim.

## Animation system

Text scrolls horizontally with the PageView; visuals live in a separate background layer that interpolates from the page controller's `page` value (0.0 – 6.0). This is what creates the keynote-style continuity — the gauge needle does not duplicate between two pages; it is one element whose value is a function of scroll position.

### `StoryFlowScreen` widget tree

```dart
Scaffold(
  body: Stack(
    children: [
      // Layer 1: visual canvas, driven by pageController.page
      AnimatedBuilder(
        animation: _pageController,
        builder: (_, __) => StoryCanvas(progress: _pageController.page ?? 0.0),
      ),
      // Layer 2: PageView with text-only pages
      PageView(
        controller: _pageController,
        children: const [
          Page1Assets(), Page2Single(), Page3Diversified(),
          Page4Optimize(), Page5Frontier(), Page6Strategy(), Page7Cta(),
        ],
      ),
      // Layer 3: Skip button (top-right) + page-dots indicator (bottom-center)
      Positioned(top: ..., right: ..., child: _SkipButton(onTap: _onSkip)),
      Positioned(bottom: ..., left: 0, right: 0, child: _PageDots(_pageController)),
    ],
  ),
)
```

### `StoryCanvas` internal layout

`StoryCanvas` is itself a Stack — `CustomPaint` background for paint-friendly shapes (dots, pie, EF curve, `??` marks) plus positioned widgets for elements that benefit from being real widgets (`RiskGauge`, event chips, CTA button). Visibility and value of each are pure functions of `progress`.

### Pure interpolation helpers

File-scoped functions in `story_canvas.dart`, trivially unit-testable. Examples:

```dart
double _gaugeOpacity(double p) {
  if (p < 1.5) return 0;
  if (p < 2.0) return (p - 1.5) / 0.5;        // fade in
  if (p < 3.0) return 1.0;
  if (p < 3.5) return 1 - (p - 3.0) / 0.5;    // fade out
  return 0;
}

double _gaugeValue(double p) {
  if (p < 2.0) return 40;
  if (p < 3.0) return 40 - (p - 2.0) * 10;    // ease 40 → 30
  return 30;
}

double _ctaOpacity(double p) {
  if (p < 6.0) return 0;
  if (p < 6.5) return (p - 6.0) / 0.5;
  return 1;
}
```

About a dozen helpers total cover every element: `_dotOpacities`, `_dotPositions`, `_pieRadius`, `_pieGreenAngle`, `_questionMarkOpacity`, `_curveDrawProgress`, `_chipOpacity(index)`, `_ctaOpacity`, plus gauge.

### Painter

`_StoryPainter` extends `CustomPainter`. `shouldRepaint` returns `true` whenever `progress` changes (every frame during scroll, intentional). `paint` dispatches by progress range:

- `< 1.5`: 4 dots with opacities and positions from helpers
- `1.5 – 4.0`: pie/circle as a single `Path` with arc parameters interpolated by `progress`; `??` marks orbit the pie via polar coords on page 4
- `4.0 – 5.5`: dots and EF curve; curve drawn via `Path` + `PathMetric.extractPath(0, length * _curveDrawProgress(p))` (same technique used in [Front-End/robo_mobile/lib/screens/onboarding/widgets/efficient_frontier_chart.dart](Front-End/robo_mobile/lib/screens/onboarding/widgets/efficient_frontier_chart.dart))
- `> 5.5`: painter no-ops; widget-layer chips and CTA take over

### Edge cases

- **Swipe-back**: progress decreases → animation plays in reverse naturally.
- **Mid-page release**: PageView snaps to nearest page, progress smoothly settles, gauge value snaps to 30 or 40.
- **Rapid swipes**: painter keeps up; no AnimationController state to corrupt.
- **CTA tap target**: `IgnorePointer(ignoring: opacity < 0.99)` so the button only accepts taps when fully visible.
- **Portrait lock**: matches existing onboarding behavior.

## `RiskGauge` component

### File

`Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_gauge.dart`

### API

```dart
class RiskGauge extends StatelessWidget {
  final double value;        // 0–100, caller-driven
  final double size;         // outer diameter; height ≈ size/2 + label
  final bool showLabel;      // "리스크 {value.round()}" centered below

  const RiskGauge({
    super.key,
    required this.value,
    this.size = 140,
    this.showLabel = true,
  });
}
```

`value` is plain double; the StoryCanvas lerps it by progress. No internal `AnimationController`.

### Visual

- Outer arc: stroked 180° semicircle, thickness `size * 0.13`
- Three zones (left→right = low→high risk):
  - 0 – 35: green
  - 35 – 65: yellow
  - 65 – 100: red (`#ff0200` — same as the home-spec red)
- Inner pivot: small filled dark-grey circle, `size * 0.08` diameter
- Needle: thin triangle `Path`, pivot at center, rotated `(value / 100) * π - π/2`
- Label: `"리스크 {value.round()}"`, headline-small typography, centered below

The boundary at 35 makes the story land: needle moves from **yellow at 40** (cautious) to **green at 30** (safe), visibly crossing zones.

### Theming

Pulls `#ff0200` for red. Green and yellow from existing `WeRoboColors` tokens if present (`success` / `warning`), otherwise add `gaugeLow` / `gaugeMid` / `gaugeHigh`. Decision deferred to plan phase after reading `theme.dart`.

### Tests

- Unit test for needle-angle formula (0 → -π/2, 100 → +π/2, 50 → 0).
- Golden tests at value = 0, 20, 35, 50, 65, 80, 100.
- Widget test that the label renders "리스크 32" when `value = 32.4`.

## QA flows

Run before merge:

1. **First-launch happy path**: fresh install → splash → story → swipe through 1–7 → CTA → LoginScreen. Story does not re-appear on subsequent launches.
2. **Skip path**: fresh install → tap Skip on each page 1–6 → LoginScreen. `hasSeenStory` persisted.
3. **Returning user**: after step 1 or 2, force-quit and relaunch → splash → LoginScreen.
4. **Auto-enter home**: returning logged-in user with completed portfolio → splash → HomeShell (story does NOT play).
5. **Swipe-back animation**: from page 5, swipe back to page 1 → all animations interpolate in reverse smoothly.
6. **Rapid swipes**: flick 1 → 7 → 1 → 7 rapidly → no broken state, gauge needle settles correctly.
7. **Dark mode**: gauge zones distinguishable; text legible.
8. **Safe areas**: Skip button and page dots respect insets on iPhone 17 Pro and Android.
9. **Portrait lock**: rotate device → stays portrait.

## Out of scope

- Home tab changes (separate spec).
- Portfolio tab changes (separate spec).
- Modifying the existing `OnboardingScreen` (frontier picker). The story prepends; it does not replace.
- Analytics beyond a `logPageEnter` call per page (named-event analytics is a follow-up).
- A/B testing of skip rate, CTA copy, or page order.
- Localization beyond Korean (existing onboarding is already Korean-only).
- Promoting `RiskGauge` to a shared widget directory (lives under `onboarding/widgets/` until another consumer arrives).
- Full a11y audit / VoiceOver labels (basic `Semantics` on Skip + CTA is in scope; deeper a11y is a follow-up).
- Custom haptics on page transitions.

## Open questions (non-blocking)

- Existing golden-test infrastructure availability.
- `SharedPreferences` usage pattern in `PortfolioState` (existing helper vs direct).
- Whether `theme.dart` already exports suitable green/yellow tokens.

All three will be resolved during plan-writing.
