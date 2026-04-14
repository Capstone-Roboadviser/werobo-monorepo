import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const PageIndicator({
    super.key,
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: WeRoboMotion.short,
          curve: WeRoboMotion.move,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? WeRoboColors.dotActive : WeRoboColors.dotInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
