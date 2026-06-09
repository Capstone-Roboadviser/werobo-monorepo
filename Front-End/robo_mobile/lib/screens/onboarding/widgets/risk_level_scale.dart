import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/investor_profile.dart';

/// The 5-segment risk scale on the result screen. The [active] level is
/// highlighted navy; the others are muted.
class RiskLevelScale extends StatelessWidget {
  final RiskLevel active;
  const RiskLevelScale({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      children: [
        for (final level in RiskLevel.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: level == active ? WeRoboColors.primary : tc.border,
                      borderRadius:
                          BorderRadius.circular(WeRoboColors.radiusFull),
                    ),
                  ),
                  const SizedBox(height: WeRoboSpacing.sm),
                  Text(
                    level.label,
                    textAlign: TextAlign.center,
                    style: WeRoboTypography.caption.copyWith(
                      color: level == active
                          ? WeRoboColors.primary
                          : tc.textTertiary,
                      fontWeight:
                          level == active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
