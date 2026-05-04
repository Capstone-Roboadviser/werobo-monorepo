import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import 'onboarding_screen.dart' show OnboardingFrontierSelection;
import 'widgets/asset_weight.dart';

/// Builds the canonical 7 `AssetWeight` rows from a weights vector indexed
/// by `AssetClass.index` (cash → newGrowth, length 7). Shared by both the
/// frontier screen's live drag bar and the portfolio review screen's
/// snapshot list, so the row order, labels, and tickers stay aligned in
/// exactly one place.
List<AssetWeight> buildAssetWeightRows(List<double> weights) => [
      AssetWeight(
        cls: AssetClass.cash,
        label: '현금성자산',
        tickers: const ['BIL', 'VCSH', 'BSV'],
        weight: weights[AssetClass.cash.index],
      ),
      AssetWeight(
        cls: AssetClass.shortBond,
        label: '단기채권',
        tickers: const ['BND', 'AGG', 'LQD'],
        weight: weights[AssetClass.shortBond.index],
      ),
      AssetWeight(
        cls: AssetClass.infraBond,
        label: '인프라채권',
        tickers: const ['NFRA', 'GII', 'IGF'],
        weight: weights[AssetClass.infraBond.index],
      ),
      AssetWeight(
        cls: AssetClass.gold,
        label: '금',
        tickers: const ['DBC', 'SGOL', 'GLD'],
        weight: weights[AssetClass.gold.index],
      ),
      AssetWeight(
        cls: AssetClass.usValue,
        label: '미국가치주',
        tickers: const ['MGV', 'VBR', 'VTV'],
        weight: weights[AssetClass.usValue.index],
      ),
      AssetWeight(
        cls: AssetClass.usGrowth,
        label: '미국성장주',
        tickers: const ['VBK', 'MGK', 'VUG'],
        weight: weights[AssetClass.usGrowth.index],
      ),
      AssetWeight(
        cls: AssetClass.newGrowth,
        label: '신성장주',
        tickers: const [],
        weight: weights[AssetClass.newGrowth.index],
      ),
    ];

/// Converts a frontier selection to the list of asset weights at the
/// selection's currently chosen point. Shared between the frontier screen
/// (live drag updates) and the portfolio review screen (snapshot at confirm).
List<AssetWeight> resolveAssetWeights(OnboardingFrontierSelection selection) {
  return buildAssetWeightRows(selection.weightsAt(selection.normalizedT));
}

class OnboardingSelectionRequest {
  final int? pointIndex;
  final double? targetVolatility;
  final String? preferredDataSource;
  final DateTime? asOfDate;

  const OnboardingSelectionRequest({
    required this.pointIndex,
    required this.targetVolatility,
    required this.preferredDataSource,
    required this.asOfDate,
  });
}

OnboardingSelectionRequest resolveOnboardingSelectionRequest({
  required double normalizedT,
  required int? selectedPointIndex,
  required double? targetVolatility,
  required String? preferredDataSource,
  required DateTime? asOfDate,
  MobileFrontierPreviewResponse? preview,
}) {
  if (preferredDataSource != null ||
      preview == null ||
      preview.points.isEmpty) {
    return OnboardingSelectionRequest(
      pointIndex: selectedPointIndex,
      targetVolatility: targetVolatility,
      preferredDataSource: preferredDataSource,
      asOfDate: asOfDate,
    );
  }

  final previewPoint = _resolvePreviewPoint(
    preview: preview,
    normalizedT: normalizedT,
    selectedPointIndex: selectedPointIndex,
    targetVolatility: targetVolatility,
  );

  return OnboardingSelectionRequest(
    pointIndex: previewPoint?.index,
    targetVolatility: previewPoint?.volatility ?? targetVolatility,
    preferredDataSource: preview.dataSource,
    asOfDate: preview.asOfDate ?? asOfDate,
  );
}

MobileFrontierPreviewPoint? _resolvePreviewPoint({
  required MobileFrontierPreviewResponse preview,
  required double normalizedT,
  required int? selectedPointIndex,
  required double? targetVolatility,
}) {
  if (preview.points.isEmpty) {
    return null;
  }

  if (targetVolatility != null) {
    return preview.points.reduce(
      (best, candidate) => (candidate.volatility - targetVolatility).abs() <
              (best.volatility - targetVolatility).abs()
          ? candidate
          : best,
    );
  }

  if (selectedPointIndex != null) {
    final matchedPoint = preview.pointByIndex(selectedPointIndex);
    if (matchedPoint != null) {
      return matchedPoint;
    }
  }

  final previewPosition = preview.points.length <= 1
      ? 0
      : (normalizedT * (preview.points.length - 1))
          .round()
          .clamp(0, preview.points.length - 1);
  return preview.points[previewPosition];
}
