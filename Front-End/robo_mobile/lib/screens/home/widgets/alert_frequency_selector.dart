import 'package:flutter/material.dart';

import '../../../app/portfolio_state.dart';
import '../../../app/theme.dart';

/// Segmented selector for alert frequency. Plain-language labels only —
/// no σ values are exposed to the user.
class AlertFrequencySelector extends StatelessWidget {
  final AlertFrequency value;
  final ValueChanged<AlertFrequency> onChanged;

  const AlertFrequencySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final f in AlertFrequency.values)
            Expanded(
              child: _Segment(
                label: f.koLabel,
                selected: f == value,
                onTap: () => onChanged(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: WeRoboMotion.short,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? WeRoboColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: WeRoboTypography.bodySmall.copyWith(
            color: selected ? WeRoboColors.white : tc.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
