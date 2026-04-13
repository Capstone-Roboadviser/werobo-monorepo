import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/projection_data.dart';

/// Monte Carlo projection engine using Geometric Brownian Motion.
///
/// Runs in a compute() isolate to avoid janking the UI thread.
/// Reference: https://robinhood.com/us/en/support/articles/future-projection/
///
/// GBM formula per monthly step:
///   S(t+dt) = S(t) * exp((mu - fee - sigma^2/2)*dt + sigma*sqrt(dt)*Z)
///   where dt = 1/12, Z ~ N(0,1) via Box-Muller transform
class MonteCarloEngine {
  MonteCarloEngine._();

  static Future<ProjectionResult> run(ProjectionParams params) {
    return compute(_runSimulation, params);
  }

  static ProjectionResult _runSimulation(ProjectionParams p) {
    final mu = p.mu.isNaN ? 0.05 : p.mu;
    final sigma = p.sigma.isNaN ? 0.15 : p.sigma.clamp(0.001, 1.0);
    final fee = p.feeRate;
    final dt = 1.0 / 12.0;
    final sqrtDt = sqrt(dt);
    final drift = (mu - fee - sigma * sigma / 2.0) * dt;
    final vol = sigma * sqrtDt;

    final months =
        ((p.targetAge - p.currentAge) * 12).round().clamp(0, 600);
    if (months <= 0) {
      return ProjectionResult(
        ages: [p.currentAge],
        p10: [p.currentValue],
        p25: [p.currentValue],
        median: [p.currentValue],
        p75: [p.currentValue],
        p90: [p.currentValue],
      );
    }

    final rng = Random(42);
    final n = p.numSimulations;
    final startValue = p.currentValue + p.oneTimeDeposit;

    // Simulate all paths: paths[sim][month]
    final paths = List.generate(n, (_) => List.filled(months + 1, 0.0));
    for (int s = 0; s < n; s++) {
      paths[s][0] = startValue;
      for (int m = 1; m <= months; m++) {
        final z = _nextGaussian(rng);
        paths[s][m] =
            paths[s][m - 1] * exp(drift + vol * z) + p.monthlyContrib;
      }
    }

    // Extract percentiles at each time step
    final ages = List<double>.generate(
      months + 1,
      (m) => p.currentAge + m / 12.0,
    );
    final p10 = List<double>.filled(months + 1, 0);
    final p25 = List<double>.filled(months + 1, 0);
    final med = List<double>.filled(months + 1, 0);
    final p75 = List<double>.filled(months + 1, 0);
    final p90 = List<double>.filled(months + 1, 0);

    final col = List<double>.filled(n, 0);
    for (int m = 0; m <= months; m++) {
      for (int s = 0; s < n; s++) {
        col[s] = paths[s][m];
      }
      col.sort();
      p10[m] = col[(n * 0.10).floor()];
      p25[m] = col[(n * 0.25).floor()];
      med[m] = col[(n * 0.50).floor()];
      p75[m] = col[(n * 0.75).floor()];
      p90[m] = col[(n * 0.90).floor().clamp(0, n - 1)];
    }

    return ProjectionResult(
      ages: ages,
      p10: p10,
      p25: p25,
      median: med,
      p75: p75,
      p90: p90,
    );
  }

  /// Box-Muller transform: uniform [0,1) -> standard normal N(0,1).
  static double _nextGaussian(Random rng) {
    final u1 = max(rng.nextDouble(), 1e-10);
    final u2 = rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }
}
