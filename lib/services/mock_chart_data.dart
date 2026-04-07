import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/chart_data.dart';
import '../models/portfolio_data.dart';

/// Mock data generators for charts.
/// Replace with real API calls when backend is ready.
class MockChartData {
  MockChartData._();

  static List<ChartPoint> _generate(
      Random rng, int days, double start, double drift, double vol) {
    final pts = <ChartPoint>[];
    double val = start;
    final baseDate = DateTime(2025, 12, 8);
    for (int i = 0; i < days; i++) {
      val += drift / days + (rng.nextDouble() - 0.5) * vol;
      pts.add(ChartPoint(
        date: baseDate.add(Duration(days: i)),
        value: val,
      ));
    }
    return pts;
  }

  static List<ChartPoint> volatilityHistory(InvestmentType type) {
    final base = type == InvestmentType.safe
        ? 0.08
        : type == InvestmentType.balanced
            ? 0.12
            : 0.16;
    final rng = Random(type.index * 7 + 1);
    return _generate(rng, 120, base, -0.01, 0.008);
  }

  static List<ChartPoint> returnHistory(InvestmentType type) {
    final base = type == InvestmentType.safe
        ? 0.05
        : type == InvestmentType.balanced
            ? 0.08
            : 0.11;
    final rng = Random(type.index * 13 + 3);
    return _generate(rng, 120, base, 0.02, 0.006);
  }

  static List<ChartLine> comparisonLines(InvestmentType type) {
    final rng = Random(type.index * 5 + 10);
    final label = type.label;
    return [
      ChartLine(
        key: type.name,
        label: label,
        color: WeRoboColors.primary,
        points: _generate(rng, 120, 0, 0.06, 0.012),
      ),
      ChartLine(
        key: '${type.name}_expected',
        label: '$label 기대수익',
        color: WeRoboColors.primary,
        dashed: true,
        points: _generate(Random(99), 120, 0, 0.09, 0.002),
      ),
      ChartLine(
        key: 'sp500',
        label: 'S&P 500',
        color: const Color(0xFFEF4444),
        points: _generate(Random(42), 120, 0, -0.02, 0.018),
      ),
      ChartLine(
        key: 'treasury',
        label: '10년 국채',
        color: const Color(0xFF78716C),
        points: _generate(Random(77), 120, 0, 0.015, 0.005),
      ),
    ];
  }

  static List<DateTime> rebalanceDates = [
    DateTime(2025, 12, 31),
    DateTime(2026, 3, 31),
  ];

  /// Flat dashed line at the promised return rate for benchmarking.
  static ChartLine promisedReturnLine(InvestmentType type) {
    final rate = type == InvestmentType.safe
        ? 0.062
        : type == InvestmentType.balanced
            ? 0.085
            : 0.112;
    final baseDate = DateTime(2025, 12, 8);
    final points = List.generate(
      120,
      (i) => ChartPoint(date: baseDate.add(Duration(days: i)), value: rate),
    );
    return ChartLine(
      key: 'promised_return',
      label: '목표 수익률',
      color: WeRoboColors.warning,
      dashed: true,
      points: points,
    );
  }
}
