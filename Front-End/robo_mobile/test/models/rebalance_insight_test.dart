import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/rebalance_insight.dart';

void main() {
  group('RebalanceInsight', () {
    test('treats rebalance cash flow as a visible history change', () {
      const insight = RebalanceInsight(
        id: 1,
        rebalanceDate: '2026-04-01',
        allocations: [],
        trigger: 'drift_guard',
        tradeCount: 3,
        cashBefore: 0,
        cashFromSales: 700000,
        cashToBuys: 520000,
        cashAfter: 180000,
        netCashChange: 180000,
        explanationText: null,
        isRead: false,
        createdAt: '2026-04-01T09:00:00Z',
      );

      expect(insight.hasCashActivity, isTrue);
      expect(insight.hasRealChanges, isTrue);
      expect(
        insight.cashFlowSummary,
        '매도 ₩700,000 · 매수 ₩520,000 · 예비현금 ₩180,000',
      );
      expect(insight.historySummary, contains('예비현금 ₩180,000'));
    });

    test('does not treat carried reserve cash alone as new activity', () {
      const insight = RebalanceInsight(
        id: 2,
        rebalanceDate: '2026-04-02',
        allocations: [],
        trigger: 'scheduled',
        tradeCount: 0,
        cashBefore: 180000,
        cashFromSales: 0,
        cashToBuys: 0,
        cashAfter: 180000,
        netCashChange: 0,
        explanationText: null,
        isRead: true,
        createdAt: '2026-04-02T09:00:00Z',
      );

      expect(insight.hasReserveCash, isTrue);
      expect(insight.hasCashActivity, isFalse);
      expect(insight.hasRealChanges, isFalse);
      expect(
        insight.generatedExplanation,
        '포트폴리오 비중이 목표와 일치하여 조정이 필요하지 않았어요.',
      );
    });

    test('keeps trade-only rebalances visible in history', () {
      const insight = RebalanceInsight(
        id: 3,
        rebalanceDate: '2026-04-03',
        allocations: [],
        trigger: 'scheduled',
        tradeCount: 2,
        cashBefore: 0,
        cashFromSales: 0,
        cashToBuys: 0,
        cashAfter: 0,
        netCashChange: 0,
        explanationText: null,
        isRead: true,
        createdAt: '2026-04-03T09:00:00Z',
      );

      expect(insight.hasCashActivity, isFalse);
      expect(insight.hasTradeActivity, isTrue);
      expect(insight.hasRealChanges, isTrue);
      expect(
        insight.historySummary,
        '리밸런싱으로 종목 2개 구성을 다시 맞췄어요.',
      );
    });
  });
}
