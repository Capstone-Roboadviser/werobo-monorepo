import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/home_tab.dart'
    show showNotificationsSheet, debugSetNotificationsApiOverride;

class _FakeApi {
  MobileVolatilityHistoryResponse? volReturn;
  Object? volError;
  MobileAssetClassNewsResponse? newsReturn;
  Object? newsError;

  Future<MobileVolatilityHistoryResponse> fetchVolatility() async {
    if (volError != null) throw volError!;
    return volReturn!;
  }

  Future<MobileAssetClassNewsResponse> fetchNews(AssetClass cls) async {
    if (newsError != null) throw newsError!;
    return newsReturn!;
  }
}

Widget _wrap(PortfolioState state) => MaterialApp(
      theme: WeRoboTheme.light,
      home: PortfolioStateProvider(
        state: state,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  tearDown(() => debugSetNotificationsApiOverride(null));

  testWidgets('volatility row appears when spike detected', (tester) async {
    final api = _FakeApi();
    final today = DateTime(2026, 5, 12);
    api.volReturn = MobileVolatilityHistoryResponse(
      portfolioCode: 'X',
      portfolioLabel: 'X',
      rollingWindow: 20,
      earliestDataDate: today.subtract(const Duration(days: 30)),
      latestDataDate: today,
      points: [
        for (int i = 30; i >= 1; i--)
          MobileVolatilityPoint(
            date: today.subtract(Duration(days: i)),
            volatility: 0.10,
          ),
        MobileVolatilityPoint(date: today, volatility: 0.20),
      ],
    );
    api.newsError = Exception('skip');

    debugSetNotificationsApiOverride((
      fetchVolatility: api.fetchVolatility,
      fetchNews: api.fetchNews,
    ));

    final state = PortfolioState();
    await tester.pumpWidget(_wrap(state));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('시장 변동성 경고'), findsOneWidget);
    expect(find.textContaining('변동성'), findsWidgets);
  });

  testWidgets('news row shows error copy on fetch failure', (tester) async {
    final api = _FakeApi();
    api.volError = Exception('skip');
    api.newsError = Exception('rss down');

    debugSetNotificationsApiOverride((
      fetchVolatility: api.fetchVolatility,
      fetchNews: api.fetchNews,
    ));

    final state = PortfolioState();
    await tester.pumpWidget(_wrap(state));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Row is always rendered; copy reflects the error state.
    expect(find.text('자산군별 뉴스'), findsOneWidget);
    expect(find.text('뉴스를 불러올 수 없어요'), findsOneWidget);
  });
}
