import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';

void main() {
  Map<String, dynamic> baseJson() => <String, dynamic>{
        'digest_date': '2026-04-29',
        'period_start': '2026-04-22',
        'period_end': '2026-04-29',
        'total_return_pct': 6.0,
        'total_return_won': 600000,
        'narrative_ko': null,
        'has_narrative': false,
        'drivers': <Map<String, dynamic>>[],
        'detractors': <Map<String, dynamic>>[],
        'sources_used': <String>[],
        'disclaimer': '...',
        'generated_at': '2026-04-29T00:00:00Z',
        'degradation_level': 0,
      };

  test('parses available=true', () {
    final json = baseJson()..['available'] = true;
    final result = MobileDigestResponse.fromJson(json);
    expect(result.available, isTrue);
  });

  test('parses available=false', () {
    final json = baseJson()..['available'] = false;
    final result = MobileDigestResponse.fromJson(json);
    expect(result.available, isFalse);
  });

  test('defaults available to true when absent', () {
    final json = baseJson(); // no 'available' key
    final result = MobileDigestResponse.fromJson(json);
    expect(result.available, isTrue);
  });

  test('parses rolling volatility trigger context', () {
    final json = baseJson()
      ..['baseline_volatility_pct'] = 0.42
      ..['trigger_threshold_pct'] = 0.84
      ..['trigger_sigma_multiple'] = 2.7;

    final result = MobileDigestResponse.fromJson(json);

    expect(result.baselineVolatilityPct, 0.42);
    expect(result.triggerThresholdPct, 0.84);
    expect(result.triggerSigmaMultiple, 2.7);
  });

  test('parses range digest response with reference news', () {
    final result = MobileRangeDigestResponse.fromJson(<String, dynamic>{
      'period_start': '2026-04-10',
      'period_end': '2026-04-18',
      'total_return_pct': 2.4,
      'total_return_won': 240000,
      'narrative_ko': '미국 성장주 반등이 수익을 이끌었어요.',
      'has_narrative': true,
      'drivers': <Map<String, dynamic>>[
        {
          'ticker': 'QQQ',
          'name_ko': '미국 성장주',
          'sector_code': 'us_growth',
          'weight_pct': 60,
          'return_pct': 4,
          'contribution_won': 180000,
          'explanation_ko': '기술주 반등이 기여했어요.',
        },
      ],
      'detractors': <Map<String, dynamic>>[],
      'reference_news': <Map<String, dynamic>>[
        {
          'ticker': 'QQQ',
          'title': 'Tech shares rise on earnings optimism',
        },
      ],
      'sources_used': <String>['Google News'],
      'disclaimer': '...',
      'generated_at': '2026-04-18T00:00:00Z',
      'degradation_level': 0,
    });

    expect(result.periodStart, '2026-04-10');
    expect(result.totalReturnPct, 2.4);
    expect(result.drivers.single.explanationKo, '기술주 반등이 기여했어요.');
    expect(result.referenceNews.single.ticker, 'QQQ');
    expect(result.referenceNews.single.title,
        'Tech shares rise on earnings optimism');
  });
}
