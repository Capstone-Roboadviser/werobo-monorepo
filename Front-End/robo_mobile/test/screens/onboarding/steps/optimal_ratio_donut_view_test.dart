import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/steps/optimal_ratio_donut_view.dart';

/// Wraps [child] in a themed MaterialApp with bounded constraints, mirroring
/// the Expanded region the orchestrator hands each step body.
Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, height: 480, child: child),
        ),
      ),
    );

void main() {
  group('OptimalRatioDonutView', () {
    testWidgets('renders center label, side labels, and two "?" marks',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const OptimalRatioDonutView(
          entrance: AlwaysStoppedAnimation<double>(1),
        ),
      ));
      await tester.pump();

      expect(find.text('최적의 비율'), findsOneWidget);
      expect(find.text('수익률?'), findsOneWidget);
      expect(find.text('리스크?'), findsOneWidget);
      // Two standalone question marks (top-right + bottom-left).
      expect(find.text('?'), findsNWidgets(2));
      // The ring + leader lines are painted.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders without overflow in a small body box',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: WeRoboTheme.light,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 320,
              child: OptimalRatioDonutView(
                entrance: AlwaysStoppedAnimation<double>(1),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('최적의 비율'), findsOneWidget);
    });

    testWidgets('builds at entrance 0 without throwing (ring not yet drawn)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const OptimalRatioDonutView(
          entrance: AlwaysStoppedAnimation<double>(0),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Text widgets exist in the tree even at opacity 0.
      expect(find.text('최적의 비율'), findsOneWidget);
    });

    testWidgets('animates from 0 to 1 with a driven controller',
        (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: WeRoboMotion.long,
      );
      final entrance = CurvedAnimation(
        parent: controller,
        curve: WeRoboMotion.enter,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(
        OptimalRatioDonutView(entrance: entrance),
      ));

      controller.forward();
      // Mid-flight frame.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      // Settle to the end.
      await tester.pumpAndSettle();
      expect(find.text('최적의 비율'), findsOneWidget);
      expect(find.text('?'), findsNWidgets(2));
    });
  });
}
