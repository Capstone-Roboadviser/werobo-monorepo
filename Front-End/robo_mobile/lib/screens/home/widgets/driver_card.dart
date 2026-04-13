import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/mobile_backend_models.dart';

class DriverCard extends StatelessWidget {
  final DigestDriver driver;
  final bool isPositive;

  const DriverCard({
    super.key,
    required this.driver,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final returnColor =
        isPositive ? WeRoboColors.accent : WeRoboColors.textSecondary;
    final sign = isPositive ? '+' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeRoboColors.surface,
        border: Border.all(color: WeRoboColors.card, width: 1.5),
        borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: WeRoboColors.card,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  driver.ticker,
                  style: WeRoboTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'IBMPlexSans',
                    color: WeRoboColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.nameKo,
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: WeRoboColors.textPrimary,
                      ),
                    ),
                    Text(
                      '비중 ${driver.weightPct.toStringAsFixed(1)}%',
                      style: WeRoboTypography.caption.copyWith(
                        color: WeRoboColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${driver.returnPct.toStringAsFixed(1)}%',
                    style: WeRoboTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'GoogleSansFlex',
                      color: returnColor,
                    ),
                  ),
                  Text(
                    '$sign${_formatWon(driver.contributionWon)}',
                    style: WeRoboTypography.caption.copyWith(
                      color: returnColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (driver.explanationKo != null &&
              driver.explanationKo!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: WeRoboColors.card),
                ),
              ),
              child: Text(
                driver.explanationKo!,
                style: WeRoboTypography.caption.copyWith(
                  color: WeRoboColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatWon(double won) {
    final abs = won.abs().round();
    if (abs >= 100000000) {
      return '₩${(won / 100000000).toStringAsFixed(1)}억';
    }
    if (abs >= 10000) {
      return '₩${(won / 10000).toStringAsFixed(1)}만';
    }
    final formatted = abs.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return won < 0 ? '-₩$formatted' : '₩$formatted';
  }
}
