import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/portfolio_data.dart';
import '../onboarding/widgets/vestor_pie_chart.dart';
import 'activity_hub_page.dart';
import 'settings_page.dart';

class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = PortfolioStateProvider.of(context);
    final summary = state.accountSummary;
    final userName = state.currentUser?.name.trim();
    final displayName = userName == null || userName.isEmpty ? '김투자' : userName;
    final allocations = _dashboardAllocations(summary);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 360 ? 18.0 : 24.0;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeader(displayName: displayName),
            const SizedBox(height: 20),
            _AssetSummaryCard(
              currentValue: summary?.currentValue ?? 128250000,
              profitLoss: summary?.profitLoss ?? 1250000,
              profitLossPct: summary?.profitLossPct ?? 0.0109,
              points: _sparklinePoints(state.accountHistory),
            ),
            const SizedBox(height: 16),
            _PortfolioCompositionCard(allocations: allocations),
            const SizedBox(height: 16),
            _QuickInsightCard(allocations: allocations),
            const SizedBox(height: 16),
            const _MarketSummarySection(),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String displayName;

  const _DashboardHeader({required this.displayName});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      children: [
        Pressable(
          onTap: () => Navigator.push(
            context,
            WeRoboMotion.fadeRoute<void>(const ActivityHubPage()),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            size: 28,
            color: tc.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '안녕하세요, $displayName님 👋',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WeRoboTypography.body.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Pressable(
          onTap: () => Navigator.push(
            context,
            WeRoboMotion.fadeRoute<void>(const SettingsPage()),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 28,
            color: tc.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AssetSummaryCard extends StatelessWidget {
  final double currentValue;
  final double profitLoss;
  final double profitLossPct;
  final List<double> points;

  const _AssetSummaryCard({
    required this.currentValue,
    required this.profitLoss,
    required this.profitLossPct,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final isGain = profitLoss >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003ACB), Color(0xFF1476F2)],
        ),
        boxShadow: WeRoboElevation.raised(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 300;
          final sparklineWidth = isCompact ? 86.0 : 112.0;
          return Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 26,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '총 자산 (평가금액)',
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            '${_formatWon(currentValue)}원',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WeRoboTypography.number.copyWith(
                              color: Colors.white,
                              fontSize: isCompact ? 26 : 30,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘 수익',
                              style: WeRoboTypography.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${isGain ? '+' : '-'}'
                              '${_formatWon(profitLoss.abs())}원 '
                              '(${isGain ? '+' : '-'}'
                              '${(profitLossPct.abs() * 100).toStringAsFixed(2)}%)',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: WeRoboTypography.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: sparklineWidth,
                        height: 58,
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            points: points,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PortfolioCompositionCard extends StatelessWidget {
  final List<PortfolioCategory> allocations;

  const _PortfolioCompositionCard({required this.allocations});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border.withValues(alpha: 0.55)),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '포트폴리오 구성',
            style: WeRoboTypography.body.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 300;
              final chartSize = isCompact ? 132.0 : 142.0;
              final chart = SizedBox(
                width: chartSize,
                height: chartSize,
                child: VestorPieChart(
                  categories: allocations,
                  size: chartSize,
                  ringWidth: isCompact ? 22 : 24,
                  selectedRingWidth: isCompact ? 26 : 28,
                  centerBuilder: (_) => Text(
                    '자산 비율\n100%',
                    textAlign: TextAlign.center,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 16),
                    _PortfolioLegend(allocations: allocations),
                  ],
                );
              }

              return Row(
                children: [
                  chart,
                  const SizedBox(width: 18),
                  Expanded(
                    child: _PortfolioLegend(allocations: allocations),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PortfolioLegend extends StatelessWidget {
  final List<PortfolioCategory> allocations;

  const _PortfolioLegend({required this.allocations});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        for (final item in allocations.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.percentage.round()}%',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: tc.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QuickInsightCard extends StatelessWidget {
  final List<PortfolioCategory> allocations;

  const _QuickInsightCard({required this.allocations});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final top = allocations.isEmpty ? null : allocations.first;
    final label = top?.name ?? '미국 기술주';
    final pct = top?.percentage.round() ?? 62;
    return Container(
      key: const Key('quick_insight_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '빠른 인사이트',
            style: WeRoboTypography.body.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? tc.surface
                  : const Color(0xFFF3F6FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tc.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: WeRoboColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: WeRoboColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$label 비중이 '),
                        TextSpan(
                          text: '성장 기여의 $pct%',
                          style: const TextStyle(color: WeRoboColors.primary),
                        ),
                        const TextSpan(text: '를\n차지하고 있어요.'),
                      ],
                    ),
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tc.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketSummarySection extends StatelessWidget {
  const _MarketSummarySection();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      key: const Key('market_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
        boxShadow: WeRoboElevation.card(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '시장 요약',
                style: WeRoboTypography.heading3.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '더보기',
                style: WeRoboTypography.bodySmall.copyWith(
                  color: WeRoboColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _MarketSummaryCards(),
        ],
      ),
    );
  }
}

class _MarketSummaryCards extends StatelessWidget {
  const _MarketSummaryCards();

  static const _cards = [
    _MarketMiniCard(
      name: 'KOSPI',
      value: '2,730.34',
      change: '+0.62%',
    ),
    _MarketMiniCard(
      name: 'S&P 500',
      value: '5,321.41',
      change: '+0.58%',
    ),
    _MarketMiniCard(
      name: 'NASDAQ',
      value: '16,832.62',
      change: '+0.81%',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < _cards.length; i++) ...[
                  SizedBox(width: 132, child: _cards[i]),
                  if (i != _cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }

        return const Row(
          children: [
            Expanded(
              child: _MarketMiniCard(
                name: 'KOSPI',
                value: '2,730.34',
                change: '+0.62%',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MarketMiniCard(
                name: 'S&P 500',
                value: '5,321.41',
                change: '+0.58%',
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _MarketMiniCard(
                name: 'NASDAQ',
                value: '16,832.62',
                change: '+0.81%',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MarketMiniCard extends StatelessWidget {
  final String name;
  final String value;
  final String change;

  const _MarketMiniCard({
    required this.name,
    required this.value,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      height: 102,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? tc.surface
            : const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WeRoboTypography.caption.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Flexible(
                child: Text(
                  change,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                height: 20,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    points: const [0.3, 0.38, 0.34, 0.52, 0.47, 0.64],
                    color: WeRoboColors.primary.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  const _SparklinePainter({
    required this.points,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.isEmpty
        ? const [0.3, 0.38, 0.34, 0.55, 0.41, 0.68, 0.62, 0.78]
        : points;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width
          : (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minValue) / span;
      final y = size.height - (normalized * size.height * 0.72) - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

List<PortfolioCategory> _dashboardAllocations(MobileAccountSummary? summary) {
  final source = summary?.sectorAllocations ?? const <MobileSectorAllocation>[];
  if (source.isEmpty) {
    return const [
      PortfolioCategory(
        name: '주식 (ETF)',
        percentage: 55,
        color: WeRoboColors.primary,
      ),
      PortfolioCategory(
        name: '채권',
        percentage: 25,
        color: Color(0xFF3388FF),
      ),
      PortfolioCategory(
        name: '대체투자',
        percentage: 10,
        color: WeRoboColors.assetGold,
      ),
      PortfolioCategory(
        name: '현금',
        percentage: 10,
        color: Color(0xFF9AA6BF),
      ),
    ];
  }

  final byName = <String, double>{};
  for (final allocation in source) {
    final name =
        _dashboardAssetName(allocation.assetCode, allocation.assetName);
    byName[name] = (byName[name] ?? 0) + allocation.weight;
  }
  final entries = byName.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final colors = [
    WeRoboColors.primary,
    const Color(0xFF3388FF),
    const Color(0xFF66C7D9),
    WeRoboColors.assetGold,
  ];
  return [
    for (var i = 0; i < math.min(entries.length, 4); i++)
      PortfolioCategory(
        name: entries[i].key,
        percentage: entries[i].value * 100,
        color: colors[i % colors.length],
      ),
  ];
}

String _dashboardAssetName(String code, String fallback) {
  final normalized = code.toLowerCase();
  if (normalized.contains('bond')) return '채권';
  if (normalized.contains('cash')) return '현금';
  if (normalized.contains('gold') || normalized.contains('infra')) {
    return '대체투자';
  }
  if (normalized.contains('growth') || normalized.contains('value')) {
    return '주식 (ETF)';
  }
  return fallback.isEmpty ? '기타' : fallback;
}

List<double> _sparklinePoints(List<MobileAccountHistoryPoint> history) {
  if (history.length < 2) {
    return const [0.32, 0.38, 0.35, 0.48, 0.41, 0.57, 0.53, 0.66];
  }
  final sorted = [...history]..sort((a, b) => a.date.compareTo(b.date));
  return sorted
      .skip(math.max(0, sorted.length - 10))
      .map((p) => p.portfolioValue)
      .toList();
}

String _formatWon(double value) {
  final raw = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(raw[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
