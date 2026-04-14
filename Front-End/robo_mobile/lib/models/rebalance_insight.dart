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
  double get afterDisplay =>
      double.parse((afterPct * 100).toStringAsFixed(1));

  /// Delta derived from rounded display values so that
  /// "5.1% → 5.1%" never shows a non-zero change.
  double get displayDelta => afterDisplay - beforeDisplay;

  /// Whether the rounded before/after percentages differ.
  bool get hasChanged => displayDelta.abs() >= 0.05;

  /// Korean display name for the asset category.
  String get displayName =>
      _assetKoreanNames[assetCode] ??
      _assetKoreanNames[assetName] ??
      assetName;

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

class RebalanceInsight {
  final int id;
  final String rebalanceDate;
  final List<RebalanceInsightAllocation> allocations;
  final String? explanationText;
  final bool isRead;
  final String createdAt;

  /// True when at least one allocation has a visible change.
  bool get hasRealChanges => allocations.any((a) => a.hasChanged);

  /// Explanation derived from rounded display values so it always
  /// matches the visible allocation rows.
  String get generatedExplanation {
    final changed = allocations.where((a) => a.hasChanged).toList()
      ..sort((a, b) =>
          b.displayDelta.abs().compareTo(a.displayDelta.abs()));
    if (changed.isEmpty) {
      return '포트폴리오 비중이 목표와 일치하여 '
          '조정이 필요하지 않았어요.';
    }
    final parts = changed.take(2).map((a) {
      final before =
          '${a.beforeDisplay.toStringAsFixed(1)}%';
      final after =
          '${a.afterDisplay.toStringAsFixed(1)}%';
      final verb =
          a.displayDelta > 0 ? '늘렸어요' : '줄였어요';
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
    return RebalanceInsight(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rebalanceDate: json['rebalance_date']?.toString() ?? '',
      allocations: allocations,
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
        explanationText: _explanations[i],
        isRead: i > 0,
        createdAt: '${_dates[i]}T09:00:00Z',
      ));
    }
    return insights;
  }
}

