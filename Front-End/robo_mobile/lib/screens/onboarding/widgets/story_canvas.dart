// Imports and the _lerpClamped helper are staged for the StoryCanvas painter
// and widget built in Task 5; they are intentionally unused at this step.
// ignore_for_file: unused_import, unused_element

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'risk_gauge.dart';

// ============================================================================
// Interpolation helpers — pure functions of `progress` (PageController.page).
// progress ∈ [0.0, 6.0]; integer values land exactly on a page.
// Exported (no underscore) so the helper tests can reach them.
// ============================================================================

double _lerpClamped(double a, double b, double t) =>
    lerpDouble(a, b, t.clamp(0.0, 1.0))!;

double storyGaugeOpacity(double p) {
  // Visible across spec pages 2-3 (progress 1.0–2.0). Fades in 0.7→1.0,
  // out 2.0→2.5.
  if (p < 0.7) return 0;
  if (p < 1.0) return (p - 0.7) / 0.3;
  if (p < 2.0) return 1.0;
  if (p < 2.5) return 1 - (p - 2.0) / 0.5;
  return 0;
}

double storyGaugeValue(double p) {
  // 40 on spec page 2 (progress 1.0), eases to 30 on spec page 3 (2.0).
  if (p < 1.0) return 40;
  if (p < 2.0) return 40 - (p - 1.0) * 10;
  return 30;
}

double storyCtaOpacity(double p) {
  // Fades in across [5.7, 6.0] so the CTA is fully visible AT spec page 7
  // (progress 6.0). The event chips on page 6 are already fading out by 5.7,
  // so there is no overlap conflict.
  if (p < 5.7) return 0;
  if (p < 6.0) return (p - 5.7) / 0.3;
  return 1.0;
}

/// 0 → 1 across [3.5, 4.0] (curve draws as user enters page 5);
/// stays at 1 through 4.5; fades back to 0 across [4.5, 5.0]
/// as the frontier scene exits toward page 6.
double storyCurveDrawProgress(double p) {
  if (p < 3.5) return 0;
  if (p < 4.0) return (p - 3.5) / 0.5;
  if (p < 4.5) return 1.0;
  if (p < 5.0) return 1 - (p - 4.5) / 0.5;
  return 0;
}

/// Opacity for each of the 4 story dots.
/// - All 4 visible on spec page 1 (progress 0).
/// - Dot 0 (red) is the "lead" — it scales into the page-2 circle so its
///   own dot opacity drops to 0 across [0.7, 1.0] (the circle takes over).
/// - Dots 1-3 fade out across [0.3, 0.8].
/// - All 4 reappear on spec page 5 (frontier scene) across [3.7, 4.0]
///   at on-curve positions, then fade out across [4.7, 5.0].
double storyDotOpacity(int index, double p) {
  // Frontier scene visibility window (spec page 5, progress 4.0)
  if (p >= 3.7 && p < 5.0) {
    if (p < 4.0) return (p - 3.7) / 0.3;
    if (p < 4.7) return 1.0;
    return 1 - (p - 4.7) / 0.3;
  }

  // Intro scene (spec page 1, progress 0)
  if (index == 0) {
    if (p < 0.7) return 1.0;
    if (p < 1.0) return 1 - (p - 0.7) / 0.3;
    return 0;
  }
  if (p < 0.3) return 1.0;
  if (p < 0.8) return 1 - (p - 0.3) / 0.5;
  return 0;
}

/// Staggered fade-in (chip 0 leads, chip 3 trails by 0.05 progress units).
/// All chips fully visible by progress 4.85, well before spec page 6
/// (progress 5.0). Fades out across [5.5, 6.0] as the user moves to page 7.
double storyChipOpacity(int index, double p) {
  final start = 4.5 + index * 0.05;
  final end = start + 0.2;
  if (p < start) return 0;
  if (p < end) return (p - start) / (end - start);
  if (p < 5.5) return 1.0;
  if (p < 6.0) return 1 - (p - 5.5) / 0.5;
  return 0;
}
