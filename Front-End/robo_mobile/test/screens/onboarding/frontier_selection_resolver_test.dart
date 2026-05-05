import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/onboarding/frontier_selection_resolver.dart';

void main() {
  MobileFrontierPreviewResponse buildPreview({
    required String dataSource,
    DateTime? asOfDate,
  }) {
    return MobileFrontierPreviewResponse(
      resolvedProfile: const MobileResolvedProfile(
        code: 'balanced',
        label: '균형형',
        propensityScore: 45,
        targetVolatility: 0.07,
        investmentHorizon: 'medium',
      ),
      recommendedPortfolioCode: 'balanced',
      dataSource: dataSource,
      asOfDate: asOfDate,
      totalPointCount: 3,
      minVolatility: 0.05,
      maxVolatility: 0.09,
      points: const [
        MobileFrontierPreviewPoint(
          index: 10,
          volatility: 0.05,
          expectedReturn: 0.04,
          isRecommended: false,
          representativeCode: 'conservative',
          representativeLabel: '안정형',
          sectorAllocations: [],
        ),
        MobileFrontierPreviewPoint(
          index: 20,
          volatility: 0.07,
          expectedReturn: 0.05,
          isRecommended: true,
          representativeCode: 'balanced',
          representativeLabel: '균형형',
          sectorAllocations: [],
        ),
        MobileFrontierPreviewPoint(
          index: 30,
          volatility: 0.09,
          expectedReturn: 0.06,
          isRecommended: false,
          representativeCode: 'growth',
          representativeLabel: '성장형',
          sectorAllocations: [],
        ),
      ],
    );
  }

  group('resolveOnboardingSelectionRequest', () {
    test('keeps authoritative selection inputs unchanged', () {
      final request = resolveOnboardingSelectionRequest(
        normalizedT: 0.45,
        selectedPointIndex: 40,
        targetVolatility: 0.0696,
        preferredDataSource: 'managed_universe',
        asOfDate: DateTime(2026, 4, 15),
        preview: buildPreview(
          dataSource: 'stock_combination_demo',
          asOfDate: DateTime(2026, 4, 14),
        ),
      );

      expect(request.pointIndex, 40);
      expect(request.targetVolatility, 0.0696);
      expect(request.preferredDataSource, 'managed_universe');
      expect(request.asOfDate, DateTime(2026, 4, 15));
    });

    test('resolves placeholder selection against preview by volatility', () {
      final request = resolveOnboardingSelectionRequest(
        normalizedT: 0.64,
        selectedPointIndex: null,
        targetVolatility: 0.0696,
        preferredDataSource: null,
        asOfDate: DateTime(2026, 4, 15),
        preview: buildPreview(
          dataSource: 'stock_combination_demo',
          asOfDate: DateTime(2026, 4, 14),
        ),
      );

      expect(request.pointIndex, 20);
      expect(request.targetVolatility, 0.07);
      expect(request.preferredDataSource, 'stock_combination_demo');
      expect(request.asOfDate, DateTime(2026, 4, 14));
    });

    test('falls back to normalized position when preview has no target hint',
        () {
      final request = resolveOnboardingSelectionRequest(
        normalizedT: 1.0,
        selectedPointIndex: null,
        targetVolatility: null,
        preferredDataSource: null,
        asOfDate: DateTime(2026, 4, 15),
        preview: buildPreview(dataSource: 'stock_combination_demo'),
      );

      expect(request.pointIndex, 30);
      expect(request.targetVolatility, 0.09);
      expect(request.preferredDataSource, 'stock_combination_demo');
      expect(request.asOfDate, DateTime(2026, 4, 15));
    });
  });
}
