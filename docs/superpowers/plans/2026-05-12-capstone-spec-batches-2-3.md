# Capstone 2026-05-12 Spec — Batches 2 + 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the remaining items from the capstone 2026-05-12 service plan: the high-risk acknowledgement modal, the portfolio detail split with donut animation, the home stat block reorg with ALFIN logo, and the market volatility addition on 내 포트폴리오.

**Architecture:** Six independent tasks. Each touches a different screen or widget and can be dispatched to a fresh subagent without conflict. No shared state changes beyond the existing theme tokens.

**Tech Stack:** Flutter, Dart. Existing patterns: `StatefulWidget` for screens with controllers, `Navigator.push` with `WeRoboMotion.fadeRoute` for transitions, `WeRoboColors`/`WeRoboTypography` tokens, `flutter test` widget tests, `AnimationController` + `Tween` for animations.

---

## Task 1: High-risk acknowledgement modal

The 시장대비 readout already flips to blue at ≥30pp riskier than market average (shipped in batch 1). The spec now wants a one-time confirmation dialog before the user can proceed past the EF screen with such a selection.

**Files:**
- Create: `Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_ack_dialog.dart`
- Modify: `Front-End/robo_mobile/lib/screens/onboarding/onboarding_screen.dart` (find the "Next" / proceed handler that advances past the EF screen — search for `OnboardingFrontierSelection` consumers)
- Test: `Front-End/robo_mobile/test/screens/onboarding/widgets/risk_ack_dialog_test.dart`

**Trigger rule:** Compare `selected.volatility - marketAverageVol` in absolute percentage points. Threshold: `>= 0.30` (decimal scale) i.e. ≥30pp. Show the modal **once** when the user tries to advance with a selection that crosses the threshold. Do not re-prompt for the same proceed action.

**Modal content per spec:**
- Header row: warning icon (`Icons.warning_amber_rounded`, `WeRoboColors.lossBlue`) + title "투자 위험 고지" in `WeRoboTypography.heading3`.
- Data table with three rows:
  - "시장 평균 비중" (label) — N% (value, gray)
  - "내 포트폴리오 비중" (label) — N% (value, `WeRoboColors.lossBlue`)
  - "초과" (label) — +Npp (value, `WeRoboColors.lossBlue`, bold)
  
  The "비중" here is the volatility expressed as a percentage, not the asset weights. Use the same `selected.volatility` and `averageVol` from the existing `_riskComparison` logic.
- Warning copy block (gray text): "선택하신 포트폴리오는 시장 평균보다 위험도가 크게 높습니다. 단기 손실 가능성을 충분히 인지하셨다면 계속 진행하실 수 있습니다."
- Required checkbox: "위험을 충분히 인지하였습니다" (default unchecked).
- Two buttons in a row at the bottom:
  - "비중 조정하기" — outlined button (`WeRoboColors.primaryDark` border + text), always enabled, pops the dialog with `false`.
  - "확인 후 유지" — filled button (`WeRoboColors.primaryDark` background, white text), enabled only when checkbox is checked, pops with `true`.

**Implementation steps:**

- [ ] **Step 1: Write the failing test for the dialog widget**

```dart
// risk_ack_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/risk_ack_dialog.dart';

void main() {
  testWidgets('confirm button starts disabled and enables on checkbox',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: WeRoboTheme.light,
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showRiskAckDialog(
                context: ctx,
                marketVolPct: 12.0,
                userVolPct: 45.0,
              );
            },
            child: const Text('open'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Confirm button disabled until checkbox checked.
    final confirmFinder = find.widgetWithText(ElevatedButton, '확인 후 유지');
    expect(tester.widget<ElevatedButton>(confirmFinder).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(confirmFinder).onPressed, isNotNull);
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/risk_ack_dialog_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: '...risk_ack_dialog.dart'".

- [ ] **Step 3: Implement the dialog**

Create `risk_ack_dialog.dart` exporting:

```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

Future<bool?> showRiskAckDialog({
  required BuildContext context,
  required double marketVolPct,
  required double userVolPct,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RiskAckDialog(
      marketVolPct: marketVolPct,
      userVolPct: userVolPct,
    ),
  );
}

class _RiskAckDialog extends StatefulWidget {
  final double marketVolPct;
  final double userVolPct;
  const _RiskAckDialog({
    required this.marketVolPct,
    required this.userVolPct,
  });
  @override
  State<_RiskAckDialog> createState() => _RiskAckDialogState();
}

class _RiskAckDialogState extends State<_RiskAckDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final excessPp = (widget.userVolPct - widget.marketVolPct);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: WeRoboColors.lossBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text('투자 위험 고지', style: WeRoboTypography.heading3),
              ],
            ),
            const SizedBox(height: 16),
            _row('시장 평균 비중',
                '${widget.marketVolPct.toStringAsFixed(1)}%',
                valueColor: WeRoboColors.textSecondary),
            const SizedBox(height: 6),
            _row('내 포트폴리오 비중',
                '${widget.userVolPct.toStringAsFixed(1)}%',
                valueColor: WeRoboColors.lossBlue),
            const SizedBox(height: 6),
            _row('초과',
                '+${excessPp.toStringAsFixed(1)}pp',
                valueColor: WeRoboColors.lossBlue,
                bold: true),
            const SizedBox(height: 14),
            Text(
              '선택하신 포트폴리오는 시장 평균보다 위험도가 크게 높습니다.\n'
              '단기 손실 가능성을 충분히 인지하셨다면 계속 진행하실 수 있습니다.',
              style: WeRoboTypography.bodySmall,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => setState(() => _acknowledged = !_acknowledged),
              child: Row(
                children: [
                  Checkbox(
                    value: _acknowledged,
                    onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  ),
                  const Expanded(
                    child: Text('위험을 충분히 인지하였습니다'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('비중 조정하기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _acknowledged
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: const Text('확인 후 유지'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {required Color valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: WeRoboTypography.bodySmall),
        Text(
          value,
          style: WeRoboTypography.bodySmall.copyWith(
            color: valueColor,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/risk_ack_dialog_test.dart
```

Expected: PASS.

- [ ] **Step 5: Wire up the trigger in onboarding_screen.dart**

Find the proceed handler that consumes `OnboardingFrontierSelection` (search for `onFrontierSelectionChanged` consumers and the "다음" / proceed button in the EF step). Before navigating forward, compute:

```dart
final selected = _selectedPreviewPoint;
if (selected != null && _preview.points.isNotEmpty) {
  final averageVol =
      _preview.points.map((p) => p.volatility).reduce((a, b) => a + b) /
          _preview.points.length;
  final diffPp = (selected.volatility - averageVol) * 100;
  if (diffPp >= 30) {
    final confirmed = await showRiskAckDialog(
      context: context,
      marketVolPct: averageVol * 100,
      userVolPct: selected.volatility * 100,
    );
    if (confirmed != true) return; // user chose 비중 조정하기 or dismissed
  }
}
// existing forward navigation
```

Add the import: `import 'widgets/risk_ack_dialog.dart';`

- [ ] **Step 6: Run analyze and full test suite**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Expected: no analyzer issues; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/widgets/risk_ack_dialog.dart \
  Front-End/robo_mobile/lib/screens/onboarding/onboarding_screen.dart \
  Front-End/robo_mobile/test/screens/onboarding/widgets/risk_ack_dialog_test.dart
git commit -m "feat(onboarding): gate 고위험 선택 with 투자 위험 고지 modal"
```

---

## Task 2: Split portfolio detail into 비중 and 비교+변동성 screens

The current `PortfolioReviewScreen` stacks `_DonutAndListColumn` (allocation) on top of `_CompareVolatilityTabs`. The spec wants the allocation on its own screen, then a "다음" advance to the comparison+volatility screen. Onboarding flow becomes: EF → 비중 → 비교+변동성.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/onboarding/portfolio_review_screen.dart`
- Test: `Front-End/robo_mobile/test/screens/onboarding/portfolio_review_screen_test.dart` (existing — may need updates to navigate through the new split)

**Implementation steps:**

- [ ] **Step 1: Read the existing PortfolioReviewScreen build to understand current composition**

Read `portfolio_review_screen.dart` end-to-end. Note where `_DonutAndListColumn` and `_CompareVolatilityTabs` are placed in the build tree. Identify the "다음" / proceed button that advances out of this screen, and what state needs to carry forward.

- [ ] **Step 2: Extract a new `PortfolioAllocationScreen` widget**

Wrap `_DonutAndListColumn` and any allocation-specific copy into a new standalone `StatefulWidget` with its own Scaffold, app bar back arrow, and a "다음" button at the bottom that pushes `PortfolioReviewScreen` (now containing only the comparison+volatility tabs) via `WeRoboMotion.fadeRoute`. The new widget lives in the same file for now.

The widget needs the same inputs the current donut column receives: the selected portfolio's asset weights and the frontier selection. Reuse the existing fetch logic — the new screen owns the same controllers and passes them down.

- [ ] **Step 3: Reduce PortfolioReviewScreen to comparison+volatility only**

Remove `_DonutAndListColumn` from `PortfolioReviewScreen.build`. The screen now shows only `_CompareVolatilityTabs`. Update the page title to "내 포트폴리오를 시장과 비교한다면?" (use `WeRoboTypography.heading2`).

Add vertical breathing room between the chart area and the tab body so they don't overlap on small screens (per spec: "프레임들이 겹치지 않게 여백을 줘서"). Add a `SizedBox(height: 16)` between the title and the tabs.

- [ ] **Step 4: Update the onboarding flow to push 비중 first**

Find where onboarding currently pushes `PortfolioReviewScreen` and change it to push the new `PortfolioAllocationScreen` instead. The allocation screen's "다음" button pushes `PortfolioReviewScreen`.

- [ ] **Step 5: Update the portfolio_review_screen_test.dart to navigate through the new split**

The existing tests pump `PortfolioReviewScreen` directly. For tests that depended on seeing the donut, switch them to pump `PortfolioAllocationScreen`. For tests that depended on tabs, keep `PortfolioReviewScreen` but ensure the test setup matches the new constructor signature.

Run iteratively until tests pass:

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/portfolio_review_screen_test.dart
```

- [ ] **Step 6: Run analyze + full test suite**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Expected: no analyzer issues; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/portfolio_review_screen.dart \
  Front-End/robo_mobile/test/screens/onboarding/portfolio_review_screen_test.dart
git commit -m "feat(onboarding): split portfolio detail into 비중 and 비교+변동성 screens"
```

---

## Task 3: Animated donut allocation reveal

The new allocation screen's donut should animate the 7 asset segments sequentially over a 2-second total budget. Each segment: label slides in from the left, the donut arc draws clockwise, and the percentage counts up from 0% to its final value. When one segment completes, the next begins.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/onboarding/widgets/donut_chart.dart` (or wherever the allocation donut is drawn — read the file to confirm)
- Modify: `Front-End/robo_mobile/lib/screens/onboarding/portfolio_review_screen.dart` (allocation screen wires up the controller)
- Test: `Front-End/robo_mobile/test/screens/onboarding/widgets/donut_chart_animation_test.dart`

**Timing:** 2000ms total ÷ 7 segments = ~285ms per segment, fully sequential. Use one `AnimationController` per segment chained on completion, OR a single 2000ms controller with per-segment intervals.

The simpler design: one `AnimationController` of `Duration(milliseconds: 2000)`. For segment `i`, its sub-interval is `Interval(i / 7, (i + 1) / 7, curve: Curves.easeOutCubic)`. Each segment's arc sweep, label opacity, and percentage `Tween<double>(begin: 0, end: weight)` all read from that interval.

**Implementation steps:**

- [ ] **Step 1: Read the existing donut_chart.dart**

Read end-to-end. Understand how segments are currently drawn (CustomPainter? widget composition?). Note which color tokens it reads from (should already match new palette).

- [ ] **Step 2: Write a test that asserts staggered animation**

```dart
// donut_chart_animation_test.dart
testWidgets('donut segments reveal sequentially over 2 seconds',
    (tester) async {
  // Pump the donut with three assets at t=0.
  // After 100ms, only segment 0 should be partially drawn (>0 sweep).
  // After 1100ms (half through segment 3), segments 0-2 fully drawn, 
  // segment 3 partial.
  // After 2100ms (past end), all segments fully drawn.
  // ...
});
```

Note: testing CustomPainter sweep angles directly is fiddly. A pragmatic alternative is to expose the per-segment progress as a debug property and assert on that, OR test the percentage `Text` widgets and assert their displayed value at given pumps.

- [ ] **Step 3: Run test to verify it fails**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/donut_chart_animation_test.dart
```

Expected: FAIL (animation not implemented yet).

- [ ] **Step 4: Implement the staggered animation**

Convert `DonutChart` (or its container) to `StatefulWidget` with a single `AnimationController` of 2000ms. For each segment:
- Arc sweep: `Tween<double>(begin: 0, end: weightFraction * 2 * pi)` driven by `CurvedAnimation(parent: controller, curve: Interval(i/7, (i+1)/7, curve: Curves.easeOutCubic))`.
- Label slide: `SlideTransition` with `Offset(-1, 0) → Offset.zero` on the same interval.
- Percentage count-up: `Tween<double>(begin: 0, end: weight * 100)` on the same interval; rendered with `(value.toStringAsFixed(0))%`.

Start the controller on `initState` or when the screen first becomes visible (use `WidgetsBinding.instance.addPostFrameCallback`). Provide a `replay` method for hot reload during dev.

- [ ] **Step 5: Run test to verify it passes**

```bash
cd Front-End/robo_mobile && flutter test test/screens/onboarding/widgets/donut_chart_animation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Run analyze + full test suite**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Expected: no analyzer issues; all tests pass.

- [ ] **Step 7: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/onboarding/widgets/donut_chart.dart \
  Front-End/robo_mobile/lib/screens/onboarding/portfolio_review_screen.dart \
  Front-End/robo_mobile/test/screens/onboarding/widgets/donut_chart_animation_test.dart
git commit -m "feat(onboarding): 순차적 donut allocation animation over 2s"
```

---

## Task 4: Home stat block reorg — vertical stack

The home screen currently shows 투자금액 and 평가금액 side-by-side (or in some other arrangement). Spec: 평가금액 sits directly under 투자금액 in a single right-aligned column. Both follow the same pattern: gray label, then same-size number that is **black and not bold**.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

**Implementation steps:**

- [ ] **Step 1: Locate the 투자금액 + 평가금액 block in home_tab.dart**

Search for "투자금액" and "평가금액". Identify the surrounding Row/Column and where they sit relative to 총손익 (line 1126 is the 총손익 label, so the principal/value block is somewhere nearby).

- [ ] **Step 2: Replace the block with a vertical column**

Replace the existing layout with:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('투자금액',
          style: WeRoboTypography.bodySmall.copyWith(
            color: WeRoboColors.textSecondary,
          )),
        Text(
          principalFormatted, // e.g. "₩10,000,000"
          style: WeRoboTypography.bodySmall.copyWith(
            color: WeRoboColors.textPrimary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
    const SizedBox(height: 4),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('평가금액',
          style: WeRoboTypography.bodySmall.copyWith(
            color: WeRoboColors.textSecondary,
          )),
        Text(
          marketValueFormatted,
          style: WeRoboTypography.bodySmall.copyWith(
            color: WeRoboColors.textPrimary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  ],
)
```

Adjust the formatter calls (`principalFormatted`, `marketValueFormatted`) to match the actual data sources in `home_tab.dart`.

- [ ] **Step 3: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze
```

Expected: no issues.

- [ ] **Step 4: Visual verification on the simulator**

The simulator should already have hot reload attached (`flutter run -d 2457356F-...`). Hot reload and verify on the home tab that:
- 평가금액 sits directly below 투자금액
- Both labels are gray, both numbers are black non-bold
- Numbers are right-aligned in a single column

- [ ] **Step 5: Run tests to make sure nothing regressed**

```bash
cd Front-End/robo_mobile && flutter test
```

Expected: all 114 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "feat(home): stack 평가금액 under 투자금액 in single column"
```

---

## Task 5: ALFIN logo above 총손익

The home screen should show a small ALFIN wordmark or icon directly above the 총손익 label. Reuse the existing logo asset / `WeRoboTypography.logo` styling if appropriate, but in a smaller size suitable for a home-screen header.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart` (insert above line 1126's 총손익 label)

**Implementation steps:**

- [ ] **Step 1: Check the existing logo treatment**

Search for `WeRoboTypography.logo` and the splash/login logo widget. Decide: use the text "ALFIN" in `WeRoboFonts.display` at a reduced size (e.g. 20px) tinted `WeRoboColors.primary`, OR an SVG asset if one exists in `assets/`.

- [ ] **Step 2: Insert the logo above the 총손익 block**

```dart
Text(
  'ALFIN',
  style: TextStyle(
    fontFamily: WeRoboFonts.display,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: WeRoboColors.primary,
    height: 1.0,
  ),
),
const SizedBox(height: 8),
// existing 총손익 label and value follow
```

- [ ] **Step 3: Run analyze + tests**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Expected: clean, all 114 tests pass.

- [ ] **Step 4: Hot-reload + screenshot to confirm placement**

Use `xcrun simctl io <UDID> screenshot /tmp/werobo-home.png` and visually confirm.

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "feat(home): add ALFIN wordmark above 총손익"
```

---

## Task 6: Market volatility alongside user volatility on 내 포트폴리오

The 내 포트폴리오 tab already shows the user's volatility (portfolio_tab.dart line 259 references "변동성"). The spec wants the market's volatility shown next to it for comparison.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/portfolio_tab.dart`
- Possibly: `Front-End/robo_mobile/lib/services/mobile_backend_api.dart` (if the backend already returns market vol on the relevant endpoint, no service change is needed)

**Implementation steps:**

- [ ] **Step 1: Locate the existing 변동성 display in portfolio_tab.dart**

Read around line 259 ("변동성" label) and line 355 ("시장 대비 위험도"). Note the surrounding widget shape — is it a stat card, an inline row, a chart legend?

- [ ] **Step 2: Identify the market volatility data source**

Check `mobile_backend_models.dart` and `mobile_backend_api.dart` for any market volatility field already returned by the portfolio detail or volatility-history endpoints. If the existing API response includes `market_volatility` or similar, use it directly. If not, fall back to computing it from the `MobileVolatilityHistoryResponse.marketSeries` (the comparison chart already plots both portfolio and market lines, so the data must be available).

- [ ] **Step 3: Render the market value next to the portfolio value**

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    _VolItem(label: '내 포트폴리오 변동성', value: userVolPct, color: WeRoboColors.primary),
    _VolItem(label: '시장 변동성', value: marketVolPct, color: WeRoboColors.textSecondary),
  ],
)
```

Use the same layout patterns already present near line 259 — match the surrounding card style and typography.

- [ ] **Step 4: Run analyze + tests**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Expected: clean, all tests pass.

- [ ] **Step 5: Hot-reload + screenshot to confirm**

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/portfolio_tab.dart
git commit -m "feat(home): show market volatility next to portfolio volatility on 내 포트폴리오"
```

---

## Final integration

After all six tasks complete, run one full pass:

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test
```

Then push the branch and fast-forward main:

```bash
git push origin honge6090/vibrant-thompson-9697e0
git push origin HEAD:main
```
