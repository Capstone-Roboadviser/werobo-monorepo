import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/news_tab.dart';

void main() {
  tearDown(() => debugSetMarketBriefingApiOverride(null));

  testWidgets('renders the objective market-close briefing report',
      (tester) async {
    debugSetMarketBriefingApiOverride(() async => _fixture());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: const Scaffold(body: NewsTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('오늘의 시장'), findsOneWidget);
    expect(find.byKey(const Key('market_briefing_summary')), findsOneWidget);
    expect(find.text('주요 지수'), findsOneWidget);
    expect(find.text('오늘의 브리핑'), findsOneWidget);
    expect(find.text('🟢 오른 업종'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('시장 지표'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('시장 지표'), findsOneWidget);
    expect(find.text('포트폴리오 뉴스 브리핑'), findsNothing);
    expect(find.text('관심 자산'), findsNothing);
  });
}

MobileMarketBriefingResponse _fixture() {
  return MobileMarketBriefingResponse(
    asOf: '2026-08-28',
    generatedAt: DateTime.utc(2026, 8, 29),
    statusNote: '미국 정규장 마감 종가 기준',
    summary: 'S&P 500은 전 거래일보다 1.00% 상승했습니다.',
    indices: const [
      MobileMarketIndex(name: 'S&P 500', close: 6500, changePct: 1),
      MobileMarketIndex(name: '나스닥', close: 22000, changePct: 1.2),
      MobileMarketIndex(name: '다우존스', close: 46000, changePct: 0.5),
    ],
    breadth: const MobileMarketBreadth(
      sectorsUp: 7,
      sectorsTotal: 11,
      marketTone: '상승 업종 우세',
    ),
    sectors: const [
      MobileMarketSector(name: '기술', etf: 'XLK', changePct: 2.1),
      MobileMarketSector(name: '에너지', etf: 'XLE', changePct: 0.5),
      MobileMarketSector(name: '헬스케어', etf: 'XLV', changePct: -0.3),
    ],
    indicators: const [
      MobileMarketIndicator(
        name: '변동성지수(VIX)',
        level: '14.20',
        change: '-2.00%',
      ),
    ],
    briefing: const [
      MobileMarketBriefingItem(
        title: '기술 +2.10% · 가장 많이 오른 업종',
        body: '업종 등락률은 미국 마감 종가 기준입니다.',
        sourceTitles: [],
      ),
    ],
    articles: const [],
    generationMode: 'rules',
  );
}
