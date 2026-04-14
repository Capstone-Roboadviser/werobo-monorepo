import '../../models/mobile_backend_models.dart';

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
