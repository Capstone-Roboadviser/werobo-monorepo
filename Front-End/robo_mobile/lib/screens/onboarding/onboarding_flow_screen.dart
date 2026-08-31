import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import 'login_screen.dart';
import 'onboarding_step.dart';
import 'steps/ai_management_view.dart';
import 'steps/asset_scatter_view.dart';
import 'steps/diversification_view.dart';
import 'steps/efficient_frontier_view.dart';
import 'steps/optimal_ratio_donut_view.dart';
import 'steps/summary_view.dart';
import 'steps/volatility_line_view.dart';
import 'widgets/onboarding_progress_bar.dart';

/// The new 7-step educational onboarding flow. Owns the shared chrome
/// (counter + progress bar, headline/caption, primary button, skip) and the
/// `PageController`; each step supplies only its visual body.
///
/// Replaces `StoryFlowScreen`. Finish (step 7 CTA) and skip both call the
/// existing [PortfolioState.markStorySeen] then route to [LoginScreen] with
/// the shared fade/slide transition — identical to the old exit.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen>
    with SingleTickerProviderStateMixin {
  static const int _stepCount = 7;

  final _pageController = PageController();
  late final AnimationController _entranceController;
  late final Animation<double> _entrance;

  /// Per-step readiness gates. Only the interactive step (index 2) ever flips
  /// to true; the others stay false and are simply ignored by the chrome.
  late final List<ValueNotifier<bool>> _readyNotifiers;

  /// Per-step live headlines. Seeded from each step's config; the interactive
  /// step reassigns its entry at runtime to swap the displayed headline.
  late final List<ValueNotifier<OnboardingHeadline>> _headlineNotifiers;

  late final List<OnboardingStep> _steps;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    logPageEnter('OnboardingFlowScreen');

    _entranceController = AnimationController(
      duration: WeRoboMotion.long,
      vsync: this,
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: WeRoboMotion.enter,
    );

    _steps = _buildSteps();
    _readyNotifiers =
        List.generate(_stepCount, (_) => ValueNotifier<bool>(false));
    _headlineNotifiers = _steps
        .map((s) => ValueNotifier<OnboardingHeadline>(s.headline))
        .toList(growable: false);

    // The first page is active immediately, so play its entrance once mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    logPageExit('OnboardingFlowScreen');
    _pageController.dispose();
    _entranceController.dispose();
    for (final n in _readyNotifiers) {
      n.dispose();
    }
    for (final n in _headlineNotifiers) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _isLastStep => _index == _stepCount - 1;

  OnboardingStep get _currentStep => _steps[_index];

  ValueNotifier<bool> get _currentReady => _readyNotifiers[_index];

  /// Forward navigation is gated only on interactive steps that aren't ready.
  bool get _canAdvance => !_currentStep.interactive || _currentReady.value;

  /// The page index to pin forward scrolling at, or null when forward motion
  /// is free. Returns the current page only while an interactive step isn't
  /// ready — so the flow can still settle ONTO that page (the button's
  /// `nextPage` animation lands cleanly), but can't be swiped or flung PAST it.
  int? _forwardLockedPage() => _canAdvance ? null : _index;

  Future<void> _exitToLogin() async {
    final state = PortfolioStateProvider.of(context);
    final navigator = Navigator.of(context);
    await state.markStorySeen();
    if (!mounted) return;
    navigator.pushReplacement(WeRoboMotion.fadeRoute(const LoginScreen()));
  }

  void _onPrimaryPressed() {
    if (_isLastStep) {
      logAction('onboarding finish');
      _exitToLogin();
      return;
    }
    if (!_canAdvance) return;
    logAction('onboarding next', {'from': _index});
    _pageController.nextPage(
      duration: WeRoboMotion.pageTransition,
      curve: WeRoboMotion.move,
    );
  }

  void _onSkipPressed() {
    logAction('onboarding skip', {'from': _index});
    _exitToLogin();
  }

  void _onPageChanged(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    // Restart the entrance animation for the freshly-active page.
    _entranceController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WeRoboSpacing.xxl,
                WeRoboSpacing.md,
                WeRoboSpacing.xxl,
                0,
              ),
              child: OnboardingProgressBar(
                index: _index,
                total: _stepCount,
              ),
            ),
            Expanded(
              // The forward lock on the interactive step is read live by the
              // physics ([_forwardLockedPage]) every frame, so it engages on
              // page change and releases the instant readiness flips — no
              // rebuild needed. It pins motion at the locked page's boundary,
              // so the button's nextPage still settles onto it; only swiping or
              // flinging PAST it is blocked. Backward swipes are always free.
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: _OnboardingPageScrollPhysics(
                  lockedPage: _forwardLockedPage,
                ),
                itemCount: _stepCount,
                itemBuilder: (context, i) => _OnboardingStepPage(
                  step: _steps[i],
                  entrance: _entrance,
                  readyNotifier: _readyNotifiers[i],
                  headlineNotifier: _headlineNotifiers[i],
                ),
              ),
            ),
            _OnboardingFooter(
              step: _currentStep,
              readyNotifier: _currentReady,
              isLastStep: _isLastStep,
              onPrimaryPressed: _onPrimaryPressed,
              onSkipPressed: _onSkipPressed,
            ),
          ],
        ),
      ),
    );
  }

  List<OnboardingStep> _buildSteps() {
    return [
      // 1 — asset scatter
      OnboardingStep(
        headline: OnboardingHeadline.plain(
          const ['시장에는 수많은 자산들이 있습니다.'],
        ),
        buttonLabel: '다음',
        bodyBuilder: (context, entrance, ready, headline) =>
            AssetScatterView(entrance: entrance),
      ),
      // 2 — volatility line
      OnboardingStep(
        headline: OnboardingHeadline.plain(
          const ['주식 몰빵 투자 정말 괜찮을까요?'],
        ),
        caption: '시장이 흔들리는 순간, 내 자산 전체가 함께 무너집니다.\n'
            "충격을 나누어 담을 '안전장치'가 없기 때문이죠.",
        buttonLabel: '분산투자하면 어떻게 될까요?',
        captionBelow: true,
        bodyBuilder: (context, entrance, ready, headline) =>
            VolatilityLineView(entrance: entrance),
      ),
      // 3 — diversification (interactive; headline swaps on first add)
      OnboardingStep(
        headline: OnboardingHeadline.plain(
          const ['분산투자만으로', '위험은 크게 줄어듭니다.'],
        ),
        caption: '서로 다른 성격의 자산들에 분산투자 하는 것만으로도\n'
            '리스크를 효과적으로 방어하고 안정적인 수익을 낼 수 있습니다.',
        buttonLabel: '계속하기',
        pendingButtonLabel: '자산을 추가해주세요',
        interactive: true,
        captionBelow: true,
        bodyBuilder: (context, entrance, ready, headline) =>
            DiversificationView(
          entrance: entrance,
          readyNotifier: ready,
          headlineNotifier: headline,
        ),
      ),
      // 4 — optimal-ratio donut
      OnboardingStep(
        headline: OnboardingHeadline.plain(
          const ['하지만 무엇을, 얼마나, 어떻게', '구성해야 할까요?'],
        ),
        caption: '수만 가지의 자산 조합에서\n'
            '모든 조합의 수익률과 리스크를 계산하여\n'
            '최적의 비율을 찾는 것은 불가능에 가깝습니다.',
        buttonLabel: 'ALFIN에게 맡겨요!',
        captionBelow: true,
        bodyBuilder: (context, entrance, ready, headline) =>
            OptimalRatioDonutView(entrance: entrance),
      ),
      // 5 — efficient frontier (display-only)
      OnboardingStep(
        headline: OnboardingHeadline.plain(
          const ['가장 완벽한 최적의 조합을', 'ALFIN이 찾아냅니다.'],
        ),
        caption: '같은 위험이면 더 높은 수익을,\n'
            '같은 수익이면 더 낮은 위험인 최적의 조합을 제공합니다.',
        buttonLabel: '다음',
        captionBelow: true,
        bodyBuilder: (context, entrance, ready, headline) =>
            OnboardingFrontierView(entrance: entrance),
      ),
      // 6 — AI management
      OnboardingStep(
        headline: OnboardingHeadline.plain(
          const ['ALFIN은 시장에 대응하여', '알아서 운용전략을 바꿉니다.'],
        ),
        caption: '시시각각 변하는 세계 정세를 ALFIN이\n'
            '실시간으로 분석하여 최고의 전략으로 포트폴리오를 운용합니다.',
        buttonLabel: '다음',
        captionBelow: true,
        bodyBuilder: (context, entrance, ready, headline) =>
            AiManagementView(entrance: entrance),
      ),
      // 7 — summary (rich navy-emphasized headline; no skip)
      OnboardingStep(
        headline: const OnboardingHeadline([
          OnboardingHeadlineLine([
            OnboardingHeadlineSegment.emphasized('최적의 자산 배분'),
            OnboardingHeadlineSegment('에'),
          ]),
          OnboardingHeadlineLine([
            OnboardingHeadlineSegment.emphasized('최고의 전략'),
            OnboardingHeadlineSegment('으로.'),
          ]),
          OnboardingHeadlineLine([
            OnboardingHeadlineSegment('보다 더 안정적이면서도'),
          ]),
          OnboardingHeadlineLine([
            OnboardingHeadlineSegment.emphasized('더 높은 수익률'),
            OnboardingHeadlineSegment('을 제공하겠습니다.'),
          ]),
        ]),
        buttonLabel: '투자 시작하기',
        showSkip: false,
        centerContent: true,
        bodyBuilder: (context, entrance, ready, headline) =>
            OnboardingSummaryView(entrance: entrance),
      ),
    ];
  }
}

/// One page of the flow: the scaffold-owned headline + caption stacked above
/// the step's visual body. The headline is driven by [headlineNotifier] so the
/// interactive step can swap it; the body is the step author's widget.
class _OnboardingStepPage extends StatelessWidget {
  final OnboardingStep step;
  final Animation<double> entrance;
  final ValueNotifier<bool> readyNotifier;
  final ValueNotifier<OnboardingHeadline> headlineNotifier;

  const _OnboardingStepPage({
    required this.step,
    required this.entrance,
    required this.readyNotifier,
    required this.headlineNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final headlineWidget = ValueListenableBuilder<OnboardingHeadline>(
      valueListenable: headlineNotifier,
      builder: (context, headline, _) =>
          _OnboardingHeadlineText(headline: headline),
    );
    final caption = step.caption == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: WeRoboSpacing.lg),
            child: Text(
              step.caption!,
              textAlign: TextAlign.center,
              style: WeRoboTypography.bodySmall.copyWith(
                color: WeRoboThemeColors.of(context).textSecondary,
              ),
            ),
          );
    final body = step.bodyBuilder(
      context,
      entrance,
      readyNotifier,
      headlineNotifier,
    );

    // Summary step: vertically center the headline (+caption); no graphic body.
    if (step.centerContent) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: WeRoboSpacing.xxl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              headlineWidget,
              if (caption != null) caption,
              body,
            ],
          ),
        ),
      );
    }

    // Default: headline (+ caption) near the top, visual fills the rest. When
    // [captionBelow], the caption instead sits beneath the visual (step 5).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WeRoboSpacing.xxl),
      child: Column(
        children: [
          const SizedBox(height: WeRoboSpacing.xxxxl),
          headlineWidget,
          if (caption != null && !step.captionBelow) caption,
          Expanded(child: body),
          if (caption != null && step.captionBelow) ...[
            caption,
            // A little breathing room between the caption and the footer CTA.
            const SizedBox(height: WeRoboSpacing.lg),
          ],
        ],
      ),
    );
  }
}

/// Renders an [OnboardingHeadline] as a single centered, multi-line rich text
/// run. Emphasized lines use the navy brand color; the rest use near-black.
class _OnboardingHeadlineText extends StatelessWidget {
  final OnboardingHeadline headline;

  const _OnboardingHeadlineText({required this.headline});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final base = WeRoboTypography.heading2.copyWith(
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    for (var li = 0; li < headline.lines.length; li++) {
      for (final seg in headline.lines[li].segments) {
        spans.add(
          TextSpan(
            text: seg.text,
            style: base.copyWith(
              color: seg.emphasized ? WeRoboColors.primary : tc.textPrimary,
            ),
          ),
        );
      }
      // A newline between lines (but not after the last), so each line's
      // segments stay together on one line.
      if (li != headline.lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }
}

/// Bottom chrome: full-width navy pill primary button + underlined skip.
/// Listens to the active step's [readyNotifier] so interactive steps flip
/// their label + enabled state live.
class _OnboardingFooter extends StatelessWidget {
  final OnboardingStep step;
  final ValueNotifier<bool> readyNotifier;
  final bool isLastStep;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSkipPressed;

  const _OnboardingFooter({
    required this.step,
    required this.readyNotifier,
    required this.isLastStep,
    required this.onPrimaryPressed,
    required this.onSkipPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WeRoboSpacing.xxl,
        WeRoboSpacing.md,
        WeRoboSpacing.xxl,
        WeRoboSpacing.lg,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: readyNotifier,
        builder: (context, ready, _) {
          final enabled = isLastStep || !step.interactive || ready;
          final label = step.interactive && !ready
              ? (step.pendingButtonLabel ?? step.buttonLabel)
              : step.buttonLabel;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: enabled ? onPrimaryPressed : null,
                  child: Text(label),
                ),
              ),
              SizedBox(
                height: 44,
                child: step.showSkip
                    ? TextButton(
                        onPressed: onSkipPressed,
                        child: Text(
                          '건너뛰기',
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: WeRoboThemeColors.of(context).textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Page physics that allow backward swipes but block forward motion PAST the
/// active step while it is forward-locked (the interactive step before its
/// first asset add). This stops a swipe/fling from bypassing the button gate
/// without freezing the legitimate `nextPage` animation that lands ON the step.
/// When unlocked it behaves like the default [PageScrollPhysics].
///
/// The lock is read LIVE via [lockedPage] every frame rather than baked into a
/// field. `Scrollable` only re-adopts physics whose `runtimeType` (walking the
/// parent chain) changes; swapping a same-typed instance carrying a different
/// field value is silently ignored once the `ScrollPosition` exists. Closing
/// over a getter keeps a single instance always consulting the current step.
///
/// [lockedPage] returns the page index to pin at (or null = free). The pin is
/// the *boundary of that page itself* (`index * viewportDimension`), so the
/// controller can still animate/settle onto it — only motion BEYOND it (toward
/// the next page) is dropped. Earlier this pinned at the live offset, which
/// froze the inbound settle halfway between pages.
class _OnboardingPageScrollPhysics extends ScrollPhysics {
  /// Evaluated every frame; the page index to lock forward motion at, or null.
  final ValueGetter<int?> lockedPage;

  const _OnboardingPageScrollPhysics({
    required this.lockedPage,
    super.parent,
  });

  @override
  _OnboardingPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OnboardingPageScrollPhysics(
      lockedPage: lockedPage,
      parent: buildParent(ancestor),
    );
  }

  /// The max scroll offset forward motion may reach (the locked page's own
  /// boundary), or null when forward scrolling is unrestricted.
  double? _maxOffset(ScrollMetrics position) {
    final page = lockedPage();
    if (page == null) return null;
    return page * position.viewportDimension;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final max = _maxOffset(position);
    // A negative user offset drives the view forward (toward the next page).
    // Drop forward drag once at/over the locked page; backward always passes.
    if (max != null && offset < 0 && position.pixels >= max) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final max = _maxOffset(position);
    if (max != null && value > max && value > position.pixels) {
      // Clamp at the locked page's boundary so a fling/overscroll can't carry
      // past it — while still allowing a settle that lands exactly on it.
      return value - max;
    }
    return super.applyBoundaryConditions(position, value);
  }
}
