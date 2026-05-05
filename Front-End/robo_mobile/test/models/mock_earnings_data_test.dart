import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mock_earnings_data.dart';

void main() {
  group('MockEarningsData.dailyAssetEarnings', () {
    test('produces one point per business day from start to today', () {
      final points = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      expect(points, isNotEmpty);
      // Every point falls on a business day (Mon-Fri)
      for (final point in points) {
        expect(point.date.weekday, lessThanOrEqualTo(5));
      }
      // First point on or after 2025-03-03 (the synthesizer's start)
      expect(points.first.date.isBefore(DateTime(2025, 3, 3)), isFalse);
    });

    test('is deterministic — same riskCode produces identical output', () {
      // Inject a fixed end date so the test isn't sensitive to midnight
      // boundaries when DateTime.now() advances between back-to-back calls.
      final asOf = DateTime(2026, 4, 30);
      final a = MockEarningsData.dailyAssetEarnings(
        riskCode: 'balanced',
        asOf: asOf,
      );
      final b = MockEarningsData.dailyAssetEarnings(
        riskCode: 'balanced',
        asOf: asOf,
      );
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].date, b[i].date);
        expect(a[i].assetEarnings, b[i].assetEarnings);
      }
    });

    test('every point includes every asset from the riskCode summary', () {
      final points = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      final expectedCodes = MockEarningsData.summaryFor('balanced')
          .map((s) => s.assetCode)
          .toSet();
      for (final point in points) {
        expect(point.assetEarnings.keys.toSet(), expectedCodes);
      }
    });

    test('asset earnings values are positive and roughly grow over time', () {
      final points = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      // First and last point of the largest weight asset (us_value @ 0.30)
      final firstUs = points.first.assetEarnings['us_value']!;
      final lastUs = points.last.assetEarnings['us_value']!;
      expect(firstUs, greaterThan(0));
      // us_value summary returnPct is +7.8 (annualized), so over the
      // multi-year synthesis window we expect cumulative growth well
      // beyond the first-day value. A negative-drift bug or a
      // disconnected loop would fail this bound.
      expect(lastUs, greaterThan(firstUs * 1.05));
    });
  });

  group('MockEarningsData.mockEarningsHistoryResponse', () {
    test('returns a response whose points match dailyAssetEarnings', () {
      final response =
          MockEarningsData.mockEarningsHistoryResponse(riskCode: 'balanced');
      final raw = MockEarningsData.dailyAssetEarnings(riskCode: 'balanced');
      expect(response.points.length, raw.length);
      expect(response.assetSummary,
          MockEarningsData.summaryFor('balanced'));
    });
  });
}
