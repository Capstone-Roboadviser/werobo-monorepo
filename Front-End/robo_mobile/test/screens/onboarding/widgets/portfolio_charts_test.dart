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
          label: '6자산 단순평균',
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
                expectedAnnualReturn: 0.12,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('포트폴리오 비교'));
      await tester.pumpAndSettle();

      expect(find.text('시장'), findsNWidgets(2));
      expect(find.text('포트폴리오'), findsOneWidget);
      expect(find.text('연 기대수익률'), findsNWidgets(2));
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
          label: '6자산 단순평균',
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
                expectedAnnualReturn: 0.12,
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
      final expectedReturn =
          lines.singleWhere((line) => line.key == 'expected_return');

      expect(bondTrend.points, hasLength(2));
      expect(expectedReturn.points, hasLength(2));
      expect(expectedReturn.points.first.value, 0.0);
      expect(expectedReturn.points.last.value, greaterThan(0.0));
    },
  );

  testWidgets(
    'filters comparison ranges from the latest available data date',
    (tester) async {
      final comparisonLines = [
        ChartLine(
          key: 'selected',
          label: 'selected',
          color: Colors.grey,
          dashed: false,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2026, 3, 26), value: 0.05),
            ChartPoint(date: DateTime(2026, 4, 1), value: 0.07),
          ],
        ),
        ChartLine(
          key: 'benchmark_avg',
          label: '6자산 단순평균',
          color: Colors.grey,
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2026, 3, 26), value: 0.02),
            ChartPoint(date: DateTime(2026, 4, 1), value: 0.03),
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
                expectedAnnualReturn: 0.12,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('포트폴리오 비교'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1주'));
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
      final portfolioLine = lines.singleWhere((line) => line.key == 'selected');

      expect(portfolioLine.points, hasLength(2));
      expect(portfolioLine.points.first.date, DateTime(2026, 3, 26));
      expect(portfolioLine.points.last.date, DateTime(2026, 4, 1));
      expect(portfolioLine.points.first.value, 0.0);
    },
  );

  testWidgets(
    'keeps portfolio and benchmark styles stable when market is enabled',
    (tester) async {
      final comparisonLines = [
        ChartLine(
          key: 'balanced_expected',
          label: '균형형 기대수익',
          color: WeRoboColors.chartGreen,
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2026, 2, 1), value: 0.02),
          ],
        ),
        ChartLine(
          key: 'account_portfolio',
          label: '계좌 포트폴리오',
          color: Colors.orange,
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2026, 2, 1), value: 0.06),
          ],
        ),
        ChartLine(
          key: 'benchmark_avg',
          label: '6자산 단순평균',
          color: WeRoboColors.chartGreen,
          dashed: true,
          points: [
            ChartPoint(date: DateTime(2026, 1, 1), value: 0.00),
            ChartPoint(date: DateTime(2026, 2, 1), value: 0.03),
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
                expectedAnnualReturn: 0.12,
                useFallbackMock: false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('포트폴리오 비교'));
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
      final portfolioLine =
          lines.singleWhere((line) => line.key == 'account_portfolio');
      final marketLine =
          lines.singleWhere((line) => line.key == 'benchmark_avg');
      final expectedReturnLine =
          lines.singleWhere((line) => line.key == 'expected_return');

      expect(portfolioLine.label, '포트폴리오');
      expect(portfolioLine.color, WeRoboColors.primary);
      expect(portfolioLine.dashed, isFalse);
      expect(marketLine.label, '시장');
      expect(marketLine.color, const Color(0xFF64748B));
      expect(marketLine.dashed, isFalse);
      expect(expectedReturnLine.color,
          WeRoboColors.chartGreen.withValues(alpha: 0.85));
      expect(expectedReturnLine.dashed, isTrue);
    },
  );
}
