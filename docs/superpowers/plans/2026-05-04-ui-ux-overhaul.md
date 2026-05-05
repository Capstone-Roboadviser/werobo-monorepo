# WeRobo UI/UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the WeRobo Flutter app to the Neon Carrot orange / flat-monochromatic system and execute the PDF-driven UX changes (efficient frontier rework, portfolio review screen, home dashboard rework, σ-based digest alert UI) to ship MVP by 2026-05-28.

**Architecture:** Theme-first sweep — Phase 1 atomically recolors the entire app via centralized tokens; Phases 2-5 are independently shippable PRs that rework one screen group each; Phase 6 polishes and verifies. Each phase ends with `flutter analyze` clean and tests passing.

**Tech Stack:** Flutter 3.x (Dart), `setState` / `ValueNotifier` / `ChangeNotifier` (no third-party state management), `CustomPaint` charts, `Navigator.push` with `PageRouteBuilder`, `flutter_test` for widget tests.

**Spec source:** [docs/superpowers/specs/2026-05-04-ui-ux-overhaul-design.md](../specs/2026-05-04-ui-ux-overhaul-design.md)
**Design system reference:** [Front-End/robo_mobile/DESIGN.md](../../../Front-End/robo_mobile/DESIGN.md)

---

## Pre-flight Setup

The Flutter project lives in iCloud-synced `werobo-monorepo`. iOS simulator builds fail from iCloud paths, so each session must rsync to a local copy before running.

- [ ] **Step 1: Sync to local working copy**

```bash
rsync -av --delete \
  --exclude='build/' --exclude='.dart_tool/' --exclude='.idea/' \
  /Users/eugenehong/Developer/werobo-monorepo/.claude/worktrees/affectionate-bose-534136/Front-End/robo_mobile/ \
  /Users/eugenehong/Developer/robo_mobile/
```

- [ ] **Step 2: Install dependencies**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter pub get
```

- [ ] **Step 3: Boot the iPhone 17 Pro simulator**

```bash
xcrun simctl boot 6BFFDF4C-A1E8-4031-8883-6C660465972B
open -a Simulator
```

- [ ] **Step 4: Capture baseline screenshots (sky blue, dark default)**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter run -d 6BFFDF4C-A1E8-4031-8883-6C660465972B
```

Manually navigate: splash → welcome → login (preview mode "로그인 없이 둘러보기") → onboarding/frontier → home. Take screenshots of each. Save as `before-<screen>.png` in a temp folder for the polish phase comparison.

- [ ] **Step 5: Verify baseline tests pass**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter test
```

Expected: all tests pass (this is the baseline before any changes).

---

## Phase 1: Theme Refactor (Atomic Visual Flip)

**Goal:** Replace sky blue with Neon Carrot orange, swap the 7-color chart palette for the 5-tier monochromatic asset palette, flip default theme to light, recolor all surfaces with warm tones. After this phase the entire app instantly looks like the new design — even unmodified screens.

### Task 1.1: Add asset tonal palette alongside chart palette

We add the new palette before deleting the old one to keep all consumers compiling. Cleanup happens in 1.3.

**Files:**
- Modify: `lib/app/theme.dart`

- [ ] **Step 1: Open `lib/app/theme.dart` and locate the chart palette block (around line 41-58)**

- [ ] **Step 2: Add the asset tonal palette + an `AssetClass` enum above the existing chart constants**

In `WeRoboColors`, just below `// Chart colors (7-color portfolio category palette)`, add:

```dart
// Asset tonal palette — 5-tier monochromatic orange (DESIGN.md §Color System).
// Conveys portfolio character (defensive ↔ aggressive) at a glance.
static const Color assetTier5 = Color(0xFFFFC091); // 현금성자산
static const Color assetTier4 = Color(0xFFFFB57D); // 단기채권
static const Color assetTier3 = Color(0xFFFFAA69); // 인프라채권, 금
static const Color assetTier2 = Color(0xFFFF9F52); // 미국가치주
static const Color assetTier1 = Color(0xFFFE9337); // 미국성장주, 신성장주

/// Ordered palette indexed by AssetClass. Use `assetColor(AssetClass)`
/// for ergonomic lookup.
static const List<Color> assetTonalPalette = [
  assetTier5, // index 0 — 현금성자산
  assetTier4, // index 1 — 단기채권
  assetTier3, // index 2 — 인프라채권
  assetTier3, // index 3 — 금 (tier-shared with 인프라채권)
  assetTier2, // index 4 — 미국가치주
  assetTier1, // index 5 — 미국성장주
  assetTier1, // index 6 — 신성장주 (tier-shared with 미국성장주)
];

static Color assetColor(AssetClass cls) =>
    assetTonalPalette[cls.index];
```

Then add the `AssetClass` enum at the bottom of the file (after `WeRoboTheme`):

```dart
/// Canonical order for portfolio asset classes. Order is defensive→aggressive
/// to match the tonal palette (lightest tier = least risky).
enum AssetClass {
  cash,        // 현금성자산
  shortBond,   // 단기채권
  infraBond,   // 인프라채권
  gold,        // 금
  usValue,     // 미국가치주
  usGrowth,    // 미국성장주
  newGrowth,   // 신성장주
}
```

- [ ] **Step 3: Run analyzer**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter analyze lib/app/theme.dart
```

Expected: no errors. The old `chartBlue` etc. constants still exist; the new palette sits alongside.

- [ ] **Step 4: Commit**

```bash
git add Front-End/robo_mobile/lib/app/theme.dart
git commit -m "Add asset tonal palette and AssetClass enum"
```

---

### Task 1.2: Update primary color to Neon Carrot

**Files:**
- Modify: `lib/app/theme.dart`

- [ ] **Step 1: Replace the `sky1`-`sky5` block + semantic aliases**

In `WeRoboColors`, replace the existing sky-blue block (around lines 7-17):

```dart
// Primary — Neon Carrot (#FE9337), main brand color (capstone 2026-05-04).
static const Color primary = Color(0xFFFE9337);
static const Color primaryDark = Color(0xFFE07A1F);    // 8% darker, pressed
static const Color primaryLight = Color(0xFFFFC091);   // = assetTier5

// Legacy aliases retained for any stragglers; remove after Phase 1.
@Deprecated('Use primary')
static const Color sky4 = primary;
@Deprecated('Use primaryLight')
static const Color sky2 = primaryLight;
@Deprecated('Use primaryDark')
static const Color sky5 = primaryDark;
```

- [ ] **Step 2: Update focus ring to orange tint**

Replace line `static const Color focusRing = Color(0x4D20A7DB);` with:

```dart
static const Color focusRing = Color(0x4DFE9337); // primary @ 30%
```

- [ ] **Step 3: Update `dotActive`**

Replace `static const Color dotActive = sky4;` with:

```dart
static const Color dotActive = primary;
```

- [ ] **Step 4: Run analyzer**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter analyze
```

Expected: deprecation warnings on `sky2/sky4/sky5` consumers (we'll fix in 1.3); no errors.

- [ ] **Step 5: Commit**

```bash
git commit -am "Switch primary to Neon Carrot orange"
```

---

### Task 1.3: Migrate chart-color consumers to asset tonal palette

The codebase has 8 references to old chart colors (`chartBlue`, `chartGreen`, `chartYellow`) outside `theme.dart`. Replace each with the appropriate `AssetClass` color.

**Files:**
- Modify: `lib/screens/onboarding/onboarding_screen.dart`
- Modify: `lib/screens/onboarding/widgets/donut_chart.dart`
- Modify: `lib/screens/onboarding/widgets/portfolio_charts.dart`

- [ ] **Step 1: Find all chart-color references**

```bash
cd /Users/eugenehong/Developer/robo_mobile
grep -rn "WeRoboColors.chart" lib/
```

Expected ~8 hits in onboarding_screen.dart (lines 247, 253, 259), donut_chart.dart (lines 48-50, 57), portfolio_charts.dart (line 522).

- [ ] **Step 2: Replace `chartBlue → assetTier1`, `chartGreen → assetTier4`, `chartYellow → assetTier3`**

These are sample/placeholder colors in the onboarding sample donut. The mapping is approximate — pick the tier that best represents the original intent. For the donut sample data in `donut_chart.dart` (45/40/15 split), use:
- 45% slice → `assetTier4` (단기채권 default)
- 40% slice → `assetTier5` (현금성자산)
- 15% slice → `assetTier3` (인프라채권)

Run this sed for the bulk swap:

```bash
cd /Users/eugenehong/Developer/robo_mobile
# onboarding_screen.dart sample chips
sed -i '' 's/WeRoboColors.chartBlue/WeRoboColors.assetTier1/g' lib/screens/onboarding/onboarding_screen.dart
sed -i '' 's/WeRoboColors.chartGreen/WeRoboColors.assetTier4/g' lib/screens/onboarding/onboarding_screen.dart
sed -i '' 's/WeRoboColors.chartYellow/WeRoboColors.assetTier3/g' lib/screens/onboarding/onboarding_screen.dart
# portfolio_charts.dart benchmark line
sed -i '' 's/WeRoboColors.chartGreen/WeRoboColors.assetTier4/g' lib/screens/onboarding/widgets/portfolio_charts.dart
```

For `donut_chart.dart`, the existing widget has hardcoded sample segments (lines 47-51). Replace with:

```dart
segments: const [
  _Segment(0.45, WeRoboColors.assetTier4),
  _Segment(0.40, WeRoboColors.assetTier5),
  _Segment(0.15, WeRoboColors.assetTier3),
],
```

And the center text color (line 56-58):

```dart
'${(45 * _animation.value).toInt()}%',
style: WeRoboTypography.number.copyWith(
  color: WeRoboColors.assetTier4,
),
```

- [ ] **Step 3: Remove the old chart palette constants from `theme.dart`**

Delete lines 41-58 (the old `// Chart colors` block including `chartPalette` list).

- [ ] **Step 4: Run analyzer**

```bash
flutter analyze
```

Expected: zero errors, zero deprecation warnings on chart colors.

- [ ] **Step 5: Run tests**

```bash
flutter test
```

Expected: pass (sample data in tests references widgets, not chart constants directly).

- [ ] **Step 6: Commit**

```bash
git commit -am "Migrate chart-color consumers to asset tonal palette"
```

---

### Task 1.4: Update light theme surface stack to warm tones

**Files:**
- Modify: `lib/app/theme.dart`

- [ ] **Step 1: Replace `WeRoboThemeColors.light` constants**

Find the `static const light = WeRoboThemeColors(...)` block (~line 325) and replace:

```dart
static const light = WeRoboThemeColors(
  background: Color(0xFFF4F2F0),  // warm gray (was #F6F7F8)
  surface: Color(0xFFFFFFFF),
  card: Color(0xFFF4F2F0),         // warm gray (was #EFF1F3)
  border: Color(0xFFE5E1DD),       // warm hairline (was #CDD1D6)
  textPrimary: Color(0xFF1A1919),  // warm black (was #000000)
  textSecondary: Color(0xFF6B6B6B),
  textTertiary: Color(0xFF8E8E8E),
  accent: Color(0xFF059669),
);
```

- [ ] **Step 2: Update the cool-tinted neutral constants too (top of `WeRoboColors`)**

Replace the `// 부 색상 (Cool-tinted Neutrals)` block:

```dart
// 부 색상 — warm-tinted neutrals to harmonize with orange.
static const Color white = Color(0xFFFFFFFF);
static const Color lightGray = Color(0xFFE5E1DD);   // warm border
static const Color silver = Color(0xFF8E8E8E);
static const Color black = Color(0xFF1A1919);       // warm black

// Surfaces (warm-tinted to harmonize with orange).
static const Color background = Color(0xFFF4F2F0);
static const Color surface = white;
static const Color card = Color(0xFFF4F2F0);

// Text
static const Color textPrimary = black;
static const Color textSecondary = Color(0xFF6B6B6B);
static const Color textTertiary = Color(0xFF8E8E8E);
```

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git commit -am "Warm-tint light theme surfaces"
```

---

### Task 1.5: Update dark theme surface stack to warm tones

**Files:**
- Modify: `lib/app/theme.dart`

- [ ] **Step 1: Replace `WeRoboThemeColors.dark` constants**

Find the `static const dark = WeRoboThemeColors(...)` block (~line 336) and replace:

```dart
static const dark = WeRoboThemeColors(
  background: Color(0xFF1A1919),   // warm black (was #141414)
  surface: Color(0xFF232020),      // warm card surface
  card: Color(0xFF2A2625),         // warm inset card
  border: Color(0xFF3A3636),       // warm hairline
  textPrimary: Color(0xFFF0EEEC),  // warm off-white
  textSecondary: Color(0xFFA39E99),
  textTertiary: Color(0xFF7A7470),
  accent: Color(0xFF34D399),       // green stays unchanged
);
```

- [ ] **Step 2: Run analyzer + tests**

```bash
flutter analyze && flutter test
```

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git commit -am "Warm-tint dark theme surfaces"
```

---

### Task 1.6: Flip default theme mode from dark to light

**Files:**
- Modify: `lib/app/theme_state.dart`

- [ ] **Step 1: Write the test**

Create `test/app/theme_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme_state.dart';

void main() {
  test('ThemeNotifier defaults to light mode', () {
    final notifier = ThemeNotifier();
    expect(notifier.mode, ThemeMode.light);
  });

  test('toggle flips light → dark → light', () {
    final notifier = ThemeNotifier();
    notifier.toggle();
    expect(notifier.mode, ThemeMode.dark);
    notifier.toggle();
    expect(notifier.mode, ThemeMode.light);
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/app/theme_state_test.dart
```

Expected: FAIL — "Expected: ThemeMode.light, Actual: ThemeMode.dark".

- [ ] **Step 3: Flip the default**

In `lib/app/theme_state.dart` line 5:

```dart
ThemeMode _mode = ThemeMode.light;
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
flutter test test/app/theme_state_test.dart
```

Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/app/theme_state.dart test/app/theme_state_test.dart
git commit -m "Flip default theme mode to light"
```

---

### Task 1.7: Update CLAUDE.md design system snippet

**Files:**
- Modify: `Front-End/robo_mobile/CLAUDE.md`

- [ ] **Step 1: Replace the `### Colors` section (~line 47-63)**

Replace the entire `### Colors` block with:

```markdown
### Colors (defined in `lib/app/theme.dart`)
**주 색상 (Primary — Neon Carrot orange):**
- primary: `#FE9337`
- primaryDark: `#E07A1F` (pressed)
- primaryLight: `#FFC091` (= assetTier5)

**Asset tonal palette (5-tier monochromatic, defensive→aggressive):**
- assetTier5 / `#FFC091`: 현금성자산
- assetTier4 / `#FFB57D`: 단기채권
- assetTier3 / `#FFAA69`: 인프라채권, 금
- assetTier2 / `#FF9F52`: 미국가치주
- assetTier1 / `#FE9337`: 미국성장주, 신성장주

**부 색상 (Warm-tinted Neutrals):**
- 화이트: `#FFFFFF` (surface)
- 카드 / 배경: `#F4F2F0` (warm gray)
- 보더: `#E5E1DD` (warm hairline)
- 텍스트 1차: `#1A1919` (warm black)
- 텍스트 보조: `#6B6B6B`
- 텍스트 3차: `#8E8E8E` (WCAG AA 4.6:1)

**Status (retained):**
- accent (gain): `#059669` green
- warning: `#FBBF24` yellow
- error: `#EF4444` red — error states only
```

- [ ] **Step 2: Commit**

```bash
git add Front-End/robo_mobile/CLAUDE.md
git commit -m "Update CLAUDE.md design system snippet"
```

---

### Task 1.8: Manual visual verification + Phase 1 baseline

- [ ] **Step 1: Sync to local working copy**

```bash
rsync -av --delete --exclude='build/' --exclude='.dart_tool/' \
  /Users/eugenehong/Developer/werobo-monorepo/.claude/worktrees/affectionate-bose-534136/Front-End/robo_mobile/ \
  /Users/eugenehong/Developer/robo_mobile/
```

- [ ] **Step 2: Run the app**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter run -d 6BFFDF4C-A1E8-4031-8883-6C660465972B
```

- [ ] **Step 3: Walk the flow and capture screenshots**

Navigate: splash → welcome → login (preview mode) → onboarding (frontier) → home → portfolio tab → settings tab. Capture each screen.

**Acceptance:**
- App boots in **light** mode (warm `#F4F2F0` background, not dark)
- Primary color is orange (CTAs, active states, dot on frontier)
- Sample donut on onboarding shows orange tonal segments (not blue/green/yellow)
- No sky-blue residue anywhere
- All text readable on light surface

If a screen has visible regressions (e.g., text invisible because it's white on white), file as a Phase 1.x bug and fix before proceeding.

- [ ] **Step 4: Run full analyzer + tests**

```bash
flutter analyze && flutter test
```

Expected: zero errors, all tests pass.

- [ ] **Step 5: Tag Phase 1 complete**

```bash
git tag phase-1-theme
```

---

## Phase 2: Efficient Frontier Rework

**Goal:** Convert the frontier chart from 1:1 to 1:3 horizontal aspect (height:width), replace scatter with a smooth idealized curve, **fix the asset positioning bug** (cash should be leftmost, growth rightmost — currently 인프라채권 is incorrectly leftmost), **remove the asset bubble size-growth animation and percentage labels**, and replace the asset weight list under the graph with a **stacked horizontal bar chart** whose segments resize live as the user drags the dot.

**Updated 2026-05-05 per user notes — supersedes original Phase 2 design.**

### Task 2.1: Create shared `AssetWeight` model + `AssetWeightBar` widget

The frontier uses a stacked bar (not a list); the portfolio review screen still uses a list (Phase 3 Task 3.2). Both consume the shared `AssetWeight` model defined here.

**Files:**
- Create: `lib/screens/onboarding/widgets/asset_weight.dart` (model + AssetWeightBar)
- Create: `test/screens/onboarding/widgets/asset_weight_bar_test.dart`

- [ ] **Step 1: Write the model and bar widget**

```dart
// lib/screens/onboarding/widgets/asset_weight.dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// One asset class with its current weight in a portfolio.
class AssetWeight {
  final AssetClass cls;
  final String label;       // e.g. "단기채권"
  final List<String> tickers; // e.g. ["BND", "AGG", "LQD"]
  final double weight;       // 0.0–1.0

  const AssetWeight({
    required this.cls,
    required this.label,
    required this.tickers,
    required this.weight,
  });
}

/// Stacked horizontal bar showing asset proportions.
/// Used by the efficient frontier (segments resize live as user drags).
/// No percentage labels — bar segments communicate proportion visually.
/// Asset order follows AssetClass enum (defensive → aggressive: cash on
/// the left, 신성장주 on the right) so the visual gradient maps to risk.
class AssetWeightBar extends StatelessWidget {
  final List<AssetWeight> assets;
  final double height;

  const AssetWeightBar({
    super.key,
    required this.assets,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by AssetClass enum order, NOT by weight, so the leftmost
    // segment is always the most defensive class (cash).
    final ordered = [...assets]
      ..sort((a, b) => a.cls.index.compareTo(b.cls.index));
    final total = ordered.fold<double>(0, (s, a) => s + a.weight);
    if (total <= 0) {
      return SizedBox(height: height);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
      child: AnimatedSize(
        duration: WeRoboMotion.short,
        curve: WeRoboMotion.move,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final a in ordered)
                Expanded(
                  flex: ((a.weight / total) * 1000).round().clamp(1, 1000000),
                  child: AnimatedContainer(
                    duration: WeRoboMotion.short,
                    color: WeRoboColors.assetColor(a.cls),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical list view (name + tickers + animated %) — used by the
/// portfolio review screen, not the frontier. Defined here to share the
/// AssetWeight model and asset color lookup.
class AssetWeightList extends StatelessWidget {
  final List<AssetWeight> assets;
  final bool compact;

  const AssetWeightList({
    super.key,
    required this.assets,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final sorted = [...assets]..sort((a, b) => b.weight.compareTo(a.weight));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in sorted) _AssetRow(asset: a, tc: tc, compact: compact),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  final AssetWeight asset;
  final WeRoboThemeColors tc;
  final bool compact;

  const _AssetRow({required this.asset, required this.tc, required this.compact});

  @override
  Widget build(BuildContext context) {
    final color = WeRoboColors.assetColor(asset.cls);
    final pct = (asset.weight * 100).toStringAsFixed(2);
    final padding = compact
        ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8)
        : const EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.label, style: WeRoboTypography.bodySmall.themed(context)
                    .copyWith(color: tc.textPrimary, fontWeight: FontWeight.w600)),
                if (asset.tickers.isNotEmpty)
                  Text(
                    asset.tickers.join(', '),
                    style: WeRoboTypography.caption.themed(context),
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: WeRoboMotion.short,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              '$pct%',
              key: ValueKey(pct),
              style: WeRoboTypography.bodySmall.copyWith(
                fontFamily: WeRoboFonts.number,
                fontWeight: FontWeight.w500,
                color: tc.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write widget tests**

```dart
// test/screens/onboarding/widgets/asset_weight_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/asset_weight.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    );

void main() {
  testWidgets('AssetWeightBar — segments ordered by AssetClass enum (defensive→aggressive)', (tester) async {
    // Provide assets in random order; the bar must reorder cash → ... → growth.
    await tester.pumpWidget(_wrap(const AssetWeightBar(assets: [
      AssetWeight(cls: AssetClass.usGrowth, label: '미국성장주', tickers: [], weight: 0.10),
      AssetWeight(cls: AssetClass.cash, label: '현금성자산', tickers: [], weight: 0.50),
      AssetWeight(cls: AssetClass.shortBond, label: '단기채권', tickers: [], weight: 0.40),
    ])));
    final containers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    final colors = containers.map((c) => (c.decoration as BoxDecoration?)?.color ?? c.color).toList();
    // Leftmost segment must be cash tier (#FFC091).
    expect(colors.first, WeRoboColors.assetTier5);
    // Rightmost segment must be growth tier (#FE9337).
    expect(colors.last, WeRoboColors.assetTier1);
  });

  testWidgets('AssetWeightBar — empty/zero weights renders an empty fixed-height SizedBox', (tester) async {
    await tester.pumpWidget(_wrap(const AssetWeightBar(assets: [])));
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('AssetWeightList — sorts by weight desc and formats %', (tester) async {
    await tester.pumpWidget(_wrap(const AssetWeightList(assets: [
      AssetWeight(cls: AssetClass.cash, label: 'A', tickers: [], weight: 0.10),
      AssetWeight(cls: AssetClass.usGrowth, label: 'B', tickers: [], weight: 0.50),
    ])));
    final aPos = tester.getTopLeft(find.text('A')).dy;
    final bPos = tester.getTopLeft(find.text('B')).dy;
    expect(bPos, lessThan(aPos)); // B (higher weight) appears first
    expect(find.text('50.00%'), findsOneWidget);
  });

  testWidgets('AssetWeightList — formats weight as XX.XX%', (tester) async {
    await tester.pumpWidget(_wrap(const AssetWeightList(assets: [
      AssetWeight(cls: AssetClass.cash, label: '현금', tickers: [], weight: 0.2998),
    ])));
    expect(find.text('29.98%'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/screens/onboarding/widgets/asset_weight_bar_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding/widgets/asset_weight.dart \
        test/screens/onboarding/widgets/asset_weight_bar_test.dart
git commit -m "Add AssetWeight model + AssetWeightBar/List widgets"
```

---

### Task 2.2: Refactor frontier chart to 1:3 horizontal aspect (3:1 width:height)

Per the 2026-05-05 user notes, target ratio is **1:3 (height:width)** — i.e. the chart is 3× wider than tall. This is more horizontal than the original 2:1 plan; it's needed for the curve slope to read clearly on small screens.

**Files:**
- Modify: `lib/screens/onboarding/widgets/efficient_frontier_chart.dart`

- [ ] **Step 1: Locate the chart container**

```bash
grep -n "AspectRatio\|height:\|width:" lib/screens/onboarding/widgets/efficient_frontier_chart.dart | head
```

Find the wrapper that determines the chart's aspect ratio (likely an `AspectRatio(aspectRatio: 1.0, ...)` or fixed height).

- [ ] **Step 2: Wrap the chart body in `AspectRatio(aspectRatio: 3.0, ...)`**

Locate the outer `LayoutBuilder` or `SizedBox` and wrap the chart contents:

```dart
return AspectRatio(
  aspectRatio: 3.0, // 1:3 height:width per 2026-05-05 user notes
  child: LayoutBuilder(
    builder: (context, constraints) {
      // ... existing CustomPaint chart body ...
    },
  ),
);
```

If 3.0 looks cramped on the iPhone Mini-class viewport during Step 3 verification, fall back to 2.5 or 2.0; if it looks too thin, push to 4.0. The user gave 1:2 / 1:3 / 1:4 as the acceptable range.

- [ ] **Step 3: Run the app, verify the chart is much wider than tall**

```bash
rsync -av --delete --exclude='build/' --exclude='.dart_tool/' \
  /Users/eugenehong/Developer/werobo-monorepo/.claude/worktrees/affectionate-bose-534136/Front-End/robo_mobile/ \
  /Users/eugenehong/Developer/robo_mobile/
cd /Users/eugenehong/Developer/robo_mobile && flutter run -d 6BFFDF4C-A1E8-4031-8883-6C660465972B
```

Navigate to the frontier screen. Confirm chart is ~3× wider than tall and the curve slope is clearly visible.

- [ ] **Step 4: Commit**

```bash
git commit -am "Frontier chart aspect ratio 1:1 → 1:3 horizontal"
```

---

### Task 2.3: Smooth idealized curve, fix asset positioning, remove bubble effects

This task bundles four sub-changes that all touch the same painter:
1. Replace the scatter plot with a single smooth idealized curve (not raw data — a visual approximation)
2. Fix the asset position bug — currently 인프라 채권 is incorrectly leftmost; cash should be leftmost, 신성장주 rightmost
3. Remove the asset bubble size-growth animation
4. Remove percentage labels from the asset bubbles

**Files:**
- Modify: `lib/screens/onboarding/widgets/efficient_frontier_chart.dart`

- [ ] **Step 1: Locate the existing scatter draw and bubble code**

```bash
grep -nE "drawCircle|drawPoints|scatter|TextPainter|bubble" lib/screens/onboarding/widgets/efficient_frontier_chart.dart | head -30
```

Note line ranges for: per-point scatter dots, per-asset bubble draws, bubble size animation, percentage TextPainter calls.

- [ ] **Step 2: Add a Bezier path builder for the idealized curve**

Inside the painter class, add a helper. The key change from raw data: we **don't** plot exact computed (vol, return) coordinates — we sample, smooth, and let the curve communicate the concept rather than the precise geometry.

```dart
/// Smooths a sparse set of (vol, ret) anchor points into a monotone-X
/// cubic Bezier approximating the efficient frontier curve. The result
/// is intentionally idealized (not raw scatter) — the curve communicates
/// "lower vol = lower return, higher vol = higher return" visually.
Path _buildFrontierPath(List<Offset> points, Size size) {
  if (points.isEmpty) return Path();
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i];
    final p1 = points[i + 1];
    final c1 = Offset(p0.dx + (p1.dx - p0.dx) / 3, p0.dy);
    final c2 = Offset(p0.dx + 2 * (p1.dx - p0.dx) / 3, p1.dy);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
  }
  return path;
}
```

If the existing data has too many points or is jittery, sub-sample down to ~8-12 anchor points before passing in. The user explicitly said "정확한 위치보다는 시각적으로 이해 가능한 수준의 배치를 목표로 함" — target visual understanding, not precision.

- [ ] **Step 3: Replace the scatter loop with a single curve stroke**

Replace the per-point `drawCircle` loop in `paint()`:

```dart
final curvePath = _buildFrontierPath(screenPoints, size);
final curvePaint = Paint()
  ..color = WeRoboColors.primary
  ..style = PaintingStyle.stroke
  ..strokeWidth = 3.0
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
canvas.drawPath(curvePath, curvePaint);
```

- [ ] **Step 4: Fix the asset bubble positions — defensive (cash) at left, aggressive (신성장주) at right**

The current bug is that asset bubbles use raw (vol, return) coords, but those coords are wrong / inconsistent and put 인프라 채권 leftmost. Replace the per-asset position computation with **fixed normalized positions in `AssetClass` enum order** along the curve:

```dart
/// Returns the (x, y) in chart coords for an asset class label, mapped
/// monotonically along the curve from defensive (left) to aggressive (right).
/// The exact (vol, return) is intentionally ignored — labels are placed for
/// visual order, not data precision (per 2026-05-05 user notes).
Offset _assetAnchor(AssetClass cls, List<Offset> curvePoints) {
  // 7 classes → 7 evenly-spaced anchors along the curve.
  // index 0 (cash) → curvePoints[0] (leftmost)
  // index 6 (newGrowth) → curvePoints.last (rightmost)
  final i = cls.index;
  final n = AssetClass.values.length - 1;
  final t = i / n; // 0.0 to 1.0
  final pos = (t * (curvePoints.length - 1)).round();
  return curvePoints[pos];
}
```

Then in the bubble draw loop, iterate `AssetClass.values` in order and draw a small fixed-radius circle (no growth animation, no % label) at `_assetAnchor(cls, screenPoints)`:

```dart
for (final cls in AssetClass.values) {
  final anchor = _assetAnchor(cls, screenPoints);
  final color = WeRoboColors.assetColor(cls);
  // Fixed radius — NO size-growth animation per 2026-05-05 user notes.
  canvas.drawCircle(anchor, 7.0, Paint()..color = color);
  // Asset name label only (NO percentage — % is removed per user notes).
  // The bar widget below the chart shows proportions.
  _drawLabel(canvas, anchor, cls.koLabel);
}
```

Add `koLabel` getter on `AssetClass` (in `lib/app/theme.dart`):

```dart
extension AssetClassLabel on AssetClass {
  String get koLabel => switch (this) {
        AssetClass.cash => '현금성자산',
        AssetClass.shortBond => '단기채권',
        AssetClass.infraBond => '인프라채권',
        AssetClass.gold => '금',
        AssetClass.usValue => '미국가치주',
        AssetClass.usGrowth => '미국성장주',
        AssetClass.newGrowth => '신성장주',
      };
}
```

If a `_drawLabel` helper doesn't exist, write it as a thin TextPainter wrapper that renders Noto Sans KR caption text near the anchor without overlap (you may need to offset by `(0, -16)` so the label sits above the bubble).

- [ ] **Step 5: Remove all references to bubble size-growth animation and % labels**

```bash
grep -nE "bubble.*Animation|sizeGrowth|TextPainter.*%" lib/screens/onboarding/widgets/efficient_frontier_chart.dart
```

Remove any `AnimationController` driving bubble radius, any `lerp` between small/large radii, and any TextPainter call that renders a `%` string.

- [ ] **Step 6: Hot-restart, verify**

```bash
rsync -av --delete --exclude='build/' --exclude='.dart_tool/' \
  /Users/eugenehong/Developer/werobo-monorepo/.claude/worktrees/affectionate-bose-534136/Front-End/robo_mobile/ \
  /Users/eugenehong/Developer/robo_mobile/
cd /Users/eugenehong/Developer/robo_mobile && flutter hot-restart
```

Navigate to frontier. Verify:
- Smooth orange curve, no scatter dots
- 7 asset bubbles in defensive→aggressive order: 현금성자산 leftmost, 신성장주 rightmost
- No bubble size animation when transitioning
- No % text on bubbles
- Bubbles use orange tonal palette (cash = lightest, growth = darkest)

- [ ] **Step 7: Commit**

```bash
git commit -am "Idealize frontier curve, fix asset order, remove bubble grow + %"
```

---

### Task 2.4: Wire `AssetWeightBar` to dot drag state

**Files:**
- Modify: `lib/screens/onboarding/onboarding_screen.dart`

- [ ] **Step 1: Add `_assetsAtT` derived from `_selectedDotT`**

In `_OnboardingScreenState`, add a method that converts the current frontier selection to a list of `AssetWeight`:

```dart
List<AssetWeight> _assetsAtT(double t) {
  final selection = _frontierSelection;
  if (selection == null) return const [];
  final weights = selection.weightsAt(t);
  return [
    AssetWeight(cls: AssetClass.cash,      label: '현금성자산', tickers: const ['BIL', 'VCSH', 'BSV'], weight: weights[AssetClass.cash.index]),
    AssetWeight(cls: AssetClass.shortBond, label: '단기채권',   tickers: const ['BND', 'AGG', 'LQD'], weight: weights[AssetClass.shortBond.index]),
    AssetWeight(cls: AssetClass.infraBond, label: '인프라채권', tickers: const ['NFRA', 'GII', 'IGF'], weight: weights[AssetClass.infraBond.index]),
    AssetWeight(cls: AssetClass.gold,      label: '금',         tickers: const ['DBC', 'SGOL', 'GLD'], weight: weights[AssetClass.gold.index]),
    AssetWeight(cls: AssetClass.usValue,   label: '미국가치주', tickers: const ['MGV', 'VBR', 'VTV'], weight: weights[AssetClass.usValue.index]),
    AssetWeight(cls: AssetClass.usGrowth,  label: '미국성장주', tickers: const ['VBK', 'MGK', 'VUG'], weight: weights[AssetClass.usGrowth.index]),
    AssetWeight(cls: AssetClass.newGrowth, label: '신성장주',   tickers: const [],                     weight: weights[AssetClass.newGrowth.index]),
  ];
}
```

`selection.weightsAt(t)` is a new method. Decide where it lives based on the existing data flow:
- If `OnboardingFrontierSelection` already has a reference to its source `MobileFrontierPreviewResponse`, add `weightsAt` on the selection that delegates to the response.
- If not, enrich `OnboardingFrontierSelection` to carry the response (or a `weights: List<List<double>>` snapshot) and add the method directly.

Either way, the signature stays `List<double> weightsAt(double t)` returning a 7-element list indexed by `AssetClass.values.indexOf(cls)`. The implementation looks up the closest sample index given `t ∈ [0, 1]`.

- [ ] **Step 2: Render `AssetWeightBar` below the chart**

In the `build()` method of the frontier page, after the `EfficientFrontierChart`, add:

```dart
const SizedBox(height: 16),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: AssetWeightBar(assets: _assetsAtT(_selectedDotT)),
),
```

The bar lives directly under the chart with 16px gap. No labels, no percentages — segments communicate proportion visually. The user said "그래프 아래 percentage 방식에서 막대 그래프 방식으로 전환".

- [ ] **Step 3: Trigger rebuild on drag**

Wherever `_selectedDotT` is updated (likely `setState((){ _selectedDotT = newT; })` in the drag callback), confirm `setState` is called. Add a comment:

```dart
// Drag updates _selectedDotT → setState → AssetWeightBar re-renders.
// Each segment's flex ratio animates smoothly via AnimatedContainer.
```

- [ ] **Step 4: Hot-restart and drag the dot**

Run the app, navigate to frontier, drag the dot. Confirm: bar segments resize smoothly as weights shift. Cash segment shrinks as you drag right (toward aggressive); growth segment grows.

- [ ] **Step 5: Commit**

```bash
git commit -am "Wire AssetWeightBar to frontier dot drag"
```

---

### Task 2.5: Verify frontier flow end-to-end

- [ ] **Step 1: Run the full test suite**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter analyze && flutter test
```

Expected: pass.

- [ ] **Step 2: Capture frontier screenshots at three drag positions**

Manually navigate to the frontier screen, drag the dot to three positions (left = defensive, middle = balanced, right = aggressive), and screenshot each. Verify against the 2026-05-05 user notes:

- [ ] Chart aspect ~3× wider than tall (1:3 height:width)
- [ ] Smooth orange curve, no scatter dots
- [ ] 현금성자산 leftmost, 신성장주 rightmost (bug fix verified)
- [ ] Asset bubbles fixed-radius, no growth animation, no % labels
- [ ] Bar below chart resizes live as user drags
- [ ] All asset colors are orange tones (no rainbow, no blue residue)

- [ ] **Step 3: Tag Phase 2 complete**

```bash
git tag phase-2-frontier
```

---

## Phase 3: Portfolio Review Screen + Onboarding Cut

**Goal:** Replace the obsolete onboarding tail (`result_screen.dart`, `comparison_screen.dart`, `confirmation_screen.dart`) with a single new `portfolio_review_screen.dart`. Layout updated 2026-05-05: **donut stacked above the asset list (vertical)** instead of side-by-side — left/right layout breaks on iPhone Mini-class viewports per user direction. Comparison tab is default, volatility-vs-market tab is secondary, 3-year default time range with pinch-zoom.

### Task 3.1: Refactor `DonutChart` to accept dynamic segments and compact mode

**Files:**
- Modify: `lib/screens/onboarding/widgets/donut_chart.dart`
- Create: `test/screens/onboarding/widgets/donut_chart_test.dart`

- [ ] **Step 1: Write tests for new dynamic API**

```dart
// test/screens/onboarding/widgets/donut_chart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/donut_chart.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders with explicit segments', (tester) async {
    await tester.pumpWidget(_wrap(const DonutChart(
      segments: [
        DonutSegment(weight: 0.5, color: Color(0xFFFE9337)),
        DonutSegment(weight: 0.5, color: Color(0xFFFFC091)),
      ],
      centerLabel: 'TEST',
    )));
    await tester.pumpAndSettle();
    expect(find.text('TEST'), findsOneWidget);
  });

  testWidgets('compact mode uses smaller diameter', (tester) async {
    await tester.pumpWidget(_wrap(const DonutChart(
      segments: [DonutSegment(weight: 1.0, color: Color(0xFFFE9337))],
      centerLabel: 'X',
      compact: true,
    )));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(DonutChart));
    expect(size.width, 180); // compact diameter per DESIGN.md
  });
}
```

- [ ] **Step 2: Refactor `DonutChart` to take parameters**

Replace the current hardcoded widget body with:

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class DonutSegment {
  final double weight; // 0.0–1.0
  final Color color;
  const DonutSegment({required this.weight, required this.color});
}

class DonutChart extends StatefulWidget {
  final List<DonutSegment> segments;
  final String centerLabel;
  final bool compact;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    this.compact = false,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: WeRoboMotion.chartDraw, vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: WeRoboMotion.chartReveal),
    );
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final size = widget.compact ? 180.0 : 240.0;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => SizedBox(
        width: size, height: size,
        child: CustomPaint(
          painter: _DonutPainter(
            progress: _animation.value,
            segments: widget.segments,
            borderColor: tc.surface,
          ),
          child: Center(
            child: Text(widget.centerLabel,
                style: WeRoboTypography.heading3.themed(context)),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final List<DonutSegment> segments;
  final Color borderColor;

  _DonutPainter({required this.progress, required this.segments, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 28.0;
    const gapAngle = 0.012; // ~1px gap at typical radius

    double startAngle = -pi / 2;
    for (final segment in segments) {
      final sweepAngle = 2 * pi * segment.weight * progress - gapAngle;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt; // butt + gap = clean separator
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, false, paint,
      );
      startAngle += 2 * pi * segment.weight * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.segments != segments;
}
```

- [ ] **Step 3: Update existing call sites in onboarding**

Find any `DonutChart()` callers via `grep -rn "DonutChart(" lib/`. Update each to pass `segments` and `centerLabel` explicitly. The previous demo donut in onboarding_screen.dart should now pass real data from the frontier selection.

- [ ] **Step 4: Run tests**

```bash
flutter test test/screens/onboarding/widgets/donut_chart_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/onboarding/widgets/donut_chart.dart \
        test/screens/onboarding/widgets/donut_chart_test.dart
git commit -m "Refactor DonutChart for dynamic segments + compact mode"
```

---

### Task 3.2: Create `PortfolioReviewScreen` skeleton

**Files:**
- Create: `lib/screens/onboarding/portfolio_review_screen.dart`

- [ ] **Step 1: Write the skeleton**

```dart
// lib/screens/onboarding/portfolio_review_screen.dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../app/portfolio_state.dart';
import 'widgets/asset_weight.dart'; // shared model + AssetWeightList
import 'widgets/donut_chart.dart';
import 'frontier_selection_resolver.dart';

/// Post-frontier confirmation screen. Layout per 2026-05-05 user notes:
///   - Donut stacked above the asset list (vertical, small-screen friendly)
///   - Tabs: 포트폴리오 비교 (default) / 변동성 (secondary)
///   - 3-year default time range with pinch-zoom
///   - Bottom CTA: 투자 확정
class PortfolioReviewScreen extends StatefulWidget {
  final OnboardingFrontierSelection selection;

  const PortfolioReviewScreen({super.key, required this.selection});

  @override
  State<PortfolioReviewScreen> createState() => _PortfolioReviewScreenState();
}

class _PortfolioReviewScreenState extends State<PortfolioReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  List<AssetWeight> get _assets => _resolveAssets(widget.selection);
  List<DonutSegment> get _segments => _assets
      .map((a) => DonutSegment(
            weight: a.weight,
            color: WeRoboColors.assetColor(a.cls),
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: tc.background,
        elevation: 0,
        leading: const BackButton(),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WeRoboColors.primaryLight,
              borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
            ),
            child: Text('선택 포트폴리오',
                style: WeRoboTypography.caption.copyWith(color: WeRoboColors.primaryDark)),
          ),
          const SizedBox(width: 8),
          Text('포트폴리오 상세', style: WeRoboTypography.heading3.themed(context)),
        ]),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _DonutAndListColumn(segments: _segments, assets: _assets),
              const SizedBox(height: 24),
              _CompareVolatilityTabs(controller: _tabController, selection: widget.selection),
              const SizedBox(height: 100), // bottom CTA clearance
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: WeRoboSpacing.bottomButton,
          child: ElevatedButton(
            onPressed: () => _confirmInvestment(context),
            child: const Text('투자 확정'),
          ),
        ),
      ),
    );
  }

  void _confirmInvestment(BuildContext context) {
    PortfolioStateProvider.of(context).recordFrontierSelection(widget.selection);
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }
}

/// Vertical layout: donut on top (~240px), asset list below.
/// Decided 2026-05-05 over a side-by-side layout because horizontal
/// arrangement breaks on iPhone Mini-class viewports (375pt wide).
class _DonutAndListColumn extends StatelessWidget {
  final List<DonutSegment> segments;
  final List<AssetWeight> assets;
  const _DonutAndListColumn({required this.segments, required this.assets});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DonutChart(
              segments: segments,
              centerLabel: '포트폴리오\n비중',
              compact: false, // full size — top of screen, anchors hierarchy
            ),
          ),
          const SizedBox(height: 20),
          AssetWeightList(assets: assets),
        ],
      ),
    );
  }
}

// _CompareVolatilityTabs is filled in Task 3.3 / 3.4.
class _CompareVolatilityTabs extends StatelessWidget {
  final TabController controller;
  final OnboardingFrontierSelection selection;
  const _CompareVolatilityTabs({required this.controller, required this.selection});

  @override
  Widget build(BuildContext context) {
    return const Placeholder(fallbackHeight: 320); // filled next
  }
}

List<AssetWeight> _resolveAssets(OnboardingFrontierSelection selection) {
  // Derive from selection weights — same shape as Task 2.4's _assetsAtT.
  // Use the resolver in frontier_selection_resolver.dart if applicable.
  // Returns the full 7-asset-class list with weights.
  // Implementation lives in the resolver to keep both screens in sync.
  return resolveAssetWeights(selection);
}
```

- [ ] **Step 2: Add `resolveAssetWeights` to the existing resolver**

In `lib/screens/onboarding/frontier_selection_resolver.dart`, add a top-level function:

```dart
List<AssetWeight> resolveAssetWeights(OnboardingFrontierSelection selection) {
  final weights = selection.weightsAt(selection.normalizedT);
  return [
    AssetWeight(cls: AssetClass.cash,      label: '현금성자산', tickers: const ['BIL', 'VCSH', 'BSV'], weight: weights[AssetClass.cash.index]),
    AssetWeight(cls: AssetClass.shortBond, label: '단기채권',   tickers: const ['BND', 'AGG', 'LQD'], weight: weights[AssetClass.shortBond.index]),
    AssetWeight(cls: AssetClass.infraBond, label: '인프라채권', tickers: const ['NFRA', 'GII', 'IGF'], weight: weights[AssetClass.infraBond.index]),
    AssetWeight(cls: AssetClass.gold,      label: '금',         tickers: const ['DBC', 'SGOL', 'GLD'], weight: weights[AssetClass.gold.index]),
    AssetWeight(cls: AssetClass.usValue,   label: '미국가치주', tickers: const ['MGV', 'VBR', 'VTV'], weight: weights[AssetClass.usValue.index]),
    AssetWeight(cls: AssetClass.usGrowth,  label: '미국성장주', tickers: const ['VBK', 'MGK', 'VUG'], weight: weights[AssetClass.usGrowth.index]),
    AssetWeight(cls: AssetClass.newGrowth, label: '신성장주',   tickers: const [],                     weight: weights[AssetClass.newGrowth.index]),
  ];
}
```

Add the necessary imports at the top of the file.

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze
```

Expected: zero errors. Placeholder is a valid widget.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/onboarding/portfolio_review_screen.dart \
        lib/screens/onboarding/frontier_selection_resolver.dart
git commit -m "Scaffold PortfolioReviewScreen + asset resolver"
```

---

### Task 3.3: Build 포트폴리오 비교 tab content (default)

**Files:**
- Modify: `lib/screens/onboarding/portfolio_review_screen.dart`
- Modify: `lib/screens/onboarding/widgets/portfolio_charts.dart` (extract reusable widget)

- [ ] **Step 1: Extract the comparison chart from `portfolio_charts.dart` into a reusable widget**

In `portfolio_charts.dart`, find the existing comparison chart implementation. Extract it into a public widget `PortfolioComparisonChart` with this signature:

```dart
class PortfolioComparisonChart extends StatefulWidget {
  final List<List<double>> seriesData;     // [portfolio, market, expected, bond]
  final List<DateTime> timeAxis;
  final TimeRange initialRange;            // default 3년
  final bool enablePinchZoom;
  final bool enableHorizontalDrag;

  const PortfolioComparisonChart({
    super.key,
    required this.seriesData,
    required this.timeAxis,
    this.initialRange = TimeRange.threeYear,
    this.enablePinchZoom = true,
    this.enableHorizontalDrag = true,
  });
  // ...
}

enum TimeRange { oneWeek, threeMonth, oneYear, fiveYear, threeYear, all }
```

If `TimeRange` already exists, reuse it; do not duplicate.

- [ ] **Step 2: Replace `_CompareVolatilityTabs.build` placeholder**

In `portfolio_review_screen.dart`, replace the `Placeholder` body:

```dart
@override
Widget build(BuildContext context) {
  final tc = WeRoboThemeColors.of(context);
  return Column(
    children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: WeRoboColors.primary,
            borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
          ),
          labelColor: WeRoboColors.white,
          unselectedLabelColor: tc.textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: '포트폴리오 비교'),
            Tab(text: '변동성'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 320,
        child: TabBarView(
          controller: controller,
          children: [
            _CompareTabBody(selection: selection),
            _VolatilityTabBody(selection: selection),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 3: Implement `_CompareTabBody`**

```dart
class _CompareTabBody extends StatelessWidget {
  final OnboardingFrontierSelection selection;
  const _CompareTabBody({required this.selection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PortfolioComparisonChart(
        seriesData: selection.compareSeries,
        timeAxis: selection.timeAxis,
        initialRange: TimeRange.threeYear,
      ),
    );
  }
}
```

If `selection.compareSeries` doesn't exist, derive it from the resolver — pull portfolio cumulative return + market benchmark + expected return + bond benchmark from the existing data fetch.

- [ ] **Step 4: Run app, verify 비교 tab is default and renders**

```bash
rsync -av --delete --exclude='build/' --exclude='.dart_tool/' \
  /Users/eugenehong/Developer/werobo-monorepo/.claude/worktrees/affectionate-bose-534136/Front-End/robo_mobile/ \
  /Users/eugenehong/Developer/robo_mobile/
flutter hot-restart
```

- [ ] **Step 5: Commit**

```bash
git commit -am "Build 포트폴리오 비교 tab in PortfolioReviewScreen"
```

---

### Task 3.4: Build 변동성 tab with portfolio σ vs market σ overlay

**Files:**
- Modify: `lib/screens/onboarding/portfolio_review_screen.dart`

- [ ] **Step 1: Implement `_VolatilityTabBody`**

```dart
class _VolatilityTabBody extends StatelessWidget {
  final OnboardingFrontierSelection selection;
  const _VolatilityTabBody({required this.selection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PortfolioComparisonChart(
        seriesData: [
          selection.portfolioVolatility,  // List<double> rolling 60d σ
          selection.marketVolatility,     // List<double> market σ overlay
        ],
        timeAxis: selection.timeAxis,
        initialRange: TimeRange.threeYear,
        // Series 0 → primary orange, series 1 → textSecondary gray
      ),
    );
  }
}
```

Required additions to `OnboardingFrontierSelection` (or its resolver/state): `portfolioVolatility` and `marketVolatility` getters returning `List<double>`. If the data isn't yet fetched from backend, add a TODO-tagged stub that returns synthesized data using the existing volatility from the frontier point — but only as a fallback. Real data source is `MobileFrontierPreviewResponse`.

- [ ] **Step 2: Update `PortfolioComparisonChart` to color series 0 orange, series 1 gray**

In `portfolio_charts.dart`, where colors are picked per series, replace the legacy mapping with:

```dart
final seriesColors = [
  WeRoboColors.primary,                       // portfolio
  WeRoboThemeColors.of(context).textSecondary, // market overlay
];
```

For 3+ series (the compare tab), use:
```dart
final seriesColors = [
  WeRoboColors.primary,                        // 포트폴리오
  WeRoboThemeColors.of(context).textSecondary, // 시장
  WeRoboColors.assetTier4,                     // 연 기대수익률
  WeRoboColors.assetTier3,                     // 채권 수익률
];
```

- [ ] **Step 3: Hot-restart, switch to 변동성 tab, verify dual-line render**

- [ ] **Step 4: Commit**

```bash
git commit -am "Build 변동성 tab with portfolio vs market σ overlay"
```

---

### Task 3.5: Add 3-year default + pinch-zoom + horizontal drag

**Files:**
- Modify: `lib/screens/onboarding/widgets/portfolio_charts.dart`

- [ ] **Step 1: Confirm `initialRange: TimeRange.threeYear` honored**

In `PortfolioComparisonChart` `initState`, set the visible window to `widget.initialRange`. Verify the time-range chip selector below the chart shows "3년" highlighted by default.

- [ ] **Step 2: Wrap chart body in `GestureDetector` for pan + pinch**

```dart
return GestureDetector(
  onScaleStart: _onScaleStart,
  onScaleUpdate: _onScaleUpdate,
  onScaleEnd: _onScaleEnd,
  child: CustomPaint(
    painter: _ChartPainter(...),
    size: Size.infinite,
  ),
);
```

State variables:

```dart
double _scale = 1.0;
double _prevScale = 1.0;
double _panOffsetX = 0.0;
double _prevPanOffsetX = 0.0;

void _onScaleStart(ScaleStartDetails d) {
  _prevScale = _scale;
  _prevPanOffsetX = _panOffsetX;
}

void _onScaleUpdate(ScaleUpdateDetails d) {
  setState(() {
    _scale = (_prevScale * d.scale).clamp(0.5, 5.0);
    _panOffsetX = _prevPanOffsetX + d.focalPointDelta.dx;
  });
}

void _onScaleEnd(ScaleEndDetails d) {}
```

The painter consumes `scale` and `panOffsetX` to clip and translate the visible time-axis window. Implementation detail per how `_ChartPainter` already maps time → x: multiply x-step by `_scale` and add `_panOffsetX`.

- [ ] **Step 3: Add a "double-tap to reset" gesture**

```dart
GestureDetector(
  onDoubleTap: () => setState(() {
    _scale = 1.0;
    _panOffsetX = 0.0;
  }),
  child: ...,
);
```

- [ ] **Step 4: Hot-restart and test**

Try pinching, dragging, and double-tapping on the chart. Verify:
- Pinch out zooms in
- Drag pans horizontally
- Double-tap resets

- [ ] **Step 5: Commit**

```bash
git commit -am "Add pinch-zoom, drag, and 3-year default to comparison chart"
```

---

### Task 3.6: Wire 투자 확정 navigation to home

**Files:**
- Modify: `lib/screens/onboarding/portfolio_review_screen.dart`
- Modify: `lib/main.dart` (add `/home` named route)

- [ ] **Step 1: Add named routes to `MaterialApp`**

In `lib/main.dart`, replace the `home: const SplashScreen(),` line with:

```dart
initialRoute: '/',
routes: {
  '/': (_) => const SplashScreen(),
  '/home': (_) => const HomeShell(),
},
```

Add `import 'screens/home/home_shell.dart';` at the top.

- [ ] **Step 2: Confirm `_confirmInvestment` uses the named route**

Already wired in 3.2 via `Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);`. Verify it actually navigates by tapping 투자 확정 in the simulator.

- [ ] **Step 3: Confirm `recordFrontierSelection` exists on `PortfolioState`**

```bash
grep -n "recordFrontierSelection\|setFrontierSelection" lib/app/portfolio_state.dart
```

If missing, add it:

```dart
OnboardingFrontierSelection? _selection;
OnboardingFrontierSelection? get frontierSelection => _selection;

void recordFrontierSelection(OnboardingFrontierSelection s) {
  _selection = s;
  notifyListeners();
}
```

- [ ] **Step 4: Tap through, verify navigation**

Hot-restart, drag dot, tap 투자 확정 → should land on home.

- [ ] **Step 5: Commit**

```bash
git commit -am "Wire 투자 확정 to home with frontier selection persisted"
```

---

### Task 3.7: Update onboarding flow routing to use new screen

**Files:**
- Modify: `lib/screens/onboarding/onboarding_screen.dart`

- [ ] **Step 1: Find the existing post-frontier navigation**

```bash
grep -n "Navigator\." lib/screens/onboarding/onboarding_screen.dart | head
```

There's likely a flow that pushes `LoadingScreen` or `ResultScreen` after the user picks a frontier point.

- [ ] **Step 2: Replace post-frontier navigation with `PortfolioReviewScreen`**

In the "next page" handler (probably the bottom 다음 button on page 1 of the existing 2-page onboarding), replace:

```dart
Navigator.of(context).push(WeRoboMotion.fadeRoute(const ResultScreen(...)));
```

with:

```dart
Navigator.of(context).push(WeRoboMotion.fadeRoute(
  PortfolioReviewScreen(selection: _frontierSelection!),
));
```

If the existing flow goes through `LoadingScreen` first (to wait for backend optimization), keep that intermediate step — `LoadingScreen` then pushes to `PortfolioReviewScreen` instead of `ResultScreen`.

- [ ] **Step 3: Drop the second page of `OnboardingScreen`**

The PDF specifies a single-page frontier interaction. Find `_pageCount = 2` and change to `_pageCount = 1`. Remove the second `PageView` page (likely a confirmation/preview view that's now superseded by `PortfolioReviewScreen`). Remove the `PageController` and `PageView` wrapper if only one page remains — collapse to a `Column`.

- [ ] **Step 4: Hot-restart, walk the flow**

splash → welcome → login → frontier (1 page only) → portfolio review → home.

- [ ] **Step 5: Commit**

```bash
git commit -am "Route onboarding through new PortfolioReviewScreen"
```

---

### Task 3.8: Delete obsolete onboarding screens and tests

**Files:**
- Delete: `lib/screens/onboarding/result_screen.dart`
- Delete: `lib/screens/onboarding/comparison_screen.dart`
- Delete: `lib/screens/onboarding/confirmation_screen.dart`
- Delete: `test/screens/onboarding/comparison_screen_test.dart`

- [ ] **Step 1: Find any remaining imports of the doomed screens**

```bash
cd /Users/eugenehong/Developer/robo_mobile
grep -rn "result_screen\|comparison_screen\|confirmation_screen" lib/ test/
```

Expected: any hits should be in the soon-to-be-deleted files themselves, or already migrated to `PortfolioReviewScreen`.

- [ ] **Step 2: Delete the source files**

```bash
git rm lib/screens/onboarding/result_screen.dart \
       lib/screens/onboarding/comparison_screen.dart \
       lib/screens/onboarding/confirmation_screen.dart \
       test/screens/onboarding/comparison_screen_test.dart
```

- [ ] **Step 3: Run analyzer to find any dangling references**

```bash
flutter analyze
```

Expected: zero errors. If any imports remain, fix them.

- [ ] **Step 4: Run tests**

```bash
flutter test
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git commit -m "Delete obsolete onboarding screens (merged into PortfolioReviewScreen)"
```

---

### Task 3.9: Simplify `onboarding_screen.dart` — strip questionnaire wrapper

**Files:**
- Modify: `lib/screens/onboarding/onboarding_screen.dart`

The current 906-line file likely includes risk-profile questions, target-return picker, tax-bracket inputs alongside the frontier interaction. After Task 3.7's page reduction, only the frontier code should remain.

- [ ] **Step 1: Identify the frontier-only code path**

The frontier interaction is gated by `_frontierPreviewFuture` and uses `EfficientFrontierChart`. Everything else (questionnaire forms, multi-step PageView state) can go.

- [ ] **Step 2: Reduce file to ~200 lines**

Keep:
- `OnboardingFrontierSelection` class (used elsewhere)
- The widget that fetches `_frontierPreviewFuture`
- Frontier chart render + dot drag handler
- Asset weight list (per Task 2.4)
- The 다음 button that navigates to `PortfolioReviewScreen` (per Task 3.7)

Remove:
- All questionnaire UI (risk-profile sliders, target-return picker, tax-bracket inputs)
- The `PageController` / `PageView` shell
- Any unused state variables and helper methods

- [ ] **Step 3: Run analyzer + tests**

```bash
flutter analyze && flutter test
```

Expected: pass.

- [ ] **Step 4: Walk the flow on simulator**

Verify: frontier → drag dot → list updates → 다음 → portfolio review → 투자 확정 → home.

- [ ] **Step 5: Commit**

```bash
git commit -am "Strip questionnaire wrapper from onboarding_screen"
```

- [ ] **Step 6: Tag Phase 3 complete**

```bash
git tag phase-3-portfolio-review
```

---

## Phase 4: Home Dashboard Rework — **DEFERRED (2026-05-05)**

> **🛑 DEFERRED.** All notes under the 홈 section in the PDF are out of scope for this MVP per user direction (2026-05-05). The home tab keeps its current structure and simply inherits the Phase 1 theme reskin (orange/light surfaces, asset tonal palette).
>
> Tasks 4.1–4.6 below are preserved as a reference for the next iteration. **Do not execute them in this plan.** Skip directly to Phase 5 after Phase 3 ships.
>
> Specifically deferred:
> - Removing 현재 자산 / 입금 현황 / +입금하기 / 정기 입금 widgets
> - Adding the realtime portfolio simulation graph at top
> - Adding the 포트폴리오 주요 이슈 알림 timeline
> - Adding the contribution tooltip on graph tap
>
> What ships in this MVP for the home tab: theme-reskinned existing layout. Dashboard rework is a follow-up project.

**Original goal (deferred):** Strip generic-banking widgets (총 자산 amount, 입금 현황 card) from the home tab and replace with a real-time portfolio simulation graph + 포트폴리오 주요 이슈 알림 timeline + contribution tooltip on graph tap. Keep the 포트폴리오 구성 list.

### Task 4.1: Strip banking widgets from `home_tab.dart`

**Files:**
- Modify: `lib/screens/home/home_tab.dart`

- [ ] **Step 1: Identify the banking widgets**

```bash
grep -n "현재 자산\|입금 현황\|+입금하기\|정기 입금\|입금하기" lib/screens/home/home_tab.dart
```

Note line ranges of each block.

- [ ] **Step 2: Delete the banking blocks**

Remove (keep line ranges in commit message for reviewers):
- The `현재 자산` header section + balance figure + ▲▼ delta line
- The `입금 현황` card with 최근 입금 / 예정 입금
- The `+ 입금하기` and `정기 입금` button row

Leave the 포트폴리오 구성 list, the bottom nav, the digest/insight infrastructure entry points.

- [ ] **Step 3: Replace with placeholder for the new top section**

Insert at the very top of the home scroll (where the 현재 자산 block was):

```dart
const _HomeTopSection(), // realtime simulation + tooltip — wired in Task 4.2-4.5
const SizedBox(height: 20),
const _IssueTimeline(), // wired in Task 4.4
const SizedBox(height: 28),
// existing 포트폴리오 구성 list continues here
```

Add stub classes at the bottom of the file:

```dart
class _HomeTopSection extends StatelessWidget {
  const _HomeTopSection();
  @override
  Widget build(BuildContext context) => const Placeholder(fallbackHeight: 240);
}

class _IssueTimeline extends StatelessWidget {
  const _IssueTimeline();
  @override
  Widget build(BuildContext context) => const Placeholder(fallbackHeight: 200);
}
```

- [ ] **Step 4: Run analyzer + tests**

```bash
flutter analyze && flutter test
```

Expected: `home_tab_test.dart` may need updates if it asserts on the deleted blocks. Adjust the test to assert the new structure (ports of `_HomeTopSection` and `_IssueTimeline` rendered).

- [ ] **Step 5: Commit**

```bash
git commit -am "Strip banking widgets from home tab (data diet)"
```

---

### Task 4.2: Create `RealtimeSimulationGraph` widget

**Files:**
- Create: `lib/screens/home/widgets/realtime_simulation_graph.dart`
- Create: `test/screens/home/widgets/realtime_simulation_graph_test.dart`

- [ ] **Step 1: Write the widget**

```dart
// lib/screens/home/widgets/realtime_simulation_graph.dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class SimulationPoint {
  final DateTime time;
  final double cumulativeReturn; // e.g. 0.092 = +9.2%
  final bool isVolatile;          // flagged by σ-detection backend

  const SimulationPoint({
    required this.time,
    required this.cumulativeReturn,
    this.isVolatile = false,
  });
}

class RealtimeSimulationGraph extends StatelessWidget {
  final List<SimulationPoint> series;
  final ValueChanged<SimulationPoint>? onPointTap;

  const RealtimeSimulationGraph({
    super.key,
    required this.series,
    this.onPointTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTapUp: (details) => _handleTap(details, context),
        child: CustomPaint(
          painter: _SimulationPainter(series: series),
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    if (onPointTap == null || series.isEmpty) return;
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width;
    final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
    final idx = (ratio * (series.length - 1)).round();
    onPointTap!(series[idx]);
  }
}

class _SimulationPainter extends CustomPainter {
  final List<SimulationPoint> series;
  _SimulationPainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final returns = series.map((p) => p.cumulativeReturn).toList();
    final minR = returns.reduce((a, b) => a < b ? a : b);
    final maxR = returns.reduce((a, b) => a > b ? a : b);
    final range = (maxR - minR).abs() < 1e-6 ? 1.0 : maxR - minR;

    final stepX = size.width / (series.length - 1);
    Offset xy(int i) => Offset(
          i * stepX,
          size.height - ((returns[i] - minR) / range) * size.height,
        );

    final path = Path()..moveTo(xy(0).dx, xy(0).dy);
    for (var i = 1; i < series.length; i++) {
      path.lineTo(xy(i).dx, xy(i).dy);
    }

    final linePaint = Paint()
      ..color = WeRoboColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Volatility markers — small filled circles on flagged points
    final markerPaint = Paint()..color = WeRoboColors.primary;
    for (var i = 0; i < series.length; i++) {
      if (series[i].isVolatile) {
        canvas.drawCircle(xy(i), 4.5, markerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimulationPainter oldDelegate) =>
      oldDelegate.series != series;
}
```

- [ ] **Step 2: Write a basic widget test**

```dart
// test/screens/home/widgets/realtime_simulation_graph_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/screens/home/widgets/realtime_simulation_graph.dart';

void main() {
  testWidgets('renders without exception with empty series', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RealtimeSimulationGraph(series: [])),
    ));
    expect(find.byType(RealtimeSimulationGraph), findsOneWidget);
  });

  testWidgets('invokes onPointTap with the nearest point', (tester) async {
    SimulationPoint? tapped;
    final series = List.generate(10, (i) => SimulationPoint(
      time: DateTime(2026, 5, i + 1),
      cumulativeReturn: i * 0.01,
    ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(
        width: 400, height: 200,
        child: RealtimeSimulationGraph(
          series: series,
          onPointTap: (p) => tapped = p,
        ),
      )),
    ));
    await tester.tapAt(const Offset(400, 100)); // far right
    expect(tapped, isNotNull);
    expect(tapped!.cumulativeReturn, closeTo(0.09, 0.005)); // last point
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/screens/home/widgets/realtime_simulation_graph_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/widgets/realtime_simulation_graph.dart \
        test/screens/home/widgets/realtime_simulation_graph_test.dart
git commit -m "Add RealtimeSimulationGraph widget"
```

---

### Task 4.3: Create `ContributionTooltip` widget

**Files:**
- Create: `lib/screens/home/widgets/contribution_tooltip.dart`
- Create: `test/screens/home/widgets/contribution_tooltip_test.dart`

- [ ] **Step 1: Define data model**

```dart
// lib/screens/home/widgets/contribution_tooltip.dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class ContributionEntry {
  final AssetClass cls;
  final String label;
  final double weight;     // 0.0–1.0
  final double assetReturn; // signed, e.g. -0.078 = -7.8%
  final double krwImpact;   // 비중 × 수익률 × 포트폴리오 가치 = ₩
  final bool isOutlier;     // true if asset moved >2× its 60d rolling σ

  const ContributionEntry({
    required this.cls,
    required this.label,
    required this.weight,
    required this.assetReturn,
    required this.krwImpact,
    this.isOutlier = false,
  });
}
```

- [ ] **Step 2: Build the tooltip widget**

```dart
class ContributionTooltip extends StatelessWidget {
  final List<ContributionEntry> top2;
  final bool dataValidationCaveat; // 신성장주 caveat

  const ContributionTooltip({
    super.key,
    required this.top2,
    this.dataValidationCaveat = false,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
        boxShadow: WeRoboElevation.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('주요 기여 자산', style: WeRoboTypography.heading3.themed(context)),
          const SizedBox(height: 12),
          for (final e in top2) _ContributionRow(entry: e, tc: tc),
          if (dataValidationCaveat) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: WeRoboColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
              ),
              child: Text(
                '신성장주 데이터 정합성 검토 중',
                style: WeRoboTypography.caption.copyWith(color: tc.textPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final ContributionEntry entry;
  final WeRoboThemeColors tc;
  const _ContributionRow({required this.entry, required this.tc});

  @override
  Widget build(BuildContext context) {
    final pct = (entry.assetReturn * 100).toStringAsFixed(1);
    final krwSign = entry.krwImpact >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: WeRoboColors.assetColor(entry.cls),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(entry.label, style: WeRoboTypography.bodySmall.themed(context)),
                if (entry.isOutlier) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: WeRoboColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(WeRoboColors.radiusS),
                    ),
                    child: Text(
                      '이례적',
                      style: WeRoboTypography.caption.copyWith(
                        color: WeRoboColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${entry.assetReturn >= 0 ? '+' : ''}$pct%  (${krwSign}₩${entry.krwImpact.abs().toStringAsFixed(0)})',
            style: WeRoboTypography.bodySmall.copyWith(
              fontFamily: WeRoboFonts.number,
              color: tc.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write a widget test**

```dart
// test/screens/home/widgets/contribution_tooltip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/widgets/contribution_tooltip.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders top 2 contributors with sign and impact', (tester) async {
    await tester.pumpWidget(_wrap(const ContributionTooltip(top2: [
      ContributionEntry(cls: AssetClass.usValue, label: '미국가치주',
        weight: 0.077, assetReturn: 0.078, krwImpact: 60100),
      ContributionEntry(cls: AssetClass.cash, label: '현금성자산',
        weight: 0.30, assetReturn: -0.012, krwImpact: -3600),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('미국가치주'), findsOneWidget);
    expect(find.text('현금성자산'), findsOneWidget);
    expect(find.textContaining('+7.8%'), findsOneWidget);
    expect(find.textContaining('-1.2%'), findsOneWidget);
  });

  testWidgets('shows 신성장주 caveat when flagged', (tester) async {
    await tester.pumpWidget(_wrap(const ContributionTooltip(
      top2: [ContributionEntry(cls: AssetClass.newGrowth, label: '신성장주',
        weight: 0.05, assetReturn: 0.15, krwImpact: 75000)],
      dataValidationCaveat: true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('신성장주 데이터 정합성 검토 중'), findsOneWidget);
  });

  testWidgets('shows 이례적 badge for outliers', (tester) async {
    await tester.pumpWidget(_wrap(const ContributionTooltip(top2: [
      ContributionEntry(cls: AssetClass.cash, label: '현금성자산',
        weight: 0.30, assetReturn: 0.05, krwImpact: 15000, isOutlier: true),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('이례적'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/screens/home/widgets/contribution_tooltip_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home/widgets/contribution_tooltip.dart \
        test/screens/home/widgets/contribution_tooltip_test.dart
git commit -m "Add ContributionTooltip widget with outlier badge and caveat"
```

---

### Task 4.4: Create `IssueTimeline` widget

**Files:**
- Create: `lib/screens/home/widgets/issue_timeline.dart`
- Create: `test/screens/home/widgets/issue_timeline_test.dart`

- [ ] **Step 1: Build the widget**

```dart
// lib/screens/home/widgets/issue_timeline.dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

enum IssueKind { alert, info, news }

class IssueItem {
  final IssueKind kind;
  final DateTime time;
  final String headline;
  final String? detail;

  const IssueItem({
    required this.kind,
    required this.time,
    required this.headline,
    this.detail,
  });
}

class IssueTimeline extends StatelessWidget {
  final List<IssueItem> items;

  const IssueTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text('최근 알림이 없어요',
            style: WeRoboTypography.bodySmall.themed(context)),
      );
    }
    final sorted = [...items]..sort((a, b) => b.time.compareTo(a.time));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('포트폴리오 주요 이슈 알림',
              style: WeRoboTypography.heading3.themed(context)),
          const SizedBox(height: 12),
          for (final item in sorted) _IssueRow(item: item, tc: tc),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final IssueItem item;
  final WeRoboThemeColors tc;
  const _IssueRow({required this.item, required this.tc});

  @override
  Widget build(BuildContext context) {
    final dotColor = item.kind == IssueKind.alert
        ? WeRoboColors.primary
        : tc.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatTime(item.time),
                    style: WeRoboTypography.caption.themed(context)),
                const SizedBox(height: 2),
                Text(item.headline,
                    style: WeRoboTypography.bodySmall.themed(context).copyWith(
                          color: tc.textPrimary,
                          fontWeight: FontWeight.w500,
                        )),
                if (item.detail != null) ...[
                  const SizedBox(height: 4),
                  Text(item.detail!,
                      style: WeRoboTypography.caption.themed(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final d = t.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 2: Write tests**

```dart
// test/screens/home/widgets/issue_timeline_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/widgets/issue_timeline.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows empty state when no items', (tester) async {
    await tester.pumpWidget(_wrap(const IssueTimeline(items: [])));
    expect(find.text('최근 알림이 없어요'), findsOneWidget);
  });

  testWidgets('renders items sorted newest first', (tester) async {
    final items = [
      IssueItem(kind: IssueKind.alert, time: DateTime(2026, 5, 1), headline: '오래된'),
      IssueItem(kind: IssueKind.info,  time: DateTime(2026, 5, 4), headline: '최근'),
    ];
    await tester.pumpWidget(_wrap(IssueTimeline(items: items)));
    final recentY = tester.getTopLeft(find.text('최근')).dy;
    final oldY = tester.getTopLeft(find.text('오래된')).dy;
    expect(recentY, lessThan(oldY));
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/screens/home/widgets/issue_timeline_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/widgets/issue_timeline.dart \
        test/screens/home/widgets/issue_timeline_test.dart
git commit -m "Add IssueTimeline widget"
```

---

### Task 4.5: Wire graph tap → ContributionTooltip in home tab

**Files:**
- Modify: `lib/screens/home/home_tab.dart`

- [ ] **Step 1: Replace `_HomeTopSection` placeholder with real wiring**

```dart
class _HomeTopSection extends StatefulWidget {
  const _HomeTopSection();
  @override
  State<_HomeTopSection> createState() => _HomeTopSectionState();
}

class _HomeTopSectionState extends State<_HomeTopSection> {
  ContributionEntry? _tooltipTop1;
  ContributionEntry? _tooltipTop2;
  bool _tooltipCaveat = false;

  void _handlePointTap(SimulationPoint point) {
    if (!point.isVolatile) {
      setState(() { _tooltipTop1 = null; _tooltipTop2 = null; });
      return;
    }
    final state = PortfolioStateProvider.of(context);
    final analysis = state.contributionAnalysisAt(point.time);
    setState(() {
      _tooltipTop1 = analysis?.top1;
      _tooltipTop2 = analysis?.top2;
      _tooltipCaveat = analysis?.containsNewGrowth ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = PortfolioStateProvider.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: RealtimeSimulationGraph(
            series: state.simulationSeries,
            onPointTap: _handlePointTap,
          ),
        ),
        if (_tooltipTop1 != null) ...[
          const SizedBox(height: 12),
          ContributionTooltip(
            top2: [_tooltipTop1!, if (_tooltipTop2 != null) _tooltipTop2!],
            dataValidationCaveat: _tooltipCaveat,
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 2: Add `simulationSeries` and `contributionAnalysisAt` to `PortfolioState`**

In `lib/app/portfolio_state.dart`, add:

```dart
class ContributionAnalysis {
  final ContributionEntry top1;
  final ContributionEntry? top2;
  final bool containsNewGrowth;

  const ContributionAnalysis({
    required this.top1,
    this.top2,
    this.containsNewGrowth = false,
  });
}

class PortfolioState extends ChangeNotifier {
  // ... existing fields ...

  List<SimulationPoint> _simulationSeries = const [];
  List<SimulationPoint> get simulationSeries => _simulationSeries;

  ContributionAnalysis? contributionAnalysisAt(DateTime time) {
    // Backend returns this; for now, return null until the API is wired.
    // Real implementation: call MobileBackendApi.fetchContributionAnalysis(time)
    // and cache responses by time. Out of scope for the UI plan — backend ticket.
    return null;
  }
}
```

The actual contribution lookup is a backend call; the UI handles the null case by hiding the tooltip.

- [ ] **Step 3: Replace `_IssueTimeline` placeholder**

```dart
class _IssueTimeline extends StatelessWidget {
  const _IssueTimeline();
  @override
  Widget build(BuildContext context) {
    final state = PortfolioStateProvider.of(context);
    return IssueTimeline(items: state.issueItems);
  }
}
```

Add `List<IssueItem> get issueItems => _issueItems;` (with `_issueItems = const []` default) to `PortfolioState`.

- [ ] **Step 4: Add necessary imports to `home_tab.dart`**

```dart
import 'widgets/realtime_simulation_graph.dart';
import 'widgets/contribution_tooltip.dart';
import 'widgets/issue_timeline.dart';
```

- [ ] **Step 5: Hot-restart, navigate to home, verify**

App should land on home with: simulation graph at top (initially flat-line if no data), placeholder timeline section ("최근 알림이 없어요"), 포트폴리오 구성 list below. Tapping the graph does nothing visible until backend wires up `contributionAnalysisAt`.

- [ ] **Step 6: Commit**

```bash
git commit -am "Wire home graph tap → tooltip and issue timeline"
```

---

### Task 4.6: Verify home tab integration end-to-end

- [ ] **Step 1: Update `home_tab_test.dart`** to assert the new structure

```bash
grep -n "현재 자산\|입금" test/screens/home/home_tab_test.dart
```

If the test asserts on deleted blocks, update to assert presence of `RealtimeSimulationGraph` and `IssueTimeline`:

```dart
expect(find.byType(RealtimeSimulationGraph), findsOneWidget);
expect(find.byType(IssueTimeline), findsOneWidget);
```

- [ ] **Step 2: Run analyzer + tests**

```bash
flutter analyze && flutter test
```

Expected: pass.

- [ ] **Step 3: Manual smoke test**

Walk: splash → login → frontier → portfolio review → home. Confirm new home structure renders.

- [ ] **Step 4: Tag Phase 4 complete**

```bash
git tag phase-4-home
```

---

## Phase 5: Alert UI

**Goal:** Build the user-facing alert frequency selector in settings (자주 받기 / 보통 / 중요할 때만), persist the choice in `PortfolioState`, add the unread-긴급-alert nav badge, hook up the 신성장주 caveat path, and emit post-launch tuning analytics. Restyle existing digest/insight pages.

### Task 5.1: Add `AlertFrequency` enum + persistence

**Files:**
- Modify: `lib/app/portfolio_state.dart`
- Create: `test/app/portfolio_state_alert_frequency_test.dart`

- [ ] **Step 1: Define enum + getter/setter**

In `portfolio_state.dart`, add at the top:

```dart
/// User-facing alert frequency setting. Maps internally to a σ threshold.
enum AlertFrequency {
  often,    // 자주 받기 → 1.5σ → ~월 2-3회
  normal,   // 보통 → 2.0σ → ~월 1-2회 (default)
  important; // 중요할 때만 → 3.0σ → ~분기 1회

  double get sigmaThreshold => switch (this) {
        AlertFrequency.often => 1.5,
        AlertFrequency.normal => 2.0,
        AlertFrequency.important => 3.0,
      };

  String get koLabel => switch (this) {
        AlertFrequency.often => '자주 받기',
        AlertFrequency.normal => '보통',
        AlertFrequency.important => '중요할 때만',
      };
}
```

In `PortfolioState`, add the field and methods:

```dart
AlertFrequency _alertFrequency = AlertFrequency.normal;
AlertFrequency get alertFrequency => _alertFrequency;

Future<void> setAlertFrequency(AlertFrequency f) async {
  if (_alertFrequency == f) return;
  _alertFrequency = f;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('alertFrequency', f.name);
  notifyListeners();
}

Future<void> _restoreAlertFrequency() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('alertFrequency');
  if (raw != null) {
    _alertFrequency = AlertFrequency.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => AlertFrequency.normal,
    );
  }
}
```

In the existing `restorePersistedState()`, call `await _restoreAlertFrequency();`.

If `shared_preferences` isn't already a dependency, add to `pubspec.yaml`:

```yaml
dependencies:
  shared_preferences: ^2.2.0
```

Then `flutter pub get`.

- [ ] **Step 2: Write tests**

```dart
// test/app/portfolio_state_alert_frequency_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to normal', () {
    final state = PortfolioState();
    expect(state.alertFrequency, AlertFrequency.normal);
  });

  test('setAlertFrequency persists across restore', () async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    await state.setAlertFrequency(AlertFrequency.important);
    expect(state.alertFrequency, AlertFrequency.important);

    final freshState = PortfolioState();
    await freshState.restorePersistedState();
    expect(freshState.alertFrequency, AlertFrequency.important);
  });

  test('sigma thresholds match spec', () {
    expect(AlertFrequency.often.sigmaThreshold, 1.5);
    expect(AlertFrequency.normal.sigmaThreshold, 2.0);
    expect(AlertFrequency.important.sigmaThreshold, 3.0);
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/app/portfolio_state_alert_frequency_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/app/portfolio_state.dart pubspec.yaml \
        test/app/portfolio_state_alert_frequency_test.dart
git commit -m "Add AlertFrequency enum with σ mapping and persistence"
```

---

### Task 5.2: Create `AlertFrequencySelector` widget

**Files:**
- Create: `lib/screens/home/widgets/alert_frequency_selector.dart`
- Create: `test/screens/home/widgets/alert_frequency_selector_test.dart`

- [ ] **Step 1: Build the segmented selector**

```dart
// lib/screens/home/widgets/alert_frequency_selector.dart
import 'package:flutter/material.dart';
import '../../../app/portfolio_state.dart';
import '../../../app/theme.dart';

class AlertFrequencySelector extends StatelessWidget {
  final AlertFrequency value;
  final ValueChanged<AlertFrequency> onChanged;

  const AlertFrequencySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final f in AlertFrequency.values)
            Expanded(child: _Segment(
              label: f.koLabel,
              selected: f == value,
              onTap: () => onChanged(f),
            )),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: WeRoboMotion.short,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? WeRoboColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: WeRoboTypography.bodySmall.copyWith(
            color: selected ? WeRoboColors.white : tc.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write a tap test**

```dart
// test/screens/home/widgets/alert_frequency_selector_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/widgets/alert_frequency_selector.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: child)),
    );

void main() {
  testWidgets('renders three labels', (tester) async {
    await tester.pumpWidget(_wrap(AlertFrequencySelector(
      value: AlertFrequency.normal,
      onChanged: (_) {},
    )));
    expect(find.text('자주 받기'), findsOneWidget);
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('중요할 때만'), findsOneWidget);
  });

  testWidgets('tap fires onChanged with correct value', (tester) async {
    AlertFrequency? selected;
    await tester.pumpWidget(_wrap(AlertFrequencySelector(
      value: AlertFrequency.normal,
      onChanged: (f) => selected = f,
    )));
    await tester.tap(find.text('중요할 때만'));
    expect(selected, AlertFrequency.important);
  });
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/screens/home/widgets/alert_frequency_selector_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home/widgets/alert_frequency_selector.dart \
        test/screens/home/widgets/alert_frequency_selector_test.dart
git commit -m "Add AlertFrequencySelector segmented control"
```

---

### Task 5.3: Add 알림 빈도 section to settings tab

**Files:**
- Modify: `lib/screens/home/settings_tab.dart`

- [ ] **Step 1: Add the section**

```dart
import '../../app/portfolio_state.dart';
import 'widgets/alert_frequency_selector.dart';

// inside the settings tab build, in the appropriate section:
ListenableBuilder(
  listenable: PortfolioStateProvider.of(context),
  builder: (context, _) {
    final state = PortfolioStateProvider.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('알림 빈도', style: WeRoboTypography.heading3.themed(context)),
        const SizedBox(height: 4),
        Text(
          '시장이 흔들릴 때 얼마나 자주 알려드릴지 골라주세요',
          style: WeRoboTypography.caption.themed(context),
        ),
        const SizedBox(height: 12),
        AlertFrequencySelector(
          value: state.alertFrequency,
          onChanged: (f) => state.setAlertFrequency(f),
        ),
      ],
    );
  },
),
```

Place this above or below the existing auto-rebalancing toggle, with 24px vertical separation.

- [ ] **Step 2: Hot-restart, navigate to settings, change selection**

Verify: tapping "중요할 때만" highlights it, persists across app restart.

- [ ] **Step 3: Commit**

```bash
git commit -am "Add 알림 빈도 section to settings tab"
```

---

### Task 5.4: Add unread-긴급 nav badge to `home_shell.dart`

**Files:**
- Modify: `lib/screens/home/home_shell.dart`
- Modify: `lib/app/portfolio_state.dart`

- [ ] **Step 1: Add `hasUnreadEmergencyAlert` to `PortfolioState`**

```dart
bool _hasUnreadEmergencyAlert = false;
bool get hasUnreadEmergencyAlert => _hasUnreadEmergencyAlert;

void markEmergencyAlertSeen() {
  if (!_hasUnreadEmergencyAlert) return;
  _hasUnreadEmergencyAlert = false;
  notifyListeners();
}

// Backend will call setHasUnreadEmergencyAlert(true) when a 긴급 alert lands;
// for now expose a setter for the simulator.
void setHasUnreadEmergencyAlert(bool v) {
  if (_hasUnreadEmergencyAlert == v) return;
  _hasUnreadEmergencyAlert = v;
  notifyListeners();
}
```

- [ ] **Step 2: Render a dot badge on the 홈 tab icon**

In `home_shell.dart`, find the `BottomNavigationBarItem` for 홈 and wrap the icon with a `Stack`:

```dart
BottomNavigationBarItem(
  icon: ListenableBuilder(
    listenable: PortfolioStateProvider.of(context),
    builder: (context, _) {
      final hasAlert = PortfolioStateProvider.of(context).hasUnreadEmergencyAlert;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.home_outlined),
          if (hasAlert)
            Positioned(
              right: -4, top: -2,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: WeRoboColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
    },
  ),
  label: '홈',
),
```

- [ ] **Step 3: Hot-restart, manually test badge**

Add a temporary debug button in `home_tab.dart` (or settings) that calls `state.setHasUnreadEmergencyAlert(true)`. Confirm the dot appears. Tap home, then tap a placeholder "mark seen" button → dot disappears. Remove debug buttons before commit.

- [ ] **Step 4: Commit**

```bash
git commit -am "Add unread 긴급-alert dot badge on 홈 tab"
```

---

### Task 5.5: 신성장주 caveat — partially deferred

The contribution tooltip lives in deferred Phase 4. This task scopes down to a small preparation pass: define the `ContributionAnalysis` model in `PortfolioState` so the data shape is locked in, with the caveat handling documented for whoever lands Phase 4 later.

**Files:**
- Modify: `lib/app/portfolio_state.dart`

- [ ] **Step 1: Define the model + stub method**

Add to `lib/app/portfolio_state.dart`:

```dart
/// Top-N contribution analysis for a moment in the portfolio simulation.
/// Consumed by Phase 4 (deferred) ContributionTooltip widget.
class ContributionAnalysis {
  final List<ContributionEntry> topEntries; // sorted by |krwImpact| desc
  final bool containsNewGrowth;             // drives "데이터 정합성 검토 중" caveat

  const ContributionAnalysis({
    required this.topEntries,
    required this.containsNewGrowth,
  });

  factory ContributionAnalysis.fromEntries(List<ContributionEntry> entries) {
    final top = [...entries]
      ..sort((a, b) => b.krwImpact.abs().compareTo(a.krwImpact.abs()));
    final top2 = top.take(2).toList();
    return ContributionAnalysis(
      topEntries: top2,
      containsNewGrowth: top2.any((e) => e.cls == AssetClass.newGrowth),
    );
  }
}

class ContributionEntry {
  final AssetClass cls;
  final String label;
  final double weight;
  final double assetReturn;
  final double krwImpact;
  final bool isOutlier;

  const ContributionEntry({
    required this.cls,
    required this.label,
    required this.weight,
    required this.assetReturn,
    required this.krwImpact,
    this.isOutlier = false,
  });
}
```

The model lives in `portfolio_state.dart` (not a Phase-4 widget file) so it's available for the eventual home tab rework without that being a blocker.

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git commit -am "Define ContributionAnalysis model with 신성장주 caveat flag"
```

---

### Task 5.6: Add post-launch tuning analytics service (no wiring)

The wiring point (graph tap) lives in deferred Phase 4. This task creates the standalone `AlertAnalytics` service so backend integration can land independently.

**Files:**
- Create: `lib/services/alert_analytics.dart`

- [ ] **Step 1: Create the service**

```dart
// lib/services/alert_analytics.dart
import 'dart:developer' as dev;
import '../app/portfolio_state.dart';

/// Records alert-event payloads so σ thresholds can be tuned post-launch
/// (DESIGN.md §Alert / Digest System → Post-launch tuning analytics).
///
/// Wiring into the home tab graph tap is part of the deferred Phase 4
/// home dashboard rework. Until then, this service is callable from
/// settings (e.g., when user changes 알림 빈도) for early telemetry.
class AlertAnalytics {
  AlertAnalytics._();
  static final instance = AlertAnalytics._();

  /// Called when an alert is shown to the user.
  Future<void> recordShown({
    required double sigma,
    required AlertFrequency userPreference,
  }) async {
    // Backend TODO: POST /api/v1/analytics/alert-shown
    dev.log('[alert] shown sigma=$sigma pref=${userPreference.name}',
        name: 'AlertAnalytics');
  }

  /// Called when the user opens, dismisses, or acts on an alert.
  Future<void> recordInteraction({
    required double sigma,
    required AlertInteraction kind,
  }) async {
    dev.log('[alert] ${kind.name} sigma=$sigma', name: 'AlertAnalytics');
  }

  /// Called when the user changes alert frequency in settings.
  /// Useful telemetry independent of Phase 4 wiring.
  Future<void> recordPreferenceChange(AlertFrequency f) async {
    dev.log('[alert] preference=${f.name}', name: 'AlertAnalytics');
  }
}

enum AlertInteraction { opened, dismissed, actedOn }
```

- [ ] **Step 2: Wire `recordPreferenceChange` from the settings selector**

In `lib/app/portfolio_state.dart`, update `setAlertFrequency` to emit:

```dart
import '../services/alert_analytics.dart';
// ...
Future<void> setAlertFrequency(AlertFrequency f) async {
  if (_alertFrequency == f) return;
  _alertFrequency = f;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('alertFrequency', f.name);
  await AlertAnalytics.instance.recordPreferenceChange(f);
  notifyListeners();
}
```

Phase 4 (deferred) will additionally wire `recordShown` and `recordInteraction` from the contribution tooltip when it's built.

- [ ] **Step 3: Run tests**

```bash
flutter test
```

Expected: pass (the existing `setAlertFrequency` test should still pass — the analytics call is fire-and-forget).

- [ ] **Step 4: Commit**

```bash
git add lib/services/alert_analytics.dart lib/app/portfolio_state.dart
git commit -m "Add AlertAnalytics service + emit on preference change"
```

---

### Task 5.7: Restyle digest/insight pages

The existing digest/insight infrastructure works; only the visual treatment needs to follow the new theme. Phase 1 already recolored most of it via theme tokens — this task is a verification + polish pass.

**Files:**
- Modify: `lib/screens/home/digest_screen.dart`
- Modify: `lib/screens/home/insight_history_page.dart`
- Modify: `lib/screens/home/insight_detail_page.dart`
- Modify: `lib/screens/home/widgets/digest_loading.dart`
- Modify: `lib/screens/home/widgets/driver_card.dart`

- [ ] **Step 1: Open each file and search for hardcoded colors**

```bash
cd /Users/eugenehong/Developer/robo_mobile
grep -nE "Color\(0xff|Colors\.(blue|green|red|orange|purple)" lib/screens/home/digest_screen.dart lib/screens/home/insight_*.dart lib/screens/home/widgets/digest_loading.dart lib/screens/home/widgets/driver_card.dart
```

For each hardcoded color, replace with the appropriate theme/asset/status token:
- Blue → `WeRoboColors.primary`
- Green for gain → `WeRoboColors.accent` (kept) or `WeRoboThemeColors.of(context).accent`
- Asset-specific → `WeRoboColors.assetColor(AssetClass.X)`

- [ ] **Step 2: Manually walk the digest flow**

Hot-restart, open digest screen (likely via insight history or a button on home). Verify: orange brand color, light background, no blue residue, asset-tonal coloring on driver cards.

- [ ] **Step 3: Run tests**

```bash
flutter test
```

If `insight_detail_page_test.dart` asserts on specific colors, update assertions to match the new tokens.

- [ ] **Step 4: Commit**

```bash
git commit -am "Restyle digest/insight pages with new theme tokens"
```

- [ ] **Step 5: Tag Phase 5 complete**

```bash
git tag phase-5-alerts
```

---

## Phase 6: Polish & Verification

**Goal:** Pass full lint + test suite, walk every screen in light + dark mode, verify acceptance criteria, capture after-screenshots.

### Task 6.1: `flutter analyze` clean

- [ ] **Step 1: Run analyzer**

```bash
cd /Users/eugenehong/Developer/robo_mobile && flutter analyze
```

- [ ] **Step 2: Fix every warning, info, and error**

Don't suppress with `// ignore:` unless absolutely necessary. Treat info-level issues as work to do (unused imports, deprecated APIs, etc.).

- [ ] **Step 3: Re-run until clean**

```bash
flutter analyze
```

Expected: `No issues found!`.

- [ ] **Step 4: Commit any fixes**

```bash
git commit -am "Pass flutter analyze with zero issues"
```

---

### Task 6.2: `flutter test` passes

- [ ] **Step 1: Run all tests**

```bash
flutter test
```

- [ ] **Step 2: Fix every failing test**

For each failure, decide:
- Test assertion is stale (asserts on deleted UI / old colors) → update the assertion
- Test exposes a real bug → fix the source

Do not delete tests to make them pass. If a test is no longer meaningful (e.g., it tested a deleted `comparison_screen` — already handled in 3.8), confirm it's already deleted.

- [ ] **Step 3: Commit fixes**

```bash
git commit -am "Pass full test suite"
```

---

### Task 6.3: Manual full-flow walkthrough on iPhone 17 Pro

- [ ] **Step 1: Sync + run**

```bash
rsync -av --delete --exclude='build/' --exclude='.dart_tool/' \
  /Users/eugenehong/Developer/werobo-monorepo/.claude/worktrees/affectionate-bose-534136/Front-End/robo_mobile/ \
  /Users/eugenehong/Developer/robo_mobile/
cd /Users/eugenehong/Developer/robo_mobile && flutter run -d 6BFFDF4C-A1E8-4031-8883-6C660465972B
```

- [ ] **Step 2: Walk each screen and capture an after-screenshot**

| # | Screen | Verify |
|---|--------|--------|
| 1 | Splash | Orange logo, warm background |
| 2 | Welcome | Light background, orange CTA |
| 3 | Login | Form readable, orange CTA, preview-mode link visible |
| 4 | Frontier (single page) | 1:3 horizontal chart, smooth orange curve, 7 asset bubbles in defensive→aggressive order, no bubble grow / no % labels, bar segments resize as dot drags |
| 5 | Portfolio review | **Donut on top, asset list below (vertical)**, 비교 tab default, 변동성 tab dual-line, 3년 default range, pinch-zoom works |
| 6 | Home (theme-reskinned only — full rework deferred) | Existing layout intact (총 자산, 입금 현황 still present) but in orange/light theme, no sky-blue residue |
| 7 | 포트폴리오 tab | Restyled portfolio composition |
| 8 | 커뮤니티 tab | Restyled, no critical regressions |
| 9 | 설정 tab | 알림 빈도 segmented control visible, persists across restart |
| 10 | Digest screen | Orange theme, no blue residue |
| 11 | Insight history / detail | Orange theme, asset tonal coloring on driver cards |

- [ ] **Step 3: Note any regressions**

If anything looks broken, file as a Phase 6.x bug and fix before signing off.

- [ ] **Step 4: Save after-screenshots**

Save each as `after-<screen>.png`. Compare against the `before-` set captured in Pre-flight Step 4.

---

### Task 6.4: Dark mode verification pass

- [ ] **Step 1: Open the app**

In the running app, navigate to settings and toggle to dark mode (the existing toggle in settings_tab; if missing, temporarily enable via debug menu or devtools to set `themeMode: ThemeMode.dark` in main).

- [ ] **Step 2: Walk the same 11 screens in dark mode**

Verify on each:
- Background is warm `#1A1919` (not pure black)
- Cards are `#232020`
- Text contrast adequate (WCAG AA at minimum)
- Orange brand color reads correctly on dark
- No light-mode-only color leaks (e.g., `#FFFFFF` text on `#FFFFFF` surface)

- [ ] **Step 3: Note + fix any dark-mode-only regressions**

---

### Task 6.5: Acceptance criteria checklist

From the spec ([§6](../specs/2026-05-04-ui-ux-overhaul-design.md#6-acceptance-criteria)):

- [ ] Every screen reachable from the new flow renders correctly in light + dark mode without sky-blue artifacts
- [ ] `flutter analyze` clean
- [ ] All existing widget tests still pass
- [ ] New flow: splash → welcome → login → frontier → 포트폴리오 비중 확인 → home (no detours through deleted screens)
- [ ] Frontier: **1:3 aspect**, smooth curve, **7 asset bubbles in defensive→aggressive order** (cash leftmost, 신성장주 rightmost — bug fix verified), **no bubble grow animation, no % labels**, bar segments below resize as dot drags
- [ ] 포트폴리오 비중 확인: **donut on top + list below (vertical)**, 비교 tab default, 변동성 tab dual-line, 3년 default range, pinch-zoom works
- [ ] Home: theme-reskinned only — full dashboard rework deferred per 2026-05-05 user direction
- [ ] Settings: 알림 빈도 selector with 자주 / 보통 / 중요할 때만 visible and persistent across app restarts
- [ ] Bottom-nav 홈 tab shows unread-긴급-alert dot when unread 긴급 exists
- [ ] `ContributionAnalysis` model present in PortfolioState with 신성장주 caveat flag (tooltip itself deferred)
- [ ] `AlertAnalytics` service present and wired to alert-frequency change
- [ ] No screen exposes raw σ to the user

- [ ] **Final commit + tag**

```bash
git commit --allow-empty -m "Phase 6 complete: UI/UX overhaul ready for review"
git tag mvp-2026-05-28
```

---

## Done

The branch is ready for PR. Open one with the title:

> **Capstone UI/UX overhaul: orange brand + PDF-driven UX rework**

Body should reference the spec doc and include before/after screenshots from Tasks 6.3-6.4. Ship target: 2026-05-28.
