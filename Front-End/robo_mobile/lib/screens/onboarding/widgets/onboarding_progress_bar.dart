import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Shared onboarding chrome: a top-right `N/total` counter above a thin
/// rounded progress bar. The navy fill = `(index + 1) / total` over a
/// light-gray track and animates whenever [index] changes.
class OnboardingProgressBar extends StatelessWidget {
  /// Zero-based index of the active step.
  final int index;

  /// Total number of steps (7).
  final int total;

  /// Track height in logical pixels (~6px per spec §3).
  final double height;

  const OnboardingProgressBar({
    super.key,
    required this.index,
    required this.total,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final fraction = ((index + 1) / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${index + 1}/$total',
            style: WeRoboTypography.caption.copyWith(
              color: tc.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: WeRoboSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Stack(
            children: [
              Container(
                height: height,
                color: WeRoboColors.lightGray,
              ),
              // Fraction-of-width fill via FractionallySizedBox so it tracks
              // any parent width; the width tween gives the animated sweep.
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction),
                duration: WeRoboMotion.medium,
                curve: WeRoboMotion.move,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: WeRoboColors.primary,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
