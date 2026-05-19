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
