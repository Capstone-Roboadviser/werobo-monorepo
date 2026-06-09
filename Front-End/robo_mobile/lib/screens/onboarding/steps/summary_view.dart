import 'package:flutter/material.dart';

/// Step 7 (summary) has no graphic. Per the Figma frame it is a
/// vertically-centered, navy-emphasized headline — which the scaffold renders
/// (see [OnboardingFlowScreen] `centerContent`). This body therefore draws
/// nothing; it exists only to satisfy the uniform step body-builder contract.
class OnboardingSummaryView extends StatelessWidget {
  /// 0→1 entrance animation. Unused here — the scaffold animates the centered
  /// headline — but kept so every step shares one constructor shape.
  final Animation<double> entrance;

  const OnboardingSummaryView({super.key, required this.entrance});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
