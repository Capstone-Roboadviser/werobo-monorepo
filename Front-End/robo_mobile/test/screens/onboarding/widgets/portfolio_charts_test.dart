import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/chart_data.dart';
import 'package:robo_mobile/models/portfolio_data.dart';
import 'package:robo_mobile/screens/onboarding/widgets/portfolio_charts.dart';

void main() {
  testWidgets(
    'shows selected portfolio line in comparison tab for exact selections',
    (tester) async {
      final comparisonLines = [
        ChartLine(
          key: 'selected',
          label: 'selected',
          color: Colors.grey,
          dashed: false,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0),
            ChartPoint(date: DateTime(2026, 2, 1), value: 0.06),
          ],
        ),
        ChartLine(
          key: 'benchmark_avg',
          label: '7자산 단순평균',
          color: Colors.grey,
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0),
            ChartPoint(date: DateTime(2026, 2, 1), value: 0.03),
          ],
        ),
        ChartLine(
          key: 'treasury',
          label: '10년 국채',
          color: const Color(0xFF78716C),
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0),
            ChartPoint(date: DateTime(2026, 2, 1), value: 0.01),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: PortfolioCharts(
                type: InvestmentType.balanced,
                comparisonLines: comparisonLines,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('포트폴리오 비교'));
      await tester.pumpAndSettle();

      expect(find.text('선택 포트폴리오'), findsOneWidget);
      expect(find.text('채권 수익률'), findsNWidgets(2));
    },
  );

  testWidgets(
    'keeps bond trend visible for non-total comparison ranges',
    (tester) async {
      final comparisonLines = [
        ChartLine(
          key: 'selected',
          label: 'selected',
          color: Colors.grey,
          dashed: false,
          points: [
            ChartPoint(date: DateTime(2024, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2025, 7, 1), value: 0.05),
            ChartPoint(date: DateTime(2026, 4, 1), value: 0.09),
          ],
        ),
        ChartLine(
          key: 'benchmark_avg',
          label: '7자산 단순평균',
          color: Colors.grey,
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2024, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2025, 7, 1), value: 0.03),
            ChartPoint(date: DateTime(2026, 4, 1), value: 0.04),
          ],
        ),
        ChartLine(
          key: 'treasury',
          label: '10년 국채',
          color: const Color(0xFF78716C),
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2024, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2025, 7, 1), value: 0.01),
            ChartPoint(date: DateTime(2026, 4, 1), value: 0.015),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: WeRoboTheme.light,
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: PortfolioCharts(
                type: InvestmentType.balanced,
                comparisonLines: comparisonLines,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('포트폴리오 비교'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1년'));
      await tester.pumpAndSettle();

      final customPaint =
          tester.widgetList<CustomPaint>(find.byType(CustomPaint)).firstWhere(
                (widget) =>
                    widget.painter != null &&
                    widget.painter.runtimeType
                        .toString()
                        .contains('MultiLineChartPainter'),
              );
      final painter = customPaint.painter as dynamic;
      final lines = painter.lines as List<ChartLine>;
      final bondTrend = lines.singleWhere((line) => line.key == 'bond_trend');

      expect(bondTrend.points, hasLength(2));
    },
  );
}
