import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/steps/summary_view.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('OnboardingSummaryView', () {
    testWidgets('renders nothing — the scaffold owns the centered headline',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OnboardingSummaryView(entrance: kAlwaysCompleteAnimation),
        ),
      );

      // Mounts without throwing.
      expect(find.byType(OnboardingSummaryView), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The body draws no graphic of its own (no headline, no CustomPaint).
      expect(find.textContaining('최적의 자산 배분'), findsNothing);
      expect(find.textContaining('최고의 전략'), findsNothing);
      expect(find.textContaining('더 높은 수익률'), findsNothing);
    });

    testWidgets('honors the exact const constructor contract', (tester) async {
      // Mirrors the orchestrator's call site: OnboardingSummaryView(entrance:).
      const widget = OnboardingSummaryView(entrance: kAlwaysCompleteAnimation);
      expect(widget.entrance.value, 1.0);

      await tester.pumpWidget(_wrap(widget));
      expect(find.byType(OnboardingSummaryView), findsOneWidget);
    });
  });
}
