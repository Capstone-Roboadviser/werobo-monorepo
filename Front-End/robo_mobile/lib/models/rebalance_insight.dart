import 'package:flutter/material.dart';

import 'mobile_backend_models.dart';
import 'portfolio_data.dart';

class RebalanceInsightAllocation {
  final String assetCode;
  final String assetName;
  final Color color;
  final double beforePct;
  final double afterPct;

  const RebalanceInsightAllocation({
    required this.assetCode,
    required this.assetName,
    required this.color,
    required this.beforePct,
    required this.afterPct,
  });

  /// Rounded display percentages (one decimal place).
  double get beforeDisplay =>
      double.parse((beforePct * 100).toStringAsFixed(1));
  double get afterDisplay => double.parse((afterPct * 100).toStringAsFixed(1));

  /// Delta derived from rounded display values so that
  /// "5.1% → 5.1%" never shows a non-zero change.
  double get displayDelta => afterDisplay - beforeDisplay;

  /// Whether the rounded before/after percentages differ.
  bool get hasChanged => displayDelta.abs() >= 0.05;

  /// Korean display name for the asset category.
  String get displayName =>
      _assetKoreanNames[assetCode] ?? _assetKoreanNames[assetName] ?? assetName;

  static const _assetKoreanNames = <String, String>{
    'us_value': '미국 가치주',
    'value_stock': '미국 가치주',
    'us_growth': '미국 성장주',
    'growth_stock': '미국 성장주',
    'new_growth': '신성장주',
    'innovation': '신성장주',
    'short_term_bond': '단기 채권',
    'bond': '단기 채권',
    'cash_equivalents': '현금성자산',
    'cash': '현금성자산',
    'cash_equivalent': '현금성자산',
    'gold': '금',
    'commodity_gold': '금',
    'infra_bond': '인프라 채권',
    'infra': '인프라 채권',
    'infrastructure': '인프라 채권',
    'infrastructure_bond': '인프라 채권',
    '미국 가치주': '미국 가치주',
    '미국 성장주': '미국 성장주',
    '신성장주': '신성장주',
    '단기 채권': '단기 채권',
    '현금성자산': '현금성자산',
    '금': '금',
    '인프라 채권': '인프라 채권',
  };

  factory RebalanceInsightAllocation.fromJson(Map<String, dynamic> json) {
    return RebalanceInsightAllocation(
      assetCode: json['asset_code']?.toString() ?? '',
      assetName: json['asset_name']?.toString() ?? '',
      color: parseBackendHexColor(json['color']?.toString() ?? '#888888'),
      beforePct: _asDouble(json['before_pct']),
      afterPct: _asDouble(json['after_pct']),
    );
  }
}

class RebalanceInsightTrade {
  final String ticker;
  final String tickerName;
  final String assetCode;
  final String assetName;
  final String direction;
  final double amount;

  const RebalanceInsightTrade({
    required this.ticker,
    required this.tickerName,
    required this.assetCode,
    required this.assetName,
    required this.direction,
    required this.amount,
  });

  bool get isBuy => direction == 'buy';
  bool get isSell => direction == 'sell';

  String get displayLabel {
    if (tickerName.isNotEmpty) return tickerName;
    if (assetName.isNotEmpty) return assetName;
    return ticker;
  }

  String get displayDirectionLabel => isBuy ? '매수' : '매도';

  String get subtitle {
    final parts = <String>[];
    if (assetName.isNotEmpty && assetName != displayLabel) {
      parts.add(assetName);
    }
    if (ticker.isNotEmpty && ticker != displayLabel) {
      parts.add(ticker);
    }
    return parts.join(' · ');
  }

  factory RebalanceInsightTrade.fromJson(Map<String, dynamic> json) {
    return RebalanceInsightTrade(
      ticker: json['ticker']?.toString() ?? '',
      tickerName: json['ticker_name']?.toString() ?? '',
      assetCode: json['asset_code']?.toString() ?? '',
      assetName: json['asset_name']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      amount: _asDouble(json['amount']),
    );
  }
}

class RebalanceInsight {
  final int id;
  final String rebalanceDate;
  final List<RebalanceInsightAllocation> allocations;
  final List<RebalanceInsightTrade> tradeDetails;
  final String? trigger;
  final int tradeCount;
  final double cashBefore;
  final double cashFromSales;
  final double cashToBuys;
  final double cashAfter;
  final double netCashChange;
  final String? explanationText;
  final bool isRead;
  final String createdAt;

  /// True when at least one allocation has a visible change.
  bool get hasReserveCash => cashAfter.abs() >= 0.5;

  List<RebalanceInsightAllocation> get visibleAllocationChanges =>
      allocations.where((a) => a.hasChanged).toList();

  List<RebalanceInsightTrade> get visibleTradeDetails =>
      tradeDetails.where((trade) => trade.amount.abs() >= 0.5).toList();

  bool get hasCashActivity =>
      cashFromSales.abs() >= 0.5 ||
      cashToBuys.abs() >= 0.5 ||
      netCashChange.abs() >= 0.5;

  bool get hasTradeActivity => tradeCount > 0 || visibleTradeDetails.isNotEmpty;

  bool get hasRealChanges =>
      visibleAllocationChanges.isNotEmpty ||
      hasCashActivity ||
      hasTradeActivity;

  String get tradeActivitySummary {
    if (visibleTradeDetails.isEmpty) {
      return hasTradeActivity ? '종목 $tradeCount개를 다시 맞췄어요.' : '';
    }

    final head = visibleTradeDetails
        .take(2)
        .map((trade) => '${trade.displayLabel} ${trade.displayDirectionLabel}')
        .join(' · ');
    final extraCount = visibleTradeDetails.length - 2;
    if (extraCount > 0) {
      return '$head 외 $extraCount건';
    }
    return head;
  }

  String get cashFlowSummary {
    if (!hasCashActivity && !hasTradeActivity) {
      return '';
    }

    final parts = <String>[];
    if (cashFromSales.abs() >= 0.5) {
      parts.add('매도 ${_formatWon(cashFromSales)}');
    }
    if (cashToBuys.abs() >= 0.5) {
      parts.add('매수 ${_formatWon(cashToBuys)}');
    }
    if (hasReserveCash || hasCashActivity) {
      parts.add('예비현금 ${_formatWon(cashAfter)}');
    }

    if (parts.isEmpty && hasTradeActivity) {
      return '종목 $tradeCount개를 다시 맞췄어요.';
    }
    return parts.join(' · ');
  }

  String get historySummary {
    if (visibleAllocationChanges.isEmpty && visibleTradeDetails.isNotEmpty) {
      if (hasCashActivity) {
        return '$tradeActivitySummary · 예비현금 ${_formatWon(cashAfter)}';
      }
      return tradeActivitySummary;
    }
    if (hasCashActivity) {
      return cashFlowSummary;
    }
    if (visibleAllocationChanges.isNotEmpty) {
      return generatedExplanation;
    }
    if (hasTradeActivity) {
      return '리밸런싱으로 종목 $tradeCount개 구성을 다시 맞췄어요.';
    }
    return generatedExplanation;
  }

  /// Explanation derived from rounded display values so it always
  /// matches the visible allocation rows.
  String get generatedExplanation {
    final changed = visibleAllocationChanges.toList()
      ..sort((a, b) => b.displayDelta.abs().compareTo(a.displayDelta.abs()));
    if (changed.isEmpty) {
      if (visibleTradeDetails.isNotEmpty) {
        final head = visibleTradeDetails
            .take(2)
            .map((trade) =>
                '${trade.displayLabel} ${trade.displayDirectionLabel}')
            .join(', ');
        final extraCount = visibleTradeDetails.length - 2;
        final extraText = extraCount > 0 ? ' 외 $extraCount건' : '';
        final cashText = hasCashActivity ? ' 리밸런싱 결과가 예비현금에 반영됐어요.' : '';
        return '실제 매매는 $head$extraText으로 진행됐어요. '
            '자산군 비중 변화가 작아 상세 비중 표시는 생략됐어요.$cashText';
      }
      if (hasCashActivity) {
        return '$cashFlowSummary. 리밸런싱 결과가 예비현금에 반영됐어요.';
      }
      if (hasTradeActivity) {
        return '리밸런싱으로 종목 구성을 다시 맞췄어요.';
      }
      return '포트폴리오 비중이 목표와 일치하여 '
          '조정이 필요하지 않았어요.';
    }
    final parts = changed.take(2).map((a) {
      final before = '${a.beforeDisplay.toStringAsFixed(1)}%';
      final after = '${a.afterDisplay.toStringAsFixed(1)}%';
      final verb = a.displayDelta > 0 ? '늘렸어요' : '줄였어요';
      return '${a.displayName} 비중을 '
          '$before에서 $after로 $verb';
    });
    return '${parts.join(", ")}. '
        '시장 변동으로 목표 비중에서 벗어난 자산군을 조정했어요.';
  }

  const RebalanceInsight({
    required this.id,
    required this.rebalanceDate,
    required this.allocations,
    required this.tradeDetails,
    required this.trigger,
    required this.tradeCount,
    required this.cashBefore,
    required this.cashFromSales,
    required this.cashToBuys,
    required this.cashAfter,
    required this.netCashChange,
    this.explanationText,
    required this.isRead,
    required this.createdAt,
  });

  factory RebalanceInsight.fromJson(Map<String, dynamic> json) {
    final rawAllocations = json['allocations'];
    final allocations = <RebalanceInsightAllocation>[];
    if (rawAllocations is List) {
      for (final item in rawAllocations) {
        if (item is Map<String, dynamic>) {
          allocations.add(RebalanceInsightAllocation.fromJson(item));
        }
      }
    }
    final rawTradeDetails = json['trade_details'];
    final tradeDetails = <RebalanceInsightTrade>[];
    if (rawTradeDetails is List) {
      for (final item in rawTradeDetails) {
        if (item is Map<String, dynamic>) {
          tradeDetails.add(RebalanceInsightTrade.fromJson(item));
        }
      }
    }
    return RebalanceInsight(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rebalanceDate: json['rebalance_date']?.toString() ?? '',
      allocations: allocations,
      tradeDetails: tradeDetails,
      trigger: json['trigger']?.toString(),
      tradeCount: (json['trade_count'] as num?)?.toInt() ?? 0,
      cashBefore: _asDouble(json['cash_before']),
      cashFromSales: _asDouble(json['cash_from_sales']),
      cashToBuys: _asDouble(json['cash_to_buys']),
      cashAfter: _asDouble(json['cash_after']),
      netCashChange: _asDouble(json['net_cash_change']),
      explanationText: json['explanation_text']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class RebalanceInsightsResponse {
  final List<RebalanceInsight> insights;
  final int unreadCount;

  const RebalanceInsightsResponse({
    required this.insights,
    required this.unreadCount,
  });

  factory RebalanceInsightsResponse.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'];
    final insights = <RebalanceInsight>[];
    if (rawInsights is List) {
      for (final item in rawInsights) {
        if (item is Map<String, dynamic>) {
          insights.add(RebalanceInsight.fromJson(item));
        }
      }
    }
    return RebalanceInsightsResponse(
      insights: insights,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Generates 3 mock rebalancing insights based on current portfolio categories.
/// Each simulates drift from target weights and a rebalance back to target.
class MockInsightData {
  MockInsightData._();

  /// Drift patterns for 3 quarterly rebalances (most recent first).
  /// Each entry is a list of per-sector drift multipliers applied to target %.
  static const _driftPatterns = <List<double>>[
    // Q1 2026: growth sectors ran hot, bonds lagged
    [1.08, 0.94, 1.12, 0.96, 0.92, 1.02, 0.97],
    // Q4 2025: bonds outperformed, equities pulled back
    [0.93, 1.07, 0.91, 1.10, 1.04, 0.98, 1.03],
    // Q3 2025: broad drift, gold surged
    [1.05, 0.97, 1.03, 0.95, 1.15, 0.90, 1.01],
  ];

  static const _dates = ['2026-04-01', '2026-01-02', '2025-10-01'];

  static const _explanations = [
    '미국 성장주와 신성장주 비중이 시장 상승으로 목표 대비 높아져, '
        '단기 채권과 금 비중을 늘리는 방향으로 리밸런싱했어요. '
        '시장 변동으로 목표 비중에서 벗어난 자산군을 조정했어요.',
    '채권 자산군이 금리 하락으로 강세를 보여 비중이 높아졌고, '
        '상대적으로 약세였던 주식형 자산군의 비중을 늘렸어요. '
        '목표 비중 대비 이탈된 자산군을 원래 수준으로 복원했어요.',
    '금 가격 급등으로 금 비중이 크게 높아져 일부 매도하고, '
        '현금성자산과 단기 채권 비중을 보충했어요. '
        '분기별 정기 리밸런싱을 통해 포트폴리오 균형을 맞췄어요.',
  ];

  static List<RebalanceInsight> insightsFor(
    List<PortfolioCategory> categories,
  ) {
    if (categories.isEmpty) return const [];

    final total = categories.fold<double>(0, (s, c) => s + c.percentage);
    if (total <= 0) return const [];

    final insights = <RebalanceInsight>[];
    for (int i = 0; i < 3; i++) {
      final driftPattern = _driftPatterns[i];
      final allocations = <RebalanceInsightAllocation>[];

      // Build drifted (before) weights
      double driftedTotal = 0;
      final driftedRaw = <double>[];
      for (int j = 0; j < categories.length; j++) {
        final drift = j < driftPattern.length ? driftPattern[j] : 1.0;
        final drifted = (categories[j].percentage / total) * drift;
        driftedRaw.add(drifted);
        driftedTotal += drifted;
      }

      for (int j = 0; j < categories.length; j++) {
        final beforePct = driftedRaw[j] / driftedTotal;
        final afterPct = categories[j].percentage / total;
        allocations.add(RebalanceInsightAllocation(
          assetCode: categories[j].name,
          assetName: categories[j].name,
          color: categories[j].color,
          beforePct: beforePct,
          afterPct: afterPct,
        ));
      }

      insights.add(RebalanceInsight(
        id: -(i + 1),
        rebalanceDate: _dates[i],
        allocations: allocations,
        tradeDetails: const [],
        trigger: 'scheduled',
        tradeCount: allocations.length,
        cashBefore: 0,
        cashFromSales: 0,
        cashToBuys: 0,
        cashAfter: 0,
        netCashChange: 0,
        explanationText: _explanations[i],
        isRead: i > 0,
        createdAt: '${_dates[i]}T09:00:00Z',
      ));
    }
    return insights;
  }
}

String _formatWon(double amount) {
  final value = amount.round().abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(value[i]);
  }
  return '₩$buffer';
}
