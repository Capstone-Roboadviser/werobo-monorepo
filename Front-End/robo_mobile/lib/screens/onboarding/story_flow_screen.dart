import 'package:flutter/material.dart';

import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import 'login_screen.dart';
import 'widgets/story_canvas.dart';

class StoryFlowScreen extends StatefulWidget {
  const StoryFlowScreen({super.key});

  @override
  State<StoryFlowScreen> createState() => _StoryFlowScreenState();
}

class _StoryFlowScreenState extends State<StoryFlowScreen> {
  final _pageController = PageController();

  static const _pages = <_StoryPageData>[
    _StoryPageData(
      headline: '시장에는 수많은 자산들이 있습니다.',
      description: null,
    ),
    _StoryPageData(
      headline: '여러 자산에 분산투자 하는 것만으로\n투자는 안전해집니다.',
      description:
          '서로 다른 성격의 자산들에\n분산투자 하는 것만으로도\n시장의 리스크를 효과적으로 방어하고\n안정적인 수익을 낼 수 있습니다.',
    ),
    _StoryPageData(
      headline: '여러 자산에 분산투자 하는 것만으로\n투자는 안전해집니다.',
      description:
          '서로 다른 성격의 자산들에\n분산투자 하는 것만으로도\n시장의 리스크를 효과적으로 방어하고\n안정적인 수익을 낼 수 있습니다.',
    ),
    _StoryPageData(
      headline: '하지만, 무엇을 얼마나 어떻게\n구성해야 할까요?',
      description:
          '수만 가지의 자산 조합 속에서\n나에게 딱 맞는 최적의 비율을 찾는 것은\n불가능에 가깝습니다.',
    ),
    _StoryPageData(
      headline: '가장 완벽한 최적의 조합을\nWeRobo가 찾아냅니다.',
      description:
          '같은 위험 대비 가장 높은 수익률을 낼 수 있는\n자산 조합을 이은 선.\nWeRobo의 알고리즘은 당신의 자산 조합을\n이 곡선 위 최적의 지점에 안착시킵니다.',
    ),
    _StoryPageData(
      headline:
          '최적의 자산 조합에 더하여,\nWeRobo는 시장에 대응하여\n알아서 전략을 바꿉니다.',
      description:
          '시시각각 변하는 세계 정세를 AI가\n실시간으로 분석하여 최적의 전략으로\n당신의 포트폴리오를 운용합니다.',
    ),
    _StoryPageData(
      headline:
          '최적의 자산 배분으로, 최선의 전략으로,\n보다 안정적이면서 높은 수익률을\nWeRobo가 제공하겠습니다.',
      description: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    logPageEnter('StoryFlowScreen');
  }

  @override
  void dispose() {
    logPageExit('StoryFlowScreen');
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _exitToLogin() async {
    final state = PortfolioStateProvider.of(context);
    final navigator = Navigator.of(context);
    await state.markStorySeen();
    if (!mounted) return;
    navigator.pushReplacement(WeRoboMotion.fadeRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WeRoboColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // PageView with text-only pages (bottom — gets swipes)
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              itemBuilder: (_, i) => _StoryPage(data: _pages[i]),
            ),
            // Visual canvas, driven by pageController.page. Stacked above
            // the PageView so the CTA on page 7 is reachable; CustomPaint
            // has no child and won't intercept swipes elsewhere.
            AnimatedBuilder(
              animation: _pageController,
              builder: (_, __) => StoryCanvas(
                progress: _pageController.hasClients
                    ? (_pageController.page ?? 0.0)
                    : 0.0,
                onStartPressed: _exitToLogin,
              ),
            ),
            // Skip button (top-right)
            Positioned(
              top: 12,
              right: 16,
              child: TextButton(
                onPressed: _exitToLogin,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(
                    color: WeRoboColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // Page dots (bottom)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (_, __) {
                  final current = _pageController.hasClients
                      ? (_pageController.page ?? 0.0).round()
                      : 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == current;
                      return Container(
                        key: ValueKey('story_page_dot_$i'),
                        width: active ? 22 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? WeRoboColors.primary
                              : WeRoboColors.lightGray,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPageData {
  final String headline;
  final String? description;
  const _StoryPageData({required this.headline, this.description});
}

class _StoryPage extends StatelessWidget {
  final _StoryPageData data;
  const _StoryPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          Text(
            data.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: WeRoboColors.primary,
              height: 1.4,
            ),
          ),
          const Spacer(),
          if (data.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Text(
                data.description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: WeRoboColors.primary,
                  height: 1.5,
                ),
              ),
            )
          else
            const SizedBox(height: 80),
        ],
      ),
    );
  }
}
