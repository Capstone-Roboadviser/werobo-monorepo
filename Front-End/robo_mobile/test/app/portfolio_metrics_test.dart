import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_metrics.dart';

/// Build a synthetic cumulative-return series from periodic returns.
/// First entry is anchored at cumReturn=0 (baseline), then each subsequent
/// point compounds the periodic return.
List<ReturnPoint> _series(List<double> periodicReturns, {DateTime? start}) {
  final base = start ?? DateTime(2025, 1, 1);
  final points = <ReturnPoint>[(date: base, cumReturn: 0.0)];
  var value = 1.0;
  for (var i = 0; i < periodicReturns.length; i++) {
    value *= (1 + periodicReturns[i]);
    points.add((
      date: base.add(Duration(days: i + 1)),
      cumReturn: value - 1.0,
    ));
  }
  return points;
}

void main() {
  group('computeMetrics – basic shape', () {
    test('returns all-null metrics on empty input', () {
      final m = computeMetrics(series: const []);
      expect(m.sharpeRatio, isNull);
      expect(m.cagr, isNull);
      expect(m.cumulativeReturn, isNull);
      expect(m.volatility, isNull);
      expect(m.maxDrawdown, isNull);
      expect(m.valueAtRisk, isNull);
      expect(m.conditionalValueAtRisk, isNull);
      expect(m.downsideDeviation, isNull);
      expect(m.sortinoRatio, isNull);
      expect(m.calmarRatio, isNull);
      expect(m.treynorRatio, isNull);
      expect(m.informationRatio, isNull);
      expect(m.omegaRatio, isNull);
      expect(m.correlation, isNull);
      expect(m.winRate, isNull);
      expect(m.alpha, isNull);
      expect(m.beta, isNull);
      expect(m.turnover, isNull);
    });

    test('returns null when only one point (no period to derive return from)',
        () {
      final m = computeMetrics(series: [
        (date: DateTime(2025, 1, 1), cumReturn: 0.0),
      ]);
      expect(m.cagr, isNull);
      expect(m.volatility, isNull);
    });
  });

  group('cumulative return', () {
    test('reports the last cumReturn value', () {
      final s = _series(const [0.01, 0.02, -0.01]);
      final m = computeMetrics(series: s);
      // (1.01 * 1.02 * 0.99) - 1 = 0.019898
      expect(m.cumulativeReturn, closeTo(0.019898, 1e-9));
    });
  });

  group('CAGR', () {
    test('returns annualized growth over the elapsed period', () {
      // 252 daily returns of +0.001 → total ~28.4% over ~252 days.
      final s = _series(List.filled(252, 0.001));
      final m = computeMetrics(series: s);
      // elapsed ≈ 252 / 365.25 years
      final elapsedYears = 252 / 365.25;
      final expected = math.pow(1 + s.last.cumReturn, 1 / elapsedYears) - 1;
      expect(m.cagr, closeTo(expected, 1e-6));
    });
  });

  group('volatility', () {
    test('is zero when all periodic returns are equal', () {
      final s = _series(List.filled(60, 0.005));
      final m = computeMetrics(series: s);
      expect(m.volatility, closeTo(0.0, 1e-12));
    });

    test('is positive when returns vary', () {
      final s = _series(const [0.02, -0.01, 0.015, -0.005, 0.01, -0.012]);
      final m = computeMetrics(series: s);
      expect(m.volatility, greaterThan(0));
    });
  });

  group('max drawdown', () {
    test('captures the largest peak-to-trough decline', () {
      // Cumulative path: 0, 0.10, 0.20, 0.10, 0.05, 0.15, 0.25
      // Peak = 1.20 at t=2; trough = 1.05 at t=4 → MDD = (1.20-1.05)/1.20 = 0.125
      final dates = List<DateTime>.generate(
        7,
        (i) => DateTime(2025, 1, 1).add(Duration(days: i)),
      );
      final cum = [0.0, 0.10, 0.20, 0.10, 0.05, 0.15, 0.25];
      final s = <ReturnPoint>[
        for (var i = 0; i < dates.length; i++)
          (date: dates[i], cumReturn: cum[i]),
      ];
      final m = computeMetrics(series: s);
      expect(m.maxDrawdown, closeTo(0.125, 1e-9));
    });

    test('is zero for monotonic growth', () {
      final s = _series(List.filled(20, 0.005));
      final m = computeMetrics(series: s);
      expect(m.maxDrawdown, closeTo(0.0, 1e-12));
    });
  });

  group('Sharpe / Sortino / Calmar', () {
    test('Sharpe is null when volatility is zero', () {
      final s = _series(List.filled(30, 0.005));
      final m = computeMetrics(series: s);
      expect(m.sharpeRatio, isNull);
    });

    test('Sharpe is positive for an upward, volatile series', () {
      // Mostly up, some chop
      final s = _series(const [0.01, -0.002, 0.012, -0.005, 0.011, 0.0,
        0.008, -0.003, 0.014, 0.001]);
      final m = computeMetrics(series: s);
      expect(m.sharpeRatio, isNotNull);
      expect(m.sharpeRatio!, greaterThan(0));
    });

    test('Sortino is null when downside deviation is zero', () {
      // All returns >= 0 → no downside
      final s = _series(const [0.01, 0.0, 0.005, 0.01, 0.02]);
      final m = computeMetrics(series: s);
      expect(m.downsideDeviation, closeTo(0.0, 1e-12));
      expect(m.sortinoRatio, isNull);
    });

    test('Calmar is null when MDD is zero', () {
      final s = _series(List.filled(20, 0.005));
      final m = computeMetrics(series: s);
      expect(m.calmarRatio, isNull);
    });

    test('Calmar = CAGR / |MDD| when both exist', () {
      final dates = List<DateTime>.generate(
        365,
        (i) => DateTime(2025, 1, 1).add(Duration(days: i)),
      );
      // Build a path with a known dip then recovery
      final periodic = <double>[];
      for (var i = 0; i < 364; i++) {
        // Day 100-110: -1% per day; otherwise +0.1%
        if (i >= 100 && i < 110) {
          periodic.add(-0.01);
        } else {
          periodic.add(0.001);
        }
      }
      final s = _series(periodic, start: dates.first);
      final m = computeMetrics(series: s);
      expect(m.cagr, isNotNull);
      expect(m.maxDrawdown, isNotNull);
      expect(m.maxDrawdown!, greaterThan(0));
      expect(m.calmarRatio,
          closeTo(m.cagr! / m.maxDrawdown!, 1e-9));
    });
  });

  group('VaR / CVaR', () {
    test('5% VaR is the 5th-percentile loss; CVaR is the average beyond it',
        () {
      // Construct 100 returns: 95 zeros, 5 known negative tail
      final periodic = <double>[
        for (var i = 0; i < 95; i++) 0.0,
        -0.01, -0.02, -0.03, -0.04, -0.05,
      ];
      final s = _series(periodic);
      final m = computeMetrics(series: s);
      // VaR returns a magnitude (positive number) representing potential loss
      expect(m.valueAtRisk, isNotNull);
      expect(m.valueAtRisk!, greaterThan(0));
      expect(m.conditionalValueAtRisk, isNotNull);
      // CVaR ≥ VaR
      expect(m.conditionalValueAtRisk!,
          greaterThanOrEqualTo(m.valueAtRisk!));
    });
  });

  group('correlation / beta / alpha', () {
    test('correlation between identical series is 1', () {
      final s = _series(const [0.01, -0.005, 0.012, -0.002, 0.008, 0.003]);
      final m = computeMetrics(series: s, benchmark: s);
      expect(m.correlation, closeTo(1.0, 1e-9));
      expect(m.beta, closeTo(1.0, 1e-9));
      expect(m.alpha, closeTo(0.0, 1e-9));
    });

    test('alpha is positive when portfolio outperforms market at same beta',
        () {
      final marketSeries = _series(const [0.01, -0.005, 0.012, -0.002, 0.008]);
      // Portfolio = market + 0.5% constant lift per period
      final periodicMarket = const [0.01, -0.005, 0.012, -0.002, 0.008];
      final portfolioPeriodic =
          periodicMarket.map((r) => r + 0.005).toList();
      final portfolio = _series(portfolioPeriodic);
      final m = computeMetrics(
        series: portfolio,
        benchmark: marketSeries,
      );
      expect(m.alpha, isNotNull);
      expect(m.alpha!, greaterThan(0));
    });

    test('paired metrics are null without a benchmark', () {
      final s = _series(const [0.01, -0.005, 0.012, -0.002, 0.008]);
      final m = computeMetrics(series: s);
      expect(m.alpha, isNull);
      expect(m.beta, isNull);
      expect(m.correlation, isNull);
      expect(m.treynorRatio, isNull);
      expect(m.informationRatio, isNull);
    });
  });

  group('omega ratio', () {
    test('omega > 1 when gains outweigh losses (threshold 0)', () {
      final s = _series(const [0.02, -0.01, 0.015, -0.005, 0.01, -0.008]);
      final m = computeMetrics(series: s);
      expect(m.omegaRatio, isNotNull);
      expect(m.omegaRatio!, greaterThan(1));
    });

    test('omega is null when there are no losses (denominator zero)', () {
      final s = _series(const [0.01, 0.0, 0.005, 0.01]);
      final m = computeMetrics(series: s);
      expect(m.omegaRatio, isNull);
    });
  });

  group('win rate', () {
    test('counts periods with strictly positive returns', () {
      final s = _series(const [0.01, 0.0, -0.01, 0.02, 0.005]);
      final m = computeMetrics(series: s);
      // 3 of 5 strictly positive → 0.6
      expect(m.winRate, closeTo(0.6, 1e-9));
    });
  });

  group('turnover', () {
    test('is null when no turnover provided', () {
      final s = _series(const [0.01, -0.005, 0.012]);
      final m = computeMetrics(series: s);
      expect(m.turnover, isNull);
    });

    test('passes through the explicit turnover input', () {
      final s = _series(const [0.01, -0.005, 0.012]);
      final m = computeMetrics(series: s, turnover: 0.42);
      expect(m.turnover, closeTo(0.42, 1e-12));
    });
  });
}
