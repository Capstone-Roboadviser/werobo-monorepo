import 'package:flutter/material.dart';

import '../../app/portfolio_metrics.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';

/// 비교 sub-screen — table comparing my portfolio against the market across
/// risk-adjusted return metrics. Metrics are computed client-side from the
/// comparison backtest series so the same numbers are reproducible from the
/// chart on the home tab.
class PortfolioComparisonPage extends StatelessWidget {
  const PortfolioComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final (mine, market) = _computeMetricsPair(state);

    final rows = <_MetricSpec>[
      _MetricSpec(
        label: '샤프 비율',
        mine: mine.sharpeRatio,
        market: market.sharpeRatio,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: 'CAGR',
        mine: mine.cagr,
        market: market.cagr,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '누적 수익률',
        mine: mine.cumulativeReturn,
        market: market.cumulativeReturn,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '알파',
        mine: mine.alpha,
        market: market.alpha,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '베타',
        mine: mine.beta,
        market: market.beta,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: '변동성',
        mine: mine.volatility,
        market: market.volatility,
        formatter: _percent,
      ),
      _MetricSpec(
        label: 'MDD',
        mine: mine.maxDrawdown,
        market: market.maxDrawdown,
        formatter: _percent,
      ),
      _MetricSpec(
        label: 'VaR (95%)',
        mine: mine.valueAtRisk,
        market: market.valueAtRisk,
        formatter: _percent,
      ),
      _MetricSpec(
        label: 'CVaR (95%)',
        mine: mine.conditionalValueAtRisk,
        market: market.conditionalValueAtRisk,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '하방 편차',
        mine: mine.downsideDeviation,
        market: market.downsideDeviation,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '소르티노 비율',
        mine: mine.sortinoRatio,
        market: market.sortinoRatio,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: '칼마 비율',
        mine: mine.calmarRatio,
        market: market.calmarRatio,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: '트레이너 비율',
        mine: mine.treynorRatio,
        market: market.treynorRatio,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '정보 비율',
        mine: mine.informationRatio,
        market: market.informationRatio,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: '오메가 비율',
        mine: mine.omegaRatio,
        market: market.omegaRatio,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: '상관계수',
        mine: mine.correlation,
        market: market.correlation,
        formatter: _decimal,
      ),
      _MetricSpec(
        label: '승률',
        mine: mine.winRate,
        market: market.winRate,
        formatter: _percent,
      ),
      _MetricSpec(
        label: '회전율',
        mine: mine.turnover,
        market: market.turnover,
        formatter: _percent,
      ),
    ];

    final hasAnyMine = rows.any((r) => r.mine != null);
    final caveat = hasAnyMine
        ? '백테스트 시계열 기준이며, 시장 라인은 동일 기간 자산군 등가중 바스켓입니다.'
        : '백테스트 데이터를 불러오는 중입니다.';

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.balance_rounded,
                    size: 24,
                    color: WeRoboColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '비교',
                    style: WeRoboTypography.heading2.themed(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: tc.surface,
                      borderRadius:
                          BorderRadius.circular(WeRoboColors.radiusL),
                      border: Border.all(color: tc.border, width: 1),
                    ),
                    child: Column(
                      children: [
                        _ComparisonHeader(),
                        for (final spec in rows) ...[
                          Divider(
                            color: tc.border.withValues(alpha: 0.4),
                            height: 1,
                            thickness: 0.5,
                          ),
                          _MetricRow(spec: spec),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    caveat,
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Extract aligned portfolio/market series from the comparison backtest
  /// and compute metrics for both columns.
  static (PortfolioMetrics, PortfolioMetrics) _computeMetricsPair(
    PortfolioState state,
  ) {
    final bt = state.backtest;
    if (bt == null) {
      return (PortfolioMetrics.empty, PortfolioMetrics.empty);
    }

    MobileComparisonLine? findLine(Iterable<String> keys) {
      for (final key in keys) {
        for (final line in bt.lines) {
          if (line.key == key) return line;
        }
      }
      return null;
    }

    final portfolioLine = findLine([
      'selected',
      state.type.riskCode,
    ]);
    final marketLine = findLine(['market', 'sp500', 'benchmark_avg']);

    if (portfolioLine == null) {
      return (PortfolioMetrics.empty, PortfolioMetrics.empty);
    }

    final portfolioSeries = _toReturnPoints(portfolioLine.points);
    final marketSeries = marketLine == null
        ? null
        : _toReturnPoints(marketLine.points);

    // Turnover proxy: my portfolio is drift-rebalanced based on the backtest
    // metadata; the 시장 line is a passive equal-weight basket and so has
    // zero strategic turnover.
    final spanDays = bt.endDate.difference(bt.startDate).inDays;
    final mineTurnover = estimateAnnualTurnover(
      rebalanceEvents: bt.rebalanceDates.length,
      spanDays: spanDays,
      driftThreshold: bt.rebalancePolicy?.driftThreshold,
    );

    final mine = computeMetrics(
      series: portfolioSeries,
      benchmark: marketSeries,
      turnover: mineTurnover,
    );
    // Pass the market as its own benchmark so the column shows the
    // definitional values (alpha=0, beta=1, correlation=1, treynor=excess
    // return). Information ratio stays null because tracking error vs self
    // is zero.
    final market = marketSeries == null
        ? PortfolioMetrics.empty
        : computeMetrics(
            series: marketSeries,
            benchmark: marketSeries,
            turnover: 0.0,
          );

    return (mine, market);
  }

  static List<ReturnPoint> _toReturnPoints(
    List<MobileComparisonLinePoint> points,
  ) {
    return [
      for (final p in points) (date: p.date, cumReturn: p.returnPct),
    ];
  }

  static String _percent(double v) =>
      '${(v * 100).toStringAsFixed(2)}%';
  static String _decimal(double v) => v.toStringAsFixed(2);
}

class _ComparisonHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final headerStyle = WeRoboTypography.caption.copyWith(
      color: tc.textSecondary,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('항목', style: headerStyle)),
          Expanded(
            flex: 3,
            child: Text(
              '내 포트폴리오',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '시장',
              style: headerStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricSpec {
  final String label;
  final double? mine;
  final double? market;
  final String Function(double) formatter;

  const _MetricSpec({
    required this.label,
    required this.mine,
    required this.market,
    required this.formatter,
  });
}

class _MetricRow extends StatelessWidget {
  final _MetricSpec spec;

  const _MetricRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final valueStyle = WeRoboTypography.body.copyWith(
      color: tc.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final missingStyle = WeRoboTypography.body.copyWith(
      color: tc.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              spec.label,
              style: WeRoboTypography.body.copyWith(
                color: tc.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              spec.mine == null ? '—' : spec.formatter(spec.mine!),
              style: spec.mine == null ? missingStyle : valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              spec.market == null ? '—' : spec.formatter(spec.market!),
              style: spec.market == null ? missingStyle : valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
