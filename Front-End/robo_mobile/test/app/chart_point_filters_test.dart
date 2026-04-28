import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/chart_point_filters.dart';
import 'package:robo_mobile/models/chart_data.dart';
import 'package:robo_mobile/app/theme.dart';

void main() {
  group('filterChartPointsFromStartDate', () {
    test('returns original points when start date is null', () {
      final points = [
        ChartPoint(date: DateTime(2026, 3, 1), value: 0.1),
        ChartPoint(date: DateTime(2026, 3, 2), value: 0.2),
      ];

      final filtered = filterChartPointsFromStartDate(points);

      expect(filtered, hasLength(2));
      expect(filtered.first.date, DateTime(2026, 3, 1));
      expect(filtered.last.date, DateTime(2026, 3, 2));
    });

    test('filters points to the portfolio start date inclusively', () {
      final points = [
        ChartPoint(date: DateTime(2026, 2, 28), value: 0.1),
        ChartPoint(date: DateTime(2026, 3, 1), value: 0.2),
        ChartPoint(date: DateTime(2026, 3, 5), value: 0.3),
      ];

      final filtered = filterChartPointsFromStartDate(
        points,
        startDate: DateTime(2026, 3, 1),
      );

      expect(filtered, hasLength(2));
      expect(filtered[0].date, DateTime(2026, 3, 1));
      expect(filtered[1].date, DateTime(2026, 3, 5));
    });
  });

  group('filterChartLinesFromStartDate', () {
    test('filters each line and drops empty lines', () {
      final lines = [
        ChartLine(
          key: 'balanced',
          label: '균형형',
          color: WeRoboColors.primary,
          points: [
            ChartPoint(date: DateTime(2026, 2, 28), value: 0.0),
            ChartPoint(date: DateTime(2026, 3, 2), value: 0.1),
          ],
        ),
        ChartLine(
          key: 'bond',
          label: '채권',
          color: WeRoboColors.warning,
          points: [
            ChartPoint(date: DateTime(2026, 2, 20), value: 0.0),
          ],
        ),
      ];

      final filtered = filterChartLinesFromStartDate(
        lines,
        startDate: DateTime(2026, 3, 1),
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.key, 'balanced');
      expect(filtered.single.points, hasLength(1));
      expect(filtered.single.points.single.date, DateTime(2026, 3, 2));
    });

    test('rebases filtered lines to zero when requested', () {
      final lines = [
        ChartLine(
          key: 'balanced',
          label: '균형형',
          color: WeRoboColors.primary,
          points: [
            ChartPoint(date: DateTime(2026, 2, 28), value: 0.03),
            ChartPoint(date: DateTime(2026, 3, 1), value: 0.08),
            ChartPoint(date: DateTime(2026, 3, 2), value: 0.11),
          ],
        ),
      ];

      final filtered = filterChartLinesFromStartDate(
        lines,
        startDate: DateTime(2026, 3, 1),
        rebaseToZero: true,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.points, hasLength(2));
      expect(filtered.single.points[0].value, 0.0);
      expect(filtered.single.points[1].value, closeTo(0.0277777778, 1e-9));
    });

    test('rebases large cumulative returns as period returns', () {
      final points = [
        ChartPoint(date: DateTime(2026, 4, 10), value: 1.715352),
        ChartPoint(date: DateTime(2026, 4, 13), value: 1.31584),
      ];

      final rebased = rebaseChartPointsToFirstValue(points);

      expect(rebased[0].value, 0.0);
      expect(rebased[1].value, closeTo(-0.1471308324, 1e-9));
    });
  });

  group('filterDatesFromStartDate', () {
    test('keeps dates on or after the start date', () {
      final dates = [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 4),
      ];

      final filtered = filterDatesFromStartDate(
        dates,
        startDate: DateTime(2026, 3, 1),
      );

      expect(filtered, hasLength(2));
      expect(filtered.first, DateTime(2026, 3, 1));
      expect(filtered.last, DateTime(2026, 3, 4));
    });
  });
}
