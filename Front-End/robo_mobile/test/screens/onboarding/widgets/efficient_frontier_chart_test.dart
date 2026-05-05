import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/onboarding/widgets/efficient_frontier_chart.dart';

void main() {
  MobileFrontierPreviewPoint pointWith({
    int index = 0,
    required double cash,
    required double shortBond,
    required double usGrowth,
  }) {
    return MobileFrontierPreviewPoint(
      index: index,
      volatility: 0.08,
      expectedReturn: 0.05,
      isRecommended: true,
      representativeCode: 'balanced',
      representativeLabel: '균형형',
      sectorAllocations: [
        MobileSectorAllocation(
          assetCode: 'cash_equivalents',
          assetName: '현금성자산',
          weight: cash,
          riskContribution: 0,
        ),
        MobileSectorAllocation(
          assetCode: 'short_term_bond',
          assetName: '단기채권',
          weight: shortBond,
          riskContribution: 0,
        ),
        MobileSectorAllocation(
          assetCode: 'us_growth',
          assetName: '미국성장주',
          weight: usGrowth,
          riskContribution: 0,
        ),
      ],
    );
  }

  test('frontier asset bubble specs scale radius from selected weights', () {
    const size = Size(320, 400);

    final defensiveSpecs = frontierAssetBubbleSpecs(
      point: pointWith(cash: 0.30, shortBond: 0.20, usGrowth: 0.03),
      size: size,
      selectedPosition: 0,
      previewPointCount: 2,
    );
    final growthSpecs = frontierAssetBubbleSpecs(
      point: pointWith(cash: 0.03, shortBond: 0.10, usGrowth: 0.30),
      size: size,
      selectedPosition: 1,
      previewPointCount: 2,
    );

    final defensiveCash = defensiveSpecs.singleWhere(
      (spec) => spec.cls == AssetClass.cash,
    );
    final growthCash = growthSpecs.singleWhere(
      (spec) => spec.cls == AssetClass.cash,
    );
    final defensiveGrowth = defensiveSpecs.singleWhere(
      (spec) => spec.cls == AssetClass.usGrowth,
    );
    final growthGrowth = growthSpecs.singleWhere(
      (spec) => spec.cls == AssetClass.usGrowth,
    );

    expect(defensiveCash.radius, greaterThan(growthCash.radius));
    expect(growthGrowth.radius, greaterThan(defensiveGrowth.radius));
    expect(defensiveCash.anchor.dy, greaterThan(size.height * 0.65));
    expect(growthGrowth.anchor.dx, greaterThan(size.width * 0.70));
  });

  testWidgets('EfficientFrontierChart repaints weighted bubbles on selection',
      (tester) async {
    final points = [
      pointWith(index: 0, cash: 0.30, shortBond: 0.20, usGrowth: 0.03),
      pointWith(index: 1, cash: 0.03, shortBond: 0.10, usGrowth: 0.30),
    ];

    Widget buildChart(int selectedPreviewPosition) {
      return MaterialApp(
        theme: WeRoboTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: EfficientFrontierChart(
                previewPoints: points,
                selectedPreviewPosition: selectedPreviewPosition,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildChart(0));
    await tester.pump(const Duration(milliseconds: 2200));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(buildChart(1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
