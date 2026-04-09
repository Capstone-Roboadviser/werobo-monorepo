import '../models/mobile_backend_models.dart';

/// Mock earnings data for demo until backend deploys
/// /portfolio/earnings-history endpoint.
class MockEarningsData {
  MockEarningsData._();

  static const balancedSummary = [
    MobileAssetEarningSummary(
      assetCode: 'us_value',
      assetName: '미국 가치주',
      weight: 0.30,
      earnings: 2340000,
      returnPct: 7.8,
    ),
    MobileAssetEarningSummary(
      assetCode: 'infra_bond',
      assetName: '인프라 채권',
      weight: 0.30,
      earnings: 1260000,
      returnPct: 4.2,
    ),
    MobileAssetEarningSummary(
      assetCode: 'short_term_bond',
      assetName: '단기 채권',
      weight: 0.19,
      earnings: 570000,
      returnPct: 3.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'us_growth',
      assetName: '미국 성장주',
      weight: 0.10,
      earnings: 890000,
      returnPct: 8.9,
    ),
    MobileAssetEarningSummary(
      assetCode: 'new_growth',
      assetName: '신성장주',
      weight: 0.05,
      earnings: -120000,
      returnPct: -2.4,
    ),
    MobileAssetEarningSummary(
      assetCode: 'gold',
      assetName: '금',
      weight: 0.03,
      earnings: 450000,
      returnPct: 15.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'cash_equivalents',
      assetName: '현금성자산',
      weight: 0.03,
      earnings: 90000,
      returnPct: 3.0,
    ),
  ];

  static const conservativeSummary = [
    MobileAssetEarningSummary(
      assetCode: 'short_term_bond',
      assetName: '단기 채권',
      weight: 0.30,
      earnings: 900000,
      returnPct: 3.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'infra_bond',
      assetName: '인프라 채권',
      weight: 0.30,
      earnings: 1260000,
      returnPct: 4.2,
    ),
    MobileAssetEarningSummary(
      assetCode: 'us_value',
      assetName: '미국 가치주',
      weight: 0.19,
      earnings: 1482000,
      returnPct: 7.8,
    ),
    MobileAssetEarningSummary(
      assetCode: 'cash_equivalents',
      assetName: '현금성자산',
      weight: 0.10,
      earnings: 300000,
      returnPct: 3.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'new_growth',
      assetName: '신성장주',
      weight: 0.05,
      earnings: -60000,
      returnPct: -1.2,
    ),
    MobileAssetEarningSummary(
      assetCode: 'gold',
      assetName: '금',
      weight: 0.03,
      earnings: 450000,
      returnPct: 15.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'us_growth',
      assetName: '미국 성장주',
      weight: 0.03,
      earnings: 267000,
      returnPct: 8.9,
    ),
  ];

  static const growthSummary = [
    MobileAssetEarningSummary(
      assetCode: 'us_value',
      assetName: '미국 가치주',
      weight: 0.30,
      earnings: 2340000,
      returnPct: 7.8,
    ),
    MobileAssetEarningSummary(
      assetCode: 'infra_bond',
      assetName: '인프라 채권',
      weight: 0.30,
      earnings: 1260000,
      returnPct: 4.2,
    ),
    MobileAssetEarningSummary(
      assetCode: 'short_term_bond',
      assetName: '단기 채권',
      weight: 0.19,
      earnings: 570000,
      returnPct: 3.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'us_growth',
      assetName: '미국 성장주',
      weight: 0.10,
      earnings: 890000,
      returnPct: 8.9,
    ),
    MobileAssetEarningSummary(
      assetCode: 'new_growth',
      assetName: '신성장주',
      weight: 0.05,
      earnings: -120000,
      returnPct: -2.4,
    ),
    MobileAssetEarningSummary(
      assetCode: 'gold',
      assetName: '금',
      weight: 0.03,
      earnings: 450000,
      returnPct: 15.0,
    ),
    MobileAssetEarningSummary(
      assetCode: 'cash_equivalents',
      assetName: '현금성자산',
      weight: 0.03,
      earnings: 90000,
      returnPct: 3.0,
    ),
  ];

  static List<MobileAssetEarningSummary> summaryFor(String riskCode) {
    switch (riskCode) {
      case 'conservative':
        return conservativeSummary;
      case 'growth':
        return growthSummary;
      case 'balanced':
      default:
        return balancedSummary;
    }
  }

  static double totalReturnFor(String riskCode) {
    final summary = summaryFor(riskCode);
    double total = 0;
    for (final a in summary) {
      total += a.earnings;
    }
    return total;
  }

  static double totalReturnPctFor(String riskCode) {
    return totalReturnFor(riskCode) / 100000000 * 100;
  }

  /// Plain-language commentary for the top contributor
  static String commentaryFor(String riskCode) {
    final summary = summaryFor(riskCode);
    final sorted = [...summary]
      ..sort((a, b) => b.earnings.compareTo(a.earnings));
    final top = sorted.first;
    final sign = top.returnPct >= 0 ? '+' : '';
    return '${top.assetName}이(가) $sign'
        '${top.returnPct.toStringAsFixed(1)}%로 '
        '가장 큰 수익 기여를 했어요.';
  }
}
