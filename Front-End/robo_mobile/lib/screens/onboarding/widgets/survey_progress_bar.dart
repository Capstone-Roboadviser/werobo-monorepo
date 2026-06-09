import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Top progress indicator: a thin navy bar that fills with `step / total`,
/// plus an `n / total` counter aligned right.
class SurveyProgressBar extends StatelessWidget {
  final int step; // 1-based
  final int total;
  const SurveyProgressBar({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final fraction = (step / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: WeRoboSpacing.xxl),
          child: Text(
            '$step / $total',
            textAlign: TextAlign.right,
            style: WeRoboTypography.bodySmall.copyWith(
              color: WeRoboColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: WeRoboSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WeRoboSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
                child: Stack(
                  children: [
                    Container(height: 6, color: tc.border),
                    AnimatedContainer(
                      duration: WeRoboMotion.medium,
                      curve: WeRoboMotion.move,
                      height: 6,
                      width: constraints.maxWidth * fraction,
                      color: WeRoboColors.primary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
