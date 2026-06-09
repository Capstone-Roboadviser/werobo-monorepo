import 'package:flutter/material.dart';

/// Builds the visual body for one onboarding step.
///
/// Every step body receives:
/// - [context]: the build context.
/// - [entrance]: a 0→1 [Animation] that runs when the step's page becomes
///   active. Steps fade/translate/draw their visual off this value.
/// - [readyNotifier]: shared readiness gate. Static (non-interactive) steps
///   ignore it; the interactive step (3) sets `.value = true` once satisfied
///   (first asset added) so the orchestrator can enable the button and unlock
///   forward swipe.
/// - [headlineNotifier]: the live headline the scaffold renders for this step.
///   It is pre-seeded with [OnboardingStep.headlineLines]. Static steps leave
///   it alone; steps with a runtime-variable headline (3) reassign its `.value`
///   to swap the displayed lines.
typedef OnboardingStepBodyBuilder = Widget Function(
  BuildContext context,
  Animation<double> entrance,
  ValueNotifier<bool> readyNotifier,
  ValueNotifier<OnboardingHeadline> headlineNotifier,
);

/// A run of headline text sharing one emphasis. [emphasized] runs render in
/// the navy brand color; the rest render near-black. Multiple segments compose
/// one [OnboardingHeadlineLine], so a single line can be partly navy (e.g.
/// step 7's "최적의 자산 배분" navy + "에" near-black on the same line).
@immutable
class OnboardingHeadlineSegment {
  final String text;
  final bool emphasized;

  const OnboardingHeadlineSegment(this.text, {this.emphasized = false});

  /// Shorthand for a navy-emphasized run.
  const OnboardingHeadlineSegment.emphasized(this.text) : emphasized = true;

  @override
  bool operator ==(Object other) =>
      other is OnboardingHeadlineSegment &&
      other.text == text &&
      other.emphasized == emphasized;

  @override
  int get hashCode => Object.hash(text, emphasized);
}

/// One line of an onboarding headline: an ordered list of [segments] rendered
/// on a single line. Most lines are a single plain segment; steps 3 and 7 mix
/// navy + near-black segments within a line.
@immutable
class OnboardingHeadlineLine {
  final List<OnboardingHeadlineSegment> segments;

  const OnboardingHeadlineLine(this.segments);

  /// A whole line from one string, uniformly [emphasized] or not.
  OnboardingHeadlineLine.text(String text, {bool emphasized = false})
      : segments = [OnboardingHeadlineSegment(text, emphasized: emphasized)];

  /// Flattened line text (segments concatenated).
  String get text => segments.map((s) => s.text).join();

  @override
  bool operator ==(Object other) =>
      other is OnboardingHeadlineLine &&
      _segmentsEqual(other.segments, segments);

  @override
  int get hashCode => Object.hashAll(segments);

  static bool _segmentsEqual(
    List<OnboardingHeadlineSegment> a,
    List<OnboardingHeadlineSegment> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// An ordered, multi-line headline. Each line carries its own segments, so a
/// headline can be partly navy (emphasized) and partly near-black — even within
/// a single line.
@immutable
class OnboardingHeadline {
  final List<OnboardingHeadlineLine> lines;

  const OnboardingHeadline(this.lines);

  /// Builds a headline where each string is its own line, all sharing the same
  /// [emphasized] flag. Handy for the static steps whose headline is one color.
  factory OnboardingHeadline.plain(
    List<String> lines, {
    bool emphasized = false,
  }) =>
      OnboardingHeadline(
        lines
            .map((l) => OnboardingHeadlineLine.text(l, emphasized: emphasized))
            .toList(growable: false),
      );

  /// Flattened text (segments concatenated per line, lines joined by `\n`) —
  /// useful for tests and semantics.
  String get text => lines.map((l) => l.text).join('\n');

  @override
  bool operator ==(Object other) =>
      other is OnboardingHeadline &&
      other.lines.length == lines.length &&
      _listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hashAll(lines);

  static bool _listEquals(
    List<OnboardingHeadlineLine> a,
    List<OnboardingHeadlineLine> b,
  ) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Immutable configuration for one onboarding step. The orchestrator owns an
/// ordered list of seven of these and renders the shared chrome (counter,
/// progress bar, primary button, skip) from them.
@immutable
class OnboardingStep {
  /// Default headline lines (the scaffold seeds its live headline notifier
  /// with this; interactive steps may swap it at runtime).
  final OnboardingHeadline headline;

  /// Optional gray caption shown below the headline. Null = no caption.
  final String? caption;

  /// Default primary-button label for this step (interactive steps may
  /// recompute it from readiness — see [interactive]).
  final String buttonLabel;

  /// Whether the underlined `건너뛰기` skip shows on this step. False on step 7.
  final bool showSkip;

  /// True only for the interactive step (3). The orchestrator gates the button
  /// (disabled until `readyNotifier.value` flips) and locks forward swipe for
  /// interactive steps; static steps are always enabled and freely swipeable.
  final bool interactive;

  /// When true, the page vertically centers the headline (+caption) instead of
  /// top-anchoring it, and the body carries no graphic. Used by the final
  /// summary step (7), whose Figma frame centers the copy with no illustration.
  final bool centerContent;

  /// When true, the gray caption renders BELOW the visual body instead of
  /// directly under the headline. Used by the frontier step (5), whose Figma
  /// frame places the explainer line beneath the chart.
  final bool captionBelow;

  /// Button label used while an [interactive] step is not yet ready. Ignored
  /// by static steps. Step 3: `자산을 추가해주세요`.
  final String? pendingButtonLabel;

  /// Builds the step's visual body. See [OnboardingStepBodyBuilder].
  final OnboardingStepBodyBuilder bodyBuilder;

  const OnboardingStep({
    required this.headline,
    this.caption,
    required this.buttonLabel,
    this.showSkip = true,
    this.interactive = false,
    this.centerContent = false,
    this.captionBelow = false,
    this.pendingButtonLabel,
    required this.bodyBuilder,
  });
}
