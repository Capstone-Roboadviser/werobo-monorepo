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
    expect(find.text('이번 주 한 줄 요약'), findsOneWidget);
    final summaryCard = tester.widget<Container>(
      find.byKey(const Key('weekly_one_line_card')),
    );
    final summaryDecoration = summaryCard.decoration! as BoxDecoration;
    expect(summaryDecoration.gradient, isA<LinearGradient>());
    expect(find.text('이번 주 가장 큰 사건 5가지 (영향이 큰 순서)'), findsOneWidget);
    expect(find.textContaining('연초 대비 +14%'), findsOneWidget);
    expect(find.textContaining('1위.'), findsOneWidget);

    expect(find.text('돈이 어느 업종으로 가고 있나'), findsOneWidget);
    expect(find.text('경기는 지금 어디쯤인가'), findsOneWidget);
    expect(find.text('다음 주 챙길 것'), findsOneWidget);
    expect(find.text('고객님 업종 한 줄'), findsNothing);
    expect(find.text('사용한 공개 스킬과 출처'), findsNothing);
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
    oneLine: '미국 주식 전체는 거의 제자리(연초 대비 +14%)입니다.',
    keyFigures: const [],
    editorialNote: '',
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
        recentSixMonthLabel: '+12%',
        ytdLabel: '+18%',
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
        indicator: '제조업 지수',
        level: '55.6',
        meaning: '50보다 높으면 제조업 활동이 늘어나는 구간입니다.',
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
    skillSources: const [],
    disclaimer: '정보 제공 목적이며 투자 권유가 아닙니다.',
    generationMode: 'static_pdf',
  );
}
