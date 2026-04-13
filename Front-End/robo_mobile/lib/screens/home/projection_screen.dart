import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/projection_data.dart';
import '../../services/monte_carlo_engine.dart';
import 'widgets/fan_chart_painter.dart';

class ProjectionScreen extends StatefulWidget {
  const ProjectionScreen({super.key});

  @override
  State<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends State<ProjectionScreen>
    with SingleTickerProviderStateMixin {
  static const _ageKey = 'werobo.user_age';
  static const _defaultAge = 25.0;
  static const _projectionYears = 30;
  static const _debounceMs = 200;

  // Ruler slider stops (in Won). Each step = 10만원.
  static const _rulerMax = 30000000.0; // ₩3,000만
  static const _rulerSteps = 30; // 30 steps × 10만 = 3,000만

  late AnimationController _animCtrl;
  Timer? _debounce;
  ProjectionResult? _result;
  bool _ageSet = false;
  double _currentAge = _defaultAge;

  // Deposit controls
  bool _isMonthly = false; // false = one-time, true = monthly
  double _depositAmount = 0;
  int? _touchIndex;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadAge();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ageSet) _runProjection();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_ageKey);
      if (stored != null && mounted) {
        setState(() {
          _currentAge = stored.toDouble();
          _ageSet = true;
        });
        _runProjection();
      }
    } catch (_) {}
  }

  Future<void> _saveAge(int age) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_ageKey, age);
    } catch (_) {}
  }

  void _onAgeEntered(double age) {
    setState(() {
      _currentAge = age;
      _ageSet = true;
    });
    _saveAge(age.round());
    _scheduleProjection();
  }

  void _scheduleProjection() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      _runProjection,
    );
  }

  Future<void> _runProjection() async {
    final portfolio =
        PortfolioStateProvider.of(context).selectedPortfolio;
    if (portfolio == null) return;

    final params = ProjectionParams(
      mu: portfolio.expectedReturn,
      sigma: portfolio.volatility,
      currentValue: _currentPortfolioValue,
      currentAge: _currentAge,
      targetAge: _currentAge + _projectionYears,
      monthlyContrib: _isMonthly ? _depositAmount : 0,
      oneTimeDeposit: _isMonthly ? 0 : _depositAmount,
    );

    try {
      final result = await MonteCarloEngine.run(params);
      if (mounted) {
        setState(() => _result = result);
        _animCtrl.forward(from: 0);
      }
    } catch (_) {}
  }

  double get _currentPortfolioValue {
    final state = PortfolioStateProvider.of(context);
    final summary = state.accountSummary;
    if (summary != null) return summary.currentValue;
    return 10000000;
  }

  void _showDepositFrequencySheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '입금 방식',
                style: WeRoboTypography.heading3.copyWith(
                  color: isDark ? Colors.white : WeRoboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _FrequencyOption(
                label: '일시 입금',
                selected: !_isMonthly,
                isDark: isDark,
                onTap: () {
                  setState(() => _isMonthly = false);
                  Navigator.pop(context);
                  _scheduleProjection();
                },
              ),
              const Divider(height: 1),
              _FrequencyOption(
                label: '월 적립',
                selected: _isMonthly,
                isDark: isDark,
                onTap: () {
                  setState(() => _isMonthly = true);
                  Navigator.pop(context);
                  _scheduleProjection();
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? Colors.white : WeRoboColors.textPrimary,
                    foregroundColor:
                        isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          WeRoboColors.radiusL),
                    ),
                  ),
                  child: Text(
                    '닫기',
                    style: WeRoboTypography.button.copyWith(
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : WeRoboColors.textPrimary;
    final portfolio =
        PortfolioStateProvider.of(context).selectedPortfolio;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: textColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '미래 예측',
          style: WeRoboTypography.heading2.copyWith(color: textColor),
        ),
        centerTitle: false,
      ),
      body: portfolio == null
          ? _buildNoPortfolio(textColor)
          : _ageSet
              ? _buildProjection(isDark, textColor)
              : _buildAgePicker(isDark, textColor),
    );
  }

  Widget _buildNoPortfolio(Color textColor) {
    return Center(
      child: Padding(
        padding: WeRoboSpacing.screenH,
        child: Text(
          '포트폴리오를 먼저 선택해주세요',
          style: WeRoboTypography.body.copyWith(
            color: WeRoboColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAgePicker(bool isDark, Color textColor) {
    return Padding(
      padding: WeRoboSpacing.screenH,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '나이를 입력해주세요',
            style: WeRoboTypography.heading2.copyWith(color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '미래 예측을 위해 현재 나이가 필요합니다',
            style: WeRoboTypography.body.copyWith(
              color: WeRoboColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 120,
            child: TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: WeRoboFonts.number,
                fontSize: 36,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: '25',
                hintStyle: TextStyle(
                  fontFamily: WeRoboFonts.number,
                  fontSize: 36,
                  color: WeRoboColors.textTertiary,
                ),
                suffixText: '세',
                suffixStyle: TextStyle(color: textColor),
                border: const UnderlineInputBorder(),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: WeRoboColors.primary,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (val) {
                final age = int.tryParse(val) ?? 25;
                _onAgeEntered(age.clamp(18, 100).toDouble());
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _onAgeEntered(_defaultAge),
              style: ElevatedButton.styleFrom(
                backgroundColor: WeRoboColors.primary,
                foregroundColor: WeRoboColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(WeRoboColors.radiusL),
                ),
              ),
              child: Text(
                '시작하기',
                style: WeRoboTypography.button
                    .copyWith(color: WeRoboColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjection(bool isDark, Color textColor) {
    final result = _result;
    final medianValue = result?.medianFinal ?? _currentPortfolioValue;
    final secondaryColor =
        isDark ? const Color(0xFF8E8E8E) : WeRoboColors.textSecondary;

    return Column(
      children: [
        // Scrollable top section
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero projected value
                Text(
                  _formatWonDisplay(medianValue),
                  style: TextStyle(
                    fontFamily: WeRoboFonts.number,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_projectionYears년 후 예상 포트폴리오 가치',
                  style: TextStyle(
                    fontFamily: WeRoboFonts.caption,
                    fontSize: 12,
                    color: secondaryColor,
                  ),
                ),

                const SizedBox(height: 20),

                // Fan chart
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFF5F5F5),
                    borderRadius:
                        BorderRadius.circular(WeRoboColors.radiusXL),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: result != null
                      ? GestureDetector(
                          onPanUpdate: (d) =>
                              _onChartPan(d, result),
                          onPanEnd: (_) =>
                              setState(() => _touchIndex = null),
                          child: AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (_, __) => CustomPaint(
                              size: const Size(double.infinity, 250),
                              painter: FanChartPainter(
                                data: result,
                                progress: _animCtrl.value,
                                touchIndex: _touchIndex,
                                gridColor: isDark
                                    ? Colors.white
                                    : Colors.black,
                                textColor: secondaryColor,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: WeRoboColors.primary,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

        // Bottom deposit controls (fixed)
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle label
              GestureDetector(
                onTap: _showDepositFrequencySheet,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isMonthly ? '월 적립금 ' : '일시 입금 ',
                      style: TextStyle(
                        fontFamily: WeRoboFonts.body,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    Text(
                      '시뮬레이션',
                      style: TextStyle(
                        fontFamily: WeRoboFonts.body,
                        fontSize: 14,
                        color: secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: secondaryColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Ruler slider
              _RulerSlider(
                value: _depositAmount,
                max: _rulerMax,
                steps: _rulerSteps,
                isDark: isDark,
                onChanged: (v) {
                  setState(() => _depositAmount = v);
                  _scheduleProjection();
                },
              ),

              const SizedBox(height: 20),

              // CTA button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white
                            : WeRoboColors.textPrimary,
                        foregroundColor:
                            isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              WeRoboColors.radiusFull),
                        ),
                      ),
                      child: Text(
                        '투자금 추가하기',
                        style: WeRoboTypography.button.copyWith(
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onChartPan(DragUpdateDetails d, ProjectionResult result) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final chartWidth = box.size.width - 24 * 2 - 48 - 16;
    final localX = d.localPosition.dx - 24 - 48;
    final frac = (localX / chartWidth).clamp(0.0, 1.0);
    final idx = (frac * (result.length - 1)).round();
    setState(() => _touchIndex = idx);
  }

  static String _formatWonDisplay(double value) {
    if (value.isNaN || value.isInfinite) return '₩0';
    final abs = value.abs();
    if (abs >= 1e8) {
      final eok = value / 1e8;
      return '₩${eok.toStringAsFixed(1)}억';
    }
    if (abs >= 1e4) {
      final man = (value / 1e4).round();
      return '₩${_addCommas(man)}만';
    }
    return '₩${_addCommas(value.round())}';
  }

  static String _addCommas(num value) {
    final s = value.abs().toString();
    final buf = StringBuffer();
    final sign = value < 0 ? '-' : '';
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign$buf';
  }
}

// ─── Bottom sheet frequency option ─────────────────────────────

class _FrequencyOption extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FrequencyOption({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : WeRoboColors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: WeRoboTypography.body.copyWith(color: textColor),
      ),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? WeRoboColors.primary : WeRoboColors.lightGray,
            width: 2,
          ),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: WeRoboColors.primary,
                  ),
                ),
              )
            : null,
      ),
      onTap: onTap,
    );
  }
}

// ─── Ruler-style slider with tick marks and floating label ──────

class _RulerSlider extends StatefulWidget {
  final double value;
  final double max;
  final int steps;
  final bool isDark;
  final ValueChanged<double> onChanged;

  const _RulerSlider({
    required this.value,
    required this.max,
    required this.steps,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_RulerSlider> createState() => _RulerSliderState();
}

class _RulerSliderState extends State<_RulerSlider> {
  late ScrollController _scrollCtrl;
  // Each step = 10만원. itemWidth controls scroll density.
  static const _itemWidth = 40.0;
  static const _majorEvery = 5; // major tick every 5 steps = 50만

  @override
  void initState() {
    super.initState();
    final initialOffset =
        (widget.value / widget.max * widget.steps) * _itemWidth;
    _scrollCtrl = ScrollController(initialScrollOffset: initialOffset);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset.clamp(0.0, _maxOffset);
    final frac = offset / _maxOffset;
    final newValue = frac * widget.max;
    // Round to nearest 10만원 (1,000,000)
    final rounded = (newValue / 1000000).round() * 1000000.0;
    widget.onChanged(rounded.clamp(0, widget.max));
  }

  double get _maxOffset => widget.steps * _itemWidth;

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isDark ? Colors.white : WeRoboColors.textPrimary;
    final tickColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black.withValues(alpha: 0.4);
    final labelBg =
        widget.isDark ? Colors.white : WeRoboColors.textPrimary;
    final labelText =
        widget.isDark ? Colors.black : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Floating value label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _formatRulerValue(widget.value),
            style: TextStyle(
              fontFamily: WeRoboFonts.number,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: labelText,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Ruler with tick marks
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(context).size.width / 2 - 24,
                ),
                itemCount: widget.steps + 1,
                itemBuilder: (_, i) {
                  final isMajor = i % _majorEvery == 0;
                  final tickH = isMajor ? 24.0 : 12.0;
                  final tickW = isMajor ? 1.5 : 0.8;
                  return SizedBox(
                    width: _itemWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: tickW,
                          height: tickH,
                          color: tickColor,
                        ),
                        if (isMajor) ...[
                          const SizedBox(height: 2),
                          Text(
                            _majorLabel(i),
                            style: TextStyle(
                              fontFamily: WeRoboFonts.number,
                              fontSize: 9,
                              color: tickColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // Center indicator line
              IgnorePointer(
                child: Container(
                  width: 2,
                  height: 28,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _majorLabel(int stepIndex) {
    // Each step = 10만. Major every 5 steps = 50만, 100만, etc.
    final man = stepIndex * 10; // in 만원 units
    if (man == 0) return '0';
    if (man >= 10000) return '${man ~/ 10000}억';
    return '$man만';
  }

  static String _formatRulerValue(double value) {
    if (value <= 0) return '₩0';
    if (value >= 1e8) {
      return '₩${(value / 1e8).toStringAsFixed(1)}억';
    }
    if (value >= 1e4) {
      final man = (value / 1e4).round();
      return '₩$man만';
    }
    return '₩${value.round()}';
  }
}
