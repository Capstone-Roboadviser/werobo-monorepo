import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/portfolio_data.dart';
import '../onboarding/widgets/vestor_pie_chart.dart';

class PortfolioTab extends StatelessWidget {
  const PortfolioTab({super.key});

  @override
  Widget build(BuildContext context) {
    const type = InvestmentType.balanced;
    final categories = PortfolioData.categoriesFor(type);
    final details = PortfolioData.detailsFor(type);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text('내 포트폴리오', style: WeRoboTypography.heading2),
            const SizedBox(height: 16),

            // Pie chart
            Center(
              child: VestorPieChart(
                categories: categories,
                size: 200,
                ringWidth: 26,
                selectedRingWidth: 32,
              ),
            ),
            const SizedBox(height: 20),

            // Sector list
            ...details.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: WeRoboColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: d.category.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(d.category.name,
                            style: WeRoboTypography.bodySmall
                                .copyWith(color: WeRoboColors.textPrimary)),
                      ),
                      Text(
                        '${d.category.percentage.toInt()}%',
                        style: WeRoboTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: WeRoboColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 28),

            // Rebalancing section
            Text('리밸런싱', style: WeRoboTypography.heading3),
            const SizedBox(height: 12),

            // Next rebalance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WeRoboColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: WeRoboColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_rounded,
                        size: 20, color: WeRoboColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('다음 리밸런싱',
                            style: WeRoboTypography.caption
                                .copyWith(color: WeRoboColors.primary)),
                        Text('2026-07-01',
                            style: WeRoboTypography.bodySmall.copyWith(
                                color: WeRoboColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontFamily: WeRoboFonts.english)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: WeRoboColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('87일',
                        style: WeRoboTypography.caption.copyWith(
                            color: WeRoboColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Rebalance history
            Text('기록', style: WeRoboTypography.caption.copyWith(
                color: WeRoboColors.textSecondary)),
            const SizedBox(height: 8),
            _RebalanceRow(date: '2026-04-01', delta: '+1.2%'),
            _RebalanceRow(date: '2026-01-02', delta: '+0.8%'),
            _RebalanceRow(date: '2025-10-01', delta: '+2.1%'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _RebalanceRow extends StatelessWidget {
  final String date;
  final String delta;
  const _RebalanceRow({required this.date, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WeRoboColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 18, color: WeRoboColors.accent),
          const SizedBox(width: 10),
          Text(date,
              style: WeRoboTypography.bodySmall.copyWith(
                  color: WeRoboColors.textPrimary,
                  fontFamily: WeRoboFonts.english)),
          const Spacer(),
          Text(delta,
              style: WeRoboTypography.bodySmall.copyWith(
                  color: WeRoboColors.accent,
                  fontWeight: FontWeight.w600,
                  fontFamily: WeRoboFonts.english)),
        ],
      ),
    );
  }
}
