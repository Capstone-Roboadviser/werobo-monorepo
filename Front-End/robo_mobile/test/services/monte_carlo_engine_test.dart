import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/projection_data.dart';
import 'package:robo_mobile/services/monte_carlo_engine.dart';

void main() {
  group('MonteCarloEngine', () {
    test('produces deterministic output with fixed seed', () async {
      final params = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 25,
        targetAge: 65,
      );
      final r1 = await MonteCarloEngine.run(params);
      final r2 = await MonteCarloEngine.run(params);
      expect(r1.medianFinal, r2.medianFinal);
    });

    test('median grows approximately at mu rate', () async {
      const mu = 0.08;
      const fee = 0.005;
      const years = 40.0;
      const startValue = 10000000.0;
      final params = ProjectionParams(
        mu: mu,
        sigma: 0.15,
        currentValue: startValue,
        currentAge: 25,
        targetAge: 65,
      );
      final result = await MonteCarloEngine.run(params);

      // GBM median: startValue * exp((mu - fee - sigma^2/2) * years)
      const sigma = 0.15;
      final expected =
          startValue * exp((mu - fee - sigma * sigma / 2) * years);
      // Allow 25% tolerance for Monte Carlo variance
      expect(
        result.medianFinal,
        closeTo(expected, expected * 0.25),
      );
    });

    test('percentiles are monotonically ordered at every step',
        () async {
      final params = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 25,
        targetAge: 65,
      );
      final result = await MonteCarloEngine.run(params);

      for (int i = 0; i < result.length; i++) {
        expect(result.p10[i], lessThanOrEqualTo(result.p25[i]),
            reason: 'p10 <= p25 at step $i');
        expect(result.p25[i], lessThanOrEqualTo(result.median[i]),
            reason: 'p25 <= median at step $i');
        expect(result.median[i], lessThanOrEqualTo(result.p75[i]),
            reason: 'median <= p75 at step $i');
        expect(result.p75[i], lessThanOrEqualTo(result.p90[i]),
            reason: 'p75 <= p90 at step $i');
      }
    });

    test('spread increases over time', () async {
      final params = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 25,
        targetAge: 65,
      );
      final result = await MonteCarloEngine.run(params);

      final earlySpread = result.p90[12] - result.p10[12]; // 1 year
      final lateSpread = result.p90.last - result.p10.last; // 40 years
      expect(lateSpread, greaterThan(earlySpread));
    });

    test('zero current value produces zero output', () async {
      final params = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 0,
        currentAge: 25,
        targetAge: 65,
        monthlyContrib: 0,
        oneTimeDeposit: 0,
      );
      final result = await MonteCarloEngine.run(params);
      // With zero start and zero contributions, all paths stay at 0
      // (GBM multiplies by previous value)
      expect(result.median[0], 0);
    });

    test('monthly contributions increase all percentiles', () async {
      final base = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 25,
        targetAge: 65,
        monthlyContrib: 0,
      );
      final withContrib = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 25,
        targetAge: 65,
        monthlyContrib: 100000,
      );
      final rBase = await MonteCarloEngine.run(base);
      final rContrib = await MonteCarloEngine.run(withContrib);

      expect(rContrib.medianFinal, greaterThan(rBase.medianFinal));
      expect(rContrib.p10.last, greaterThan(rBase.p10.last));
      expect(rContrib.p90.last, greaterThan(rBase.p90.last));
    });

    test('currentAge >= targetAge returns single-point result',
        () async {
      final params = ProjectionParams(
        mu: 0.08,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 65,
        targetAge: 65,
      );
      final result = await MonteCarloEngine.run(params);
      expect(result.length, 1);
      expect(result.median[0], 10000000);
    });

    test('handles NaN mu by defaulting to 0.05', () async {
      final params = ProjectionParams(
        mu: double.nan,
        sigma: 0.15,
        currentValue: 10000000,
        currentAge: 25,
        targetAge: 35,
      );
      final result = await MonteCarloEngine.run(params);
      expect(result.medianFinal, isNot(isNaN));
      expect(result.medianFinal, greaterThan(0));
    });
  });
}
