import 'dart:math' as math;

/// One point on a cumulative-return time series. cumReturn is the decimal
/// return relative to the start of the series (0.0 at t0, 0.05 = +5% later).
typedef ReturnPoint = ({DateTime date, double cumReturn});

/// Risk and performance metrics for a single portfolio (and optionally
/// against a benchmark). Every field is nullable: math that requires more
/// data than the input provides (e.g. variance with constant returns) yields
/// null rather than infinity or NaN.
class PortfolioMetrics {
  final double? sharpeRatio;
  final double? cagr;
  final double? cumulativeReturn;
  final double? alpha;
  final double? beta;
  final double? volatility;
  final double? maxDrawdown;
  final double? valueAtRisk;
  final double? conditionalValueAtRisk;
  final double? downsideDeviation;
  final double? sortinoRatio;
  final double? calmarRatio;
  final double? treynorRatio;
  final double? informationRatio;
  final double? omegaRatio;
  final double? correlation;
  final double? winRate;
  final double? turnover;

  const PortfolioMetrics({
    this.sharpeRatio,
    this.cagr,
    this.cumulativeReturn,
    this.alpha,
    this.beta,
    this.volatility,
    this.maxDrawdown,
    this.valueAtRisk,
    this.conditionalValueAtRisk,
    this.downsideDeviation,
    this.sortinoRatio,
    this.calmarRatio,
    this.treynorRatio,
    this.informationRatio,
    this.omegaRatio,
    this.correlation,
    this.winRate,
    this.turnover,
  });

  static const empty = PortfolioMetrics();
}

/// Compute risk/performance metrics from a cumulative-return series. When
/// [benchmark] is supplied, also fills paired metrics (alpha, beta,
/// correlation, information ratio, Treynor). [riskFreeAnnual] is decimal
/// (0.025 = 2.5%/year). [turnover] is passed through unchanged when present.
PortfolioMetrics computeMetrics({
  required List<ReturnPoint> series,
  List<ReturnPoint>? benchmark,
  double riskFreeAnnual = 0.025,
  double? turnover,
}) {
  if (series.length < 2) {
    return PortfolioMetrics(turnover: turnover);
  }

  final sorted = [...series]..sort((a, b) => a.date.compareTo(b.date));
  final periodic = _periodicReturns(sorted);
  if (periodic.isEmpty) {
    return PortfolioMetrics(turnover: turnover);
  }

  // Period-to-year scaling derived from the actual elapsed time so this
  // works for daily, weekly, or sampled data.
  final elapsedDays =
      sorted.last.date.difference(sorted.first.date).inDays;
  if (elapsedDays <= 0) {
    return PortfolioMetrics(turnover: turnover);
  }
  final elapsedYears = elapsedDays / 365.25;
  final periodsPerYear = periodic.length / elapsedYears;
  final annualVolScale = math.sqrt(periodsPerYear);

  final cumReturn = sorted.last.cumReturn;
  final cagr = elapsedYears > 0
      ? math.pow(1 + cumReturn, 1 / elapsedYears) - 1
      : null;

  final meanPeriodic = _mean(periodic);
  final stdPeriodic = _std(periodic);
  final annualMean = meanPeriodic * periodsPerYear;
  final annualStd = stdPeriodic * annualVolScale;

  final sharpe = (annualStd > 0)
      ? (annualMean - riskFreeAnnual) / annualStd
      : null;

  final mdd = _maxDrawdown(sorted);

  // Downside dev / Sortino: only periods below 0 (simple MAR=0 convention)
  // contribute. Downside dev annualized for ratio comparability.
  final downside = _downsideDeviation(periodic) * annualVolScale;
  final sortino = downside > 0
      ? (annualMean - riskFreeAnnual) / downside
      : null;

  final calmar = (mdd != null && mdd > 0 && cagr != null)
      ? (cagr / mdd).toDouble()
      : null;

  // 5% VaR/CVaR on periodic returns. Both expressed as positive magnitudes
  // (worst-case loss). Periodic, not annualized — matches industry convention
  // for tail-risk reporting on raw return series.
  final var5 = _historicalVaR(periodic, 0.05);
  final cvar5 = _conditionalVaR(periodic, 0.05);

  final omega = _omega(periodic, threshold: 0.0);
  final winRate = _winRate(periodic);

  double? alpha;
  double? beta;
  double? correlation;
  double? treynor;
  double? informationRatio;
  if (benchmark != null && benchmark.length >= 2) {
    final benchSorted = [...benchmark]..sort((a, b) => a.date.compareTo(b.date));
    final (alignedSeries, alignedBench) = _alignByDate(sorted, benchSorted);
    if (alignedSeries.length >= 2) {
      final periodicS = _periodicReturns(alignedSeries);
      final periodicB = _periodicReturns(alignedBench);
      if (periodicS.length == periodicB.length && periodicS.isNotEmpty) {
        final varB = _variance(periodicB);
        if (varB > 0) {
          beta = _covariance(periodicS, periodicB) / varB;
          final annualMeanB = _mean(periodicB) * periodsPerYear;
          alpha = (annualMean - riskFreeAnnual) -
              beta * (annualMeanB - riskFreeAnnual);
          if (beta != 0) {
            treynor = (annualMean - riskFreeAnnual) / beta;
          }
        }
        correlation = _pearson(periodicS, periodicB);
        final diff = <double>[
          for (var i = 0; i < periodicS.length; i++)
            periodicS[i] - periodicB[i],
        ];
        final teAnnual = _std(diff) * annualVolScale;
        if (teAnnual > 0) {
          final annualMeanB = _mean(periodicB) * periodsPerYear;
          informationRatio = (annualMean - annualMeanB) / teAnnual;
        }
      }
    }
  }

  return PortfolioMetrics(
    sharpeRatio: sharpe,
    cagr: cagr?.toDouble(),
    cumulativeReturn: cumReturn,
    alpha: alpha,
    beta: beta,
    volatility: annualStd,
    maxDrawdown: mdd,
    valueAtRisk: var5,
    conditionalValueAtRisk: cvar5,
    downsideDeviation: downside,
    sortinoRatio: sortino,
    calmarRatio: calmar,
    treynorRatio: treynor,
    informationRatio: informationRatio,
    omegaRatio: omega,
    correlation: correlation,
    winRate: winRate,
    turnover: turnover,
  );
}

// ─── Helpers ────────────────────────────────────────────────────────────────

List<double> _periodicReturns(List<ReturnPoint> series) {
  final r = <double>[];
  for (var i = 1; i < series.length; i++) {
    final prev = 1 + series[i - 1].cumReturn;
    final curr = 1 + series[i].cumReturn;
    if (prev <= 0) continue;
    r.add((curr / prev) - 1.0);
  }
  return r;
}

double _mean(List<double> xs) {
  if (xs.isEmpty) return 0;
  var s = 0.0;
  for (final x in xs) {
    s += x;
  }
  return s / xs.length;
}

double _variance(List<double> xs) {
  if (xs.length < 2) return 0;
  final m = _mean(xs);
  var s = 0.0;
  for (final x in xs) {
    final d = x - m;
    s += d * d;
  }
  // Sample variance (n-1) — matches std in stats packages.
  return s / (xs.length - 1);
}

double _std(List<double> xs) => math.sqrt(_variance(xs));

double _covariance(List<double> a, List<double> b) {
  if (a.length < 2 || a.length != b.length) return 0;
  final ma = _mean(a);
  final mb = _mean(b);
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - ma) * (b[i] - mb);
  }
  return s / (a.length - 1);
}

double? _pearson(List<double> a, List<double> b) {
  final sa = _std(a);
  final sb = _std(b);
  if (sa == 0 || sb == 0) return null;
  return _covariance(a, b) / (sa * sb);
}

double? _maxDrawdown(List<ReturnPoint> series) {
  if (series.length < 2) return null;
  var peak = 1 + series.first.cumReturn;
  var maxDd = 0.0;
  for (final p in series) {
    final v = 1 + p.cumReturn;
    if (v > peak) peak = v;
    if (peak > 0) {
      final dd = (peak - v) / peak;
      if (dd > maxDd) maxDd = dd;
    }
  }
  return maxDd;
}

double _downsideDeviation(List<double> periodic, {double threshold = 0.0}) {
  if (periodic.length < 2) return 0;
  var s = 0.0;
  var n = 0;
  for (final r in periodic) {
    if (r < threshold) {
      final d = r - threshold;
      s += d * d;
      n++;
    }
  }
  if (n == 0) return 0;
  // Population-style downside deviation: divide by total count, not n-1.
  // This matches the standard Sortino convention.
  return math.sqrt(s / periodic.length);
}

double? _historicalVaR(List<double> periodic, double alpha) {
  if (periodic.length < 5) return null;
  final sorted = [...periodic]..sort();
  // Linear-interpolated lower-tail quantile.
  final idx = alpha * (sorted.length - 1);
  final lower = idx.floor();
  final upper = idx.ceil();
  final frac = idx - lower;
  final q = sorted[lower] + (sorted[upper] - sorted[lower]) * frac;
  // VaR is a loss magnitude → flip sign if negative; 0 if no left tail.
  if (q >= 0) return 0.0;
  return -q;
}

double? _conditionalVaR(List<double> periodic, double alpha) {
  if (periodic.length < 5) return null;
  final sorted = [...periodic]..sort();
  final cutoffIdx = (alpha * sorted.length).floor();
  if (cutoffIdx <= 0) {
    // Need at least one tail observation.
    return _historicalVaR(periodic, alpha);
  }
  var s = 0.0;
  for (var i = 0; i < cutoffIdx; i++) {
    s += sorted[i];
  }
  final avg = s / cutoffIdx;
  if (avg >= 0) return 0.0;
  return -avg;
}

double? _omega(List<double> periodic, {required double threshold}) {
  var gains = 0.0;
  var losses = 0.0;
  for (final r in periodic) {
    final excess = r - threshold;
    if (excess > 0) {
      gains += excess;
    } else if (excess < 0) {
      losses += -excess;
    }
  }
  if (losses == 0) return null;
  return gains / losses;
}

double? _winRate(List<double> periodic) {
  if (periodic.isEmpty) return null;
  var wins = 0;
  for (final r in periodic) {
    if (r > 0) wins++;
  }
  return wins / periodic.length;
}

/// Restrict two series to their shared dates so paired metrics line up.
(List<ReturnPoint>, List<ReturnPoint>) _alignByDate(
  List<ReturnPoint> a,
  List<ReturnPoint> b,
) {
  final byDateA = {for (final p in a) p.date: p};
  final outA = <ReturnPoint>[];
  final outB = <ReturnPoint>[];
  for (final p in b) {
    final match = byDateA[p.date];
    if (match != null) {
      outA.add(match);
      outB.add(p);
    }
  }
  // Re-anchor cumReturn so each aligned series starts at 0 — keeps periodic
  // returns honest after dropping leading points that the other side lacks.
  return (_reanchor(outA), _reanchor(outB));
}

List<ReturnPoint> _reanchor(List<ReturnPoint> s) {
  if (s.isEmpty) return s;
  final base = 1 + s.first.cumReturn;
  if (base == 0) return s;
  return [
    for (final p in s)
      (date: p.date, cumReturn: (1 + p.cumReturn) / base - 1),
  ];
}
