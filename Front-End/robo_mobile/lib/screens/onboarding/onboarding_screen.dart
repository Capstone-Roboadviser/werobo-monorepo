import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/debug_page_logger.dart';
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
  void initState() {
    super.initState();
    logPageEnter('OnboardingScreen');
    logPageEnter('onboarding step 1/2');
    _prefetchFrontierPreview();
  }

  /// Start fetching the frontier preview while the user is still on page 1
  /// so it's cached by the time they swipe to the frontier page.
  Future<void> _prefetchFrontierPreview() async {
    try {
      final preview = await MobileBackendApi.instance.fetchFrontierPreview(
        propensityScore: 45.0,
      );
      if (!mounted) return;
      PortfolioStateProvider.of(context).setFrontierPreview(preview);
    } catch (_) {
      // Frontier page will retry on its own if the prefetch fails.
    }
  }

  @override
  void dispose() {
    logPageExit('OnboardingScreen');
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
                  logPageEnter('onboarding step ${index + 1}/2');
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

  /// Embedded frontier preview so the real curve renders instantly.
  /// Silently replaced when the live API responds.
  static final _embeddedPreview =
      MobileFrontierPreviewResponse.fromJson(const <String, dynamic>{
    'resolved_profile': {
      'code': 'balanced',
      'label': '균형형',
      'propensity_score': 45.0,
      'target_volatility': 0.0696,
      'investment_horizon': 'medium',
    },
    'recommended_portfolio_code': 'balanced',
    'data_source': 'managed_universe',
    'total_point_count': 80,
    'min_volatility': 0.0567,
    'max_volatility': 0.1918,
    'points': <Map<String, dynamic>>[
      {
        'index': 0,
        'volatility': 0.0567,
        'expected_return': 0.043,
        'is_recommended': false,
        'representative_code': 'conservative',
        'representative_label': '안정형'
      },
      {
        'index': 1,
        'volatility': 0.0567,
        'expected_return': 0.0433,
        'is_recommended': false
      },
      {
        'index': 3,
        'volatility': 0.0568,
        'expected_return': 0.0438,
        'is_recommended': false
      },
      {
        'index': 4,
        'volatility': 0.0569,
        'expected_return': 0.044,
        'is_recommended': false
      },
      {
        'index': 5,
        'volatility': 0.057,
        'expected_return': 0.0443,
        'is_recommended': false
      },
      {
        'index': 7,
        'volatility': 0.0573,
        'expected_return': 0.0448,
        'is_recommended': false
      },
      {
        'index': 8,
        'volatility': 0.0575,
        'expected_return': 0.045,
        'is_recommended': false
      },
      {
        'index': 9,
        'volatility': 0.0576,
        'expected_return': 0.0453,
        'is_recommended': false
      },
      {
        'index': 11,
        'volatility': 0.058,
        'expected_return': 0.0457,
        'is_recommended': false
      },
      {
        'index': 12,
        'volatility': 0.0583,
        'expected_return': 0.046,
        'is_recommended': false
      },
      {
        'index': 14,
        'volatility': 0.0588,
        'expected_return': 0.0465,
        'is_recommended': false
      },
      {
        'index': 16,
        'volatility': 0.0593,
        'expected_return': 0.047,
        'is_recommended': false
      },
      {
        'index': 18,
        'volatility': 0.0599,
        'expected_return': 0.0475,
        'is_recommended': false
      },
      {
        'index': 20,
        'volatility': 0.0605,
        'expected_return': 0.048,
        'is_recommended': false
      },
      {
        'index': 22,
        'volatility': 0.0612,
        'expected_return': 0.0485,
        'is_recommended': false
      },
      {
        'index': 25,
        'volatility': 0.0623,
        'expected_return': 0.0492,
        'is_recommended': false
      },
      {
        'index': 28,
        'volatility': 0.0635,
        'expected_return': 0.0499,
        'is_recommended': false
      },
      {
        'index': 30,
        'volatility': 0.0643,
        'expected_return': 0.0504,
        'is_recommended': false
      },
      {
        'index': 33,
        'volatility': 0.0657,
        'expected_return': 0.0512,
        'is_recommended': false
      },
      {
        'index': 36,
        'volatility': 0.0673,
        'expected_return': 0.0519,
        'is_recommended': false
      },
      {
        'index': 40,
        'volatility': 0.0696,
        'expected_return': 0.0529,
        'is_recommended': true,
        'representative_code': 'balanced',
        'representative_label': '균형형'
      },
      {
        'index': 43,
        'volatility': 0.0715,
        'expected_return': 0.0536,
        'is_recommended': false
      },
      {
        'index': 46,
        'volatility': 0.0735,
        'expected_return': 0.0544,
        'is_recommended': false
      },
      {
        'index': 49,
        'volatility': 0.0762,
        'expected_return': 0.0551,
        'is_recommended': false
      },
      {
        'index': 53,
        'volatility': 0.0813,
        'expected_return': 0.0561,
        'is_recommended': false
      },
      {
        'index': 57,
        'volatility': 0.0871,
        'expected_return': 0.0571,
        'is_recommended': false
      },
      {
        'index': 61,
        'volatility': 0.0948,
        'expected_return': 0.0581,
        'is_recommended': false
      },
      {
        'index': 65,
        'volatility': 0.1055,
        'expected_return': 0.0591,
        'is_recommended': false
      },
      {
        'index': 68,
        'volatility': 0.1129,
        'expected_return': 0.0598,
        'is_recommended': false
      },
      {
        'index': 72,
        'volatility': 0.1288,
        'expected_return': 0.0608,
        'is_recommended': false
      },
      {
        'index': 76,
        'volatility': 0.1511,
        'expected_return': 0.0618,
        'is_recommended': false
      },
      {
        'index': 79,
        'volatility': 0.1918,
        'expected_return': 0.0625,
        'is_recommended': false,
        'representative_code': 'growth',
        'representative_label': '성장형'
      },
    ],
  });

  double _dotT = 0.45;
  late MobileFrontierPreviewResponse _preview;
  int? _selectedPreviewPosition;
  bool _previewLoading = false;
  bool _previewUnavailable = false;
  bool _didUseInitialCache = false;

  MobileFrontierPreviewPoint? get _selectedPreviewPoint {
    final selectedPreviewPosition = _selectedPreviewPosition;
    if (_preview.points.isEmpty ||
        selectedPreviewPosition == null ||
        selectedPreviewPosition < 0 ||
        selectedPreviewPosition >= _preview.points.length) {
      return null;
    }
    return _preview.points[selectedPreviewPosition];
  }

  double get _returnRate {
    final previewPoint = _selectedPreviewPoint;
    if (previewPoint != null) {
      return previewPoint.expectedReturn * 100;
    }
    return 24.7 + (_dotT * (31.6 - 24.7));
  }

  ({String text, Color color}) get _riskComparison {
    final points = _preview.points;
    if (points.isEmpty) {
      return (
        text: '시장 평균 수준',
        color: WeRoboColors.accent,
      );
    }
    final averageVol =
        points.map((p) => p.volatility).reduce((a, b) => a + b) / points.length;
    final selected = _selectedPreviewPoint;
    if (selected == null || averageVol == 0) {
      return (
        text: '시장 평균 수준',
        color: WeRoboColors.accent,
      );
    }
    final diff = (selected.volatility - averageVol) / averageVol;
    final percentDiff = (diff.abs() * 100).round();
    final isRiskier = diff > 0;
    if (percentDiff == 0) {
      return (
        text: '시장 평균 수준',
        color: WeRoboColors.accent,
      );
    }
    // Smooth green→orange transition based on risk factor
    final lerpT = isRiskier ? (diff.abs() * 2).clamp(0.0, 1.0) : 0.0;
    final color = Color.lerp(
      const Color(0xFF059669),
      const Color(0xFFF97316),
      lerpT,
    )!;
    final text = '시장대비 약 $percentDiff%\n'
        '${isRiskier ? '더 위험한' : '더 안전한'} 포트폴리오';
    return (text: text, color: color);
  }

  @override
  void initState() {
    super.initState();
    // Show the embedded frontier instantly, then silently replace
    // with live data when the API responds.
    _preview = _embeddedPreview;
    final rec = _embeddedPreview.recommendedPreviewPosition;
    _selectedPreviewPosition = rec;
    _dotT = _embeddedPreview.points.length <= 1
        ? _initialDotT
        : rec / (_embeddedPreview.points.length - 1);
    widget.onPositionChanged?.call(_dotT);
    _loadFrontierPreview();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didUseInitialCache) {
      return;
    }
    _didUseInitialCache = true;
    final cachedPreview = PortfolioStateProvider.of(context).frontierPreview;
    if (cachedPreview == null || cachedPreview.points.isEmpty) {
      return;
    }
    _applyPreview(cachedPreview, fromCache: true);
  }

  Future<void> _loadFrontierPreview() async {
    try {
      final preview = await MobileBackendApi.instance.fetchFrontierPreview(
        propensityScore: _previewPropensityScore,
      );
      if (!mounted) {
        return;
      }
      PortfolioStateProvider.of(context).setFrontierPreview(preview);
      _applyPreview(preview);
    } catch (_) {
      if (!mounted) {
        return;
      }
      // Keep the embedded preview — it's better than showing nothing.
      setState(() {
        _previewLoading = false;
        _previewUnavailable = true;
      });
    }
  }

  void _applyPreview(
    MobileFrontierPreviewResponse preview, {
    bool fromCache = false,
  }) {
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
    if (fromCache) {
      logAction('use cached frontier preview', {
        'dataSource': preview.dataSource,
        'points': preview.points.length,
      });
    } else {
      logAction('update frontier preview', {
        'dataSource': preview.dataSource,
        'points': preview.points.length,
      });
    }
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
  }

  void _handlePreviewPositionChanged(int previewPosition) {
    if (_preview.points.isEmpty) {
      return;
    }
    final normalizedT = _preview.points.length <= 1
        ? _initialDotT
        : previewPosition / (_preview.points.length - 1);
    setState(() {
      _selectedPreviewPosition = previewPosition;
      _dotT = normalizedT;
    });
    widget.onPositionChanged?.call(normalizedT);
    widget.onFrontierSelectionChanged?.call(
      OnboardingFrontierSelection(
        normalizedT: normalizedT,
        targetVolatility: _preview.points[previewPosition].volatility,
        dataSource: _preview.dataSource,
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

          // Return + risk display
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '연 기대수익률',
                  value: '${_returnRate.toStringAsFixed(1)}%',
                  color: WeRoboColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _riskComparison.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: WeRoboTypography.caption.copyWith(
                      color: _riskComparison.color,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    child: Text(
                      _riskComparison.text,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          EfficientFrontierChart(
            previewPoints: _preview.points,
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
          Text(value, style: WeRoboTypography.number.copyWith(color: color)),
        ],
      ),
    );
  }
}
