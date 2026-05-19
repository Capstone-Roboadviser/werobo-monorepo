# Onboarding Story Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 7-page scroll-driven story flow before the existing onboarding to establish WeRobo's value proposition (assets exist → diversification → optimal allocation → AI adaptation → start). Shown once per device on first launch, dismissable via Skip.

**Architecture:** A new `StoryFlowScreen` hosts a `PageView` of 7 text-only pages with a fixed-position background layer (`StoryCanvas`) that interpolates visuals (dots, pie, risk gauge, EF curve, event chips, CTA button) as a pure function of `pageController.page`. State persistence uses `SharedPreferences` via a new `hasSeenStory` flag on `PortfolioState` (mirrors the existing `welcomeBannerSeen` pattern at [Front-End/robo_mobile/lib/app/portfolio_state.dart:108](Front-End/robo_mobile/lib/app/portfolio_state.dart:108)). Splash routing extended to send first-launch users to the story before login.

**Tech Stack:** Flutter · `CustomPainter` · `PageController.page` listener · `SharedPreferences` · `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-05-19-onboarding-story-design.md`](../specs/2026-05-19-onboarding-story-design.md)

**Plan amendment:** Spec proposed seven separate files under `story_pages/`. Implementation instead uses a single shared `_StoryPage` widget instantiated 7 times inline in `story_flow_screen.dart`. Same visual outcome, less file churn — each "page" is just `(headline, description)` text data.

---

## File map

**New files:**
- `Front-End/robo_mobile/lib/screens/onboarding/story_flow_screen.dart` — orchestrator: PageView, Skip, page dots, navigation
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart` — visual canvas + interpolation helpers + `_StoryPainter`
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_gauge.dart` — reusable semicircle gauge widget
- `Front-End/robo_mobile/test/app/portfolio_state_story_test.dart` — `hasSeenStory` + `markStorySeen` unit tests
- `Front-End/robo_mobile/test/screens/onboarding/widgets/risk_gauge_test.dart` — gauge widget + needle-angle tests
- `Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_helpers_test.dart` — interpolation helpers
- `Front-End/robo_mobile/test/screens/onboarding/story_flow_screen_test.dart` — end-to-end widget test

**Modified files:**
- `Front-End/robo_mobile/lib/app/portfolio_state.dart` — add `hasSeenStory` getter, `_storySeenKey`, `markStorySeen()`, restore in `restorePersistedState`, wipe in `clearAuthAndPortfolioState`-style methods (keep semantics consistent with `_welcomeBannerSeen`)
- `Front-End/robo_mobile/lib/app/theme.dart` — add `WeRoboColors.dangerRed = Color(0xFFFF0200)` after the existing status colors (line ~31)
- `Front-End/robo_mobile/lib/screens/onboarding/splash_screen.dart` — extend `_scheduleNavigation` to branch on `!hasSeenStory` and route to `StoryFlowScreen`

---

## Task 1: `hasSeenStory` flag on `PortfolioState`

**Files:**
- Modify: `Front-End/robo_mobile/lib/app/portfolio_state.dart`
- Test: `Front-End/robo_mobile/test/app/portfolio_state_story_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `Front-End/robo_mobile/test/app/portfolio_state_story_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PortfolioState.hasSeenStory', () {
    late PortfolioState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = PortfolioState();
    });

    tearDown(() {
      state.dispose();
    });

    test('defaults to false', () {
      expect(state.hasSeenStory, false);
    });

    test('markStorySeen flips it true and notifies', () async {
      var notified = false;
      state.addListener(() => notified = true);
      await state.markStorySeen();
      expect(state.hasSeenStory, true);
      expect(notified, true);
    });

    test('markStorySeen persists to SharedPreferences', () async {
      await state.markStorySeen();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('werobo.story_seen'), true);
    });

    test('restorePersistedState rehydrates from prefs', () async {
      SharedPreferences.setMockInitialValues({'werobo.story_seen': true});
      final fresh = PortfolioState();
      addTearDown(fresh.dispose);
      await fresh.restorePersistedState();
      expect(fresh.hasSeenStory, true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Front-End/robo_mobile && flutter test test/app/portfolio_state_story_test.dart
```

Expected: FAIL with "The getter 'hasSeenStory' isn't defined" (or similar).

- [ ] **Step 3: Add the storage key constant**

In `Front-End/robo_mobile/lib/app/portfolio_state.dart`, add a new key constant beside the existing ones around line 108:

```dart
static const String _storySeenKey = 'werobo.story_seen';
```

Place it directly after:
```dart
static const String _welcomeBannerSeenKey = 'werobo.welcome_banner_seen';
```

- [ ] **Step 4: Add the field**

Near line 130 (next to `bool _welcomeBannerSeen = false;`):

```dart
bool _storySeen = false;
```

- [ ] **Step 5: Add the getter**

Near line 163 (next to `bool get welcomeBannerSeen => _welcomeBannerSeen;`):

```dart
bool get hasSeenStory => _storySeen;
```

- [ ] **Step 6: Restore from prefs**

In `restorePersistedState` (around line 496) add one line right after the `_welcomeBannerSeen` restore:

```dart
_welcomeBannerSeen = prefs.getBool(_welcomeBannerSeenKey) ?? false;
_storySeen = prefs.getBool(_storySeenKey) ?? false;     // <-- new
```

- [ ] **Step 7: Add the marker method**

Below `markWelcomeBannerSeen()` (around line 783):

```dart
Future<void> markStorySeen() async {
  if (_storySeen) return;
  _storySeen = true;
  notifyListeners();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_storySeenKey, true);
}
```

The early return mirrors the `_welcomeBannerSeen` pattern but is slightly stricter (avoid duplicate writes). Acceptable departure — the test 'markStorySeen flips it true and notifies' only checks the first call.

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd Front-End/robo_mobile && flutter test test/app/portfolio_state_story_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 9: Run the full portfolio_state test file to check no regressions**

```bash
cd Front-End/robo_mobile && flutter test test/app/portfolio_state_test.dart
```

Expected: PASS (whatever count was passing before).

- [ ] **Step 10: Commit**

```bash
git add Front-End/robo_mobile/lib/app/portfolio_state.dart \
        Front-End/robo_mobile/test/app/portfolio_state_story_test.dart
git commit -m "feat(onboarding): add hasSeenStory persistent flag"
```

---

## Task 2: Add `dangerRed` color token

**Files:**
- Modify: `Front-End/robo_mobile/lib/app/theme.dart` (~line 31)

- [ ] **Step 1: Add the color constant**

In `Front-End/robo_mobile/lib/app/theme.dart`, locate the status colors block (around line 30):

```dart
  // Status
  static const Color accent = Color(0xFF059669);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
```

Add immediately after `error`:

```dart
  /// Hot red used by the risk gauge's high zone and (later) the home-tab
  /// loss indicator. Sourced from the UIUX-2026-05-19 spec.
  static const Color dangerRed = Color(0xFFFF0200);
```

- [ ] **Step 2: Verify the project still compiles**

```bash
cd Front-End/robo_mobile && flutter analyze lib/app/theme.dart
```

Expected: no analyzer errors.

- [ ] **Step 3: Commit**

```bash
git add Front-End/robo_mobile/lib/app/theme.dart
git commit -m "feat(theme): add dangerRed token for risk gauge"
```

---

## Task 3: `RiskGauge` widget

**Files:**
- Create: `Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_gauge.dart`
- Test: `Front-End/robo_mobile/test/screens/onboarding/widgets/risk_gauge_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `Front-End/robo_mobile/test/screens/onboarding/widgets/risk_gauge_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/screens/onboarding/widgets/risk_gauge.dart';

void main() {
  group('riskGaugeNeedleAngle', () {
    test('0 returns -pi/2 (points left)', () {
      expect(riskGaugeNeedleAngle(0), closeTo(-math.pi / 2, 1e-9));
    });

    test('100 returns +pi/2 (points right)', () {
      expect(riskGaugeNeedleAngle(100), closeTo(math.pi / 2, 1e-9));
    });

    test('50 returns 0 (straight up)', () {
      expect(riskGaugeNeedleAngle(50), closeTo(0, 1e-9));
    });

    test('clamps negative input', () {
      expect(riskGaugeNeedleAngle(-25), closeTo(-math.pi / 2, 1e-9));
    });

    test('clamps over-100 input', () {
      expect(riskGaugeNeedleAngle(150), closeTo(math.pi / 2, 1e-9));
    });
  });

  group('RiskGauge widget', () {
    testWidgets('renders rounded integer label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: RiskGauge(value: 32.4))),
        ),
      );
      expect(find.text('리스크 32'), findsOneWidget);
    });

    testWidgets('omits label when showLabel is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: RiskGauge(value: 50, showLabel: false)),
          ),
        ),
      );
      expect(find.textContaining('리스크'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/risk_gauge_test.dart
```

Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Create the widget**

Create `Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_gauge.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Maps a 0-100 risk value to the needle's rotation angle in radians.
/// Pivot is at the center of the semicircle; -π/2 points left (low risk),
/// +π/2 points right (high risk). Out-of-range inputs are clamped.
double riskGaugeNeedleAngle(double value) {
  final clamped = value.clamp(0.0, 100.0);
  return (clamped / 100) * math.pi - math.pi / 2;
}

/// Semicircle gauge with three colored zones (green/yellow/red) and a
/// rotating needle. Caller-driven `value` (no internal animation) so the
/// story canvas can lerp it from PageView scroll position.
class RiskGauge extends StatelessWidget {
  final double value;
  final double size;
  final bool showLabel;

  const RiskGauge({
    super.key,
    required this.value,
    this.size = 140,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final labelHeight = showLabel ? 28.0 : 0.0;
    return SizedBox(
      width: size,
      height: size / 2 + labelHeight + 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size / 2 + 4,
            child: CustomPaint(
              painter: _RiskGaugePainter(value: value),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 4),
            Text(
              '리스크 ${value.round()}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: WeRoboColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double value;

  _RiskGaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final radius = size.width / 2 - 6;
    final thickness = size.width * 0.13;
    final center = Offset(centerX, size.height - 4);

    // Three arc zones along 180°: green [0,35], yellow [35,65], red [65,100].
    final rect = Rect.fromCircle(center: center, radius: radius);
    void arc(double startFrac, double endFrac, Color color) {
      final startAngle = math.pi + math.pi * startFrac; // pi = left edge
      final sweepAngle = math.pi * (endFrac - startFrac);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    arc(0.0, 0.35, WeRoboColors.accent);   // green
    arc(0.35, 0.65, WeRoboColors.warning); // yellow
    arc(0.65, 1.0, WeRoboColors.dangerRed);

    // Pivot dot
    final pivotPaint = Paint()..color = WeRoboColors.textPrimary;
    canvas.drawCircle(center, size.width * 0.04, pivotPaint);

    // Needle
    final angle = riskGaugeNeedleAngle(value);
    final needleLength = radius - thickness / 2 - 4;
    final needlePaint = Paint()
      ..color = WeRoboColors.textPrimary
      ..style = PaintingStyle.fill;
    final tip = Offset(
      center.dx + needleLength * math.sin(angle),
      center.dy - needleLength * math.cos(angle),
    );
    final baseHalf = size.width * 0.025;
    final basePerp = angle + math.pi / 2;
    final baseA = Offset(
      center.dx + baseHalf * math.sin(basePerp),
      center.dy - baseHalf * math.cos(basePerp),
    );
    final baseB = Offset(
      center.dx - baseHalf * math.sin(basePerp),
      center.dy + baseHalf * math.cos(basePerp),
    );
    final path = Path()
      ..moveTo(baseA.dx, baseA.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(baseB.dx, baseB.dy)
      ..close();
    canvas.drawPath(path, needlePaint);
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) =>
      oldDelegate.value != value;
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/risk_gauge_test.dart
```

Expected: PASS (7 tests).

- [ ] **Step 5: Visual sanity check via existing app**

The widget isn't wired into anything yet; skip manual visual check until Task 5 puts it on the canvas. Move on.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_gauge.dart \
        Front-End/robo_mobile/test/screens/onboarding/widgets/risk_gauge_test.dart
git commit -m "feat(onboarding): add RiskGauge widget"
```

---

## Task 4: Story canvas interpolation helpers

These are the pure functions that map `progress` (0.0 – 6.0) to opacities, sizes, and positions for every story element. Build them first; the painter and canvas widget consume them in Task 5.

**Important timing convention:** `PageController.page` value of `N` means the user is fully on page index `N` (spec page `N+1`). So:
- spec page 1 (intro dots) ↔ progress 0.0
- spec page 2 (single asset, gauge 40) ↔ progress 1.0
- spec page 3 (diversified, gauge 30) ↔ progress 2.0
- spec page 4 (??) ↔ progress 3.0
- spec page 5 (EF curve) ↔ progress 4.0
- spec page 6 (events) ↔ progress 5.0
- spec page 7 (CTA) ↔ progress 6.0

Every element is fully visible at its primary integer progress.

**Files:**
- Create: `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart` (helpers only at this stage)
- Test: `Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_helpers_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_helpers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/screens/onboarding/widgets/story_canvas.dart';

void main() {
  group('storyGaugeOpacity', () {
    test('0 before fade-in window', () {
      expect(storyGaugeOpacity(0), 0);
      expect(storyGaugeOpacity(0.7), 0);
    });

    test('eases 0 → 1 across [0.7, 1.0]', () {
      expect(storyGaugeOpacity(0.85), closeTo(0.5, 1e-9));
      expect(storyGaugeOpacity(1.0), closeTo(1.0, 1e-9));
    });

    test('full opacity across pages 2-3', () {
      expect(storyGaugeOpacity(1.0), 1.0);
      expect(storyGaugeOpacity(2.0), 1.0);
    });

    test('eases 1 → 0 across [2.0, 2.5]', () {
      expect(storyGaugeOpacity(2.25), closeTo(0.5, 1e-9));
      expect(storyGaugeOpacity(2.5), closeTo(0, 1e-9));
    });

    test('0 after fade-out', () {
      expect(storyGaugeOpacity(3.0), 0);
      expect(storyGaugeOpacity(6.0), 0);
    });
  });

  group('storyGaugeValue', () {
    test('40 on page 2 (progress 1.0)', () {
      expect(storyGaugeValue(1.0), 40);
      expect(storyGaugeValue(0.5), 40);
    });

    test('eases 40 → 30 across [1.0, 2.0]', () {
      expect(storyGaugeValue(1.5), closeTo(35, 1e-9));
      expect(storyGaugeValue(2.0), 30);
    });

    test('30 after page 3', () {
      expect(storyGaugeValue(3.0), 30);
    });
  });

  group('storyCtaOpacity', () {
    test('0 before fade-in', () {
      expect(storyCtaOpacity(5.6), 0);
    });

    test('fades in across [5.7, 6.0]', () {
      expect(storyCtaOpacity(5.7), 0);
      expect(storyCtaOpacity(5.85), closeTo(0.5, 1e-9));
      expect(storyCtaOpacity(6.0), 1.0);
    });

    test('full opacity at and past page 7', () {
      expect(storyCtaOpacity(6.0), 1.0);
      expect(storyCtaOpacity(7.0), 1.0);
    });
  });

  group('storyCurveDrawProgress', () {
    test('0 before page 5 fade-in', () {
      expect(storyCurveDrawProgress(3.4), 0);
    });

    test('draws 0 → 1 across [3.5, 4.0]', () {
      expect(storyCurveDrawProgress(3.5), 0);
      expect(storyCurveDrawProgress(3.75), closeTo(0.5, 1e-9));
      expect(storyCurveDrawProgress(4.0), 1.0);
    });

    test('1 across [4.0, 4.5]', () {
      expect(storyCurveDrawProgress(4.25), 1.0);
    });

    test('fades back to 0 across [4.5, 5.0]', () {
      expect(storyCurveDrawProgress(4.75), closeTo(0.5, 1e-9));
      expect(storyCurveDrawProgress(5.0), 0);
    });
  });

  group('storyDotOpacity', () {
    test('all 4 dots visible at page 1 (progress 0)', () {
      for (var i = 0; i < 4; i++) {
        expect(storyDotOpacity(i, 0), 1.0);
      }
    });

    test('red dot (index 0) fades out across [0.7, 1.0] as the circle takes over', () {
      expect(storyDotOpacity(0, 0.7), 1.0);
      expect(storyDotOpacity(0, 0.85), closeTo(0.5, 1e-9));
      expect(storyDotOpacity(0, 1.0), 0);
    });

    test('dots 1-3 fade out across [0.3, 0.8]', () {
      expect(storyDotOpacity(1, 0.3), 1.0);
      expect(storyDotOpacity(1, 0.55), closeTo(0.5, 1e-9));
      expect(storyDotOpacity(1, 0.8), 0);
      expect(storyDotOpacity(3, 0.8), 0);
    });

    test('all 4 dots reappear at page 5 (progress 4)', () {
      for (var i = 0; i < 4; i++) {
        expect(storyDotOpacity(i, 4.0), 1.0);
      }
    });

    test('dots fade out across [4.7, 5.0]', () {
      expect(storyDotOpacity(0, 4.85), closeTo(0.5, 1e-9));
      expect(storyDotOpacity(0, 5.0), 0);
    });
  });

  group('storyChipOpacity', () {
    test('0 before stagger window starts', () {
      expect(storyChipOpacity(0, 4.4), 0);
      expect(storyChipOpacity(3, 4.4), 0);
    });

    test('staggered fade-in: chip 0 leads, chip 3 has not yet started at 4.6', () {
      expect(storyChipOpacity(0, 4.6), closeTo(0.5, 1e-9));
      expect(storyChipOpacity(3, 4.6), 0);
    });

    test('all chips fully visible at page 6 (progress 5.0)', () {
      for (var i = 0; i < 4; i++) {
        expect(storyChipOpacity(i, 5.0), 1.0);
      }
    });

    test('fades out across [5.5, 6.0]', () {
      expect(storyChipOpacity(0, 5.75), closeTo(0.5, 1e-9));
      expect(storyChipOpacity(0, 6.0), 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/story_canvas_helpers_test.dart
```

Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Create the story canvas file with helpers**

Create `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'risk_gauge.dart';

// ============================================================================
// Interpolation helpers — pure functions of `progress` (PageController.page).
// progress ∈ [0.0, 6.0]; integer values land exactly on a page.
// Exported (no underscore) so the helper tests can reach them.
// ============================================================================

double _lerpClamped(double a, double b, double t) =>
    lerpDouble(a, b, t.clamp(0.0, 1.0))!;

double storyGaugeOpacity(double p) {
  // Visible across spec pages 2-3 (progress 1.0–2.0). Fades in 0.7→1.0,
  // out 2.0→2.5.
  if (p < 0.7) return 0;
  if (p < 1.0) return (p - 0.7) / 0.3;
  if (p < 2.0) return 1.0;
  if (p < 2.5) return 1 - (p - 2.0) / 0.5;
  return 0;
}

double storyGaugeValue(double p) {
  // 40 on spec page 2 (progress 1.0), eases to 30 on spec page 3 (2.0).
  if (p < 1.0) return 40;
  if (p < 2.0) return 40 - (p - 1.0) * 10;
  return 30;
}

double storyCtaOpacity(double p) {
  // Fades in across [5.7, 6.0] so the CTA is fully visible AT spec page 7
  // (progress 6.0). The event chips on page 6 are already fading out by 5.7,
  // so there is no overlap conflict.
  if (p < 5.7) return 0;
  if (p < 6.0) return (p - 5.7) / 0.3;
  return 1.0;
}

/// 0 → 1 across [3.5, 4.0] (curve draws as user enters page 5);
/// stays at 1 through 4.5; fades back to 0 across [4.5, 5.0]
/// as the frontier scene exits toward page 6.
double storyCurveDrawProgress(double p) {
  if (p < 3.5) return 0;
  if (p < 4.0) return (p - 3.5) / 0.5;
  if (p < 4.5) return 1.0;
  if (p < 5.0) return 1 - (p - 4.5) / 0.5;
  return 0;
}

/// Opacity for each of the 4 story dots.
/// - All 4 visible on spec page 1 (progress 0).
/// - Dot 0 (red) is the "lead" — it scales into the page-2 circle so its
///   own dot opacity drops to 0 across [0.7, 1.0] (the circle takes over).
/// - Dots 1-3 fade out across [0.3, 0.8].
/// - All 4 reappear on spec page 5 (frontier scene) across [3.7, 4.0]
///   at on-curve positions, then fade out across [4.7, 5.0].
double storyDotOpacity(int index, double p) {
  // Frontier scene visibility window (spec page 5, progress 4.0)
  if (p >= 3.7 && p <= 5.0) {
    if (p < 4.0) return (p - 3.7) / 0.3;
    if (p < 4.7) return 1.0;
    return 1 - (p - 4.7) / 0.3;
  }

  // Intro scene (spec page 1, progress 0)
  if (index == 0) {
    if (p < 0.7) return 1.0;
    if (p < 1.0) return 1 - (p - 0.7) / 0.3;
    return 0;
  }
  if (p < 0.3) return 1.0;
  if (p < 0.8) return 1 - (p - 0.3) / 0.5;
  return 0;
}

/// Staggered fade-in (chip 0 leads, chip 3 trails by 0.05 progress units).
/// All chips fully visible by progress 4.85, well before spec page 6
/// (progress 5.0). Fades out across [5.5, 6.0] as the user moves to page 7.
double storyChipOpacity(int index, double p) {
  final start = 4.5 + index * 0.05;
  final end = start + 0.2;
  if (p < start) return 0;
  if (p < end) return (p - start) / (end - start);
  if (p < 5.5) return 1.0;
  if (p < 6.0) return 1 - (p - 5.5) / 0.5;
  return 0;
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/story_canvas_helpers_test.dart
```

Expected: PASS (all tests).

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart \
        Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_helpers_test.dart
git commit -m "feat(onboarding): add story canvas interpolation helpers"
```

---

## Task 5: `StoryCanvas` widget + `_StoryPainter`

Build the visual layer that consumes the helpers from Task 4 and the `RiskGauge` from Task 3.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart` (append the widget + painter)
- Test: extend `Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_helpers_test.dart` with a widget test, or create `story_canvas_widget_test.dart` (preferred for clarity)

- [ ] **Step 1: Write the failing widget tests**

Create `Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/screens/onboarding/widgets/risk_gauge.dart';
import 'package:robo_mobile/screens/onboarding/widgets/story_canvas.dart';

void main() {
  group('StoryCanvas', () {
    Future<void> pump(WidgetTester tester, double progress) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StoryCanvas(progress: progress)),
        ),
      );
    }

    testWidgets('gauge invisible on page 1 (progress 0)', (tester) async {
      await pump(tester, 0.0);
      final gauge = tester.widget<Opacity>(
        find.ancestor(of: find.byType(RiskGauge), matching: find.byType(Opacity)).first,
      );
      expect(gauge.opacity, 0);
    });

    testWidgets('gauge fully visible on page 2 (progress 1.0)', (tester) async {
      await pump(tester, 1.0);
      final gauge = tester.widget<Opacity>(
        find.ancestor(of: find.byType(RiskGauge), matching: find.byType(Opacity)).first,
      );
      expect(gauge.opacity, 1.0);
    });

    testWidgets('gauge value drops 40 → 30 across pages 2-3', (tester) async {
      await pump(tester, 1.0);
      expect(find.text('리스크 40'), findsOneWidget);
      await pump(tester, 2.0);
      expect(find.text('리스크 30'), findsOneWidget);
    });

    testWidgets('CTA button visible on page 7 (progress 6.0)', (tester) async {
      await pump(tester, 6.0);
      expect(find.text('투자 시작하기'), findsOneWidget);
    });

    testWidgets('event chips visible on page 6 (progress 5.0)', (tester) async {
      await pump(tester, 5.0);
      expect(find.text('유가 변동'), findsOneWidget);
      expect(find.text('관세 전쟁'), findsOneWidget);
      expect(find.text('인플레이션'), findsOneWidget);
      expect(find.text('전쟁'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/story_canvas_widget_test.dart
```

Expected: FAIL with "StoryCanvas isn't defined" or similar.

- [ ] **Step 3: Append the `StoryCanvas` widget and painter**

Append to `Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart`:

```dart

// ============================================================================
// StoryCanvas — visual layer for the onboarding story.
// `progress` is `PageController.page ?? 0.0` from the host screen.
// ============================================================================

/// Story scene constants. Page-relative positions are unitless fractions
/// of the canvas; the painter scales them to actual pixels.
const _kDotColors = [
  Color(0xFFFF4141), // red
  Color(0xFF5568E3), // blue
  Color(0xFFE6CC0B), // yellow
  Color(0xFF85C410), // green
];

const _kEventLabels = ['유가 변동', '관세 전쟁', '인플레이션', '전쟁'];

class StoryCanvas extends StatelessWidget {
  final double progress;
  final VoidCallback? onStartPressed;

  const StoryCanvas({
    super.key,
    required this.progress,
    this.onStartPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final centerY = size.height * 0.45;
        final ctaY = size.height * 0.62;

        return Stack(
          children: [
            // Paint layer: dots, pie/circle, ?? marks, EF curve
            Positioned.fill(
              child: CustomPaint(painter: _StoryPainter(progress: progress)),
            ),

            // Gauge widget layer (pages 2-3)
            Positioned(
              left: 0,
              right: 0,
              top: centerY - 110,
              child: Opacity(
                opacity: storyGaugeOpacity(progress),
                child: Center(
                  child: RiskGauge(
                    value: storyGaugeValue(progress),
                    size: 140,
                  ),
                ),
              ),
            ),

            // Event chips (page 6) — 2x2 grid
            ..._buildEventChips(centerY, size.width),

            // CTA button (page 7)
            Positioned(
              left: 0,
              right: 0,
              top: ctaY,
              child: IgnorePointer(
                ignoring: storyCtaOpacity(progress) < 0.99,
                child: Opacity(
                  opacity: storyCtaOpacity(progress),
                  child: Center(
                    child: _StartButton(onPressed: onStartPressed),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildEventChips(double centerY, double width) {
    return List.generate(_kEventLabels.length, (i) {
      final col = i % 2;
      final row = i ~/ 2;
      final x = col == 0 ? width * 0.18 : width * 0.55;
      final y = centerY - 30 + row * 50.0;
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: storyChipOpacity(i, progress),
          child: Text(
            _kEventLabels[i],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WeRoboColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _StartButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WeRoboColors.primaryLight,
        foregroundColor: WeRoboColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
      ),
      child: const Text(
        '투자 시작하기',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// _StoryPainter — draws dots, pie/circle, ?? marks, EF curve.
// Repaints on every progress change (every PageView scroll frame).
// ============================================================================

class _StoryPainter extends CustomPainter {
  final double progress;

  _StoryPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    _paintDots(canvas, size);
    _paintCircleOrPie(canvas, size);
    _paintQuestionMarks(canvas, size);
    _paintFrontierCurve(canvas, size);
  }

  void _paintDots(Canvas canvas, Size size) {
    // Page 1 layout: scattered positions (fractions of canvas).
    // Page 5 layout: positions along the frontier curve.
    const scattered = [
      Offset(0.62, 0.32), // red
      Offset(0.25, 0.42), // blue
      Offset(0.38, 0.40), // yellow
      Offset(0.50, 0.38), // green
    ];
    const onCurve = [
      Offset(0.78, 0.34), // red — top-right
      Offset(0.22, 0.55), // blue — lower-left
      Offset(0.55, 0.43), // yellow — middle
      Offset(0.40, 0.48), // green — left-middle
    ];

    for (var i = 0; i < 4; i++) {
      final op = storyDotOpacity(i, progress);
      if (op <= 0) continue;

      // Pick scattered vs on-curve based on progress range.
      // On-curve positions kick in once the frontier scene starts fading in.
      final pos = progress >= 3.7 ? onCurve[i] : scattered[i];
      final paint = Paint()
        ..color = _kDotColors[i].withValues(alpha: op)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(pos.dx * size.width, pos.dy * size.height),
        12,
        paint,
      );
    }
  }

  void _paintCircleOrPie(Canvas canvas, Size size) {
    // Visible across spec pages 2-4 (progress 1.0-3.0). Fades in 0.7-1.0,
    // fades out 3.0-3.5.
    if (progress < 0.7 || progress > 3.5) return;

    final center = Offset(size.width / 2, size.height * 0.45 + 30);
    // Radius grows 0 → 60 across [0.7, 1.0]; steady thereafter.
    final radius = progress < 1.0
        ? _lerpClamped(0, 60, (progress - 0.7) / 0.3)
        : 60.0;

    // Green-slice angle grows across [1.0, 2.0] (page 2 → page 3).
    final greenSweep = progress < 1.0
        ? 0.0
        : progress < 2.0
            ? _lerpClamped(0, math.pi * 2 * 0.32, progress - 1.0)
            : math.pi * 2 * 0.32;

    // Overall alpha: fades out as we leave spec page 4 (progress 3.0 → 3.5).
    final alpha = progress < 3.0 ? 1.0 : 1 - (progress - 3.0) / 0.5;
    final clampedAlpha = alpha.clamp(0.0, 1.0);

    final redPaint = Paint()
      ..color = const Color(0xFFFF4141).withValues(alpha: clampedAlpha);
    final greenPaint = Paint()
      ..color = const Color(0xFF85C410).withValues(alpha: clampedAlpha);

    // Red full disc, then green wedge over it.
    canvas.drawCircle(center, radius, redPaint);
    if (greenSweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        greenSweep,
        true,
        greenPaint,
      );
    }
  }

  void _paintQuestionMarks(Canvas canvas, Size size) {
    // Visible on spec page 4 (progress 3.0). Fades in 2.5-3.0, out 3.0-3.5.
    if (progress < 2.5 || progress > 3.5) return;

    final fade = progress < 3.0
        ? (progress - 2.5) / 0.5
        : 1 - (progress - 3.0) / 0.5;
    final alpha = fade.clamp(0.0, 1.0);
    if (alpha <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.45 + 30);
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < 2; i++) {
      final angle = -math.pi / 4 + i * (math.pi / 2);
      final pos = Offset(
        center.dx + 90 * math.sin(angle),
        center.dy - 90 * math.cos(angle),
      );
      tp.text = TextSpan(
        text: '??',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: WeRoboColors.textPrimary.withValues(alpha: alpha),
        ),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintFrontierCurve(Canvas canvas, Size size) {
    final drawT = storyCurveDrawProgress(progress);
    if (drawT <= 0) return;

    // The curve fades out as we leave spec page 5 (progress 4.0) toward
    // spec page 6 (progress 5.0).
    final overallAlpha = (progress < 4.5
            ? 1.0
            : 1 - (progress - 4.5) / 0.5)
        .clamp(0.0, 1.0);

    // Hardcoded illustrative EF curve: cubic bezier sweeping from
    // lower-left to upper-right.
    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.60)
      ..cubicTo(
        size.width * 0.30, size.height * 0.55,
        size.width * 0.55, size.height * 0.32,
        size.width * 0.85, size.height * 0.30,
      );

    // Truncate to drawT fraction using PathMetric.
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * drawT);

    final paint = Paint()
      ..color = WeRoboColors.textPrimary.withValues(alpha: overallAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(covariant _StoryPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
```

- [ ] **Step 4: Run widget tests**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/story_canvas_widget_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run analyzer to catch typos / unused imports**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/onboarding/widgets/story_canvas.dart
```

Expected: no warnings/errors.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/widgets/story_canvas.dart \
        Front-End/robo_mobile/test/screens/onboarding/widgets/story_canvas_widget_test.dart
git commit -m "feat(onboarding): add StoryCanvas widget + painter"
```

---

## Task 6: `StoryFlowScreen` orchestrator

PageView with text pages, Skip button, page dots indicator. Wires up navigation back to `LoginScreen`.

**Files:**
- Create: `Front-End/robo_mobile/lib/screens/onboarding/story_flow_screen.dart`
- Test: `Front-End/robo_mobile/test/screens/onboarding/story_flow_screen_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `Front-End/robo_mobile/test/screens/onboarding/story_flow_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/login_screen.dart';
import 'package:robo_mobile/screens/onboarding/story_flow_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // PortfolioStateProvider must sit ABOVE MaterialApp so that pushed routes
  // (LoginScreen accesses PortfolioStateProvider in build) can find it.
  Future<PortfolioState> pumpStoryFlow(WidgetTester tester) async {
    final state = PortfolioState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      PortfolioStateProvider(
        state: state,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: const StoryFlowScreen(),
        ),
      ),
    );
    await tester.pump();
    return state;
  }

  testWidgets('renders the first page headline', (tester) async {
    await pumpStoryFlow(tester);
    expect(find.text('시장에는 수많은 자산들이 있습니다.'), findsOneWidget);
  });

  testWidgets('Skip button is visible', (tester) async {
    await pumpStoryFlow(tester);
    expect(find.text('건너뛰기'), findsOneWidget);
  });

  testWidgets('Skip marks story seen and navigates to LoginScreen',
      (tester) async {
    final state = await pumpStoryFlow(tester);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(state.hasSeenStory, true);
  });

  testWidgets('shows 7 page dots', (tester) async {
    await pumpStoryFlow(tester);
    // Page dots are simple Container widgets in a Row; first and last
    // are sufficient to confirm the dot row spans all 7 pages.
    expect(find.byKey(const ValueKey('story_page_dot_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('story_page_dot_6')), findsOneWidget);
  });

  testWidgets('CTA on page 7 also marks story seen and navigates',
      (tester) async {
    final state = await pumpStoryFlow(tester);

    // Jump the PageView directly to page index 6 (spec page 7, CTA page).
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(6);
    await tester.pumpAndSettle();

    // At progress 6.0, storyCtaOpacity == 1.0, so IgnorePointer is off
    // and the button is tappable.
    await tester.tap(find.text('투자 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(state.hasSeenStory, true);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/story_flow_screen_test.dart
```

Expected: FAIL with "StoryFlowScreen isn't defined".

- [ ] **Step 3: Create the screen**

Create `Front-End/robo_mobile/lib/screens/onboarding/story_flow_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import 'login_screen.dart';
import 'widgets/story_canvas.dart';

class StoryFlowScreen extends StatefulWidget {
  const StoryFlowScreen({super.key});

  @override
  State<StoryFlowScreen> createState() => _StoryFlowScreenState();
}

class _StoryFlowScreenState extends State<StoryFlowScreen> {
  final _pageController = PageController();

  static const _pages = <_StoryPageData>[
    _StoryPageData(
      headline: '시장에는 수많은 자산들이 있습니다.',
      description: null,
    ),
    _StoryPageData(
      headline: '여러 자산에 분산투자 하는 것만으로\n투자는 안전해집니다.',
      description:
          '서로 다른 성격의 자산들에\n분산투자 하는 것만으로도\n시장의 리스크를 효과적으로 방어하고\n안정적인 수익을 낼 수 있습니다.',
    ),
    _StoryPageData(
      headline: '여러 자산에 분산투자 하는 것만으로\n투자는 안전해집니다.',
      description:
          '서로 다른 성격의 자산들에\n분산투자 하는 것만으로도\n시장의 리스크를 효과적으로 방어하고\n안정적인 수익을 낼 수 있습니다.',
    ),
    _StoryPageData(
      headline: '하지만, 무엇을 얼마나 어떻게\n구성해야 할까요?',
      description:
          '수만 가지의 자산 조합 속에서\n나에게 딱 맞는 최적의 비율을 찾는 것은\n불가능에 가깝습니다.',
    ),
    _StoryPageData(
      headline: '가장 완벽한 최적의 조합을\nWeRobo가 찾아냅니다.',
      description:
          '같은 위험 대비 가장 높은 수익률을 낼 수 있는\n자산 조합을 이은 선.\nWeRobo의 알고리즘은 당신의 자산 조합을\n이 곡선 위 최적의 지점에 안착시킵니다.',
    ),
    _StoryPageData(
      headline:
          '최적의 자산 조합에 더하여,\nWeRobo는 시장에 대응하여\n알아서 전략을 바꿉니다.',
      description:
          '시시각각 변하는 세계 정세를 AI가\n실시간으로 분석하여 최적의 전략으로\n당신의 포트폴리오를 운용합니다.',
    ),
    _StoryPageData(
      headline:
          '최적의 자산 배분으로, 최선의 전략으로,\n보다 안정적이면서 높은 수익률을\nWeRobo가 제공하겠습니다.',
      description: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    logPageEnter('StoryFlowScreen');
  }

  @override
  void dispose() {
    logPageExit('StoryFlowScreen');
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _exitToLogin() async {
    final state = PortfolioStateProvider.of(context);
    final navigator = Navigator.of(context);
    await state.markStorySeen();
    if (!mounted) return;
    navigator.pushReplacement(WeRoboMotion.fadeRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Background visual canvas, driven by pageController.page
            AnimatedBuilder(
              animation: _pageController,
              builder: (_, __) => StoryCanvas(
                progress: _pageController.hasClients
                    ? (_pageController.page ?? 0.0)
                    : 0.0,
                onStartPressed: _exitToLogin,
              ),
            ),
            // PageView with text-only pages
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              itemBuilder: (_, i) => _StoryPage(data: _pages[i]),
            ),
            // Skip button (top-right)
            Positioned(
              top: 12,
              right: 16,
              child: TextButton(
                onPressed: _exitToLogin,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(
                    color: WeRoboColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // Page dots (bottom)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (_, __) {
                  final current = _pageController.hasClients
                      ? (_pageController.page ?? 0.0).round()
                      : 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == current;
                      return Container(
                        key: ValueKey('story_page_dot_$i'),
                        width: active ? 22 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? WeRoboColors.primary
                              : WeRoboColors.lightGray,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPageData {
  final String headline;
  final String? description;
  const _StoryPageData({required this.headline, this.description});
}

class _StoryPage extends StatelessWidget {
  final _StoryPageData data;
  const _StoryPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          Text(
            data.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: WeRoboColors.primary,
              height: 1.4,
            ),
          ),
          const Spacer(),
          if (data.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Text(
                data.description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: WeRoboColors.primary,
                  height: 1.5,
                ),
              ),
            )
          else
            const SizedBox(height: 80),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/story_flow_screen_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Run analyzer**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/onboarding/story_flow_screen.dart
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/story_flow_screen.dart \
        Front-End/robo_mobile/test/screens/onboarding/story_flow_screen_test.dart
git commit -m "feat(onboarding): add StoryFlowScreen with PageView + Skip + page dots"
```

---

## Task 7: Splash routing — route through story on first launch

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/onboarding/splash_screen.dart` (~lines 60-95)
- Test: optional — keep test-only at the unit level since splash uses a real Timer; tested manually in Task 8

- [ ] **Step 1: Add the import**

In `Front-End/robo_mobile/lib/screens/onboarding/splash_screen.dart`, add the import beside `login_screen.dart`:

```dart
import 'story_flow_screen.dart';
```

- [ ] **Step 2: Replace the destination logic**

Locate (around line 76):

```dart
    _navigationTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) {
        return;
      }
      final destination =
          state.canAutoEnterHome ? const HomeShell() : const LoginScreen();
      logAction('route from splash', {
        'target': state.canAutoEnterHome ? 'home' : 'login',
        'loggedIn': state.isLoggedIn,
        'hasPortfolio': state.hasCompletedPortfolioSetup,
      });
      Navigator.of(context).pushReplacement(
        WeRoboMotion.fadeRoute(destination),
      );
    });
```

Replace with:

```dart
    _navigationTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) {
        return;
      }
      final Widget destination;
      final String target;
      if (state.canAutoEnterHome) {
        destination = const HomeShell();
        target = 'home';
      } else if (!state.hasSeenStory) {
        destination = const StoryFlowScreen();
        target = 'story';
      } else {
        destination = const LoginScreen();
        target = 'login';
      }
      logAction('route from splash', {
        'target': target,
        'loggedIn': state.isLoggedIn,
        'hasPortfolio': state.hasCompletedPortfolioSetup,
        'hasSeenStory': state.hasSeenStory,
      });
      Navigator.of(context).pushReplacement(
        WeRoboMotion.fadeRoute(destination),
      );
    });
```

- [ ] **Step 3: Run the existing onboarding tests to catch any regression**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/
```

Expected: PASS (all tests, including new story_flow_screen_test.dart and any pre-existing ones).

- [ ] **Step 4: Run analyzer on the modified splash**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/onboarding/splash_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/splash_screen.dart
git commit -m "feat(onboarding): route first-launch users through story flow"
```

---

## Task 8: Manual QA pass on iPhone 17 Pro simulator

No test framework can prove the keynote feel. Drive the simulator manually and verify each QA flow from the spec.

- [ ] **Step 1: Reset SharedPreferences and relaunch**

If the simulator is still running from earlier (background task `bl6px7ojc`), use the hot-restart key (uppercase `R`) in that terminal. Otherwise:

```bash
cd Front-End/robo_mobile && flutter run -d 2457356F-C3E4-4FCC-B5AE-3E80FB059693
```

In the simulator's Settings → General → Reset → "Reset All Content and Settings" to clear SharedPreferences. Or run:

```bash
xcrun simctl spawn 2457356F-C3E4-4FCC-B5AE-3E80FB059693 defaults delete com.example.roboMobile 2>/dev/null
```

- [ ] **Step 2: First-launch happy path**

- Launch app.
- Splash → story flow appears.
- Swipe through all 7 pages.
- Verify each headline + description matches the spec.
- On page 2, gauge needle is at 40 (yellow zone), red circle below.
- On page 3, gauge needle has eased to 30 (green zone), red circle has a green wedge.
- On page 4, `??` marks appear around the pie.
- On page 5, EF curve draws left-to-right, 4 dots reappear along the curve.
- On page 6, 4 event chips stagger in.
- On page 7, `투자 시작하기` button fades in.
- Tap CTA → LoginScreen appears.

- [ ] **Step 3: Persistence check**

- Force-quit the app from the simulator.
- Relaunch.
- Splash → goes directly to LoginScreen (story does NOT replay).

- [ ] **Step 4: Skip path**

- Reset prefs again (Step 1's command).
- Launch app.
- On any story page, tap `건너뛰기` (top-right).
- LoginScreen appears immediately.
- Force-quit and relaunch → goes directly to LoginScreen (story marked seen).

- [ ] **Step 5: Swipe-back animation**

- Reset prefs.
- Launch app.
- Swipe forward to page 5.
- Swipe back to page 1.
- Verify animations interpolate in reverse smoothly (curve un-draws, dots re-scatter, no jank).

- [ ] **Step 6: Rapid swipes**

- Flick rapidly between pages 1 → 7 → 1 → 7.
- Verify no broken state, no visual glitches, gauge settles to correct value when scroll stops.

- [ ] **Step 7: Dark mode**

- In the simulator's Settings → Developer → Dark Appearance ON.
- Re-enter the story (reset prefs → relaunch).
- Verify text is legible, gauge zones distinguishable.
- _Acceptable departure:_ if the deep navy headline color reads poorly on a dark background, file a follow-up but do not block. The existing onboarding has the same constraint.

- [ ] **Step 8: Auto-enter home path is preserved**

- This requires being a returning logged-in user. Skip in QA if no test account is handy.
- If a test account is available: log in, complete onboarding, force-quit, relaunch → splash → HomeShell (story does NOT play).

- [ ] **Step 9: Safe area on iPhone 17 Pro Dynamic Island**

- Confirm Skip button sits below the Dynamic Island, page dots above the home indicator.

- [ ] **Step 10: Final analyze + test pass**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Expected: zero analyzer errors, all tests PASS.

- [ ] **Step 11: Commit any QA-driven tweaks**

If QA surfaced minor tweaks (color tuning, padding adjustments), make them in small follow-up commits with messages like `fix(onboarding): tighten story headline padding`. No commit needed if QA passed cleanly.

---

## Out of scope (covered by separate plans / follow-ups)

- Home tab changes (₩→원, color tokens, AI-summary replacement, single-screen fit, global notification bell, read/unread alerts). Separate spec to follow.
- Portfolio tab changes (3-tile grid, 리포트/비중/비교 sub-screens, strategy message, metric comparison). Separate spec to follow.
- Promoting `RiskGauge` to `lib/widgets/` for cross-tab reuse — defer until a second consumer arrives.
- Named analytics events beyond `logPageEnter` / `logPageExit` — flag for follow-up.
- Full a11y audit / VoiceOver labels beyond the existing `Semantics` defaults.
- Custom haptics on page transitions.
- Portrait lock — existing onboarding doesn't lock orientation; story inherits that.
