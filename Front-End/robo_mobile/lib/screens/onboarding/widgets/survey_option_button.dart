import 'package:flutter/material.dart';
import '../../../app/pressable.dart';
import '../../../app/theme.dart';

/// A single answer card. White with a hairline border; when [selected] it
/// shows a navy border and a faint navy tint.
class SurveyOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SurveyOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WeRoboSpacing.md),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: WeRoboMotion.short,
          curve: WeRoboMotion.move,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: WeRoboSpacing.lg,
            vertical: WeRoboSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: selected
                ? WeRoboColors.primary.withValues(alpha: 0.06)
                : tc.card,
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
            border: Border.all(
              color: selected ? WeRoboColors.primary : tc.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Semantics(
            button: true,
            selected: selected,
            child: Text(
              label,
              style: WeRoboTypography.body.copyWith(
                color: tc.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
