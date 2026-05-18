import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

void main() {
  group('MobileFrontierPreviewResponse', () {
    test('calculates risk against market benchmark volatility', () {
      final response = MobileFrontierPreviewResponse.fromJson(const {
        'resolved_profile': {
          'code': 'balanced',
          'label': '균형형',
          'propensity_score': 45,
          'target_volatility': 0.15,
          'investment_horizon': 'medium',
        },
        'recommended_portfolio_code': 'balanced',
        'data_source': 'managed_universe',
        'market_benchmark_volatility': 0.10,
        'total_point_count': 2,
        'min_volatility': 0.10,
        'max_volatility': 0.15,
        'points': [
          {
            'index': 0,
            'volatility': 0.15,
            'expected_return': 0.08,
            'is_recommended': true,
          },
        ],
      });

      final comparison =
          response.marketBenchmarkRiskComparison(response.recommendedPoint);

      expect(response.marketBenchmarkVolatility, 0.10);
      expect(comparison, isNotNull);
      expect(comparison?.percentDiff, 50);
      expect(comparison?.isRiskier, isTrue);
    });

    test('does not fall back to frontier average when benchmark is missing',
        () {
      final response = MobileFrontierPreviewResponse.fromJson(const {
        'resolved_profile': {
          'code': 'balanced',
          'label': '균형형',
          'propensity_score': 45,
          'target_volatility': 0.15,
          'investment_horizon': 'medium',
        },
        'recommended_portfolio_code': 'balanced',
        'data_source': 'managed_universe',
        'total_point_count': 2,
        'min_volatility': 0.05,
        'max_volatility': 0.15,
        'points': [
          {
            'index': 0,
            'volatility': 0.05,
            'expected_return': 0.04,
            'is_recommended': false,
          },
          {
            'index': 1,
            'volatility': 0.15,
            'expected_return': 0.08,
            'is_recommended': true,
          },
        ],
      });

      final comparison =
          response.marketBenchmarkRiskComparison(response.recommendedPoint);

      expect(response.averageVolatility, 0.10);
      expect(response.marketBenchmarkVolatility, isNull);
      expect(comparison, isNull);
    });
  });
}
