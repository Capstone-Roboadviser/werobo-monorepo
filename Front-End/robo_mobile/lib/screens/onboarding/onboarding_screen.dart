import 'package:flutter/material.dart';
import '../../app/portfolio_state.dart';
import '../../app/debug_page_logger.dart';
import '../../app/theme.dart';
import '../../models/mobile_backend_models.dart';
import '../../services/mobile_backend_api.dart';
import 'frontier_selection_resolver.dart';
import 'portfolio_review_screen.dart';
import 'widgets/asset_weight.dart';
import 'widgets/efficient_frontier_chart.dart';

const _frontierPreviewSamplePoints = 301;

/// Maps backend `asset_code` strings to the `AssetClass` enum.
/// Returns `null` for unknown codes (caller skips those allocations).
AssetClass? _assetClassForCode(String code) => switch (code) {
      'cash_equivalents' => AssetClass.cash,
      'short_term_bond' => AssetClass.shortBond,
      'infra_bond' => AssetClass.infraBond,
      'gold' => AssetClass.gold,
      'us_value' => AssetClass.usValue,
      'us_growth' => AssetClass.usGrowth,
      'new_growth' => AssetClass.newGrowth,
      _ => null,
    };

class OnboardingFrontierSelection {
  final double normalizedT;
  final int selectedPointIndex;
  final double targetVolatility;
  final String dataSource;
  final DateTime? asOfDate;
  final bool isAuthoritative;
  final MobileFrontierPreviewResponse? preview;

  const OnboardingFrontierSelection({
    required this.normalizedT,
    required this.selectedPointIndex,
    required this.targetVolatility,
    required this.dataSource,
    required this.asOfDate,
    required this.isAuthoritative,
    this.preview,
  });

  /// Returns the asset-class weight vector at the given t ∈ [0, 1].
  /// Output is indexed by `AssetClass.index` (cash → newGrowth, length 7).
  /// Falls back to a zero vector when no preview/allocations are available.
  List<double> weightsAt(double t) {
    final result = List<double>.filled(AssetClass.values.length, 0);
    final preview = this.preview;
    if (preview == null || preview.points.isEmpty) {
      return result;
    }
    final clamped = t.clamp(0.0, 1.0);
    final position = preview.points.length <= 1
        ? 0
        : (clamped * (preview.points.length - 1))
            .round()
            .clamp(0, preview.points.length - 1);
    for (final allocation in preview.points[position].sectorAllocations) {
      final cls = _assetClassForCode(allocation.assetCode);
      if (cls == null) {
        continue;
      }
      result[cls.index] += allocation.weight;
    }
    return result;
  }
}

class OnboardingScreen extends StatefulWidget {
  final DateTime? asOfDate;

  const OnboardingScreen({
    super.key,
    this.asOfDate,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  double _selectedDotT = 0.45;
  OnboardingFrontierSelection? _frontierSelection;
  late final Future<MobileFrontierPreviewResponse?> _frontierPreviewFuture;

  @override
  void initState() {
    super.initState();
    logPageEnter('OnboardingScreen');
    _frontierPreviewFuture = _fetchFrontierPreview();
  }

  /// Kick off the frontier preview fetch immediately so the chart can swap
  /// from the embedded sample data to the live curve as soon as it lands.
  Future<MobileFrontierPreviewResponse?> _fetchFrontierPreview() async {
    try {
      final preview = await MobileBackendApi.instance.fetchFrontierPreview(
        propensityScore: 45.0,
        samplePoints: _frontierPreviewSamplePoints,
        asOfDate: widget.asOfDate,
      );
      if (!mounted) {
        return preview;
      }
      PortfolioStateProvider.of(context).setFrontierPreview(preview);
      return preview;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    logPageExit('OnboardingScreen');
    super.dispose();
  }

  void _goToReview() {
    final resolvedSelection =
        _frontierSelection ?? _selectionFromCachedPreview();
    if (resolvedSelection == null) {
      logAction('frontier selection unavailable on next', {
        'dotT': _selectedDotT.toStringAsFixed(2),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포트폴리오 데이터를 불러오는 중이에요. 잠시 후 다시 시도해 주세요.'),
        ),
      );
      return;
    }
    if (_frontierSelection == null) {
      logAction('hydrate initial frontier selection', {
        'selected_point_index': resolvedSelection.selectedPointIndex,
        'target_volatility':
            resolvedSelection.targetVolatility.toStringAsFixed(4),
        'dataSource': resolvedSelection.dataSource,
      });
    }
    Navigator.of(context).push(
      WeRoboMotion.fadeRoute(
        PortfolioReviewScreen(selection: resolvedSelection),
      ),
    );
  }

  OnboardingFrontierSelection? _selectionFromCachedPreview() {
    final preview = PortfolioStateProvider.of(context).frontierPreview;
    if (preview == null || preview.points.isEmpty) {
      return null;
    }
    final previewPosition = preview.points.length <= 1
        ? 0
        : (_selectedDotT * (preview.points.length - 1))
            .round()
            .clamp(0, preview.points.length - 1);
    final point = preview.points[previewPosition];
    return OnboardingFrontierSelection(
      normalizedT: preview.points.length <= 1
          ? _selectedDotT
          : previewPosition / (preview.points.length - 1),
      selectedPointIndex: point.index,
      targetVolatility: point.volatility,
      dataSource: preview.dataSource,
      asOfDate: preview.asOfDate ?? widget.asOfDate,
      isAuthoritative: true,
      preview: preview,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _FrontierBody(
                asOfDate: widget.asOfDate,
                frontierPreviewFuture: _frontierPreviewFuture,
                onPositionChanged: (t) {
                  _selectedDotT = t;
                },
                onFrontierSelectionChanged: (selection) {
                  _frontierSelection = selection;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToReview,
                  child: const Text('다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frontier interaction body. Renders an embedded preview synchronously,
/// then hot-swaps to the live API response and any cached preview that
/// arrives via `PortfolioStateProvider`.
class _FrontierBody extends StatefulWidget {
  final DateTime? asOfDate;
  final Future<MobileFrontierPreviewResponse?> frontierPreviewFuture;
  final ValueChanged<double>? onPositionChanged;
  final ValueChanged<OnboardingFrontierSelection?>? onFrontierSelectionChanged;

  const _FrontierBody({
    this.asOfDate,
    required this.frontierPreviewFuture,
    this.onPositionChanged,
    this.onFrontierSelectionChanged,
  });

  @override
  State<_FrontierBody> createState() => _FrontierBodyState();
}

class _FrontierBodyState extends State<_FrontierBody> {
  static const double _initialDotT = 0.45;

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
  bool _previewIsAuthoritative = false;

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

  /// Returns the risk-comparison card payload. The card shares the
  /// `_StatCard` shape with 연 기대수익률, so the data is split into
  /// a static `value` (e.g. "약 30% 더 안전한") and `color` so the
  /// label "시장대비" can sit muted above it just like 연 기대수익률.
  ({String value, Color color}) get _riskComparison {
    final points = _preview.points;
    if (points.isEmpty) {
      return (
        value: '시장 평균 수준',
        color: WeRoboColors.accent,
      );
    }
    final averageVol =
        points.map((p) => p.volatility).reduce((a, b) => a + b) / points.length;
    final selected = _selectedPreviewPoint;
    if (selected == null || averageVol == 0) {
      return (
        value: '시장 평균 수준',
        color: WeRoboColors.accent,
      );
    }
    final diff = (selected.volatility - averageVol) / averageVol;
    final percentDiff = (diff.abs() * 100).round();
    final isRiskier = diff > 0;
    if (percentDiff == 0) {
      return (
        value: '시장 평균 수준',
        color: WeRoboColors.accent,
      );
    }
    // Smooth green→orange transition based on risk factor.
    final lerpT = isRiskier ? (diff.abs() * 2).clamp(0.0, 1.0) : 0.0;
    final color = Color.lerp(
      const Color(0xFF059669),
      const Color(0xFFF97316),
      lerpT,
    )!;
    final value = '약 $percentDiff% ${isRiskier ? '더 위험한' : '더 안전한'}';
    return (value: value, color: color);
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
    widget.onFrontierSelectionChanged?.call(
      _selectionForPreviewPosition(rec),
    );
    _bindFrontierPreviewFuture();
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

  Future<void> _bindFrontierPreviewFuture() async {
    final preview = await widget.frontierPreviewFuture;
    if (!mounted) {
      return;
    }
    if (preview == null || preview.points.isEmpty) {
      if (_previewIsAuthoritative) {
        return;
      }
      // Keep the embedded preview — it's better than showing nothing.
      setState(() {
        _previewLoading = false;
        _previewUnavailable = true;
      });
      return;
    }
    _applyPreview(preview);
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
      _previewIsAuthoritative = true;
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
    widget.onFrontierSelectionChanged?.call(
      _selectionForPreviewPosition(recommendedPosition),
    );
  }

  void _handlePreviewPositionChanged(int previewPosition) {
    final selection = _selectionForPreviewPosition(previewPosition);
    if (selection == null) {
      return;
    }
    setState(() {
      _selectedPreviewPosition = _preview.positionForPointIndex(
        selection.selectedPointIndex,
      );
      _dotT = selection.normalizedT;
    });
    widget.onPositionChanged?.call(selection.normalizedT);
    widget.onFrontierSelectionChanged?.call(selection);
  }

  OnboardingFrontierSelection? _selectionForPreviewPosition(
      int previewPosition) {
    if (_preview.points.isEmpty ||
        previewPosition < 0 ||
        previewPosition >= _preview.points.length) {
      return null;
    }
    final point = _preview.points[previewPosition];
    final normalizedT = _preview.points.length <= 1
        ? _initialDotT
        : previewPosition / (_preview.points.length - 1);
    return OnboardingFrontierSelection(
      normalizedT: normalizedT,
      selectedPointIndex: point.index,
      targetVolatility: point.volatility,
      dataSource: _preview.dataSource,
      asOfDate: _preview.asOfDate ?? widget.asOfDate,
      isAuthoritative: _previewIsAuthoritative,
      preview: _preview,
    );
  }

  OnboardingFrontierSelection? _selectionForNormalizedT(double normalizedT) {
    if (_preview.points.isEmpty) {
      return null;
    }
    final previewPosition = _preview.points.length <= 1
        ? 0
        : (normalizedT * (_preview.points.length - 1))
            .round()
            .clamp(0, _preview.points.length - 1);
    return _selectionForPreviewPosition(previewPosition);
  }

  /// Builds the 7 `AssetWeight` rows the bar consumes, sourced from the
  /// frontier sample point closest to [t]. Returns an empty list when no
  /// preview data is loaded yet (the bar collapses to a zero-height stub).
  List<AssetWeight> _assetsAtT(double t) {
    final selection = _selectionForNormalizedT(t);
    if (selection == null) return const [];
    return buildAssetWeightRows(selection.weightsAt(t));
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            '나에게 맞는 투자 찾기',
            style: WeRoboTypography.heading2.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '이 곡선은 같은 위험도에서 가장 높은\n'
            '수익을 내는 조합을 보여줍니다',
            style: WeRoboTypography.bodySmall.themed(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Return + risk display — both cards share `_StatCard` so the
          // shape, padding, border, and label/value hierarchy match.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: _StatCard(
                    label: '시장대비',
                    value: _riskComparison.value,
                    color: _riskComparison.color,
                    valueStyle: WeRoboTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Chart fills all leftover vertical space — no fixed aspect
          // ratio, no scrolling, just maximizes height inside the column.
          Expanded(
            child: EfficientFrontierChart(
              previewPoints: _preview.points,
              selectedPreviewPosition: _selectedPreviewPosition,
              onPreviewPointChanged: _handlePreviewPositionChanged,
              onPositionChanged: (t) {
                // Drag updates _dotT → setState → AssetWeightBar re-renders.
                // Each segment's flex ratio animates smoothly via
                // AnimatedContainer.
                final selection = _selectionForNormalizedT(t);
                setState(() {
                  _dotT = selection?.normalizedT ?? t;
                  _selectedPreviewPosition = selection == null
                      ? null
                      : _preview
                          .positionForPointIndex(selection.selectedPointIndex);
                });
                widget.onPositionChanged?.call(selection?.normalizedT ?? t);
                widget.onFrontierSelectionChanged?.call(selection);
              },
            ),
          ),
          const SizedBox(height: 12),
          AssetWeightBar(assets: _assetsAtT(_dotT)),
          if (_previewLoading || _previewUnavailable) ...[
            const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  /// Optional override for the value's text style. Defaults to the
  /// large Numbers style used by 연 기대수익률; the 시장대비 card
  /// passes a bodySmall style because its value is multi-word Korean
  /// rather than a single number.
  final TextStyle? valueStyle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final resolvedValueStyle =
        (valueStyle ?? WeRoboTypography.number).copyWith(color: color);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style:
                  WeRoboTypography.caption.copyWith(color: tc.textSecondary)),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: resolvedValueStyle,
            textAlign: TextAlign.center,
            child: Text(value, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
