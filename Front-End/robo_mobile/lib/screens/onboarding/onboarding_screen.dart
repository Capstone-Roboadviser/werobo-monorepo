import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import 'loading_screen.dart';
import 'widgets/donut_chart.dart';
import 'widgets/efficient_frontier_chart.dart';
import 'widgets/page_indicator.dart';

class OnboardingFrontierSelection {
  final double normalizedT;
  final double targetVolatility;
  final String dataSource;

  const OnboardingFrontierSelection({
    required this.normalizedT,
    required this.targetVolatility,
    required this.dataSource,
  });
}

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
  OnboardingFrontierSelection? _frontierSelection;

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
            PortfolioLoadingScreen(
          dotT: _selectedDotT,
          targetVolatility: _frontierSelection?.targetVolatility,
          previewDataSource: _frontierSelection?.dataSource,
        ),
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
                    onFrontierSelectionChanged: (selection) {
                      _frontierSelection = selection;
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
            '데이터가 찾아주는\n최적의 포트폴리오',
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
  final ValueChanged<OnboardingFrontierSelection?>? onFrontierSelectionChanged;

  const _EfficientFrontierPage({
    this.onDragStateChanged,
    this.onPositionChanged,
    this.onFrontierSelectionChanged,
  });

  @override
  State<_EfficientFrontierPage> createState() => _EfficientFrontierPageState();
}

class _EfficientFrontierPageState extends State<_EfficientFrontierPage> {
  static const double _initialDotT = 0.45;
  static const double _previewPropensityScore = 45.0;

  double _dotT = 0.45;
  MobileFrontierPreviewResponse? _preview;
  int? _selectedPreviewPosition;
  bool _previewLoading = true;
  bool _previewUnavailable = false;

  MobileFrontierPreviewPoint? get _selectedPreviewPoint {
    final preview = _preview;
    final selectedPreviewPosition = _selectedPreviewPosition;
    if (preview == null ||
        preview.points.isEmpty ||
        selectedPreviewPosition == null ||
        selectedPreviewPosition < 0 ||
        selectedPreviewPosition >= preview.points.length) {
      return null;
    }
    return preview.points[selectedPreviewPosition];
  }

  double get _risk {
    final previewPoint = _selectedPreviewPoint;
    if (previewPoint != null) {
      return previewPoint.volatility * 100;
    }
    return 8.4 + (_dotT * (13.7 - 8.4));
  }

  double get _returnRate {
    final previewPoint = _selectedPreviewPoint;
    if (previewPoint != null) {
      return previewPoint.expectedReturn * 100;
    }
    return 24.7 + (_dotT * (31.6 - 24.7));
  }

  @override
  void initState() {
    super.initState();
    widget.onPositionChanged?.call(_dotT);
    _loadFrontierPreview();
  }

  Future<void> _loadFrontierPreview() async {
    try {
      final preview = await MobileBackendApi.instance.fetchFrontierPreview(
        propensityScore: _previewPropensityScore,
      );
      if (!mounted) {
        return;
      }
      final recommendedPosition = preview.recommendedPreviewPosition;
      final normalizedT = preview.points.length <= 1
          ? _initialDotT
          : recommendedPosition / (preview.points.length - 1);
      setState(() {
        _preview = preview;
        _selectedPreviewPosition = recommendedPosition;
        _previewLoading = false;
        _previewUnavailable = false;
        _dotT = normalizedT;
      });
      widget.onPositionChanged?.call(_dotT);
      final previewPoint = preview.recommendedPoint;
      if (previewPoint != null) {
        widget.onFrontierSelectionChanged?.call(
          OnboardingFrontierSelection(
            normalizedT: normalizedT,
            targetVolatility: previewPoint.volatility,
            dataSource: preview.dataSource,
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = null;
        _selectedPreviewPosition = null;
        _previewLoading = false;
        _previewUnavailable = true;
      });
      widget.onFrontierSelectionChanged?.call(null);
    }
  }

  void _handlePreviewPositionChanged(int previewPosition) {
    final preview = _preview;
    if (preview == null || preview.points.isEmpty) {
      return;
    }
    final normalizedT = preview.points.length <= 1
        ? _initialDotT
        : previewPosition / (preview.points.length - 1);
    setState(() {
      _selectedPreviewPosition = previewPosition;
      _dotT = normalizedT;
    });
    widget.onPositionChanged?.call(normalizedT);
    widget.onFrontierSelectionChanged?.call(
      OnboardingFrontierSelection(
        normalizedT: normalizedT,
        targetVolatility: preview.points[previewPosition].volatility,
        dataSource: preview.dataSource,
      ),
    );
  }

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
            '나에게 맞는 투자 찾기',
            style: WeRoboTypography.heading2.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '이 곡선은 같은 위험도에서 가장 높은\n'
            '수익을 내는 조합을 보여줍니다',
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
            previewPoints: _preview?.points,
            selectedPreviewPosition: _selectedPreviewPosition,
            onDragStateChanged: widget.onDragStateChanged,
            onPreviewPointChanged: _handlePreviewPositionChanged,
            onPositionChanged: (t) {
              setState(() {
                _dotT = t;
                _selectedPreviewPosition = null;
              });
              widget.onPositionChanged?.call(t);
              widget.onFrontierSelectionChanged?.call(null);
            },
          ),
          if (_previewLoading || _previewUnavailable) ...[
            const SizedBox(height: 12),
            Text(
              _previewLoading
                  ? '실제 frontier preview를 불러오는 중이에요.'
                  : 'preview를 불러오지 못해 예시 곡선을 표시하고 있어요.',
              style: WeRoboTypography.caption.copyWith(
                color: tc.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                    '점을 움직여 나에게 맞는 위치를 찾아보세요.\n'
                    '오른쪽으로 갈수록 수익이 높지만 위험도 커져요.',
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
              style:
                  WeRoboTypography.caption.copyWith(color: tc.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: WeRoboTypography.number.copyWith(color: tc.textPrimary)),
        ],
      ),
    );
  }
}
