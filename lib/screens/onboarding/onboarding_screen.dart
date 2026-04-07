import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'loading_screen.dart';
import 'widgets/donut_chart.dart';
import 'widgets/efficient_frontier_chart.dart';
import 'widgets/page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _chartDragging = false;
  double _selectedDotT = 0.45;

  static const int _pageCount = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLoading();
    }
  }

  void _goToLoading() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PortfolioLoadingScreen(dotT: _selectedDotT),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: _chartDragging
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  const _ServiceDescriptionPage(),
                  _EfficientFrontierPage(
                    onDragStateChanged: (dragging) {
                      setState(() => _chartDragging = dragging);
                    },
                    onPositionChanged: (t) {
                      _selectedDotT = t;
                    },
                  ),
                ],
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: PageIndicator(
                count: _pageCount,
                current: _currentPage,
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == 0 ? '시작하기' : '다음',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page 1: Service description with donut chart
class _ServiceDescriptionPage extends StatelessWidget {
  const _ServiceDescriptionPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text(
            'AI가 찾아주는\n최적의 포트폴리오',
            style: WeRoboTypography.heading2.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '글로벌 자산에 분산 투자하여\n안정적인 수익을 추구합니다',
            style: WeRoboTypography.bodySmall.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const DonutChart(),
          const SizedBox(height: 32),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: WeRoboColors.chartBlue,
                label: '미국 주식',
                value: '45%',
              ),
              const SizedBox(width: 20),
              _LegendItem(
                color: WeRoboColors.chartGreen,
                label: '미국 채권',
                value: '40%',
              ),
              const SizedBox(width: 20),
              _LegendItem(
                color: WeRoboColors.chartYellow,
                label: '금',
                value: '15%',
              ),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: WeRoboTypography.caption.themed(context)),
        Text(
          value,
          style: WeRoboTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: tc.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Page 2: Efficient Frontier explanation
class _EfficientFrontierPage extends StatefulWidget {
  final ValueChanged<bool>? onDragStateChanged;
  final ValueChanged<double>? onPositionChanged;

  const _EfficientFrontierPage({
    this.onDragStateChanged,
    this.onPositionChanged,
  });

  @override
  State<_EfficientFrontierPage> createState() => _EfficientFrontierPageState();
}

class _EfficientFrontierPageState extends State<_EfficientFrontierPage> {
  // t=0 -> low risk/return, t=1 -> high risk/return
  double _dotT = 0.45;

  // Placeholder ranges (will be replaced by real algorithm later)
  // Risk: 8.4% (t=0) to 13.7% (t=1)
  // Return: 24.7% (t=0) to 31.6% (t=1)
  double get _risk => 8.4 + (_dotT * (13.7 - 8.4));
  double get _returnRate => 24.7 + (_dotT * (31.6 - 24.7));

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text(
            '이피션트 프론티어',
            style: WeRoboTypography.heading2.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '최적의 포트폴리오를 찾아드립니다',
            style: WeRoboTypography.bodySmall.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Risk / Return display
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '위험도',
                  value: '${_risk.toStringAsFixed(1)}%',
                  color: WeRoboColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: '수익률',
                  value: '${_returnRate.toStringAsFixed(1)}%',
                  color: tc.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          EfficientFrontierChart(
            onDragStateChanged: widget.onDragStateChanged,
            onPositionChanged: (t) {
              setState(() => _dotT = t);
              widget.onPositionChanged?.call(t);
            },
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: WeRoboColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: WeRoboColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '점을 드래그하여 원하는 포트폴리오를 선택하세요.',
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Column(
        children: [
          Text(label,
              style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: WeRoboTypography.number.copyWith(
                  color: tc.textPrimary)),
        ],
      ),
    );
  }
}
