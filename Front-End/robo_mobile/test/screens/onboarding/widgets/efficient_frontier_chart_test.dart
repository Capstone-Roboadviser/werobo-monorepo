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

  test('frontier asset bubble labels use full asset-class names', () {
    expect(frontierAssetBubbleLabel(AssetClass.cash), '현금성자산');
    expect(frontierAssetBubbleLabel(AssetClass.usValue), '미국가치주');
    expect(frontierAssetBubbleLabel(AssetClass.usGrowth), '미국성장주');
    expect(frontierAssetBubbleLabel(AssetClass.newGrowth), '신성장주');
  });

  test(
    'frontier asset bubble specs lock anchors and scale radius by weight',
    () {
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

      // All seven asset classes always render.
      expect(defensiveSpecs.length, AssetClass.values.length);
      expect(growthSpecs.length, AssetClass.values.length);

      // Anchors are locked — they don't move with selection.
      for (final cls in AssetClass.values) {
        final a = defensiveSpecs.firstWhere((s) => s.cls == cls);
        final b = growthSpecs.firstWhere((s) => s.cls == cls);
        expect(a.anchor, b.anchor);
      }

      // Radius scales with weight: cash is heavier in defensive,
      // usGrowth heavier in growth.
      final defensiveCash = defensiveSpecs.firstWhere(
        (s) => s.cls == AssetClass.cash,
      );
      final growthCash = growthSpecs.firstWhere(
        (s) => s.cls == AssetClass.cash,
      );
      final defensiveGrowth = defensiveSpecs.firstWhere(
        (s) => s.cls == AssetClass.usGrowth,
      );
      final growthGrowth = growthSpecs.firstWhere(
        (s) => s.cls == AssetClass.usGrowth,
      );
      expect(defensiveCash.radius, greaterThan(growthCash.radius));
      expect(growthGrowth.radius, greaterThan(defensiveGrowth.radius));

      // Radius stays inside the 65%/110% bounds of the 7.0px base.
      for (final spec in [...defensiveSpecs, ...growthSpecs]) {
        expect(spec.radius, greaterThanOrEqualTo(4.55));
        expect(spec.radius, lessThanOrEqualTo(7.7));
      }

      // Stair-step direction: cash bottom-left, newGrowth top-right.
      final cash = defensiveSpecs.firstWhere((s) => s.cls == AssetClass.cash);
      final newGrowth =
          defensiveSpecs.firstWhere((s) => s.cls == AssetClass.newGrowth);
      expect(cash.anchor.dy, greaterThan(size.height * 0.85));
      expect(newGrowth.anchor.dx, greaterThan(size.width * 0.70));
      expect(newGrowth.anchor.dy, lessThan(size.height * 0.25));
    },
  );

  test('frontier curve uses most of the chart width', () {
    const size = Size(320, 360);

    final start = frontierCurvePointForT(0, size);
    final end = frontierCurvePointForT(1, size);

    expect(start.dx, lessThanOrEqualTo(size.width * 0.10));
    expect(end.dx, greaterThan(size.width * 0.90));
  });

  test('frontier bubble label layout avoids overlap in compact charts', () {
    const size = Size(260, 220);
    final specs = frontierAssetBubbleSpecs(
      point: null,
      size: size,
      selectedPosition: 60,
      previewPointCount: 61,
    );

    final labels = frontierAssetBubbleLabelLayouts(
      bubbleSpecs: specs,
      size: size,
    );

    for (var i = 0; i < labels.length; i++) {
      expect(labels[i].rect.left, greaterThanOrEqualTo(0));
      expect(labels[i].rect.right, lessThanOrEqualTo(size.width));
      expect(labels[i].rect.top, greaterThanOrEqualTo(0));
      expect(labels[i].rect.bottom, lessThanOrEqualTo(size.height));
      for (var j = i + 1; j < labels.length; j++) {
        expect(
          labels[i].rect.overlaps(labels[j].rect),
          isFalse,
          reason: '${labels[i].cls.koLabel} overlaps ${labels[j].cls.koLabel}',
        );
      }
    }
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
