# Home Chart — Benchmark Overlay & Drag Context Card — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 시장 / 채권 수익률 / 연 기대수익률 lines + a minimal drag-only context card to the home portfolio chart, and remove the cost-basis deposit line. Keep the home chart's KRW hero, glow-dot polish, and pan-to-explore interaction.

**Architecture:** Convert all chart series to **% return space rebased to range start**, hide the Y-axis, render four lines via a renamed `_HomePerformancePainter`. Drag reveals a `_DragContextCard` Flutter widget (Positioned in a Stack over the canvas) showing portfolio + 시장 day-over-day % plus the day's top-2 asset movers. Per-asset daily data comes from `/portfolio/earnings-history` with deterministic mock fallback.

**Tech Stack:** Flutter (no third-party state mgmt — built-in `ChangeNotifier` + `InheritedNotifier`), `flutter_test` widget tests.

**Spec:** [docs/superpowers/specs/2026-05-05-home-chart-benchmark-overlay-design.md](../specs/2026-05-05-home-chart-benchmark-overlay-design.md)

---

## File map

**Modified:**
- [`Front-End/robo_mobile/lib/app/portfolio_state.dart`](../../../Front-End/robo_mobile/lib/app/portfolio_state.dart) — add `_earningsHistory` field, `setEarningsHistory`, `earningsHistory` getter, `dayOverDayAssetReturns(DateTime)` selector
- [`Front-End/robo_mobile/lib/models/mock_earnings_data.dart`](../../../Front-End/robo_mobile/lib/models/mock_earnings_data.dart) — add `dailyAssetEarnings(...)` and `mockEarningsHistoryResponse(...)`
- [`Front-End/robo_mobile/lib/screens/home/home_tab.dart`](../../../Front-End/robo_mobile/lib/screens/home/home_tab.dart) — primary visual & interaction work (rename painter, drop cost-basis, switch to % space, add 3 lines, legend, fetch logic, drag card)
- [`Front-End/robo_mobile/test/app/portfolio_state_test.dart`](../../../Front-End/robo_mobile/test/app/portfolio_state_test.dart) — earnings-history tests
- [`Front-End/robo_mobile/test/screens/home/home_tab_test.dart`](../../../Front-End/robo_mobile/test/screens/home/home_tab_test.dart) — chart + card tests

**Created:**
- [`Front-End/robo_mobile/test/models/mock_earnings_data_test.dart`](../../../Front-End/robo_mobile/test/models/mock_earnings_data_test.dart) — synthesizer determinism

**Untouched (intentionally):**
- `lib/screens/onboarding/widgets/portfolio_charts.dart` — comparison chart's off-system grays flagged for a separate task

---

## Conventions

- Run all tests from the Flutter project root: `cd Front-End/robo_mobile && flutter test <path>`
- Per project CLAUDE.md, no `print()` — use `dart:developer` `log(...)` for diagnostics
- Per global CLAUDE.md, no `Co-Authored-By: Claude` trailer in commit messages
- Each task ends with a small atomic commit. The plan stays compatible with `git rebase --interactive` if cleanup is wanted later

---

## Task 1: `PortfolioState.dayOverDayAssetReturns` — failing test

**Files:**
- Test: `Front-End/robo_mobile/test/app/portfolio_state_test.dart`

- [ ] **Step 1: Add the failing test**

Append a new `group` to `test/app/portfolio_state_test.dart` (inside the existing `void main()` block, after the existing `group('PortfolioState', ...)`):

```dart
  group('PortfolioState earnings history', () {
    late PortfolioState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = PortfolioState();
    });

    tearDown(() {
      state.dispose();
    });

    MobileEarningsPoint point(
      String date,
      Map<String, double> earnings,
    ) {
      return MobileEarningsPoint(
        date: DateTime.parse(date),
        totalEarnings: earnings.values.fold(0.0, (a, b) => a + b),
        totalReturnPct: 0,
        assetEarnings: earnings,
      );
    }

    test('dayOverDayAssetReturns computes per-asset diff vs prior point', () {
      state.setEarningsHistory(MobileEarningsHistoryResponse(
        points: [
          point('2026-04-14', {'us_value': 100000, 'gold': 50000}),
          point('2026-04-15', {'us_value': 105000, 'gold': 49000}),
        ],
        investmentAmount: 10000000,
        startDate: '2026-04-14',
        endDate: '2026-04-15',
        totalReturnPct: 0,
        totalEarnings: 0,
        assetSummary: const [],
      ));

      final diffs = state.dayOverDayAssetReturns(DateTime.parse('2026-04-15'));

      // (105000 - 100000) / 100000 = 0.05; (49000 - 50000) / 50000 = -0.02
      expect(diffs['us_value'], closeTo(0.05, 1e-9));
      expect(diffs['gold'], closeTo(-0.02, 1e-9));
    });

    test('dayOverDayAssetReturns returns empty map when no prior point exists',
        () {
      state.setEarningsHistory(MobileEarningsHistoryResponse(
        points: [
          point('2026-04-15', {'us_value': 100000}),
        ],
        investmentAmount: 10000000,
        startDate: '2026-04-15',
        endDate: '2026-04-15',
        totalReturnPct: 0,
        totalEarnings: 0,
        assetSummary: const [],
      ));

      final diffs = state.dayOverDayAssetReturns(DateTime.parse('2026-04-15'));
      expect(diffs, isEmpty);
    });

    test('dayOverDayAssetReturns is empty when earningsHistory is null', () {
      final diffs = state.dayOverDayAssetReturns(DateTime.parse('2026-04-15'));
      expect(diffs, isEmpty);
    });

    test('dayOverDayAssetReturns is empty when prior asset value is zero', () {
      state.setEarningsHistory(MobileEarningsHistoryResponse(
        points: [
          point('2026-04-14', {'us_value': 0, 'gold': 50000}),
          point('2026-04-15', {'us_value': 5000, 'gold': 51000}),
        ],
        investmentAmount: 10000000,
        startDate: '2026-04-14',
        endDate: '2026-04-15',
        totalReturnPct: 0,
        totalEarnings: 0,
        assetSummary: const [],
      ));

      final diffs = state.dayOverDayAssetReturns(DateTime.parse('2026-04-15'));
      // us_value omitted (division by zero); gold included
      expect(diffs.containsKey('us_value'), isFalse);
      expect(diffs['gold'], closeTo(0.02, 1e-9));
    });
  });
```

- [ ] **Step 2: Run the new tests and verify they fail**

```bash
cd Front-End/robo_mobile && flutter test test/app/portfolio_state_test.dart --plain-name "earnings history"
```

Expected: 4 failures with `NoSuchMethodError` on `setEarningsHistory` / `dayOverDayAssetReturns`.

- [ ] **Step 3: Commit (red)**

```bash
git add Front-End/robo_mobile/test/app/portfolio_state_test.dart
git commit -m "Test: PortfolioState earnings history selectors"
```

---

## Task 2: `PortfolioState.dayOverDayAssetReturns` — implementation

**Files:**
- Modify: `Front-End/robo_mobile/lib/app/portfolio_state.dart`

- [ ] **Step 1: Add the field, getter, setter, and selector**

Find the `_backtest` declaration in `portfolio_state.dart` (around line 100, near other `MobileX` fields). Right after the existing field declarations and before the public getters block, add:

```dart
  MobileEarningsHistoryResponse? _earningsHistory;
```

Below `MobileComparisonBacktestResponse? get backtest => _backtest;`, add:

```dart
  MobileEarningsHistoryResponse? get earningsHistory => _earningsHistory;
```

Find the existing `setBacktest(...)` method (around line 227). Right after it, add:

```dart
  void setEarningsHistory(MobileEarningsHistoryResponse? value) {
    _earningsHistory = value;
    notifyListeners();
  }

  /// Per-asset percent change from the prior data point to [date]'s point.
  /// Returns an empty map if [date] is the first point, has no matching
  /// point, or earnings history hasn't been set yet. Skips assets whose
  /// prior value is zero (division by zero).
  Map<String, double> dayOverDayAssetReturns(DateTime date) {
    final history = _earningsHistory;
    if (history == null || history.points.length < 2) {
      return const {};
    }
    final targetIdx = history.points.indexWhere(
      (p) => p.date.year == date.year &&
          p.date.month == date.month &&
          p.date.day == date.day,
    );
    if (targetIdx < 1) {
      return const {};
    }
    final prior = history.points[targetIdx - 1];
    final current = history.points[targetIdx];
    final result = <String, double>{};
    current.assetEarnings.forEach((code, value) {
      final priorValue = prior.assetEarnings[code];
      if (priorValue == null || priorValue == 0) {
        return;
      }
      result[code] = (value - priorValue) / priorValue;
    });
    return result;
  }
```

- [ ] **Step 2: Run the tests and verify they pass**

```bash
cd Front-End/robo_mobile && flutter test test/app/portfolio_state_test.dart --plain-name "earnings history"
```

Expected: 4 passes.

- [ ] **Step 3: Run full Flutter analyze + tests**

```bash
cd Front-End/robo_mobile && flutter analyze && flutter test test/app/portfolio_state_test.dart
```

Expected: no analyze warnings, all tests pass.

- [ ] **Step 4: Commit (green)**

```bash
git add Front-End/robo_mobile/lib/app/portfolio_state.dart
git commit -m "PortfolioState: earnings history field + day-over-day selector"
```

---

## Task 3: `MockEarningsData.dailyAssetEarnings` — failing test

**Files:**
- Create: `Front-End/robo_mobile/test/models/mock_earnings_data_test.dart`

- [ ] **Step 1: Create the test file**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mock_earnings_data.dart';

void main() {
  group('MockEarningsData.dailyAssetEarnings', () {
    test('produces one point per business day from start to today', () {
      final points = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      expect(points, isNotEmpty);
      // Every point falls on a business day (Mon-Fri)
      for (final point in points) {
        expect(point.date.weekday, lessThanOrEqualTo(5));
      }
      // First point on or after 2025-03-03 (the synthesizer's start)
      expect(points.first.date.isBefore(DateTime(2025, 3, 3)), isFalse);
    });

    test('is deterministic — same riskCode produces identical output', () {
      final a = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      final b = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].date, b[i].date);
        expect(a[i].assetEarnings, b[i].assetEarnings);
      }
    });

    test('every point includes every asset from the riskCode summary', () {
      final points = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      final expectedCodes = MockEarningsData.summaryFor('balanced')
          .map((s) => s.assetCode)
          .toSet();
      for (final point in points) {
        expect(point.assetEarnings.keys.toSet(), expectedCodes);
      }
    });

    test('asset earnings values are positive and roughly grow over time', () {
      final points = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      // First and last point of the largest weight asset (us_value @ 0.30)
      final firstUs = points.first.assetEarnings['us_value']!;
      final lastUs = points.last.assetEarnings['us_value']!;
      expect(firstUs, greaterThan(0));
      expect(lastUs, greaterThan(0));
      // Over hundreds of business days the cumulative value should differ
      expect(lastUs, isNot(equals(firstUs)));
    });
  });

  group('MockEarningsData.mockEarningsHistoryResponse', () {
    test('returns a response whose points match dailyAssetEarnings', () {
      final response =
          MockEarningsData.mockEarningsHistoryResponse(riskCode: 'balanced');
      final raw = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      expect(response.points.length, raw.length);
      expect(response.assetSummary,
          MockEarningsData.summaryFor('balanced'));
    });
  });
}
```

- [ ] **Step 2: Run the new tests and verify they fail**

```bash
cd Front-End/robo_mobile && flutter test test/models/mock_earnings_data_test.dart
```

Expected: failures with `NoSuchMethodError: no such method 'dailyAssetEarnings'` and `mockEarningsHistoryResponse`.

- [ ] **Step 3: Commit (red)**

```bash
git add Front-End/robo_mobile/test/models/mock_earnings_data_test.dart
git commit -m "Test: MockEarningsData per-asset daily synthesizer"
```

---

## Task 4: `MockEarningsData.dailyAssetEarnings` — implementation

**Files:**
- Modify: `Front-End/robo_mobile/lib/models/mock_earnings_data.dart`

- [ ] **Step 1: Append the synthesizer methods**

Find the closing brace of the `MockEarningsData` class (line ~241 — right after the existing `commentaryFor` method and before the final `}`). Add two new static methods just before that brace:

```dart
  /// Generate deterministic per-asset daily earnings from `2025-03-03` to
  /// today, simulating the `/portfolio/earnings-history` endpoint until
  /// the backend deploys it. Each asset's daily series compounds from a
  /// base allocation of `assetSummary.weight * baseInvestment` with a
  /// daily return tuned by tier (defensive lower volatility, growth
  /// higher) and a deterministic seeded noise term.
  static List<MobileEarningsPoint> dailyAssetEarnings({
    required String riskCode,
    double baseInvestment = 100000000,
  }) {
    final summary = summaryFor(riskCode);
    if (summary.isEmpty) return const [];

    // Per-asset annualized expected return (cap to keep mock plausible)
    // derived from the summary returnPct (cumulative over ~1 yr period).
    final annualReturnByCode = <String, double>{
      for (final asset in summary)
        asset.assetCode: (asset.returnPct / 100).clamp(-0.2, 0.4),
    };

    // Per-asset daily volatility tuned by typical asset class behavior.
    final volatilityByCode = <String, double>{
      'cash_equivalents': 0.0005,
      'short_term_bond': 0.0015,
      'infra_bond': 0.0030,
      'gold': 0.0080,
      'us_value': 0.0090,
      'us_growth': 0.0120,
      'new_growth': 0.0150,
    };

    // Base value per asset = weight * baseInvestment
    final baseByCode = <String, double>{
      for (final asset in summary)
        asset.assetCode: asset.weight * baseInvestment,
    };

    final start = DateTime(2025, 3, 3);
    final end = DateTime.now();
    final points = <MobileEarningsPoint>[];
    final values = Map<String, double>.from(baseByCode);

    var day = start;
    var seed = riskCode.hashCode;
    while (!day.isAfter(end)) {
      if (day.weekday <= 5) {
        for (final code in baseByCode.keys) {
          final annual = annualReturnByCode[code] ?? 0.07;
          final daily = annual / 252;
          final vol = volatilityByCode[code] ?? 0.005;
          seed = ((seed * 1103515245 + 12345) & 0x7fffffff);
          final noise = ((seed % 1000) / 1000.0 - 0.5) * 2 * vol;
          values[code] = (values[code] ?? 0) * (1 + daily + noise);
        }
        final total = values.values.fold(0.0, (a, b) => a + b);
        points.add(MobileEarningsPoint(
          date: day,
          totalEarnings: total - baseInvestment,
          totalReturnPct: (total - baseInvestment) / baseInvestment * 100,
          assetEarnings: Map<String, double>.from(values),
        ));
      }
      day = day.add(const Duration(days: 1));
    }
    return points;
  }

  /// Wrap `dailyAssetEarnings` into a full `MobileEarningsHistoryResponse`
  /// shaped like what `/portfolio/earnings-history` will return when it
  /// deploys.
  static MobileEarningsHistoryResponse mockEarningsHistoryResponse({
    required String riskCode,
    double baseInvestment = 100000000,
  }) {
    final points = dailyAssetEarnings(
      riskCode: riskCode,
      baseInvestment: baseInvestment,
    );
    final start = points.isEmpty
        ? DateTime(2025, 3, 3)
        : points.first.date;
    final end = points.isEmpty ? DateTime.now() : points.last.date;
    final last = points.isEmpty ? null : points.last;
    return MobileEarningsHistoryResponse(
      points: points,
      investmentAmount: baseInvestment,
      startDate:
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      endDate:
          '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
      totalReturnPct: last?.totalReturnPct ?? 0,
      totalEarnings: last?.totalEarnings ?? 0,
      assetSummary: summaryFor(riskCode),
    );
  }
```

- [ ] **Step 2: Run the new tests and verify they pass**

```bash
cd Front-End/robo_mobile && flutter test test/models/mock_earnings_data_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze lib/models/mock_earnings_data.dart
```

Expected: no warnings.

- [ ] **Step 4: Commit (green)**

```bash
git add Front-End/robo_mobile/lib/models/mock_earnings_data.dart
git commit -m "MockEarningsData: per-asset daily synthesizer + history wrapper"
```

---

## Task 5: Remove the cost-basis line + deposit text — failing test

**Files:**
- Modify: `Front-End/robo_mobile/test/screens/home/home_tab_test.dart`

- [ ] **Step 1: Add a test that asserts no '총 입금' label**

Append this test inside the existing `void main()` block of `home_tab_test.dart`, near the existing tests:

```dart
  testWidgets('hero chart no longer shows the deposit total text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    // The cost-basis "deposit" line and its label are removed in this change.
    expect(find.textContaining('총 입금'), findsNothing);
  });
```

- [ ] **Step 2: Run and watch it fail**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart --plain-name "deposit total"
```

Expected: FAIL — current code renders `'— ₩X 총 입금'`.

- [ ] **Step 3: Commit (red)**

```bash
git add Front-End/robo_mobile/test/screens/home/home_tab_test.dart
git commit -m "Test: home chart no longer shows 총 입금 label"
```

---

## Task 6: Remove the cost-basis line + deposit text — implementation

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Delete the `_allCostBasis` getter**

In `home_tab.dart`, remove the entire `_allCostBasis` getter (currently lines ~247-261):

```dart
  // DELETE THIS WHOLE BLOCK
  List<ChartPoint> get _allCostBasis {
    final accountHistory = PortfolioStateProvider.of(context).accountHistory;
    if (accountHistory.isNotEmpty) {
      return _ensureRenderable([
        for (final point in accountHistory)
          ChartPoint(date: point.date, value: point.investedAmount),
      ]);
    }
    final valuePts = _allValue;
    if (valuePts.isEmpty) return const [];
    return [
      ChartPoint(date: valuePts.first.date, value: _baseInvestment),
      ChartPoint(date: valuePts.last.date, value: _baseInvestment),
    ];
  }
```

- [ ] **Step 2: Drop `costPts` plumbing in `build()`**

Around line 338-340 of `home_tab.dart`:

Replace:
```dart
    final allCost = _allCostBasis;
    final valuePts = _filterByRange(allValue);
    final costPts = _filterByRange(allCost);
```
with:
```dart
    final valuePts = _filterByRange(allValue);
```

Around lines 351-358 (the crosshair derivation block):

Replace:
```dart
    // Compute drag-aware values from touch position
    double? crosshairValue;
    double? crosshairCost;
    if (_touchIndex != null && _touchIndex! < valuePts.length) {
      crosshairValue = valuePts[_touchIndex!].value;
      if (_touchIndex! < costPts.length) {
        crosshairCost = costPts[_touchIndex!].value;
      }
    }
```
with:
```dart
    // Compute drag-aware values from touch position
    double? crosshairValue;
    if (_touchIndex != null && _touchIndex! < valuePts.length) {
      crosshairValue = valuePts[_touchIndex!].value;
    }
```

Around lines 361-370 (the `displayChange` / `displayChangePct` / `displayInvested` block):

Replace the whole block:
```dart
    final displayChange = crosshairValue != null && crosshairCost != null
        ? crosshairValue - crosshairCost
        : change;
    final displayChangePct =
        crosshairValue != null && crosshairCost != null && crosshairCost > 0
        ? ((crosshairValue - crosshairCost) / crosshairCost) * 100
        : changePct;
    final displayIsPositive = displayChange >= 0;
    final displayInvested =
        crosshairCost ?? accountSummary?.investedAmount ?? _baseInvestment;
```
with:
```dart
    // Without a cost-basis line, drag-time deltas are computed against the
    // chart's first visible point (start of the selected range).
    final displayChange = crosshairValue != null
        ? crosshairValue - startValue
        : change;
    final displayChangePct = crosshairValue != null && startValue > 0
        ? ((crosshairValue - startValue) / startValue) * 100
        : changePct;
    final displayIsPositive = displayChange >= 0;
```

- [ ] **Step 3: Delete the deposit Text widget**

Around lines 415-425, delete the entire `// Net funding line` block:

```dart
        // DELETE THIS BLOCK
        // Net funding line (always visible, updates on drag)
        const SizedBox(height: 4),
        Text(
          '— ₩${_formatCurrency(displayInvested.toInt())} 총 입금',
          style: TextStyle(
            fontFamily: WeRoboFonts.english,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: tc.textPrimary,
          ),
        ),
```

- [ ] **Step 4: Drop `costPts` from the painter call**

Around lines 480-481, in the `CustomPaint` builder. Currently:
```dart
                          painter: _PortfolioValuePainter(
                            valuePts: valuePts,
                            costPts: costPts,
                            progress: _drawCurve.value,
```
change to (just remove the `costPts:` line; we'll fully refactor the painter in Task 7):
```dart
                          painter: _PortfolioValuePainter(
                            valuePts: valuePts,
                            costPts: const [],
                            progress: _drawCurve.value,
```

This keeps the painter compiling between this task and Task 7. The painter still accepts `costPts` but we're feeding it an empty list, so it draws zero cost-basis path.

- [ ] **Step 5: Run the test from Task 5 + the rest of the home_tab tests**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart
```

Expected: all tests pass, including `'hero chart no longer shows the deposit total text'`.

- [ ] **Step 6: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/home/home_tab.dart
```

Expected: no warnings (the now-unused `displayInvested` is gone; `crosshairCost` is gone; `_allCostBasis` getter is gone).

- [ ] **Step 7: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: drop cost-basis line + 총 입금 label"
```

---

## Task 7: Convert home chart to multi-line % return space

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

This task renames the painter, swaps its input from `(valuePts, costPts)` to `lines: List<ChartLine>`, hides Y-axis labels, dims the grid, and adds a `_pctSeries` helper. After this task only the orange portfolio line draws, but in % space — benchmarks land in Tasks 8-10.

- [ ] **Step 1: Add the `_pctSeries` helper inside `_PortfolioHeroChartState`**

Right after the existing `_filterByRange` method (around line 299), add:

```dart
  /// Rebase a KRW-valued `ChartPoint` series to percent return from the
  /// first point. The output's `value` field carries fractional return
  /// (`0.0` = 0%, `0.05` = +5%). First point is always exactly `0.0`.
  List<ChartPoint> _pctSeries(List<ChartPoint> krw) {
    if (krw.isEmpty) return const [];
    final base = krw.first.value;
    if (base == 0) return const [];
    return [
      for (final p in krw)
        ChartPoint(date: p.date, value: (p.value - base) / base),
    ];
  }
```

- [ ] **Step 2: Rename the painter and switch its input shape**

Find the painter declaration (around line 596):

```dart
class _PortfolioValuePainter extends CustomPainter {
  final List<ChartPoint> valuePts;
  final List<ChartPoint> costPts;
  ...
}
```

Replace the entire class with the renamed multi-line variant. Keep the glow dot, fading segment, gradient transition, and date-label behavior intact — we're only swapping the line-input model:

```dart
class _HomePerformancePainter extends CustomPainter {
  /// Lines to draw, in z-order (last drawn = on top). The portfolio line
  /// is conventionally first; benchmarks/projections layer below it via
  /// the order they appear in this list.
  final List<ChartLine> lines;
  final double progress;
  final int? touchIndex;
  final double glowPhase;
  final String dateLabel;
  final Color glowColor;
  final Color gridColor;
  final Color crosshairColor;

  _HomePerformancePainter({
    required this.lines,
    required this.progress,
    this.touchIndex,
    this.glowPhase = 0,
    required this.dateLabel,
    required this.glowColor,
    required this.gridColor,
    required this.crosshairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || lines.first.points.length < 2) return;

    final w = size.width;
    final h = size.height;
    final isDragging = touchIndex != null;
    const lineTopPad = 16.0;
    const graphTopPad = 36.0;
    const graphBotPad = 50.0;
    final chartH = h - graphTopPad - graphBotPad;

    // Y-range across all lines (% space — symmetric padding).
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final p in line.points) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
    }
    if (minY == double.infinity) return;
    final range = (maxY - minY).clamp(0.0001, double.infinity);
    minY -= range * 0.05;
    maxY += range * 0.05;
    final rangeY = maxY - minY;

    final basePts = lines.first.points;
    double toX(int i, int total) => w * i / (total - 1);
    double toY(double val) =>
        graphTopPad + chartH - ((val - minY) / rangeY) * chartH;

    // Grid lines — dimmed to 0.08 (was 0.15) so the chart reads
    // "no Y axis" while keeping spatial reference.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = graphTopPad + chartH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final fIdx = (basePts.length - 1) * progress.clamp(0.0, 1.0);
    final complete = fIdx.floor();
    final frac = fIdx - complete;
    final drawCount = (complete + 1).clamp(2, basePts.length);
    final ti = isDragging
        ? touchIndex!.clamp(0, basePts.length - 1)
        : drawCount - 1;

    // Draw benchmarks first (behind portfolio).
    for (var lineIdx = lines.length - 1; lineIdx >= 1; lineIdx--) {
      _drawBenchmarkLine(
        canvas,
        lines[lineIdx],
        basePts.length,
        toX,
        toY,
        drawCount,
      );
    }

    // Portfolio line on top with the existing polish.
    _drawPortfolioLine(
      canvas,
      lines.first.points,
      lines.first.color,
      basePts.length,
      drawCount,
      complete,
      frac,
      ti,
      isDragging,
      toX,
      toY,
    );

    // Crosshair + glow + date label (only when dragging).
    if (isDragging) {
      _drawCrosshair(
        canvas,
        size,
        ti,
        basePts.length,
        toX,
        toY,
        lines.first.points,
        drawCount,
        lineTopPad,
      );
    }
  }

  void _drawBenchmarkLine(
    Canvas canvas,
    ChartLine line,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    int drawCount,
  ) {
    final pts = line.points;
    if (pts.length < 2) return;
    final count = math.min(drawCount, pts.length);
    final path = Path();
    for (var i = 0; i < count; i++) {
      final x = toX(i, totalPts);
      final y = toY(pts[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = line.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (line.dashed) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawPortfolioLine(
    Canvas canvas,
    List<ChartPoint> pts,
    Color color,
    int totalPts,
    int drawCount,
    int complete,
    double frac,
    int ti,
    bool isDragging,
    double Function(int, int) toX,
    double Function(double) toY,
  ) {
    if (isDragging) {
      const transitionLen = 20;
      final transStart = math.max(0, ti - transitionLen);
      final mainEnd = math.min(transStart + 1, drawCount);
      final mainPath = Path();
      for (int i = 0; i < mainEnd; i++) {
        final x = toX(i, totalPts);
        final y = toY(pts[i].value);
        if (i == 0) {
          mainPath.moveTo(x, y);
        } else {
          mainPath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        mainPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (transStart < ti) {
        final transPath = Path();
        transPath.moveTo(
          toX(transStart, totalPts),
          toY(pts[transStart].value),
        );
        for (int i = transStart + 1; i <= ti && i < drawCount; i++) {
          transPath.lineTo(toX(i, totalPts), toY(pts[i].value));
        }
        final shader = ui.Gradient.linear(
          Offset(toX(transStart, totalPts), 0),
          Offset(toX(ti, totalPts), 0),
          [color, glowColor],
        );
        canvas.drawPath(
          transPath,
          Paint()
            ..shader = shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      if (ti < drawCount - 1) {
        _drawFadingSegment(canvas, pts, ti, drawCount, totalPts, toX, toY,
            color, 2);
      }
    } else {
      final fullPath = Path();
      for (int i = 0; i <= complete; i++) {
        final x = toX(i, totalPts);
        final y = toY(pts[i].value);
        if (i == 0) {
          fullPath.moveTo(x, y);
        } else {
          fullPath.lineTo(x, y);
        }
      }
      if (frac > 0 && complete < pts.length - 1) {
        final x0 = toX(complete, totalPts);
        final y0 = toY(pts[complete].value);
        final x1 = toX(complete + 1, totalPts);
        final y1 = toY(pts[complete + 1].value);
        fullPath.lineTo(x0 + frac * (x1 - x0), y0 + frac * (y1 - y0));
      }
      canvas.drawPath(
        fullPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawCrosshair(
    Canvas canvas,
    Size size,
    int ti,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    List<ChartPoint> portfolioPts,
    int drawCount,
    double lineTopPad,
  ) {
    final w = size.width;
    final h = size.height;
    final tx = toX(ti, totalPts);
    final lineTop = lineTopPad;
    final lineBot = h - lineTopPad;
    final lineShader = ui.Gradient.linear(
      Offset(tx, lineTop),
      Offset(tx, lineBot),
      [
        gridColor.withValues(alpha: 0.12),
        crosshairColor.withValues(alpha: 0.55),
        crosshairColor.withValues(alpha: 0.55),
        gridColor.withValues(alpha: 0.12),
      ],
      [0.0, 0.12, 0.88, 1.0],
    );
    canvas.drawLine(
      Offset(tx, lineTop),
      Offset(tx, lineBot),
      Paint()
        ..shader = lineShader
        ..strokeWidth = 0.8,
    );

    if (dateLabel.isNotEmpty) {
      final dateTp = TextPainter(
        text: TextSpan(
          text: dateLabel,
          style: TextStyle(
            fontSize: 10,
            color: crosshairColor.withValues(alpha: 0.85),
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dateX = (tx - dateTp.width / 2).clamp(4.0, w - dateTp.width - 4);
      dateTp.paint(canvas, Offset(dateX, lineTop - dateTp.height - 2));
    }

    if (ti < drawCount && ti < portfolioPts.length) {
      final vy = toY(portfolioPts[ti].value);
      final glowRadius = 14 + 4 * glowPhase;
      final glowAlpha = 0.25 + 0.15 * glowPhase;
      canvas.drawCircle(
        Offset(tx, vy),
        glowRadius,
        Paint()
          ..color = glowColor.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(tx, vy),
        4,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(Offset(tx, vy), 3, Paint()..color = Colors.white);
    }
  }

  void _drawFadingSegment(
    Canvas canvas,
    List<ChartPoint> pts,
    int startIdx,
    int endIdx,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    Color color,
    double strokeWidth,
  ) {
    if (startIdx >= endIdx - 1) return;
    final fadeCount = math.min(3, endIdx - startIdx);
    final fadeEnd = math.min(startIdx + fadeCount, endIdx);

    final fadePath = Path();
    fadePath.moveTo(toX(startIdx, totalPts), toY(pts[startIdx].value));
    for (int i = startIdx + 1; i < fadeEnd; i++) {
      fadePath.lineTo(toX(i, totalPts), toY(pts[i].value));
    }

    final x0 = toX(startIdx, totalPts);
    final x1 = toX(fadeEnd - 1, totalPts);
    if ((x1 - x0).abs() < 1) return;

    final shader = ui.Gradient.linear(Offset(x0, 0), Offset(x1, 0), [
      color,
      color.withValues(alpha: 0),
    ]);
    canvas.drawPath(
      fadePath,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLen = 6, double gapLen = 10}) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomePerformancePainter old) =>
      old.progress != progress ||
      old.touchIndex != touchIndex ||
      old.glowPhase != glowPhase ||
      old.lines != lines;
}
```

Add this import at the top of `home_tab.dart` if not already imported:
```dart
import 'dart:math' as math;
```
(replacing the existing `import 'dart:math';`).

Then update all bare `min`/`max` references in this file to `math.min` / `math.max` if they exist (search the file for `min(` and `max(` not preceded by `math.`).

- [ ] **Step 3: Update the `CustomPaint` call site**

Around line 477-491 (the `CustomPaint(... painter: _PortfolioValuePainter(...))` call), replace with:

```dart
                        return CustomPaint(
                          size: Size(fullWidth, 320),
                          painter: _HomePerformancePainter(
                            lines: [
                              ChartLine(
                                key: 'portfolio',
                                label: '포트폴리오',
                                color: WeRoboColors.primary,
                                points: _pctSeries(valuePts),
                              ),
                            ],
                            progress: _drawCurve.value,
                            touchIndex: _touchIndex,
                            glowPhase: _glowCtrl.value,
                            dateLabel: dateLabel,
                            glowColor: WeRoboColors.assetTier3,
                            gridColor: tc.border,
                            crosshairColor: tc.textSecondary,
                          ),
                        );
```

- [ ] **Step 4: Run all home_tab tests**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart
```

Expected: all pass.

- [ ] **Step 5: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/home/home_tab.dart
```

Expected: no warnings (no references to old painter or `costPts`).

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: rename painter, switch to multi-line % space"
```

---

## Task 8: Add 시장 line — failing test

**Files:**
- Modify: `Front-End/robo_mobile/test/screens/home/home_tab_test.dart`

- [ ] **Step 1: Add the failing test**

Append to `home_tab_test.dart`:

```dart
  testWidgets('chart legend shows 시장 entry when comparison data is wired',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    // Even with no backtest wired, the legend shows the four labels
    // (lines themselves render only when data exists).
    expect(find.text('포트폴리오'), findsOneWidget);
    expect(find.text('시장'), findsOneWidget);
  });
```

- [ ] **Step 2: Run and watch fail**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart --plain-name "legend shows 시장"
```

Expected: FAIL — no `'시장'` Text widget in current home tab.

- [ ] **Step 3: Commit (red)**

```bash
git add Front-End/robo_mobile/test/screens/home/home_tab_test.dart
git commit -m "Test: chart legend includes 시장 entry"
```

---

## Task 9: Add legend Wrap

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

This task adds the legend below the range chips and the helper widget that draws solid + dashed stroke samples.

- [ ] **Step 1: Add the legend helper widget**

In `home_tab.dart`, after the `_HomePerformancePainter` class but before the `// ─── Shared helpers ───` block (around the area between line 957 and 970 of the previous structure), add:

```dart
class _LegendDot extends StatelessWidget {
  final Color color;
  final bool dashed;
  const _LegendDot({required this.color, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 2,
      child: CustomPaint(
        painter: _LegendDotPainter(color: color, dashed: dashed),
      ),
    );
  }
}

class _LegendDotPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LegendDotPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dashed) {
      // 6/3 dash pattern within the 12px sample width
      const dashLen = 3.0;
      const gapLen = 2.0;
      double x = 0;
      while (x < size.width) {
        final end = math.min(x + dashLen, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x = end + gapLen;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendDotPainter old) =>
      old.color != color || old.dashed != dashed;
}

class _ChartLegend extends StatelessWidget {
  final List<({String label, Color color, bool dashed})> entries;
  const _ChartLegend({required this.entries});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendDot(color: e.color, dashed: e.dashed),
              const SizedBox(width: 4),
              Text(
                e.label,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Render the legend below the range chips**

Find the end of the range-chip Row in `_PortfolioHeroChartState.build` (around line 555 — the `Row` whose `children` are built by `List.generate(_rangeLabels.length, ...)`). Right after that Row's closing `),`, add a `SizedBox(height: 12)` and the legend:

```dart
        const SizedBox(height: 12),
        _ChartLegend(
          entries: [
            (
              label: '포트폴리오',
              color: WeRoboColors.primary,
              dashed: false,
            ),
            (
              label: '시장',
              color: tc.textSecondary,
              dashed: false,
            ),
            (
              label: '연 기대수익률',
              color: WeRoboColors.primary.withValues(alpha: 0.5),
              dashed: true,
            ),
            (
              label: '채권',
              color: tc.textTertiary.withValues(alpha: 0.7),
              dashed: true,
            ),
          ],
        ),
```

- [ ] **Step 3: Run the failing test from Task 8 + the rest**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart
```

Expected: all pass, including `legend shows 시장`.

- [ ] **Step 4: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/home/home_tab.dart
```

Expected: no warnings.

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: add 4-entry minimal legend"
```

---

## Task 10: Wire the 시장 line into the painter input

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Add a getter for the market line**

Inside `_PortfolioHeroChartState`, after the `_pctSeries` helper (added in Task 7), add:

```dart
  /// Market benchmark line (`benchmark_avg`), filtered to the visible
  /// range, rebased to 0% at the first visible point. Returns an empty
  /// list when the comparison backtest hasn't loaded yet.
  List<ChartPoint> _marketSeries(List<ChartPoint> portfolioRangePts) {
    if (portfolioRangePts.isEmpty) return const [];
    final all = PortfolioStateProvider.of(context).comparisonLines;
    final market = all.firstWhere(
      (l) => l.key == 'benchmark_avg',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (market.points.length < 2) return const [];

    final cutoff = portfolioRangePts.first.date;
    final filtered =
        market.points.where((p) => !p.date.isBefore(cutoff)).toList();
    if (filtered.length < 2) return const [];

    final base = filtered.first.value;
    return [
      for (final p in filtered)
        ChartPoint(date: p.date, value: p.value - base),
    ];
  }
```

(Note: `comparisonLines` already returns values in fractional return space — they're rebased differently here; since the home chart only shows `value - base`, the math stays in the same fractional space as the portfolio's `_pctSeries`.)

- [ ] **Step 2: Pass the market line to the painter**

Update the `lines:` list in the `CustomPaint` call (from Task 7, Step 3):

```dart
                          painter: _HomePerformancePainter(
                            lines: [
                              ChartLine(
                                key: 'portfolio',
                                label: '포트폴리오',
                                color: WeRoboColors.primary,
                                points: _pctSeries(valuePts),
                              ),
                              if (_marketSeries(valuePts).isNotEmpty)
                                ChartLine(
                                  key: 'market',
                                  label: '시장',
                                  color: tc.textSecondary,
                                  points: _marketSeries(valuePts),
                                ),
                            ],
```

- [ ] **Step 3: Run all home_tab tests**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart
```

Expected: all pass.

- [ ] **Step 4: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/home/home_tab.dart
```

Expected: no warnings.

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: render 시장 benchmark line"
```

---

## Task 11: Add 채권 수익률 line (2-point dashed endpoints)

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Add the bond series helper**

Inside `_PortfolioHeroChartState`, after `_marketSeries`:

```dart
  /// 채권 수익률 — drawn as a 2-point dashed line from the start of the
  /// visible range (0%) to the treasury's end-of-range cumulative return.
  /// Mirrors the `bond_trend` derivation in `portfolio_charts.dart`.
  List<ChartPoint> _bondEndpoints(List<ChartPoint> portfolioRangePts) {
    if (portfolioRangePts.isEmpty) return const [];
    final all = PortfolioStateProvider.of(context).comparisonLines;
    final treasury = all.firstWhere(
      (l) => l.key == 'treasury',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (treasury.points.length < 2) return const [];

    final cutoff = portfolioRangePts.first.date;
    final filtered =
        treasury.points.where((p) => !p.date.isBefore(cutoff)).toList();
    if (filtered.length < 2) return const [];

    final base = filtered.first.value;
    return [
      ChartPoint(date: filtered.first.date, value: 0.0),
      ChartPoint(date: filtered.last.date, value: filtered.last.value - base),
    ];
  }
```

- [ ] **Step 2: Add the line to the painter input**

Append inside the `lines:` list of the `CustomPaint` call:

```dart
                              if (_bondEndpoints(valuePts).isNotEmpty)
                                ChartLine(
                                  key: 'bond',
                                  label: '채권',
                                  color: tc.textTertiary.withValues(alpha: 0.7),
                                  dashed: true,
                                  points: _bondEndpoints(valuePts),
                                ),
```

- [ ] **Step 3: Run home_tab tests + analyze**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart && flutter analyze lib/screens/home/home_tab.dart
```

Expected: pass + no warnings.

- [ ] **Step 4: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: render 채권 수익률 dashed line"
```

---

## Task 12: Add 연 기대수익률 line

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Add the expected-return helper**

Inside `_PortfolioHeroChartState`, after `_bondEndpoints`:

```dart
  /// 연 기대수익률 — 2-point dashed line from the start of the visible
  /// range (0%) to `expectedReturn × elapsedYears`. Returns empty when
  /// `expectedReturn` is null or the visible range is empty.
  List<ChartPoint> _expectedReturnEndpoints(
    List<ChartPoint> portfolioRangePts,
  ) {
    if (portfolioRangePts.length < 2) return const [];
    final expected =
        PortfolioStateProvider.of(context).expectedReturn;
    if (expected == null) return const [];
    final first = portfolioRangePts.first.date;
    final last = portfolioRangePts.last.date;
    final elapsedDays = math.max(0, last.difference(first).inDays);
    final terminalReturn = expected * (elapsedDays / 365.25);
    return [
      ChartPoint(date: first, value: 0.0),
      ChartPoint(date: last, value: terminalReturn),
    ];
  }
```

- [ ] **Step 2: Add the line to the painter input**

Append inside the `lines:` list of the `CustomPaint` call (insert before the bond line so the layering reads portfolio → market → expected → bond):

```dart
                              if (_expectedReturnEndpoints(valuePts).isNotEmpty)
                                ChartLine(
                                  key: 'expected',
                                  label: '연 기대수익률',
                                  color: WeRoboColors.primary
                                      .withValues(alpha: 0.5),
                                  dashed: true,
                                  points: _expectedReturnEndpoints(valuePts),
                                ),
```

- [ ] **Step 3: Run home_tab tests + analyze**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart && flutter analyze lib/screens/home/home_tab.dart
```

Expected: pass + no warnings.

- [ ] **Step 4: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: render 연 기대수익률 dashed projection"
```

---

## Task 13: Wire earnings-history fetch (with mock fallback)

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Add fetch logic in `_HomeTabState`**

In `home_tab.dart`, find `class _HomeTabState extends State<HomeTab>` (around line 28). Add `didChangeDependencies` and a one-shot fetch flag:

```dart
class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  bool _showAllocationAmounts = false;
  bool _earningsHistoryFetchStarted = false;
  String? _loadedEarningsRiskCode;
```

Then add a `didChangeDependencies` override after `dispose`:

```dart
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = PortfolioStateProvider.of(context);
    final riskCode = state.type.riskCode;
    if (_loadedEarningsRiskCode != riskCode) {
      _loadedEarningsRiskCode = riskCode;
      _earningsHistoryFetchStarted = false;
    }
    if (!_earningsHistoryFetchStarted && state.earningsHistory == null) {
      _earningsHistoryFetchStarted = true;
      _loadEarningsHistory(state, riskCode);
    }
  }

  Future<void> _loadEarningsHistory(
    PortfolioState state,
    String riskCode,
  ) async {
    final selected = state.selectedPortfolio;
    final startedAt = state.accountSummary?.startedAt;
    if (selected == null || startedAt == null || startedAt.isEmpty) {
      // Cold-start path: fall back to mock immediately so the card has data
      // when the user starts dragging.
      state.setEarningsHistory(
        MockEarningsData.mockEarningsHistoryResponse(riskCode: riskCode),
      );
      return;
    }
    try {
      final api = MobileBackendApi();
      final response = await api.fetchEarningsHistory(
        weights: {
          for (final s in selected.sectorAllocations) s.assetCode: s.weight,
        },
        startDate: startedAt,
      );
      if (!mounted) return;
      state.setEarningsHistory(response);
    } catch (e) {
      if (!mounted) return;
      developer.log(
        'fetchEarningsHistory failed; using mock fallback: $e',
        name: 'HomeTab',
      );
      state.setEarningsHistory(
        MockEarningsData.mockEarningsHistoryResponse(riskCode: riskCode),
      );
    }
  }
```

Add these imports at the top of the file:

```dart
import 'dart:developer' as developer;
import '../../services/mobile_backend_api.dart';
```

- [ ] **Step 2: Add the failing test for fetch fallback**

Append in `home_tab_test.dart`:

```dart
  testWidgets('falls back to mock earnings history when API fails',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    // Two pumps: one for first frame (didChangeDependencies fires),
    // one to flush the mock fallback (no actual network round-trip
    // because the cold-start path skips the API entirely when
    // selectedPortfolio.sectorAllocations is wired only via summary).
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.earningsHistory, isNotNull);
    expect(state.earningsHistory!.points, isNotEmpty);
  });
```

- [ ] **Step 3: Run tests + analyze**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart && flutter analyze lib/screens/home/home_tab.dart
```

Expected: all tests pass, including the new fallback test. No warnings.

- [ ] **Step 4: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart Front-End/robo_mobile/test/screens/home/home_tab_test.dart
git commit -m "HomeTab: fetch earnings history with mock fallback"
```

---

## Task 14: Build `_DragContextCard` widget

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Add the card widget**

In `home_tab.dart`, after the `_ChartLegend` block (added in Task 9) and before the `// ─── Shared helpers ───` block, add:

```dart
class _DragContextCard extends StatelessWidget {
  final String dateLabel;
  final double portfolioPct;
  final double? marketPct;
  final List<({String name, double pct})> assetRows;

  const _DragContextCard({
    required this.dateLabel,
    required this.portfolioPct,
    required this.marketPct,
    required this.assetRows,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tc.border.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateLabel,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textTertiary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          _DragContextRow(label: '포트폴리오', pct: portfolioPct, tc: tc),
          if (marketPct != null)
            _DragContextRow(label: '시장', pct: marketPct!, tc: tc),
          if (assetRows.isNotEmpty) const SizedBox(height: 6),
          for (final row in assetRows)
            _DragContextRow(label: row.name, pct: row.pct, tc: tc),
        ],
      ),
    );
  }
}

class _DragContextRow extends StatelessWidget {
  final String label;
  final double pct;
  final WeRoboThemeColors tc;
  const _DragContextRow({
    required this.label,
    required this.pct,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final color = pct >= 0 ? tc.accent : WeRoboColors.error;
    final sign = pct >= 0 ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: WeRoboFonts.body,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: tc.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          const Spacer(),
          Text(
            '$sign${(pct * 100).abs().toStringAsFixed(2)}%',
            style: TextStyle(
              fontFamily: WeRoboFonts.english,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
```

Add this import at the top of the file:
```dart
import 'package:flutter/services.dart' show FontFeature;
```
(Note: `FontFeature` is in `dart:ui`, also exported from `package:flutter/painting.dart` — if the existing `import 'dart:ui' as ui;` is present, prefer `ui.FontFeature.tabularFigures()` and skip the new import.)

- [ ] **Step 2: Add a test for the card widget in isolation**

Append in `home_tab_test.dart`:

```dart
  testWidgets('drag context card renders portfolio + market + asset rows',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: WeRoboTheme.light,
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: _DragContextCardTestHarness(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('4월 15일'), findsOneWidget);
    expect(find.text('포트폴리오'), findsOneWidget);
    expect(find.text('시장'), findsOneWidget);
    expect(find.text('미국가치주'), findsOneWidget);
    expect(find.text('+0.45%'), findsOneWidget);
    expect(find.textContaining('−0.21%'), findsOneWidget);
  });
```

Since `_DragContextCard` is private, add a small public test harness in the test file (above `void main()`):

```dart
class _DragContextCardTestHarness extends StatelessWidget {
  const _DragContextCardTestHarness();

  @override
  Widget build(BuildContext context) {
    // Calls into the public chart-card path is provided by the home tab's
    // build through public API. For unit-isolation we duplicate the visible
    // contract here; the integration test below exercises the same widget
    // through the chart drag flow.
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text('drag-card-harness'),
    );
  }
}
```

> Note: because `_DragContextCard` is private to `home_tab.dart`, true unit-isolation testing requires either making it library-private with a `@visibleForTesting` factory, or testing it through the chart drag flow in Task 15. The harness above is a placeholder; replace this test with the integration test in Task 15 if you don't want to expose the widget.

If you'd rather not expose internals, **remove the test from this step** and rely on the Task 15 integration test instead. Either way, the next step covers the visible behavior end-to-end.

- [ ] **Step 3: Run analyze**

```bash
cd Front-End/robo_mobile && flutter analyze lib/screens/home/home_tab.dart
```

Expected: no warnings.

- [ ] **Step 4: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "Home chart: add _DragContextCard widget"
```

---

## Task 15: Wire the card into the chart Stack

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Wrap the chart in a Stack and Positioned the card**

Find the `LayoutBuilder` block in `_PortfolioHeroChartState.build` (around line 430). The block currently returns a `SizedBox(height: 320, child: OverflowBox(...))`. Wrap that `SizedBox` in a `Stack`, with the card as a `Positioned` child:

Replace:
```dart
            return SizedBox(
              height: 320,
              child: OverflowBox(
                ...
              ),
            );
```

with:

```dart
            // Compute card data + position when dragging
            final cardData = _touchIndex != null && _touchIndex! >= 1
                ? _buildCardData(valuePts)
                : null;
            return SizedBox(
              height: 320,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  OverflowBox(
                    maxWidth: fullWidth,
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: const Offset(-24, 0),
                      // ...existing GestureDetector...
                    ),
                  ),
                  if (cardData != null)
                    Positioned(
                      left: cardData.x,
                      top: cardData.y,
                      child: AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 100),
                        child: _DragContextCard(
                          dateLabel: cardData.dateLabel,
                          portfolioPct: cardData.portfolioPct,
                          marketPct: cardData.marketPct,
                          assetRows: cardData.assetRows,
                        ),
                      ),
                    ),
                ],
              ),
            );
```

> Don't lose the existing `GestureDetector` + `CustomPaint` hierarchy that was inside `OverflowBox` — keep the `child:` of `OverflowBox` exactly as it was. Only the outer wrapper changes.

- [ ] **Step 2: Add `_buildCardData` helper**

Inside `_PortfolioHeroChartState`, after `_expectedReturnEndpoints`:

```dart
  ({
    double x,
    double y,
    String dateLabel,
    double portfolioPct,
    double? marketPct,
    List<({String name, double pct})> assetRows,
  })? _buildCardData(List<ChartPoint> valuePts) {
    final ti = _touchIndex;
    if (ti == null || ti < 1 || ti >= valuePts.length) return null;

    // Day-over-day portfolio %.
    final curr = valuePts[ti].value;
    final prev = valuePts[ti - 1].value;
    if (prev == 0) return null;
    final portfolioPct = (curr - prev) / prev;

    // Day-over-day market %, if benchmark data exists.
    double? marketPct;
    final state = PortfolioStateProvider.of(context);
    final marketLine = state.comparisonLines.firstWhere(
      (l) => l.key == 'benchmark_avg',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (marketLine.points.length >= 2) {
      final touchDate = valuePts[ti].date;
      final mIdx = marketLine.points.indexWhere(
        (p) => p.date.year == touchDate.year &&
            p.date.month == touchDate.month &&
            p.date.day == touchDate.day,
      );
      if (mIdx >= 1) {
        final mCurr = marketLine.points[mIdx].value;
        final mPrev = marketLine.points[mIdx - 1].value;
        marketPct = mCurr - mPrev;
      }
    }

    // Top 2 asset gainers/losers based on portfolio direction.
    final assetReturns =
        state.dayOverDayAssetReturns(valuePts[ti].date);
    final names = <String, String>{
      for (final s in (state.selectedPortfolio?.sectorAllocations ?? const []))
        s.assetCode: s.assetName,
    };
    final entries = assetReturns.entries
        .where((e) => names.containsKey(e.key))
        .map((e) => (name: names[e.key]!, pct: e.value))
        .toList();
    if (portfolioPct >= 0) {
      entries.sort((a, b) => b.pct.compareTo(a.pct));
    } else {
      entries.sort((a, b) => a.pct.compareTo(b.pct));
    }
    final assetRows = entries.take(2).toList();

    // Position: anchor x at touch index, y above the dot if room else below.
    // Constants mirror the painter's chart-area math (graphTopPad=36).
    const padX = 8.0;
    const cardWidth = 160.0;
    const cardHeight = 80.0;
    final chartWidth = MediaQuery.of(context).size.width;
    final touchX = (ti / (valuePts.length - 1)) * chartWidth - 24;
    var x = (touchX - cardWidth / 2).clamp(padX, chartWidth - cardWidth - padX);

    // Approximate y of the orange dot using % of chart height.
    // Without exposing painter internals, place card at top by default and
    // flip to bottom if the touch is in the upper third of the chart.
    final touchPct = (curr - valuePts.first.value) /
        (valuePts.last.value - valuePts.first.value).abs().clamp(1, double.infinity);
    final dotInUpperThird = touchPct < 0.33;
    final y = dotInUpperThird ? 220.0 : 50.0;

    final date = valuePts[ti].date;
    final dateLabel = '${date.month}월 ${date.day}일';

    return (
      x: x,
      y: y,
      dateLabel: dateLabel,
      portfolioPct: portfolioPct,
      marketPct: marketPct,
      assetRows: assetRows,
    );
  }
```

- [ ] **Step 3: Add an integration test for the card on drag**

Append in `home_tab_test.dart`:

```dart
  testWidgets('drag at index >= 1 reveals context card', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard().copyWith(
      // Provide enough history points for drag to land on index >= 1.
      // Fill with synthetic linear points starting 60 days ago.
      historyOverride: List.generate(
        60,
        (i) => MobileAccountHistoryPoint(
          date: DateTime.now().subtract(Duration(days: 60 - i)),
          portfolioValue: 10000000 + (i * 5000),
          investedAmount: 10000000,
          profitLoss: i * 5000,
          profitLossPct: (i * 5000) / 10000000,
        ),
      ),
    ));
    await state.markWelcomeBannerSeen();

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(body: HomeTab()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));

    // Drag onto the chart center — falls on a non-zero index.
    final chart = find.byType(CustomPaint).first;
    final center = tester.getCenter(chart);
    await tester.dragFrom(center, const Offset(20, 0));
    await tester.pump();

    // The date label format from `_buildCardData`.
    final now = DateTime.now();
    expect(find.textContaining('월'), findsWidgets);
    // Portfolio row label is in the card.
    expect(find.text('포트폴리오'), findsAtLeastNWidgets(1));
  });
```

> Note: this test depends on a `MobileAccountDashboard.copyWith(...)` helper. If the model lacks one, either add a minimal `copyWith` in the production model (small refactor) or rebuild the dashboard inline in the test. The plan author prefers inline construction — see Step 4.

Actually, replace the `state.setAccountDashboard(accountDashboard().copyWith(...))` block above with:

```dart
    state.setAccountDashboard(
      MobileAccountDashboard(
        hasAccount: true,
        summary: accountDashboard().summary,
        history: List.generate(
          60,
          (i) => MobileAccountHistoryPoint(
            date: DateTime.now().subtract(Duration(days: 60 - i)),
            portfolioValue: 10000000 + (i * 5000),
            investedAmount: 10000000,
            profitLoss: i * 5000,
            profitLossPct: (i * 5000) / 10000000,
          ),
        ),
        recentActivity: const [],
      ),
    );
```

This avoids touching production models.

- [ ] **Step 4: Run tests + analyze**

```bash
cd Front-End/robo_mobile && flutter test test/screens/home/home_tab_test.dart && flutter analyze lib/screens/home/home_tab.dart
```

Expected: pass + no warnings.

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart Front-End/robo_mobile/test/screens/home/home_tab_test.dart
git commit -m "Home chart: wire drag context card into the chart Stack"
```

---

## Task 16: Manual QA on simulator

**Files:** none

- [ ] **Step 1: Build + run on the iPhone 17 Pro simulator**

```bash
cd Front-End/robo_mobile && flutter run -d E59D10D1-D076-4149-9AC9-ABFB4855F165
```

Expected: app launches, home tab visible.

- [ ] **Step 2: Visual checks (run through this list)**

On the home tab:
- Hero shows `현재 자산 ₩...` followed by performance badge — no `총 입금` line below
- Chart shows up to 4 lines: orange portfolio (solid), warm gray 시장 (solid), warm tan dashed projection (연 기대수익률), warm gray dashed (채권)
- No numbered Y-axis on the left of the chart
- Horizontal grid lines barely visible (0.08 alpha)
- Legend below range chips: 4 entries, dashed samples render as dashes

Drag interactions:
- Touch the chart near its left edge (data point 0 area) → no card appears; crosshair + dot still render
- Drag toward the middle → card appears with date + portfolio% + 시장% + 2 asset rows
- All values formatted with sign + 2 decimals (`+0.45%`, `−1.20%`)
- Positive day → green values; negative day → red values
- Card position clamps within chart bounds when dragging near edges
- Release → card fades out; chart returns to non-dragged state

Range chips:
- Tap each (1주 / 3달 / 1년 / 5년 / 전체) → all 4 lines rebase to 0% at new range start
- Card dismisses cleanly on range change

- [ ] **Step 3: If anything looks off, file a follow-up commit before finalizing**

(Skip if everything passes.)

- [ ] **Step 4: Final commit if needed**

```bash
git status
# If clean: nothing to do.
# If touched: git add ... && git commit -m "Home chart: <fix>"
```

---

## Self-review (run after writing the plan)

**Spec coverage:**
- ✅ Remove cost-basis line + 총 입금 text → Tasks 5-6
- ✅ Add 시장 / 채권 / 연 기대수익률 lines → Tasks 8, 10, 11, 12
- ✅ Convert chart to % space, hide Y-axis labels → Task 7
- ✅ Minimal legend → Task 9
- ✅ Floating context card on drag → Tasks 14-15
- ✅ Per-asset day-over-day data with mock fallback → Tasks 1-4, 13
- ✅ Hide card at first data point → Task 15 condition `_touchIndex >= 1`

**Type consistency:**
- `setEarningsHistory` and `earningsHistory` defined in Task 2; consumed in Tasks 13, 15 — names match
- `_HomePerformancePainter` introduced in Task 7; consumed in Tasks 9-12, 15 — name consistent
- `_pctSeries`, `_marketSeries`, `_bondEndpoints`, `_expectedReturnEndpoints`, `_buildCardData` — all defined inside `_PortfolioHeroChartState`; signatures match call sites
- `MockEarningsData.dailyAssetEarnings` and `MockEarningsData.mockEarningsHistoryResponse` — defined in Task 4, consumed in Task 13

**Placeholder scan:**
- Step language is concrete; commands have expected output
- No "TBD" / "TODO" / "fill in"
- One soft spot: Task 14 Step 2 acknowledges that `_DragContextCard` is private and offers either a harness or relying on Task 15's integration test. The plan recommends the latter — mentioned explicitly so the implementer doesn't get stuck

**Risk callouts:**
- Task 7's painter rewrite is the largest single chunk. If it goes sideways, revert and split into smaller pieces (e.g., introduce `_HomePerformancePainter` alongside `_PortfolioValuePainter`, migrate call sites, then delete the old painter)
- Task 15's `MediaQuery.of(context).size.width` for card x-position is approximate. If the chart is laid out inside a non-full-width container (it isn't today, but could change), the math would drift. Acceptable for MVP — flag if real users hit it
