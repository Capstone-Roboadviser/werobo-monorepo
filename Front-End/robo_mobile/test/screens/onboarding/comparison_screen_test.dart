import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

void main() {
  group('formatRatioPercent', () {
    test('formats ratio as percentage with one decimal', () {
      expect(formatRatioPercent(0.074), '7.4%');
      expect(formatRatioPercent(0.055), '5.5%');
      expect(formatRatioPercent(0.12), '12.0%');
      expect(formatRatioPercent(0.0), '0.0%');
    });
  });

  group('sliderToVolatility mapping', () {
    // Replicate the _sliderToVolatility logic for testing
    double sliderToVolatility(double t, double minVol, double maxVol) =>
        minVol + t * (maxVol - minVol);

    test('maps t=0 to minVol', () {
      expect(sliderToVolatility(0.0, 0.04, 0.20), closeTo(0.04, 0.001));
    });

    test('maps t=1 to maxVol', () {
      expect(sliderToVolatility(1.0, 0.04, 0.20), closeTo(0.20, 0.001));
    });

    test('maps t=0.5 to midpoint', () {
      expect(sliderToVolatility(0.5, 0.04, 0.20), closeTo(0.12, 0.001));
    });

    test('handles equal min and max', () {
      expect(sliderToVolatility(0.5, 0.10, 0.10), closeTo(0.10, 0.001));
    });
  });

  group('risk display formatting', () {
    // Replicate the risk formatting logic
    String formatRisk(double volatility, double avgVolatility) {
      if (avgVolatility <= 0) return '0%';
      final diff = (volatility - avgVolatility) / avgVolatility;
      final pct = (diff.abs() * 100).round();
      if (pct == 0) return '0%';
      return diff >= 0 ? '+$pct%' : '-$pct%';
    }

    test('shows +X% for riskier portfolio', () {
      // 30% riskier than average
      expect(formatRisk(0.13, 0.10), '+30%');
    });

    test('shows -X% for safer portfolio', () {
      // 15% safer than average
      expect(formatRisk(0.085, 0.10), '-15%');
    });

    test('shows 0% when equal to average', () {
      expect(formatRisk(0.10, 0.10), '0%');
    });

    test('handles zero average volatility', () {
      expect(formatRisk(0.10, 0.0), '0%');
    });
  });

  group('parseValue', () {
    // Replicate _parseValue logic
    double parseValue(String v) =>
        double.tryParse(v.replaceAll(RegExp(r'[%+]'), '')) ?? 0;

    test('strips % and parses number', () {
      expect(parseValue('5.5%'), 5.5);
    });

    test('strips + and parses positive', () {
      expect(parseValue('+30%'), 30.0);
    });

    test('preserves - for negative', () {
      expect(parseValue('-15%'), -15.0);
    });

    test('returns 0 for invalid input', () {
      expect(parseValue('abc'), 0.0);
    });

    test('handles bare number', () {
      expect(parseValue('7.4'), 7.4);
    });
  });

  group('marketRiskComparison', () {
    MobileRecommendationResponse makeRecommendation(List<double> volatilities) {
      return MobileRecommendationResponse(
        resolvedProfile: const MobileResolvedProfile(
          code: 'balanced',
          label: '균형형',
          propensityScore: 50,
          targetVolatility: 0.12,
          investmentHorizon: 'medium',
        ),
        recommendedPortfolioCode: 'balanced',
        dataSource: 'managed_universe',
        asOfDate: DateTime(2026, 4, 15),
        portfolios: [
          for (int i = 0; i < volatilities.length; i++)
            MobilePortfolioRecommendation(
              code: ['conservative', 'balanced', 'growth'][i],
              label: ['안정형', '균형형', '성장형'][i],
              portfolioId: 'test-$i',
              targetVolatility: volatilities[i],
              expectedReturn: 0.05 + i * 0.02,
              volatility: volatilities[i],
              sharpeRatio: 0.5,
              sectorAllocations: const [],
              stockAllocations: const [],
            ),
        ],
      );
    }

    test('averageVolatility computes mean of all portfolios', () {
      final rec = makeRecommendation([0.08, 0.12, 0.16]);
      expect(rec.averageVolatility, closeTo(0.12, 0.001));
    });

    test('returns isRiskier=true for above-average volatility', () {
      final rec = makeRecommendation([0.08, 0.12, 0.16]);
      final growth = rec.portfolios[2];
      final result = rec.marketRiskComparison(growth);
      expect(result.isRiskier, isTrue);
      expect(result.percentDiff, greaterThan(0));
    });

    test('returns isRiskier=false for below-average volatility', () {
      final rec = makeRecommendation([0.08, 0.12, 0.16]);
      final conservative = rec.portfolios[0];
      final result = rec.marketRiskComparison(conservative);
      expect(result.isRiskier, isFalse);
      expect(result.percentDiff, greaterThan(0));
    });

    test('returns percentDiff=0 when volatility equals average', () {
      final rec = makeRecommendation([0.10, 0.10, 0.10]);
      final result = rec.marketRiskComparison(rec.portfolios[0]);
      expect(result.percentDiff, 0);
    });
  });
}
