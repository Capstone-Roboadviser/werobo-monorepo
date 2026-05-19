import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';

/// 비교 sub-screen — table comparing my portfolio against the market across
/// risk-adjusted return metrics (Sharpe, CAGR, MDD, volatility, alpha, beta).
/// UIUX 2026-05-20 spec; full computation lands in Phase E.
class PortfolioComparisonPage extends StatelessWidget {
  const PortfolioComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final portfolio = state.selectedPortfolio;

    final rows = <_MetricRow>[
      _MetricRow(
        label: '샤프 비율',
        mine: portfolio?.sharpeRatio,
        market: null,
        formatter: _decimal,
      ),
      _MetricRow(
        label: 'CAGR',
        mine: portfolio?.expectedReturn,
        market: null,
        formatter: _percent,
      ),
      _MetricRow(
        label: '누적 수익률',
        mine: state.trailingMonthReturn,
        market: null,
        formatter: _percent,
      ),
      _MetricRow(
        label: '변동성',
        mine: portfolio?.volatility,
        market: null,
        formatter: _percent,
      ),
      _MetricRow(
        label: 'MDD',
        mine: null,
        market: null,
        formatter: _percent,
      ),
      _MetricRow(
        label: '알파',
        mine: null,
        market: null,
        formatter: _decimal,
      ),
      _MetricRow(
        label: '베타',
        mine: null,
        market: null,
        formatter: _decimal,
      ),
    ];

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
                        for (final row in rows) ...[
                          Divider(
                            color: tc.border.withValues(alpha: 0.4),
                            height: 1,
                            thickness: 0.5,
                          ),
                          row,
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '시장 비교 값은 곧 추가됩니다.',
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

class _MetricRow extends StatelessWidget {
  final String label;
  final double? mine;
  final double? market;
  final String Function(double) formatter;

  const _MetricRow({
    required this.label,
    required this.mine,
    required this.market,
    required this.formatter,
  });

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
              label,
              style: WeRoboTypography.body.copyWith(
                color: tc.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              mine == null ? '—' : formatter(mine!),
              style: mine == null ? missingStyle : valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              market == null ? '—' : formatter(market!),
              style: market == null ? missingStyle : valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
