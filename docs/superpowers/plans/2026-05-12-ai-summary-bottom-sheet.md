# AI 요약 Bottom Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the full-page `DigestScreen` route with a modal bottom sheet that slides up from the bottom, applied to both home entry points (AI 요약 card and standalone digest banner). Reuse the existing digest content verbatim.

**Architecture:** Move the contents of `digest_screen.dart` into a new `widgets/digest_sheet.dart`. The new file exposes a public `DigestSheetShell` chrome widget (drag handle + X close button + rounded surface) and a `DigestSheet` state widget that owns the existing fetch state machine. A static `DigestSheet.show` helper wraps `showModalBottomSheet`. Both call sites in `home_tab.dart` swap from `Navigator.push(WeRoboMotion.fadeRoute(DigestScreen))` to `DigestSheet.show(context)`. `digest_screen.dart` is deleted.

**Tech Stack:** Flutter 3.x, Material `showModalBottomSheet`, existing `PortfolioStateProvider`, existing `MobileBackendApi.fetchDigest`, existing widgets (`DigestLoading`, `ReturnBarChart`, `DriverCard`, `WeRoboThemeColors`, `WeRoboTypography`).

---

## Spec reference

[docs/superpowers/specs/2026-05-12-ai-summary-bottom-sheet-design.md](../specs/2026-05-12-ai-summary-bottom-sheet-design.md)

## File map

- Create: `Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart`
- Create: `Front-End/robo_mobile/test/screens/home/digest_sheet_test.dart`
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart` (lines 18, 290–295, 318–323)
- Delete: `Front-End/robo_mobile/lib/screens/home/digest_screen.dart`

All commands run from the working tree root unless otherwise noted. The Flutter project lives under `Front-End/robo_mobile/`, so most `flutter` commands need `cd Front-End/robo_mobile && ...`.

---

## Task 1: DigestSheetShell chrome widget (TDD)

**Goal:** Build the reusable sheet shell that supplies the rounded surface, drag handle, and X close button. No business logic.

**Files:**
- Create: `Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart`
- Create: `Front-End/robo_mobile/test/screens/home/digest_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `Front-End/robo_mobile/test/screens/home/digest_sheet_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/home/widgets/digest_sheet.dart';

void main() {
  group('DigestSheetShell', () {
    testWidgets('renders drag handle and X close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: const Scaffold(
            body: DigestSheetShell(
              child: Center(child: Text('body')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('digest_sheet_drag_handle')), findsOneWidget);
      expect(find.byKey(const Key('digest_sheet_close_button')), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('tapping X pops the route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const DigestSheetShell(
                      child: SizedBox(height: 200, child: Text('body')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);

      await tester.tap(find.byKey(const Key('digest_sheet_close_button')));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw test test/screens/home/digest_sheet_test.dart
```

Expected: compile error — `digest_sheet.dart` does not exist.

- [ ] **Step 3: Create the digest_sheet.dart file with only the shell**

Create `Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Chrome for the AI 요약 modal bottom sheet: rounded top corners, drag
/// handle, X close button, and a slot for the scrollable body.
///
/// No business logic — the parent widget owns state and supplies the body.
class DigestSheetShell extends StatelessWidget {
  final Widget child;

  const DigestSheetShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Material(
      color: tc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      key: const Key('digest_sheet_drag_handle'),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tc.border.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: IconButton(
                      key: const Key('digest_sheet_close_button'),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: tc.textSecondary,
                      ),
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify both shell tests pass**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw test test/screens/home/digest_sheet_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart \
        Front-End/robo_mobile/test/screens/home/digest_sheet_test.dart
git commit -m "feat(home): add DigestSheetShell chrome widget"
```

---

## Task 2: Port DigestScreen state and content into DigestSheet

**Goal:** Move the fetch state machine and rendering pieces from `digest_screen.dart` into `digest_sheet.dart` as private content widgets plus a public `DigestSheet` stateful widget with a `show` helper. No behavior change beyond the new chrome.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart`

- [ ] **Step 1: Append DigestSheet state widget and show helper**

Open `Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart` and add the following imports at the top of the existing import block (keep `app/theme.dart` import):

```dart
import '../../../app/debug_page_logger.dart';
import '../../../app/portfolio_state.dart';
import '../../../models/mobile_backend_models.dart';
import '../../../services/mobile_backend_api.dart';
import 'digest_loading.dart';
import 'driver_card.dart';
import 'return_bar_chart.dart';
```

Then append below `DigestSheetShell`:

```dart
/// AI 요약 detail body for the modal bottom sheet.
///
/// Owns the fetch + loading/error state machine. Identical to the previous
/// `DigestScreen` behavior, including the "skip loading animation when the
/// digest was already seen" short-circuit and the 5500ms minimum loading
/// duration for first-time digests.
class DigestSheet extends StatefulWidget {
  const DigestSheet({super.key});

  /// Opens the sheet as a modal bottom sheet covering ~92% of screen height.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const DigestSheet(),
    );
  }

  @override
  State<DigestSheet> createState() => _DigestSheetState();
}

class _DigestSheetState extends State<DigestSheet> {
  MobileDigestResponse? _digest;
  String? _error;
  bool _loading = true;
  bool _fetchStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchStarted) {
      _fetchStarted = true;
      _fetchDigest();
    }
  }

  Future<void> _fetchDigest() async {
    final state = PortfolioStateProvider.of(context);
    final token = state.authSession?.accessToken;
    if (token == null) {
      setState(() {
        _error = '로그인이 필요합니다.';
        _loading = false;
      });
      return;
    }

    final alreadySeen = state.hasSeenCurrentDigest;

    try {
      if (alreadySeen) {
        final result =
            await MobileBackendApi.instance.fetchDigest(accessToken: token);
        if (mounted) {
          setState(() {
            _digest = result;
            _loading = false;
          });
        }
      } else {
        const minDuration = Duration(milliseconds: 5500);
        final results = await Future.wait([
          MobileBackendApi.instance.fetchDigest(accessToken: token),
          Future<void>.delayed(minDuration),
        ]);
        if (mounted) {
          final result = results[0] as MobileDigestResponse;
          await state.markDigestSeen(result.digestDate);
          setState(() {
            _digest = result;
            _loading = false;
          });
        }
      }
    } on MobileBackendException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.statusCode == 422
              ? '다이제스트를 만들기 위한 최근 데이터가 아직 부족합니다. '
                  '다음 가격 갱신 후 다시 확인해주세요.'
              : e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    logPageEnter('DigestSheet');
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.92,
      ),
      child: DigestSheetShell(child: _renderBody()),
    );
  }

  Widget _renderBody() {
    if (_loading) return const DigestLoading();
    if (_error != null) return _ErrorState(message: _error!);
    final digest = _digest;
    if (digest == null) return const SizedBox.shrink();
    return _DigestContent(digest: digest);
  }
}
```

- [ ] **Step 2: Append the content widgets (verbatim from digest_screen.dart)**

Append the body widgets (copy verbatim from the existing `digest_screen.dart` lines 119–453, dropping nothing). Paste this block at the end of `digest_sheet.dart`:

```dart
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Center(
      child: Padding(
        padding: WeRoboSpacing.screenH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: tc.textTertiary,
            ),
            const SizedBox(height: WeRoboSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: WeRoboTypography.body.copyWith(
                color: tc.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigestContent extends StatelessWidget {
  final MobileDigestResponse digest;
  const _DigestContent({required this.digest});

  @override
  Widget build(BuildContext context) {
    if (!digest.available) {
      return const _ErrorState(
        message: '표시할 다이제스트가 없습니다.',
      );
    }
    final tc = WeRoboThemeColors.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      children: [
        _DateBadge(start: digest.periodStart, end: digest.periodEnd),
        const SizedBox(height: WeRoboSpacing.lg),
        _SummaryCard(digest: digest),
        const SizedBox(height: WeRoboSpacing.xl),
        if (digest.drivers.isNotEmpty || digest.detractors.isNotEmpty) ...[
          ReturnBarChart(
            drivers: digest.drivers,
            detractors: digest.detractors,
          ),
          const SizedBox(height: WeRoboSpacing.xxl),
        ],
        if (digest.drivers.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.arrow_drop_up,
            iconColor: tc.accent,
            title: '상승 기여 종목',
          ),
          const SizedBox(height: WeRoboSpacing.md),
          ...digest.drivers.map(
            (d) => DriverCard(driver: d, isPositive: true),
          ),
          const SizedBox(height: WeRoboSpacing.xl),
        ],
        if (digest.detractors.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.arrow_drop_down,
            iconColor: WeRoboColors.error,
            title: '하락 기여 종목',
          ),
          const SizedBox(height: WeRoboSpacing.md),
          ...digest.detractors.map(
            (d) => DriverCard(driver: d, isPositive: false),
          ),
          const SizedBox(height: WeRoboSpacing.xl),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Text(
            digest.disclaimer,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textTertiary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateBadge extends StatelessWidget {
  final String start;
  final String end;
  const _DateBadge({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_formatDate(start)} - ${_formatDate(end)}',
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.month}월 ${d.day}일';
  }
}

class _SummaryCard extends StatelessWidget {
  final MobileDigestResponse digest;
  const _SummaryCard({required this.digest});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final isNegative = digest.totalReturnWon < 0;
    final returnColor = isNegative ? WeRoboColors.error : tc.accent;
    final sign = isNegative ? '' : '+';
    final wonStr = _formatWon(digest.totalReturnWon);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$sign$wonStr',
                style: WeRoboTypography.number.copyWith(
                  color: returnColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($sign${digest.totalReturnPct.toStringAsFixed(1)}%)',
                style: WeRoboTypography.body.copyWith(
                  color: returnColor,
                ),
              ),
            ],
          ),
          if (_volatilityContextText != null) ...[
            const SizedBox(height: 8),
            Text(
              _volatilityContextText!,
              style: WeRoboTypography.caption.copyWith(
                color: tc.textTertiary,
              ),
            ),
          ],
          if (digest.hasNarrative && digest.narrativeKo != null) ...[
            const SizedBox(height: 12),
            Text.rich(
              _buildNarrativeSpans(digest, tc),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                height: 1.7,
              ),
            ),
          ],
          if (digest.sourcesUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${digest.sourcesUsed.join(", ")} 기반 분석',
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textTertiary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? get _volatilityContextText {
    final multiple = digest.triggerSigmaMultiple;
    if (multiple == null) return null;
    return '최근 60영업일 기준, 평소보다 ${multiple.toStringAsFixed(1)}배 큰 움직임이에요.';
  }

  TextSpan _buildNarrativeSpans(
    MobileDigestResponse d,
    WeRoboThemeColors tc,
  ) {
    final narrative = _insertBenchmarkSentence(d);

    final names = <String>{};
    for (final driver in [...d.drivers, ...d.detractors]) {
      names.add(driver.ticker);
      if (driver.nameKo.isNotEmpty) names.add(driver.nameKo);
    }
    if (names.isEmpty) return TextSpan(text: narrative);

    final escaped = names.map((n) => RegExp.escape(n)).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(escaped.join('|'));

    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in pattern.allMatches(narrative)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: narrative.substring(lastEnd, match.start),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < narrative.length) {
      spans.add(TextSpan(
        text: narrative.substring(lastEnd),
      ));
    }
    return TextSpan(children: spans);
  }

  String _insertBenchmarkSentence(MobileDigestResponse d) {
    final narrative = d.narrativeKo!;
    if (d.benchmark7assetReturnPct == null) return narrative;

    final asset7 = d.benchmark7assetReturnPct!;
    final excess7 = d.totalReturnPct - asset7;
    final sign7 = excess7 >= 0 ? '+' : '';
    final parts = <String>[
      '시장 대비 $sign7${excess7.toStringAsFixed(1)}%',
    ];
    if (d.benchmarkBondReturnPct != null) {
      final excessBond = d.totalReturnPct - d.benchmarkBondReturnPct!;
      final signBond = excessBond >= 0 ? '+' : '';
      parts.add(
        '채권 대비 $signBond${excessBond.toStringAsFixed(1)}%',
      );
    }
    final verb = excess7 >= 0 ? '초과 수익' : '하회';
    final benchmarkSentence = '${parts.join(", ")} $verb을 기록했습니다.';

    final dotIdx = narrative.indexOf('. ');
    if (dotIdx >= 0) {
      final first = narrative.substring(0, dotIdx + 1);
      final rest = narrative.substring(dotIdx + 1).trimLeft();
      return '$first $benchmarkSentence $rest';
    }
    return '$narrative $benchmarkSentence';
  }

  String _formatWon(double won) {
    final abs = won.abs().round();
    final formatted = abs.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return won < 0 ? '-₩$formatted' : '₩$formatted';
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 4),
        Text(
          title,
          style: WeRoboTypography.heading3.copyWith(
            fontSize: 16,
            color: tc.textPrimary,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2.5: Verify the file is internally consistent**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw analyze lib/screens/home/widgets/digest_sheet.dart
```

Expected: no errors. (Warnings about unused imports from `app/theme.dart` are OK if any — the shell uses `tc`.)

- [ ] **Step 3: Run the shell tests again**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw test test/screens/home/digest_sheet_test.dart
```

Expected: 2 tests pass (no regression from adding the state widget).

- [ ] **Step 4: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart
git commit -m "feat(home): port DigestScreen content to DigestSheet"
```

---

## Task 3: Wire up home_tab.dart to call DigestSheet.show

**Goal:** Both AI 요약 entry points open the bottom sheet instead of the full-page route.

**Files:**
- Modify: `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- [ ] **Step 1: Swap the import**

Open `Front-End/robo_mobile/lib/screens/home/home_tab.dart`. Find the import line (line 18):

```dart
import 'digest_screen.dart';
```

Replace with:

```dart
import 'widgets/digest_sheet.dart';
```

- [ ] **Step 2: Replace the `_PortfolioIssueFeed.onDigestTap` call site (line ~290)**

Find this block:

```dart
                  onDigestTap: issueData.usesPlaceholderDigest
                      ? null
                      : () => Navigator.push(
                            context,
                            WeRoboMotion.fadeRoute<void>(
                              const DigestScreen(),
                            ),
                          ),
```

Replace with:

```dart
                  onDigestTap: issueData.usesPlaceholderDigest
                      ? null
                      : () => DigestSheet.show(context),
```

- [ ] **Step 3: Replace the `_DigestBanner.onTap` call site (line ~318)**

Find this block:

```dart
              _stagger(
                ++staggerIdx,
                _DigestBanner(
                  onTap: () => Navigator.push(
                    context,
                    WeRoboMotion.fadeRoute<void>(const DigestScreen()),
                  ),
                ),
              ),
```

Replace with:

```dart
              _stagger(
                ++staggerIdx,
                _DigestBanner(
                  onTap: () => DigestSheet.show(context),
                ),
              ),
```

- [ ] **Step 4: Run analyzer on home_tab.dart**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw analyze lib/screens/home/home_tab.dart
```

Expected: no errors. (If the analyzer complains about unused `WeRoboMotion` import, leave it — other call sites in this file still use `WeRoboMotion.fadeRoute` for non-digest routes.)

- [ ] **Step 5: Run the full app test suite to catch regressions**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw test
```

Expected: all tests pass. The existing `home_tab_test.dart` may exercise the digest banner — if it pushes a route and expects a particular screen, update it to expect the sheet (`DigestSheet` widget present) instead. If no such test exists, skip.

- [ ] **Step 6: Commit**

```bash
git add Front-End/robo_mobile/lib/screens/home/home_tab.dart
git commit -m "feat(home): open AI 요약 as a bottom sheet"
```

---

## Task 4: Delete digest_screen.dart

**Goal:** Remove the now-unused full-page screen.

**Files:**
- Delete: `Front-End/robo_mobile/lib/screens/home/digest_screen.dart`

- [ ] **Step 1: Confirm no remaining references**

Run:

```bash
grep -rn "digest_screen\|DigestScreen" Front-End/robo_mobile/lib Front-End/robo_mobile/test
```

Expected: zero hits. If any hits remain in files other than `digest_screen.dart` itself, stop and reconcile before deleting.

- [ ] **Step 2: Delete the file**

Run:

```bash
git rm Front-End/robo_mobile/lib/screens/home/digest_screen.dart
```

- [ ] **Step 3: Run analyzer over the whole project**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw analyze
```

Expected: no new errors. If the analyzer reports issues about missing imports, undo the deletion and revisit Task 3.

- [ ] **Step 4: Run all tests once more**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git commit -m "chore(home): remove unused digest_screen.dart"
```

---

## Task 5: Manual verification on simulator

**Goal:** Verify the user-facing behavior matches the spec on a real device frame.

**Files:** None.

- [ ] **Step 1: Boot the iOS simulator and run the app**

Run:

```bash
cd Front-End/robo_mobile && ./tool/flutterw run -d E59D10D1-D076-4149-9AC9-ABFB4855F165
```

Expected: app launches on iPhone 17 Pro.

- [ ] **Step 2: Verify entry point 1 — AI 요약 card**

Steps:

1. Log in and reach the home tab.
2. Tap the AI 요약 card (✨ icon + "AI 요약 · 최근 ...").

Expected:

- Sheet slides up from the bottom with ~250ms animation.
- Sheet settles at ~92% screen height with home peeking through under a dimmed scrim.
- Top has a 36×4 drag handle (centered) and a 24px X icon (top-right).
- Top corners are rounded.
- Body shows the loading animation initially, then the digest content (date badge, return summary, drivers/detractors, disclaimer).

- [ ] **Step 3: Verify dismiss paths**

While the sheet is open, verify each dismiss path works:

1. Tap the X button → sheet closes.
2. Re-open, swipe down on the sheet → sheet closes.
3. Re-open, tap the dimmed scrim above the sheet → sheet closes.

- [ ] **Step 4: Verify entry point 2 — standalone digest banner**

Steps:

1. From the home tab, scroll to where the `_DigestBanner` would appear (this banner only shows when there's no AI 요약 feed item — may need to clear digest seen state via dev tools or use a fresh account).
2. Tap the banner.

Expected: same sheet, same behavior as Step 2.

If the standalone banner cannot be triggered in the current state, note that and skip — the call site swap is mechanically identical to entry point 1.

- [ ] **Step 5: Verify dark mode**

Steps:

1. Open the sheet from entry point 1.
2. Toggle dark mode (Settings → Display → Appearance).

Expected: sheet surface darkens, drag handle and X stay visible, text remains legible.

- [ ] **Step 6: Verify previously-seen digest skips loading animation**

Steps:

1. Open the sheet, wait for the digest to load fully.
2. Close the sheet.
3. Re-open the sheet within the same session.

Expected: second open shows the digest immediately, no `DigestLoading` animation.

- [ ] **Step 7: Final commit if anything changed**

If steps 2–6 surfaced any tweaks (e.g., adjusting the header band height or body padding), make those edits and commit. Otherwise this task is verification-only and produces no commit.

---

## Self-review checklist

- [x] Every spec requirement maps to a task: shell anatomy (Task 1), state machine port (Task 2), entry-point swaps (Task 3), cleanup (Task 4), motion/dismiss/dark-mode/loading-skip checks (Task 5).
- [x] No placeholders or "implement later" steps.
- [x] All file paths absolute or rooted at the working tree.
- [x] Type/widget names consistent: `DigestSheetShell`, `DigestSheet`, `DigestSheet.show`, `_DigestContent`, `_ErrorState`, `_SummaryCard`, `_DateBadge`, `_SectionHeader` — same in every reference.
- [x] Commands include the `cd Front-End/robo_mobile` prefix where Flutter tooling needs it.
