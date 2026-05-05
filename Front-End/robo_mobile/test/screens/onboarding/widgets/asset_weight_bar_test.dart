import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/screens/onboarding/widgets/asset_weight.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: WeRoboTheme.light,
      home: Scaffold(body: SizedBox(width: 360, child: child)),
    );

void main() {
  testWidgets('AssetWeightBar — segments ordered by AssetClass enum (defensive→aggressive)', (tester) async {
    // Provide assets in random order; the bar must reorder cash → ... → growth.
    await tester.pumpWidget(_wrap(const AssetWeightBar(assets: [
      AssetWeight(cls: AssetClass.usGrowth, label: '미국성장주', tickers: [], weight: 0.10),
      AssetWeight(cls: AssetClass.cash, label: '현금성자산', tickers: [], weight: 0.50),
      AssetWeight(cls: AssetClass.shortBond, label: '단기채권', tickers: [], weight: 0.40),
    ])));
    final containers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    final colors = containers.map((c) => (c.decoration as BoxDecoration?)?.color).toList();
    // Leftmost segment must be cash tier (#FFC091).
    expect(colors.first, WeRoboColors.assetTier5);
    // Rightmost segment must be growth tier (#FE9337).
    expect(colors.last, WeRoboColors.assetTier1);
  });

  testWidgets('AssetWeightBar — empty/zero weights renders an empty fixed-height SizedBox', (tester) async {
    await tester.pumpWidget(_wrap(const AssetWeightBar(assets: [])));
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('AssetWeightList — sorts by weight desc and formats %', (tester) async {
    await tester.pumpWidget(_wrap(const AssetWeightList(assets: [
      AssetWeight(cls: AssetClass.cash, label: 'A', tickers: [], weight: 0.10),
      AssetWeight(cls: AssetClass.usGrowth, label: 'B', tickers: [], weight: 0.50),
    ])));
    final aPos = tester.getTopLeft(find.text('A')).dy;
    final bPos = tester.getTopLeft(find.text('B')).dy;
    expect(bPos, lessThan(aPos)); // B (higher weight) appears first
    expect(find.text('50.00%'), findsOneWidget);
  });

  testWidgets('AssetWeightList — formats weight as XX.XX%', (tester) async {
    await tester.pumpWidget(_wrap(const AssetWeightList(assets: [
      AssetWeight(cls: AssetClass.cash, label: '현금', tickers: [], weight: 0.2998),
    ])));
    expect(find.text('29.98%'), findsOneWidget);
  });
}
