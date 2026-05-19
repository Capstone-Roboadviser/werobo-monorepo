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
