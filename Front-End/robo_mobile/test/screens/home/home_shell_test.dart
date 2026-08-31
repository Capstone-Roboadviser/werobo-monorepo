import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/pressable.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/app/theme_state.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/home_dashboard_tab.dart';
import 'package:robo_mobile/screens/home/home_shell.dart';
import 'package:robo_mobile/screens/home/portfolio_analysis_tab.dart';
import 'package:robo_mobile/screens/onboarding/widgets/vestor_pie_chart.dart';

void main() {
  MobileAccountHistoryPoint point(int day, double value) {
    return MobileAccountHistoryPoint(
      date: DateTime(2026, 8, day),
      portfolioValue: value,
      investedAmount: 10000000,
      profitLoss: value - 10000000,
      profitLossPct: value / 10000000 - 1,
    );
  }

  test('flat account history uses a visible fallback sparkline', () {
    final history = [for (var day = 1; day <= 12; day++) point(day, 10571089)];

    final result = dashboardSparklinePoints(history);

    expect(result.toSet().length, greaterThan(1));
  });

  test('sparkline preserves actual changing account history', () {
    final history = [
      point(1, 10000000),
      point(2, 10050000),
      point(3, 10020000),
      point(4, 10110000),
    ];

    expect(
      dashboardSparklinePoints(history),
      [10000000, 10050000, 10020000, 10110000],
    );
  });

  Widget buildSubject() {
    final state = PortfolioState();
    final themeNotifier = ThemeNotifier();
    addTearDown(state.dispose);
    addTearDown(themeNotifier.dispose);
    return PortfolioStateProvider(
      state: state,
      child: ThemeStateProvider(
        notifier: themeNotifier,
        child: MaterialApp(
          theme: WeRoboTheme.light,
          home: const HomeShell(),
        ),
      ),
    );
  }

  testWidgets('bottom navigation shows icon labels for all tabs',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    for (final label in ['홈', '분석', '커뮤니티', '뉴스', '설정']) {
      expect(find.widgetWithText(Pressable, label), findsOneWidget);
    }
  });

  testWidgets('selected bottom navigation item uses the writing button navy',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(
      tester.widget<Icon>(find.byIcon(Icons.home_rounded)).color,
      WeRoboColors.primary,
    );

    await tester.tap(find.widgetWithText(Pressable, '커뮤니티'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      tester.widget<Icon>(find.byIcon(Icons.forum_rounded)).color,
      WeRoboColors.primary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color,
      const Color(0xFF8B94A5),
    );
  });

  testWidgets('home uses white surfaces and the light bottom navigation',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.white);

    for (final key in ['quick_insight_card', 'market_summary_card']) {
      final container = tester.widget<Container>(find.byKey(Key(key)));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, WeRoboThemeColors.light.card);
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
    }

    final navigation = tester.widget<Container>(
      find.byKey(const Key('main_bottom_navigation')),
    );
    final navigationDecoration = navigation.decoration! as BoxDecoration;
    expect(navigationDecoration.color, Colors.white);
    expect(navigationDecoration.border, isNotNull);
    expect(navigationDecoration.boxShadow, isNotEmpty);

    expect(
      tester.widget<Icon>(find.byIcon(Icons.home_rounded)).color,
      WeRoboColors.primary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.analytics_outlined)).color,
      const Color(0xFF8B94A5),
    );
  });

  testWidgets('home opens the summary dashboard by default', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.textContaining('안녕하세요'), findsOneWidget);
    expect(find.text('총 자산 (평가금액)'), findsOneWidget);
    expect(find.text('포트폴리오 구성'), findsOneWidget);
    expect(find.text('빠른 인사이트'), findsOneWidget);
    expect(find.text('시장 요약'), findsOneWidget);
  });

  testWidgets('home donut keeps every asset while legend shows top four',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final chart = tester.widget<VestorPieChart>(find.byType(VestorPieChart));
    expect(chart.categories, hasLength(7));

    const expectedNames = [
      '현금성자산',
      '미국 성장주',
      '미국 가치주',
      '금',
    ];
    const expectedColors = [
      WeRoboColors.assetCash,
      WeRoboColors.assetUSGrowth,
      WeRoboColors.assetUSValue,
      WeRoboColors.assetGold,
    ];

    for (var index = 0; index < expectedNames.length; index++) {
      expect(
        tester
            .widget<Text>(
              find.byKey(Key('home_allocation_name_$index')),
            )
            .data,
        expectedNames[index],
      );
      final colorDot = tester.widget<Container>(
        find.byKey(Key('home_allocation_color_$index')),
      );
      expect(
        (colorDot.decoration! as BoxDecoration).color,
        expectedColors[index],
      );
    }

    expect(find.byKey(const Key('home_allocation_name_4')), findsNothing);
    expect(find.byKey(const Key('home_allocation_color_4')), findsNothing);
  });

  testWidgets('dashboard header matches the prominent greeting layout',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final headerFinder = find.byKey(const Key('dashboard_header'));
    final greetingFinder = find.byKey(const Key('dashboard_greeting'));
    final notificationFinder = find.byKey(
      const Key('dashboard_notification'),
    );
    final greeting = tester.widget<Text>(greetingFinder);

    expect(greeting.style!.fontSize, WeRoboTypography.heading2.fontSize);
    expect(greeting.style!.fontWeight, FontWeight.w900);
    expect(
      tester.getTopLeft(greetingFinder).dx,
      lessThan(tester.getTopLeft(notificationFinder).dx),
    );
    expect(
      find.descendant(
        of: headerFinder,
        matching: find.byIcon(Icons.settings_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: headerFinder,
        matching: find.byIcon(Icons.notifications_none_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('quick insight keeps its closing phrase on the second line',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final firstLineFinder = find.byKey(
      const Key('quick_insight_first_line'),
    );
    final secondLineFinder = find.byKey(
      const Key('quick_insight_second_line'),
    );
    final firstLine = tester.widget<Text>(firstLineFinder);
    final secondLine = tester.widget<Text>(secondLineFinder);

    expect(firstLine.textSpan!.toPlainText(), endsWith('%를'));
    expect(secondLine.data, '차지하고 있어요.');
    expect(
      tester.getTopLeft(secondLineFinder).dy,
      greaterThan(tester.getTopLeft(firstLineFinder).dy),
    );
  });

  testWidgets('home dashboard stacks portfolio legend on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    final chartBottom = tester.getBottomLeft(find.byType(VestorPieChart)).dy;
    final legendTop = tester.getTopLeft(find.text('현금성자산')).dy;

    expect(tester.takeException(), isNull);
    expect(legendTop, greaterThan(chartBottom));
  });

  testWidgets('analysis navigation item opens the portfolio analysis tab',
      (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '분석'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('포트폴리오 분석'), findsOneWidget);
    expect(find.text('자산배분'), findsOneWidget);
    expect(find.text('자산 배분 현황'), findsOneWidget);
    expect(find.byKey(const Key('analysis_holdings_card')), findsOneWidget);
    expect(find.text('보유자산'), findsOneWidget);
    expect(find.widgetWithText(Pressable, '보유자산'), findsNothing);
    expect(find.text('수익률 (연환산)'), findsNothing);
    expect(find.text('변동성'), findsNothing);
    expect(find.text('샤프지수'), findsNothing);
    expect(find.text('분산투자 점수'), findsNothing);
    expect(find.text('성과 추이'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('analysis_holdings_card'))).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const Key('analysis_allocation_overview_card')),
            )
            .dy,
      ),
    );
    expect(find.byKey(const Key('analysis_notification')), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);

    final analysisChart = tester.widget<VestorPieChart>(
      find.descendant(
        of: find.byKey(const Key('analysis_allocation_overview_card')),
        matching: find.byType(VestorPieChart),
      ),
    );
    expect(analysisChart.categories, hasLength(7));
    expect(
      analysisChart.categories.map((category) => category.name),
      [
        '현금성자산',
        '미국 성장주',
        '미국 가치주',
        '금',
        '신성장주',
        '단기 채권',
        '인프라 채권',
      ],
    );
    const expectedLegendNames = [
      '현금성자산',
      '미국 성장주',
      '미국 가치주',
      '금',
    ];
    for (var index = 0; index < expectedLegendNames.length; index++) {
      expect(
        tester
            .widget<Text>(
              find.byKey(Key('analysis_allocation_name_$index')),
            )
            .data,
        expectedLegendNames[index],
      );
    }
    expect(
      find.byKey(const Key('analysis_allocation_name_4')),
      findsNothing,
    );
    expect(
      tester.getCenter(find.byKey(const Key('analysis_notification'))).dy,
      closeTo(
        tester.getCenter(find.byKey(const Key('analysis_header_title'))).dy,
        1,
      ),
    );
  });

  testWidgets('analysis tab avoids overflow on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '분석'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('포트폴리오 분석'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis internal tabs avoid overflow on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.15),
        ),
        child: buildSubject(),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '분석'));
    await tester.pump(const Duration(milliseconds: 150));

    for (final label in ['요약', '성과', '자산배분']) {
      await tester.tap(find.text(label).first);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'analysis metric cards avoid overflow on phone width text scaling',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(393, 852),
          textScaler: TextScaler.linear(1.2),
        ),
        child: buildSubject(),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '분석'));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.text('성과').first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('수익률 (연환산)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analysis tab text is not truncated with ellipsis',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(393, 852),
          textScaler: TextScaler.linear(1.15),
        ),
        child: buildSubject(),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '분석'));
    await tester.pump(const Duration(milliseconds: 150));

    for (final label in ['요약', '자산배분', '성과']) {
      await tester.tap(find.text(label).first);
      await tester.pump(const Duration(milliseconds: 250));

      final analysisTexts = find.descendant(
        of: find.byType(PortfolioAnalysisTab),
        matching: find.byType(Text),
      );
      for (final element in analysisTexts.evaluate()) {
        final text = element.widget as Text;
        expect(text.overflow, isNot(TextOverflow.ellipsis));
      }
    }
  });

  testWidgets('news navigation item opens the news tab', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.widgetWithText(Pressable, '뉴스'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const Key('news_tab')), findsOneWidget);
  });
}
