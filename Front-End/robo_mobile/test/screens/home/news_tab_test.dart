import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/news_tab.dart';

void main() {
  tearDown(() => debugSetWeeklyMarketReportApiOverride(null));

  testWidgets('renders the five-minute weekly report structure',
      (tester) async {
    tester.view.physicalSize = const Size(430, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugSetWeeklyMarketReportApiOverride(() async => _fixture());

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: const Scaffold(body: NewsTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이번 주 시장, 5분 요약'), findsOneWidget);
    expect(find.text('한 줄로'), findsOneWidget);
    expect(find.text('이번 주 가장 큰 사건 5가지'), findsOneWidget);
    expect(find.textContaining('1위.'), findsOneWidget);

    expect(find.text('돈이 어느 업종으로 가고 있나'), findsOneWidget);
    expect(find.text('경기는 지금 어디쯤인가'), findsOneWidget);
    expect(find.text('포트폴리오 뉴스 브리핑'), findsNothing);
    expect(find.text('주요 지수'), findsNothing);
  });
}

MobileWeeklyMarketReportResponse _fixture() {
  return MobileWeeklyMarketReportResponse(
    periodStart: '2026-08-19',
    periodEnd: '2026-08-28',
    generatedAt: DateTime.utc(2026, 8, 29),
    title: '이번 주 시장, 5분 요약',
    introduction: '숫자와 출처를 확인한 내용만 담았습니다.',
    oneLine: '금과 기술 업종이 올랐고 에너지 업종은 내렸습니다.',
    events: List.generate(
      5,
      (index) => MobileWeeklyEvent(
        rank: index + 1,
        title: '확인된 시장 사건 ${index + 1}',
        whatHappened: '마감 가격이 움직였습니다.',
        why: '확인된 기사 제목만 사용했습니다.',
        meaning: '시장 전체와 한 업종의 움직임은 다를 수 있습니다.',
        sourceTitles: const [],
      ),
    ),
    otherItems: const ['그 밖의 확인된 소식'],
    sectorFlows: const [
      MobileWeeklySectorFlow(
        name: '기술',
        etf: 'XLK',
        recentSixMonthPct: 12,
        ytdPct: 18,
        note: '이번 주에도 상승했습니다.',
      ),
      MobileWeeklySectorFlow(
        name: '에너지',
        etf: 'XLE',
        recentSixMonthPct: -2,
        ytdPct: 3,
        note: '이번 주에는 하락했습니다.',
      ),
    ],
    flowSummary: '기술 업종의 가격 흐름이 가장 높았습니다.',
    economySignals: const [
      MobileWeeklyEconomySignal(
        signal: 'green',
        indicator: '변동성지수(VIX) 15.0',
        meaning: '시장 불안이 비교적 낮은 구간입니다.',
      ),
    ],
    economySummary: '신호등은 현재 상태를 정리한 표시입니다.',
    calendar: const [],
    glossary: const [
      MobileWeeklyGlossaryItem(
        term: '연준(Fed)',
        description: '미국 중앙은행입니다.',
      ),
    ],
    sources: const [],
    disclaimer: '정보 제공 목적이며 투자 권유가 아닙니다.',
    generationMode: 'rules',
  );
}
