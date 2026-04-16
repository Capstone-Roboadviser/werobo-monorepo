import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/app/portfolio_state.dart';
import 'package:robo_mobile/app/theme.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/home/home_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  MobileSectorAllocation sector({
    required String code,
    required String name,
    required double weight,
  }) {
    return MobileSectorAllocation(
      assetCode: code,
      assetName: name,
      weight: weight,
      riskContribution: weight,
    );
  }

  MobileStockAllocation stock({
    required String ticker,
    required String name,
    required String sectorCode,
    required String sectorName,
    required double weight,
  }) {
    return MobileStockAllocation(
      ticker: ticker,
      name: name,
      sectorCode: sectorCode,
      sectorName: sectorName,
      weight: weight,
    );
  }

  MobileAccountDashboard accountDashboard() {
    return MobileAccountDashboard(
      hasAccount: true,
      summary: MobileAccountSummary(
        portfolioCode: 'balanced',
        portfolioLabel: '균형형',
        portfolioId: 'account-portfolio',
        dataSource: 'managed_universe',
        investmentHorizon: 'medium',
        targetVolatility: 0.12,
        expectedReturn: 0.08,
        volatility: 0.11,
        sharpeRatio: 0.7,
        startedAt: '2026-03-01',
        lastSnapshotDate: '2026-04-15',
        currentValue: 10500000,
        investedAmount: 10000000,
        profitLoss: 500000,
        cashBalance: 25000,
        profitLossPct: 0.05,
        sectorAllocations: [
          sector(code: 'us_value', name: '미국 가치주', weight: 0.6),
          sector(code: 'gold', name: '금', weight: 0.4),
        ],
        stockAllocations: [
          stock(
            ticker: 'VTV',
            name: 'Vanguard Value ETF',
            sectorCode: 'us_value',
            sectorName: '미국 가치주',
            weight: 0.6,
          ),
          stock(
            ticker: 'GLD',
            name: 'SPDR Gold Shares',
            sectorCode: 'gold',
            sectorName: '금',
            weight: 0.4,
          ),
        ],
      ),
      history: const [],
      recentActivity: const [],
    );
  }

  testWidgets('shows reserve cash as separate from portfolio allocation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = PortfolioState();
    addTearDown(state.dispose);

    state.setAccountDashboard(accountDashboard());
    await state.markWelcomeBannerSeen();
    await state.markDigestSeen('2026-04-16');

    await tester.pumpWidget(
      MaterialApp(
        theme: WeRoboTheme.light,
        home: PortfolioStateProvider(
          state: state,
          child: const Scaffold(
            body: HomeTab(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('포트폴리오 구성'), findsOneWidget);
    expect(find.text('예비 현금'), findsOneWidget);
    expect(find.text('포트폴리오 구성 비중에는 포함되지 않아요.'), findsOneWidget);
    expect(find.text('리밸런싱 시 별도로 보관됐다가 자동 사용돼요.'), findsOneWidget);
    expect(find.text('₩25,000'), findsOneWidget);
  });
}
