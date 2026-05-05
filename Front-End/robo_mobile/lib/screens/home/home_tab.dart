import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mobile_backend_models.dart';
import '../../models/mock_earnings_data.dart';
import '../../models/portfolio_data.dart';
import '../../models/rebalance_insight.dart';
import 'activity_hub_page.dart';
import 'digest_screen.dart';
import 'insight_detail_page.dart';
import 'portfolio_allocation_detail_page.dart';
import 'widgets/glowing_border.dart';
import 'projection_screen.dart';
import 'widgets/insight_transition_chart.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  bool _showAllocationAmounts = false;

  @override
  void initState() {
    super.initState();
    logPageEnter('HomeTab');
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    logPageExit('HomeTab');
    _staggerCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fadeAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: WeRoboMotion.enter),
    );
  }

  Animation<Offset> _slideAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: WeRoboMotion.enter),
      ),
    );
  }

  Widget _stagger(int index, Widget child) {
    return SlideTransition(
      position: _slideAt(index),
      child: FadeTransition(opacity: _fadeAt(index), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final state = PortfolioStateProvider.of(context);
    final type = state.type;
    final activities = state.accountActivities;
    final accountSummary = state.accountSummary;
    final allocationDetails = state.categoryDetails;
    final hasResolvedPortfolio =
        state.selectedPortfolio != null || state.accountSummary != null;
    final hasInsightBanner = state.unreadInsightCount > 0;
    final hasDigestBanner =
        state.isWeeklyDigestAvailable && !state.hasSeenCurrentDigest;
    int staggerIdx = 0;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Notification icon (persistent access)
            Align(
              alignment: Alignment.centerRight,
              child: _NotificationIconButton(
                hasUnread: state.unreadInsightCount > 0,
              ),
            ),
            const SizedBox(height: 8),

            // Welcome banner (first visit only)
            if (!state.welcomeBannerSeen)
              _stagger(
                staggerIdx,
                _WelcomeBanner(
                  type: type,
                  onDismiss: () => state.markWelcomeBannerSeen(),
                ),
              )
            else
              const SizedBox.shrink(),
            if (!state.welcomeBannerSeen)
              const SizedBox(height: 16)
            else
              const SizedBox.shrink(),

            // Hero: value + chart + time range
            _stagger(
              !state.welcomeBannerSeen ? ++staggerIdx : staggerIdx,
              _PortfolioHeroChart(type: type),
            ),
            const SizedBox(height: 28),

            // Insight banner (after rebalancing) — below chart
            if (hasInsightBanner)
              Divider(color: tc.border.withValues(alpha: 0.3), height: 1),
            if (hasInsightBanner) const SizedBox(height: 16),
            if (hasInsightBanner)
              _stagger(
                ++staggerIdx,
                _InsightBanner(
                  latestInsight: state.unreadInsights.first,
                  unreadCount: state.unreadInsightCount,
                ),
              ),
            if (hasInsightBanner) const SizedBox(height: 20),

            // Digest entry point (hidden after user has seen it)
            if (hasDigestBanner)
              _stagger(
                ++staggerIdx,
                _DigestBanner(
                  onTap: () => Navigator.push(
                    context,
                    WeRoboMotion.fadeRoute<void>(const DigestScreen()),
                  ),
                ),
              ),
            if (hasDigestBanner) const SizedBox(height: 20),

            _stagger(
              ++staggerIdx,
              _DepositsPanel(
                activities: activities,
                accountSummary: accountSummary,
              ),
            ),
            const SizedBox(height: 20),
            Divider(
              color: WeRoboThemeColors.of(
                context,
              ).border.withValues(alpha: 0.15),
              height: 1,
              thickness: 0.5,
            ),
            const SizedBox(height: 20),
            _stagger(
              ++staggerIdx,
              _PortfolioAllocationPanel(
                details: allocationDetails,
                baseValue: _portfolioAllocationBaseValue(accountSummary),
                showAmounts: _showAllocationAmounts,
                hasResolvedPortfolio: hasResolvedPortfolio,
                onValueModeChanged: (showAmounts) {
                  setState(() => _showAllocationAmounts = showAmounts);
                },
              ),
            ),
            if (accountSummary != null) const SizedBox(height: 20),
            if (accountSummary != null)
              _stagger(
                ++staggerIdx,
                _ReserveCashPanel(
                  reserveCashAmount: accountSummary.cashBalance,
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Hero chart: value + chart + time range ─────────

class _PortfolioHeroChart extends StatefulWidget {
  final InvestmentType type;
  const _PortfolioHeroChart({required this.type});

  @override
  State<_PortfolioHeroChart> createState() => _PortfolioHeroChartState();
}

class _PortfolioHeroChartState extends State<_PortfolioHeroChart>
    with TickerProviderStateMixin {
  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체', '미래'];
  static const _rangeDays = [7, 90, 365, 1825, 99999, -1];
  static const _baseInvestment = 10000000.0;

  late AnimationController _drawCtrl;
  late CurvedAnimation _drawCurve;
  late AnimationController _glowCtrl;
  int _range = 4; // 전체
  int? _touchIndex;

  List<ChartPoint> get _allValue {
    final accountHistory = PortfolioStateProvider.of(context).accountHistory;
    if (accountHistory.isNotEmpty) {
      return _ensureRenderable([
        for (final point in accountHistory)
          ChartPoint(date: point.date, value: point.portfolioValue),
      ]);
    }
    final backtest = PortfolioStateProvider.of(
      context,
    ).portfolioValuePoints(baseInvestment: _baseInvestment);
    if (backtest.isNotEmpty) return backtest;
    final riskCode = PortfolioStateProvider.of(context).type.riskCode;
    return MockEarningsData.dailyCumulativePoints(
      riskCode: riskCode,
      baseInvestment: _baseInvestment,
    );
  }

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _drawCurve = CurvedAnimation(parent: _drawCtrl, curve: Curves.linear);
    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _PortfolioHeroChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _touchIndex = null;
      _drawCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _drawCurve.dispose();
    _drawCtrl.dispose();
    super.dispose();
  }

  List<ChartPoint> _filterByRange(List<ChartPoint> all) {
    if (all.isEmpty) return all;
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    final filtered = all.where((p) => p.date.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  List<ChartPoint> _ensureRenderable(List<ChartPoint> points) {
    if (points.length != 1) {
      return points;
    }
    final point = points.first;
    return [
      ChartPoint(
        date: point.date.subtract(const Duration(days: 1)),
        value: point.value,
      ),
      point,
    ];
  }

  /// Rebase a KRW-valued `ChartPoint` series to percent return from the
  /// first point. The output's `value` field carries fractional return
  /// (`0.0` = 0%, `0.05` = +5%). First point is always exactly `0.0`.
  List<ChartPoint> _pctSeries(List<ChartPoint> krw) {
    if (krw.isEmpty) return const [];
    final base = krw.first.value;
    if (base == 0) return const [];
    return [
      for (final p in krw)
        ChartPoint(date: p.date, value: (p.value - base) / base),
    ];
  }

  /// Market benchmark line (`benchmark_avg`), filtered to the visible
  /// range, rebased to 0% at the first visible point. Returns an empty
  /// list when the comparison backtest hasn't loaded yet.
  List<ChartPoint> _marketSeries(List<ChartPoint> portfolioRangePts) {
    if (portfolioRangePts.isEmpty) return const [];
    final all = PortfolioStateProvider.of(context).comparisonLines;
    final market = all.firstWhere(
      (l) => l.key == 'benchmark_avg',
      orElse: () => const ChartLine(
        key: '',
        label: '',
        color: Colors.transparent,
        points: [],
      ),
    );
    if (market.points.length < 2) return const [];

    final cutoff = portfolioRangePts.first.date;
    final filtered =
        market.points.where((p) => !p.date.isBefore(cutoff)).toList();
    if (filtered.length < 2) return const [];

    final base = filtered.first.value;
    return [
      for (final p in filtered)
        ChartPoint(date: p.date, value: p.value - base),
    ];
  }

  void _selectRange(int idx) {
    // "미래" tab navigates to ProjectionScreen
    if (idx == _rangeLabels.length - 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProjectionScreen()),
      );
      return;
    }
    if (idx == _range) return;
    setState(() {
      _range = idx;
      _touchIndex = null;
    });
    _drawCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final portfolioState = PortfolioStateProvider.of(context);
    final accountSummary = portfolioState.accountSummary;
    final allValue = _allValue;
    final valuePts = _filterByRange(allValue);

    // Compute hero stats from filtered data
    final currentValue =
        accountSummary?.currentValue ??
        (valuePts.isNotEmpty ? valuePts.last.value : 0.0);
    final startValue = valuePts.isNotEmpty ? valuePts.first.value : 0.0;
    final change = accountSummary?.profitLoss ?? (currentValue - startValue);
    final changePct = accountSummary != null
        ? accountSummary.profitLossPct * 100
        : (startValue > 0 ? (change / startValue) * 100 : 0.0);
    // Compute drag-aware values from touch position
    double? crosshairValue;
    if (_touchIndex != null && _touchIndex! < valuePts.length) {
      crosshairValue = valuePts[_touchIndex!].value;
    }

    // Without a cost-basis line, drag-time deltas are computed against the
    // chart's first visible point (start of the selected range).
    final displayChange = crosshairValue != null
        ? crosshairValue - startValue
        : change;
    final displayChangePct = crosshairValue != null && startValue > 0
        ? ((crosshairValue - startValue) / startValue) * 100
        : changePct;
    final displayIsPositive = displayChange >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          '현재 자산',
          style: WeRoboTypography.caption.copyWith(
            color: tc.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),

        // Value (animated count-up, updates on drag)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: currentValue),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            final v = crosshairValue ?? val;
            return Text(
              '₩${_formatCurrency(v.toInt())}',
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Performance badge (always visible, values update on drag)
        _PerformanceBadge(
          changePct: displayChangePct,
          changeAmount: displayChange,
          isPositive: displayIsPositive,
          rangeLabel: _rangeLabels[_range],
        ),

        const SizedBox(height: 20),

        // Chart (edge-to-edge)
        LayoutBuilder(
          builder: (context, constraints) {
            final fullWidth = constraints.maxWidth + 48;
            // Date label for drag position
            final dateLabel =
                _touchIndex != null && _touchIndex! < valuePts.length
                ? () {
                    final d = valuePts[_touchIndex!].date;
                    return '${d.year}년 ${d.month}월 ${d.day}일';
                  }()
                : '';
            return SizedBox(
              height: 320,
              child: OverflowBox(
                maxWidth: fullWidth,
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-24, 0),
                  child: GestureDetector(
                    onPanDown: (d) {
                      final x = d.localPosition.dx;
                      final idx = ((x / fullWidth) * (valuePts.length - 1))
                          .round()
                          .clamp(0, valuePts.length - 1);
                      _glowCtrl.repeat(reverse: true);
                      setState(() => _touchIndex = idx);
                    },
                    onPanUpdate: (d) {
                      final x = d.localPosition.dx;
                      final idx = ((x / fullWidth) * (valuePts.length - 1))
                          .round()
                          .clamp(0, valuePts.length - 1);
                      setState(() => _touchIndex = idx);
                    },
                    onPanEnd: (_) {
                      _glowCtrl.stop();
                      _glowCtrl.value = 0;
                      setState(() => _touchIndex = null);
                    },
                    onPanCancel: () {
                      _glowCtrl.stop();
                      _glowCtrl.value = 0;
                      setState(() => _touchIndex = null);
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_drawCurve, _glowCtrl]),
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(fullWidth, 320),
                          painter: _HomePerformancePainter(
                            lines: [
                              ChartLine(
                                key: 'portfolio',
                                label: '포트폴리오',
                                color: WeRoboColors.primary,
                                points: _pctSeries(valuePts),
                              ),
                              if (_marketSeries(valuePts).isNotEmpty)
                                ChartLine(
                                  key: 'market',
                                  label: '시장',
                                  color: tc.textSecondary,
                                  points: _marketSeries(valuePts),
                                ),
                            ],
                            progress: _drawCurve.value,
                            touchIndex: _touchIndex,
                            glowPhase: _glowCtrl.value,
                            dateLabel: dateLabel,
                            glowColor: WeRoboColors.assetTier3,
                            gridColor: tc.border,
                            crosshairColor: tc.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Time range chips. Rev K (2026-05-04): the previous styling used
        // white-with-45%-alpha on the warm-gray app background, making
        // inactive chips invisible. Switched to theme-aware
        // tc.textSecondary so every chip reads against the background.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_rangeLabels.length, (i) {
            final active = i == _range;
            final isFuture = i == _rangeLabels.length - 1;

            final chip = GestureDetector(
              onTap: () => _selectRange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active && !isFuture
                      ? WeRoboColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _rangeLabels[i],
                  style: TextStyle(
                    fontFamily: WeRoboFonts.body,
                    fontSize: 12,
                    fontWeight: (isFuture || active)
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isFuture
                        ? WeRoboColors.primary
                        : active
                        ? WeRoboColors.white
                        : tc.textSecondary,
                  ),
                ),
              ),
            );

            final child = isFuture
                ? GlowingBorder(borderRadius: 8, shrinkWrap: true, child: chip)
                : chip;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: child,
            );
          }),
        ),
        const SizedBox(height: 12),
        _ChartLegend(
          entries: [
            (
              label: '포트폴리오',
              color: WeRoboColors.primary,
              dashed: false,
            ),
            (
              label: '시장',
              color: tc.textSecondary,
              dashed: false,
            ),
            (
              label: '연 기대수익률',
              color: WeRoboColors.primary.withValues(alpha: 0.5),
              dashed: true,
            ),
            (
              label: '채권',
              color: tc.textTertiary.withValues(alpha: 0.7),
              dashed: true,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Performance badge ────────────────────────────────────────

class _PerformanceBadge extends StatelessWidget {
  final double changePct;
  final double changeAmount;
  final bool isPositive;
  final String rangeLabel;

  const _PerformanceBadge({
    required this.changePct,
    required this.changeAmount,
    required this.isPositive,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final color = isPositive ? tc.accent : WeRoboColors.error;
    final arrow = isPositive ? '▲' : '▼';

    return Text(
      '$arrow ₩${_formatCurrency(changeAmount.abs().toInt())} (${changePct.abs().toStringAsFixed(1)}%) $rangeLabel',
      style: TextStyle(
        fontFamily: WeRoboFonts.english,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

// ─── Multi-line % return chart painter ───────────────────────

class _HomePerformancePainter extends CustomPainter {
  /// Lines to draw. The portfolio line (index 0) is drawn last and sits
  /// on top of every benchmark. Benchmarks at higher indices are drawn
  /// earlier and therefore sit below benchmarks at lower indices.
  final List<ChartLine> lines;
  final double progress;
  final int? touchIndex;
  final double glowPhase;
  final String dateLabel;
  final Color glowColor;
  final Color gridColor;
  final Color crosshairColor;

  _HomePerformancePainter({
    required this.lines,
    required this.progress,
    this.touchIndex,
    this.glowPhase = 0,
    required this.dateLabel,
    required this.glowColor,
    required this.gridColor,
    required this.crosshairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty || lines.first.points.length < 2) return;

    final w = size.width;
    final h = size.height;
    final isDragging = touchIndex != null;
    const lineTopPad = 16.0;
    const graphTopPad = 36.0;
    const graphBotPad = 50.0;
    final chartH = h - graphTopPad - graphBotPad;

    // Y-range across all lines (% space — symmetric padding).
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final p in line.points) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
    }
    if (minY == double.infinity) return;
    final range = (maxY - minY).clamp(0.0001, double.infinity);
    minY -= range * 0.05;
    maxY += range * 0.05;
    final rangeY = maxY - minY;

    final basePts = lines.first.points;
    double toX(int i, int total) => w * i / (total - 1);
    double toY(double val) =>
        graphTopPad + chartH - ((val - minY) / rangeY) * chartH;

    // Grid lines — dimmed to 0.08 (was 0.15) so the chart reads
    // "no Y axis" while keeping spatial reference.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = graphTopPad + chartH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final fIdx = (basePts.length - 1) * progress.clamp(0.0, 1.0);
    final complete = fIdx.floor();
    final frac = fIdx - complete;
    final drawCount = (complete + 1).clamp(2, basePts.length);
    final ti = isDragging
        ? touchIndex!.clamp(0, basePts.length - 1)
        : drawCount - 1;

    // Draw benchmarks first (behind portfolio).
    for (var lineIdx = lines.length - 1; lineIdx >= 1; lineIdx--) {
      _drawBenchmarkLine(
        canvas,
        lines[lineIdx],
        basePts.length,
        toX,
        toY,
        drawCount,
      );
    }

    // Portfolio line on top with the existing polish.
    _drawPortfolioLine(
      canvas,
      lines.first.points,
      lines.first.color,
      basePts.length,
      drawCount,
      complete,
      frac,
      ti,
      isDragging,
      toX,
      toY,
    );

    // Crosshair + glow + date label (only when dragging).
    if (isDragging) {
      _drawCrosshair(
        canvas,
        size,
        ti,
        basePts.length,
        toX,
        toY,
        lines.first.points,
        drawCount,
        lineTopPad,
      );
    }
  }

  void _drawBenchmarkLine(
    Canvas canvas,
    ChartLine line,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    int drawCount,
  ) {
    final pts = line.points;
    if (pts.length < 2) return;
    final count = math.min(drawCount, pts.length);
    final path = Path();
    for (var i = 0; i < count; i++) {
      final x = toX(i, totalPts);
      final y = toY(pts[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = line.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (line.dashed) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawPortfolioLine(
    Canvas canvas,
    List<ChartPoint> pts,
    Color color,
    int totalPts,
    int drawCount,
    int complete,
    double frac,
    int ti,
    bool isDragging,
    double Function(int, int) toX,
    double Function(double) toY,
  ) {
    if (isDragging) {
      const transitionLen = 20;
      final transStart = math.max(0, ti - transitionLen);
      final mainEnd = math.min(transStart + 1, drawCount);
      final mainPath = Path();
      for (int i = 0; i < mainEnd; i++) {
        final x = toX(i, totalPts);
        final y = toY(pts[i].value);
        if (i == 0) {
          mainPath.moveTo(x, y);
        } else {
          mainPath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        mainPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (transStart < ti) {
        final transPath = Path();
        transPath.moveTo(
          toX(transStart, totalPts),
          toY(pts[transStart].value),
        );
        for (int i = transStart + 1; i <= ti && i < drawCount; i++) {
          transPath.lineTo(toX(i, totalPts), toY(pts[i].value));
        }
        final shader = ui.Gradient.linear(
          Offset(toX(transStart, totalPts), 0),
          Offset(toX(ti, totalPts), 0),
          [color, glowColor],
        );
        canvas.drawPath(
          transPath,
          Paint()
            ..shader = shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      if (ti < drawCount - 1) {
        _drawFadingSegment(canvas, pts, ti, drawCount, totalPts, toX, toY,
            color, 2);
      }
    } else {
      final fullPath = Path();
      for (int i = 0; i <= complete; i++) {
        final x = toX(i, totalPts);
        final y = toY(pts[i].value);
        if (i == 0) {
          fullPath.moveTo(x, y);
        } else {
          fullPath.lineTo(x, y);
        }
      }
      if (frac > 0 && complete < pts.length - 1) {
        final x0 = toX(complete, totalPts);
        final y0 = toY(pts[complete].value);
        final x1 = toX(complete + 1, totalPts);
        final y1 = toY(pts[complete + 1].value);
        fullPath.lineTo(x0 + frac * (x1 - x0), y0 + frac * (y1 - y0));
      }
      canvas.drawPath(
        fullPath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawCrosshair(
    Canvas canvas,
    Size size,
    int ti,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    List<ChartPoint> portfolioPts,
    int drawCount,
    double lineTopPad,
  ) {
    final w = size.width;
    final h = size.height;
    final tx = toX(ti, totalPts);
    final lineTop = lineTopPad;
    final lineBot = h - lineTopPad;
    final lineShader = ui.Gradient.linear(
      Offset(tx, lineTop),
      Offset(tx, lineBot),
      [
        gridColor.withValues(alpha: 0.12),
        crosshairColor.withValues(alpha: 0.55),
        crosshairColor.withValues(alpha: 0.55),
        gridColor.withValues(alpha: 0.12),
      ],
      [0.0, 0.12, 0.88, 1.0],
    );
    canvas.drawLine(
      Offset(tx, lineTop),
      Offset(tx, lineBot),
      Paint()
        ..shader = lineShader
        ..strokeWidth = 0.8,
    );

    if (dateLabel.isNotEmpty) {
      final dateTp = TextPainter(
        text: TextSpan(
          text: dateLabel,
          style: TextStyle(
            fontSize: 10,
            color: crosshairColor.withValues(alpha: 0.85),
            fontFamily: 'NotoSansKR',
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dateX =
          (tx - dateTp.width / 2).clamp(4.0, w - dateTp.width - 4);
      dateTp.paint(canvas, Offset(dateX, lineTop - dateTp.height - 2));
    }

    if (ti < drawCount && ti < portfolioPts.length) {
      final vy = toY(portfolioPts[ti].value);
      final glowRadius = 14 + 4 * glowPhase;
      final glowAlpha = 0.25 + 0.15 * glowPhase;
      canvas.drawCircle(
        Offset(tx, vy),
        glowRadius,
        Paint()
          ..color = glowColor.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(tx, vy),
        4,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(Offset(tx, vy), 3, Paint()..color = Colors.white);
    }
  }

  void _drawFadingSegment(
    Canvas canvas,
    List<ChartPoint> pts,
    int startIdx,
    int endIdx,
    int totalPts,
    double Function(int, int) toX,
    double Function(double) toY,
    Color color,
    double strokeWidth,
  ) {
    if (startIdx >= endIdx - 1) return;
    final fadeCount = math.min(3, endIdx - startIdx);
    final fadeEnd = math.min(startIdx + fadeCount, endIdx);

    final fadePath = Path();
    fadePath.moveTo(toX(startIdx, totalPts), toY(pts[startIdx].value));
    for (int i = startIdx + 1; i < fadeEnd; i++) {
      fadePath.lineTo(toX(i, totalPts), toY(pts[i].value));
    }

    final x0 = toX(startIdx, totalPts);
    final x1 = toX(fadeEnd - 1, totalPts);
    if ((x1 - x0).abs() < 1) return;

    final shader = ui.Gradient.linear(Offset(x0, 0), Offset(x1, 0), [
      color,
      color.withValues(alpha: 0),
    ]);
    canvas.drawPath(
      fadePath,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLen = 6, double gapLen = 10}) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HomePerformancePainter old) =>
      old.progress != progress ||
      old.touchIndex != touchIndex ||
      old.glowPhase != glowPhase;
  // `lines` is freshly constructed every build (new list, new ChartLine
  // instances) so reference equality is always false — we'd always
  // repaint. Range/data changes already trigger a setState that
  // unconditionally rebuilds, so omitting `lines` here is safe.
}

// ─── Chart legend ─────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final bool dashed;
  const _LegendDot({required this.color, required this.dashed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 2,
      child: CustomPaint(
        painter: _LegendDotPainter(color: color, dashed: dashed),
      ),
    );
  }
}

class _LegendDotPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  _LegendDotPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (dashed) {
      // 3-on/2-off dash pattern within the 12 px sample
      const dashLen = 3.0;
      const gapLen = 2.0;
      double x = 0;
      while (x < size.width) {
        final end = math.min(x + dashLen, size.width);
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
        x = end + gapLen;
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LegendDotPainter old) =>
      old.color != color || old.dashed != dashed;
}

class _ChartLegend extends StatelessWidget {
  final List<({String label, Color color, bool dashed})> entries;
  const _ChartLegend({required this.entries});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final e in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendDot(color: e.color, dashed: e.dashed),
              const SizedBox(width: 4),
              Text(
                e.label,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────

String _formatCurrency(int amount) {
  final str = amount.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
    buf.write(str[i]);
  }
  return buf.toString();
}

String _formatPercentLabel(double percentage) {
  return '${percentage.toStringAsFixed(2)}%';
}

String _formatWonFromRatio(double? baseValue, double percentage) {
  if (baseValue == null || baseValue <= 0) {
    return '-';
  }
  final amount = (baseValue * percentage / 100).round();
  return '₩${_formatCurrency(amount)}';
}

String _formatWonAmount(double? amount) {
  if (amount == null) {
    return '-';
  }
  return '₩${_formatCurrency(amount.round())}';
}

double? _portfolioAllocationBaseValue(MobileAccountSummary? summary) {
  if (summary == null) {
    return null;
  }
  final currentInvestedValue = summary.currentValue - summary.cashBalance;
  if (currentInvestedValue > 0) {
    return currentInvestedValue;
  }
  final investedPrincipalExcludingCash =
      summary.investedAmount - summary.cashBalance;
  if (investedPrincipalExcludingCash > 0) {
    return investedPrincipalExcludingCash;
  }
  return null;
}

DateTime? _parseIsoDate(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime _addOneMonth(DateTime date) {
  final nextMonth = date.month == 12 ? 1 : date.month + 1;
  final nextYear = date.month == 12 ? date.year + 1 : date.year;
  final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
  final nextDay = math.min(date.day, lastDayOfNextMonth);
  return DateTime(nextYear, nextMonth, nextDay);
}

String _formatKoreanMonthDay(DateTime date) {
  return '${date.month}월 ${date.day}일';
}

// ─── Welcome banner ───────────────────────────────────────────

// ─── Insight banner ──────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  final RebalanceInsight latestInsight;
  final int unreadCount;

  const _InsightBanner({
    required this.latestInsight,
    required this.unreadCount,
  });

  String _formatKoreanDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return '${date.year}년 ${date.month}월';
  }

  String _summaryText() {
    final allocs = latestInsight.allocations;
    if (allocs.isEmpty) return '포트폴리오 비중을 조정했어요.';

    // Find the allocation with the largest absolute display delta
    RebalanceInsightAllocation biggest = allocs.first;
    for (final a in allocs) {
      if (a.displayDelta.abs() > biggest.displayDelta.abs()) {
        biggest = a;
      }
    }

    if (!biggest.hasChanged) {
      return '포트폴리오 비중을 조정했어요.';
    }

    final pct = biggest.displayDelta.abs().toStringAsFixed(1);
    if (biggest.displayDelta > 0) {
      return '${biggest.displayName} 비중을 $pct% 늘렸어요.';
    }
    return '${biggest.displayName} 비중을 $pct% 줄였어요.';
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);

    return Pressable(
      onTap: () {
        Navigator.push(
          context,
          WeRoboMotion.fadeRoute<void>(
            InsightDetailPage(insight: latestInsight),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Icon
            InsightDonutThumbnail(
              allocations: latestInsight.allocations,
              size: 40,
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'New · ${_formatKoreanDate(latestInsight.rebalanceDate)}',
                        style: WeRoboTypography.caption.copyWith(
                          color: tc.textTertiary,
                        ),
                      ),
                      if (unreadCount > 1) ...[
                        Text(
                          '  ·  ',
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                        Text(
                          '+${unreadCount - 1}개 더 보기',
                          style: WeRoboTypography.caption.copyWith(
                            color: tc.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _summaryText(),
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(Icons.chevron_right_rounded, size: 18, color: tc.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Welcome banner ─────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final InvestmentType type;
  final VoidCallback onDismiss;

  const _WelcomeBanner({required this.type, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WeRoboColors.primary,
            WeRoboColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.label} 포트폴리오가 설정되었습니다!',
                  style: WeRoboTypography.bodySmall.copyWith(
                    color: WeRoboColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '투자 여정을 시작해 보세요',
                  style: WeRoboTypography.caption.copyWith(
                    color: WeRoboColors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: WeRoboColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositsPanel extends StatelessWidget {
  final List<MobileAccountActivity> activities;
  final MobileAccountSummary? accountSummary;

  const _DepositsPanel({
    required this.activities,
    required this.accountSummary,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final latestDeposit = _findLatestDeposit(activities);
    final latestAmount =
        latestDeposit?.amount ??
        ((accountSummary?.investedAmount ?? 0) > 0
            ? accountSummary?.investedAmount
            : null);
    final latestDate = _parseIsoDate(
      latestDeposit?.date ?? accountSummary?.startedAt,
    );
    const upcomingAmount = 100000.0;
    final upcomingDate = latestDate == null ? null : _addOneMonth(latestDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '입금 현황',
              style: WeRoboTypography.heading3.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: tc.textTertiary),
          ],
        ),
        const SizedBox(height: 16),
        _DepositInfoRow(
          label: '최근 입금',
          valueText: latestAmount == null
              ? '아직 입금 내역이 없어요'
              : '₩${_formatCurrency(latestAmount.round())}'
                    ' · ${_formatKoreanMonthDay(latestDate!)}',
        ),
        Divider(
          color: tc.border.withValues(alpha: 0.4),
          height: 1,
          thickness: 0.5,
        ),
        _DepositInfoRow(
          label: '예정 입금',
          valueText: upcomingDate == null
              ? '예정된 입금이 없어요'
              : '₩${_formatCurrency(upcomingAmount.round())}'
                    ' · ${_formatKoreanMonthDay(upcomingDate)}',
        ),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(
              child: _DepositActionButton(
                icon: Icons.add_rounded,
                label: '입금하기',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _DepositActionButton(
                icon: Icons.event_repeat_rounded,
                label: '정기 입금',
              ),
            ),
          ],
        ),
      ],
    );
  }

  MobileAccountActivity? _findLatestDeposit(List<MobileAccountActivity> items) {
    final deposits =
        items
            .where(
              (activity) =>
                  activity.type == 'cash_in' ||
                  activity.type == 'initial_deposit',
            )
            .toList()
          ..sort((a, b) {
            final aDate = _parseIsoDate(a.date) ?? DateTime(1970);
            final bDate = _parseIsoDate(b.date) ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });

    if (deposits.isEmpty) {
      return null;
    }
    return deposits.first;
  }
}

class _DepositInfoRow extends StatelessWidget {
  final String label;
  final String valueText;

  const _DepositInfoRow({required this.label, required this.valueText});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            valueText,
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w500,
              fontFamily: WeRoboFonts.english,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DepositActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: () {},
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.border.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: tc.textPrimary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WeRoboTypography.bodySmall.copyWith(
                  color: tc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioAllocationPanel extends StatelessWidget {
  final List<PortfolioCategoryDetail> details;
  final double? baseValue;
  final bool showAmounts;
  final bool hasResolvedPortfolio;
  final ValueChanged<bool> onValueModeChanged;

  const _PortfolioAllocationPanel({
    required this.details,
    required this.baseValue,
    required this.showAmounts,
    required this.hasResolvedPortfolio,
    required this.onValueModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '포트폴리오 구성',
              style: WeRoboTypography.heading3.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _PortfolioValueToggle(
              showAmounts: showAmounts,
              onValueModeChanged: onValueModeChanged,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (details.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              hasResolvedPortfolio
                  ? '자산군 비중 데이터가 아직 없습니다.'
                  : '포트폴리오 데이터를 불러오는 중입니다.',
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textSecondary,
              ),
            ),
          )
        else
          ...List.generate(details.length, (index) {
            final detail = details[index];
            return Column(
              children: [
                _PortfolioAllocationRow(
                  detail: detail,
                  baseValue: baseValue,
                  showAmounts: showAmounts,
                  onTap: () => _openAllocationDetailPage(context, detail),
                ),
                Divider(
                  color: tc.border.withValues(alpha: 0.4),
                  height: 1,
                  thickness: 0.5,
                ),
              ],
            );
          }),
        const SizedBox(height: 16),
        Pressable(
          onTap: () {},
          child: Text(
            '포트폴리오 조정',
            style: WeRoboTypography.bodySmall.copyWith(
              color: tc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _openAllocationDetailPage(
    BuildContext context,
    PortfolioCategoryDetail detail,
  ) {
    Navigator.push(
      context,
      WeRoboMotion.fadeRoute<void>(
        PortfolioAllocationDetailPage(
          detail: detail,
          baseValue: baseValue,
          initialShowAmounts: showAmounts,
        ),
      ),
    );
  }
}

class _ReserveCashPanel extends StatelessWidget {
  final double reserveCashAmount;

  const _ReserveCashPanel({required this.reserveCashAmount});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '예비 현금',
          style: WeRoboTypography.heading3.copyWith(
            color: tc.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '포트폴리오 구성 비중에는 포함되지 않아요.',
          style: WeRoboTypography.bodySmall.copyWith(color: tc.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '리밸런싱 시 별도로 보관됐다가 자동 사용돼요.',
          style: WeRoboTypography.caption.copyWith(color: tc.textTertiary),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '현재 보유',
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              _formatWonAmount(reserveCashAmount),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: WeRoboFonts.english,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PortfolioValueToggle extends StatelessWidget {
  final bool showAmounts;
  final ValueChanged<bool> onValueModeChanged;

  const _PortfolioValueToggle({
    required this.showAmounts,
    required this.onValueModeChanged,
  });

  static const double _chipSize = 36.0;
  static const double _padding = 3.0;

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    const totalWidth = _chipSize * 2 + _padding * 2 + 4;
    return Pressable(
      onTap: () => onValueModeChanged(!showAmounts),
      child: Container(
        width: totalWidth,
        height: _chipSize + _padding * 2,
        padding: const EdgeInsets.all(_padding),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: showAmounts
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: _chipSize,
                height: _chipSize,
                decoration: BoxDecoration(
                  color: tc.card,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: _chipSize + 2,
                  child: Center(
                    child: Text(
                      '%',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: !showAmounts ? tc.textPrimary : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: _chipSize + 2,
                  child: Center(
                    child: Text(
                      '₩',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: showAmounts ? tc.textPrimary : tc.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontFamily: WeRoboFonts.english,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioAllocationRow extends StatelessWidget {
  final PortfolioCategoryDetail detail;
  final double? baseValue;
  final bool showAmounts;
  final VoidCallback onTap;

  const _PortfolioAllocationRow({
    required this.detail,
    required this.baseValue,
    required this.showAmounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.category.name,
                    style: WeRoboTypography.bodySmall.copyWith(
                      color: tc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _buildAllocationSubtitle(detail),
                    style: WeRoboTypography.caption.copyWith(
                      color: tc.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              showAmounts
                  ? _formatWonFromRatio(baseValue, detail.category.percentage)
                  : _formatPercentLabel(detail.category.percentage),
              style: WeRoboTypography.bodySmall.copyWith(
                color: tc.textPrimary,
                fontWeight: FontWeight.w500,
                fontFamily: WeRoboFonts.english,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: tc.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }

  String _buildAllocationSubtitle(PortfolioCategoryDetail detail) {
    if (detail.tickers.isEmpty) {
      return '세부 종목 정보 없음';
    }
    final symbols = detail.tickers
        .take(3)
        .map((ticker) => ticker.symbol)
        .join(', ');
    if (detail.tickers.length <= 3) {
      return symbols;
    }
    return '$symbols 외 ${detail.tickers.length - 3}개';
  }
}

// ─── Digest banner ──────────────────────────────────────────

class _DigestBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DigestBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return GlowingBorder(
      borderRadius: WeRoboColors.radiusXL,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WeRoboColors.primary.withValues(alpha: 0.08),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: WeRoboColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주간 다이제스트',
                      style: WeRoboTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tc.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI가 분석한 이번 주 포트폴리오 리포트',
                      style: WeRoboTypography.caption.copyWith(
                        color: tc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tc.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Notification icon ──────────────────────────────────────

class _NotificationIconButton extends StatelessWidget {
  final bool hasUnread;
  const _NotificationIconButton({this.hasUnread = false});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      onTap: () => Navigator.push(
        context,
        WeRoboMotion.fadeRoute<void>(const ActivityHubPage()),
      ),
      child: Icon(
        hasUnread
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded,
        size: 24,
        color: tc.textSecondary,
      ),
    );
  }
}
