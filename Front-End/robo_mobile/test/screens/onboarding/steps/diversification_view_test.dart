import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/onboarding_step.dart';
import 'package:robo_mobile/screens/onboarding/steps/diversification_view.dart';

void main() {
  // Default (stock-only) headline the orchestrator seeds the notifier with.
  const seededHeadline = OnboardingHeadline([
    OnboardingHeadlineLine([OnboardingHeadlineSegment('분산투자만으로')]),
    OnboardingHeadlineLine([OnboardingHeadlineSegment('위험은 크게 줄어듭니다.')]),
  ]);

  // Headline after the portfolio diversifies (a second asset is added).
  const addedHeadline = OnboardingHeadline([
    OnboardingHeadlineLine([OnboardingHeadlineSegment('흔들림은 최소로,')]),
    OnboardingHeadlineLine([OnboardingHeadlineSegment('자산은 꾸준히 우상향합니다.')]),
  ]);

  late ValueNotifier<bool> ready;
  late ValueNotifier<OnboardingHeadline> headline;

  setUp(() {
    ready = ValueNotifier<bool>(false);
    headline = ValueNotifier<OnboardingHeadline>(seededHeadline);
  });

  tearDown(() {
    ready.dispose();
    headline.dispose();
  });

  // Pumps DiversificationView with an always-complete entrance animation so
  // the chart is fully revealed and chips are interactive immediately.
  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: DiversificationView(
              entrance: const AlwaysStoppedAnimation<double>(1.0),
              readyNotifier: ready,
              headlineNotifier: headline,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the asset-add card with all four asset chips',
      (tester) async {
    await pumpView(tester);

    expect(find.text('자산 추가하기'), findsOneWidget);
    expect(find.text('주식'), findsOneWidget);
    expect(find.text('채권'), findsOneWidget);
    expect(find.text('금'), findsOneWidget);
    expect(find.text('부동산'), findsOneWidget);

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starts stock-only: not-ready with the seeded headline',
      (tester) async {
    await pumpView(tester);

    // 주식 is preselected but a single asset is not yet diversified.
    expect(ready.value, isFalse);
    expect(headline.value, seededHeadline);
  });

  testWidgets('adding a second asset flips readiness and swaps the headline',
      (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('채권'));
    await tester.pump();

    expect(ready.value, isTrue);
    expect(headline.value, addedHeadline);
    expect(tester.takeException(), isNull);
  });

  testWidgets('readiness stays true and headline unchanged on further adds',
      (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('채권'));
    await tester.pump();
    expect(ready.value, isTrue);
    expect(headline.value, addedHeadline);

    await tester.tap(find.text('금'));
    await tester.pumpAndSettle();
    expect(ready.value, isTrue);
    expect(headline.value, addedHeadline);

    expect(tester.takeException(), isNull);
  });

  testWidgets('re-tapping an already-added chip is a no-op', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('채권'));
    await tester.pump();
    expect(ready.value, isTrue);

    await tester.tap(find.text('채권'));
    await tester.pumpAndSettle();
    expect(ready.value, isTrue);
    expect(headline.value, addedHeadline);

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not flip readiness before any interaction',
      (tester) async {
    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(ready.value, isFalse);
    expect(headline.value, seededHeadline);
  });
}
