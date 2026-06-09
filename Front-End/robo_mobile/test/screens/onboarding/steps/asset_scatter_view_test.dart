import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/steps/asset_scatter_view.dart';

/// Wraps the step body in a themed scaffold with a bounded box, mirroring the
/// `Expanded` region the orchestrator hands each step. The CustomPaint uses
/// `Size.infinite`, so it needs bounded constraints (a bare Center would hand
/// it unbounded constraints and fail layout).
Widget _wrap(Animation<double> entrance) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 420,
            child: AssetScatterView(entrance: entrance),
          ),
        ),
      ),
    );

/// Finds the `CustomPaint` whose painter is the view's scatter painter. The
/// painter is private to the view, so we match on its runtime type name.
Finder _scatterPaint() => find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_AssetScatterPainter',
    );

void main() {
  testWidgets(
    'renders the scatter painter inside the available box',
    (tester) async {
      // Always-complete entrance (fully revealed).
      await tester.pumpWidget(_wrap(const AlwaysStoppedAnimation<double>(1)));
      await tester.pumpAndSettle();

      expect(find.byType(AssetScatterView), findsOneWidget);
      expect(_scatterPaint(), findsOneWidget);
      // The step body is purely the painted visual: the four dot labels are
      // drawn on the canvas, so the body owns no Text widgets (the scaffold
      // renders the headline/caption).
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exposes all four asset labels via semantics',
    (tester) async {
      await tester.pumpWidget(_wrap(const AlwaysStoppedAnimation<double>(1)));
      await tester.pumpAndSettle();

      // 주식 (red), 금 (gold), 부동산 (green), 채권 (blue) — drawn on the canvas,
      // so assert the single accessibility label rather than Text finders.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('금')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('주식')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('부동산')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('채권')), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'paints without error at the start of the entrance (nothing drawn yet)',
    (tester) async {
      // A 0-value entrance means nothing is visible yet; each dot's local
      // reveal is 0 (skipped), but the painter must still mount cleanly.
      await tester.pumpWidget(_wrap(const AlwaysStoppedAnimation<double>(0)));
      await tester.pump();

      expect(_scatterPaint(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advancing the entrance repaints with a fresh painter',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: WeRoboMotion.long,
      );

      await tester.pumpWidget(_wrap(controller));

      controller.value = 0.5;
      await tester.pump();
      final midPainter = tester.widget<CustomPaint>(_scatterPaint()).painter;

      controller.value = 1.0;
      await tester.pump();
      final endPainter = tester.widget<CustomPaint>(_scatterPaint()).painter;

      // AnimatedBuilder rebuilds the CustomPaint with a new painter as the
      // entrance value changes, so the two instances differ.
      expect(midPainter, isNot(same(endPainter)));
      expect(tester.takeException(), isNull);

      controller.dispose();
    },
  );

  testWidgets(
    'drives a real forward entrance from 0 to 1 without error',
    (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: WeRoboMotion.long,
      );
      final entrance = CurvedAnimation(
        parent: controller,
        curve: WeRoboMotion.enter,
      );

      await tester.pumpWidget(_wrap(entrance));
      controller.forward();
      // First frame registers the ticker's t=0; the next frame advances the
      // clock through the full 400ms entrance plus a frame of slack.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.value, 1.0);
      expect(_scatterPaint(), findsOneWidget);
      expect(tester.takeException(), isNull);

      controller.dispose();
    },
  );
}
