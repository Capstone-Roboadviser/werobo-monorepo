import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/pressable.dart';
import '../../app/theme.dart';
import '../../models/chart_data.dart';
import '../../models/mock_earnings_data.dart';
import '../../models/portfolio_data.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    logPageEnter('HomeTab');
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
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
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  Animation<Offset> _slideAt(int index) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    ));
  }

  Widget _stagger(int index, Widget child) {
    return SlideTransition(
      position: _slideAt(index),
      child: FadeTransition(
        opacity: _fadeAt(index),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final type = PortfolioStateProvider.of(context).type;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Welcome banner (first visit only)
            if (_showWelcome)
              _stagger(
                  0,
                  _WelcomeBanner(
                    type: type,
                    onDismiss: () => setState(() => _showWelcome = false),
                  )),
            if (_showWelcome) const SizedBox(height: 16),

            // Hero: value + chart + time range
            _stagger(
              _showWelcome ? 1 : 0,
              _PortfolioHeroChart(type: type),
            ),
            const SizedBox(height: 28),

            // Recent activity
            _stagger(
                _showWelcome ? 2 : 1,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('최근 활동',
                        style: WeRoboTypography.heading3.themed(context)),
                    const SizedBox(height: 12),
                    _ActivityCard(
                      icon: Icons.sync_alt_rounded,
                      iconColor: WeRoboColors.primary,
                      title: '리밸런싱 완료',
                      date: '2026-04-01',
                      value: '₩15,826,400',
                    ),
                    _ActivityCard(
                      icon: Icons.arrow_downward_rounded,
                      iconColor: tc.accent,
                      title: '입금',
                      date: '2026-03-15',
                      value: '+₩500,000',
                      valueColor: tc.accent,
                    ),
                    _ActivityCard(
                      icon: Icons.sync_alt_rounded,
                      iconColor: WeRoboColors.primary,
                      title: '리밸런싱 완료',
                      date: '2026-01-02',
                      value: '₩15,120,000',
                    ),
                  ],
                )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Hero chart: value + dual-line chart + time range ─────────

class _PortfolioHeroChart extends StatefulWidget {
  final InvestmentType type;
  const _PortfolioHeroChart({required this.type});

  @override
  State<_PortfolioHeroChart> createState() => _PortfolioHeroChartState();
}

class _PortfolioHeroChartState extends State<_PortfolioHeroChart>
    with SingleTickerProviderStateMixin {
  static const _rangeLabels = ['1주', '3달', '1년', '5년', '전체'];
  static const _rangeDays = [7, 90, 365, 1825, 99999];
  static const _baseInvestment = 10000000.0;

  late AnimationController _drawCtrl;
  int _range = 4; // 전체
  int? _touchIndex;

  List<ChartPoint> get _allValue {
    // Use backtest data if available, otherwise mock daily
    // cumulative returns from Mar 3 (meeting requirement).
    final backtest = PortfolioStateProvider.of(context)
        .portfolioValuePoints(baseInvestment: _baseInvestment);
    if (backtest.isNotEmpty) return backtest;
    final riskCode = PortfolioStateProvider.of(context).type.riskCode;
    return MockEarningsData.dailyCumulativePoints(
      riskCode: riskCode,
      baseInvestment: _baseInvestment,
    );
  }

  /// Flat cost basis at base investment (deposits tracked by API
  /// when available; for now base investment is the floor).
  List<ChartPoint> _costBasisFor(List<ChartPoint> valuePts) {
    if (valuePts.isEmpty) return const [];
    return [
      ChartPoint(date: valuePts.first.date, value: _baseInvestment),
      ChartPoint(date: valuePts.last.date, value: _baseInvestment),
    ];
  }

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
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
    _drawCtrl.dispose();
    super.dispose();
  }

  List<ChartPoint> _filterByRange(List<ChartPoint> all) {
    if (all.isEmpty) return all;
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_range]));
    final filtered = all.where((p) => p.date.isAfter(cutoff)).toList();
    return filtered.isNotEmpty ? filtered : all;
  }

  void _selectRange(int idx) {
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
    final allValue = _allValue;
    final valuePts = _filterByRange(allValue);
    final costPts = _costBasisFor(valuePts);

    // Compute hero stats from filtered data
    final currentValue = valuePts.isNotEmpty ? valuePts.last.value : 0.0;
    final startValue = valuePts.isNotEmpty ? valuePts.first.value : 0.0;
    final change = currentValue - startValue;
    final changePct = startValue > 0 ? (change / startValue) * 100 : 0.0;
    final isPositive = change >= 0;

    // Crosshair values
    String? crosshairDate;
    double? crosshairValue;
    double? crosshairCost;
    if (_touchIndex != null && _touchIndex! < valuePts.length) {
      final pt = valuePts[_touchIndex!];
      crosshairDate =
          '${pt.date.year}-${pt.date.month.toString().padLeft(2, '0')}-${pt.date.day.toString().padLeft(2, '0')}';
      crosshairValue = pt.value;
      if (_touchIndex! < costPts.length) {
        crosshairCost = costPts[_touchIndex!].value;
      }
    }

    final rangeLabel = _range == 4 ? '전체' : '${_rangeLabels[_range]} 대비';

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

        // Value (animated count-up or crosshair override)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: currentValue),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            final displayVal = crosshairValue ?? val;
            return Text(
              '₩${_formatCurrency(displayVal.toInt())}',
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

        // Performance badge
        if (crosshairDate != null)
          // Crosshair mode: show date + cost basis
          _CrosshairBadge(
            date: crosshairDate,
            portfolioValue: crosshairValue!,
            costBasis: crosshairCost,
          )
        else
          _PerformanceBadge(
            changePct: changePct,
            changeAmount: change,
            label: rangeLabel,
            isPositive: isPositive,
          ),

        const SizedBox(height: 20),

        // Chart
        LayoutBuilder(builder: (context, constraints) {
          return GestureDetector(
            onPanUpdate: (d) {
              const padL = 12.0;
              const padR = 12.0;
              final chartW = constraints.maxWidth - padL - padR;
              final x = d.localPosition.dx - padL;
              final idx = ((x / chartW) * (valuePts.length - 1))
                  .round()
                  .clamp(0, valuePts.length - 1);
              setState(() => _touchIndex = idx);
            },
            onPanEnd: (_) => setState(() => _touchIndex = null),
            onTapUp: (_) => setState(() => _touchIndex = null),
            child: AnimatedBuilder(
              animation: _drawCtrl,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, 240),
                  painter: _PortfolioValuePainter(
                    valuePts: valuePts,
                    costPts: costPts,
                    progress: _drawCtrl.value,
                    touchIndex: _touchIndex,
                    primaryColor: WeRoboColors.primary,
                    costColor: tc.border,
                    gridColor: tc.border,
                    textColor: tc.textTertiary,
                    tooltipBg: tc.surface,
                    tooltipBorder: tc.border,
                    textPrimaryColor: tc.textPrimary,
                  ),
                );
              },
            ),
          );
        }),

        const SizedBox(height: 16),

        // Time range chips
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_rangeLabels.length, (i) {
            final active = i == _range;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => _selectRange(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? WeRoboColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: active
                        ? null
                        : Border.all(color: tc.border, width: 0.5),
                  ),
                  child: Text(
                    _rangeLabels[i],
                    style: TextStyle(
                      fontFamily: WeRoboFonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: active ? WeRoboColors.white : tc.textTertiary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── Performance badge ────────────────────────────────────────

class _PerformanceBadge extends StatelessWidget {
  final double changePct;
  final double changeAmount;
  final String label;
  final bool isPositive;

  const _PerformanceBadge({
    required this.changePct,
    required this.changeAmount,
    required this.label,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final color = isPositive ? tc.accent : WeRoboColors.error;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$sign${changePct.toStringAsFixed(1)}%',
            style: TextStyle(
              fontFamily: WeRoboFonts.english,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(₩${_formatCurrency(changeAmount.abs().toInt())})',
            style: TextStyle(
              fontFamily: WeRoboFonts.english,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: WeRoboFonts.body,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: tc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosshairBadge extends StatelessWidget {
  final String date;
  final double portfolioValue;
  final double? costBasis;

  const _CrosshairBadge({
    required this.date,
    required this.portfolioValue,
    this.costBasis,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final gain = costBasis != null ? portfolioValue - costBasis! : null;
    final isPositive = gain != null && gain >= 0;
    final color = isPositive ? tc.accent : WeRoboColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            date,
            style: TextStyle(
              fontFamily: WeRoboFonts.english,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tc.textSecondary,
            ),
          ),
          if (gain != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 14,
              color: tc.border,
            ),
            const SizedBox(width: 8),
            Text(
              '원금 ₩${_formatCurrency(costBasis!.toInt())}',
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: tc.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isPositive ? '+' : ''}₩${_formatCurrency(gain.abs().toInt())}',
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Dual-line chart painter ──────────────────────────────────

class _PortfolioValuePainter extends CustomPainter {
  final List<ChartPoint> valuePts;
  final List<ChartPoint> costPts;
  final double progress;
  final int? touchIndex;
  final Color primaryColor;
  final Color costColor;
  final Color gridColor;
  final Color textColor;
  final Color tooltipBg;
  final Color tooltipBorder;
  final Color textPrimaryColor;

  _PortfolioValuePainter({
    required this.valuePts,
    required this.costPts,
    required this.progress,
    this.touchIndex,
    required this.primaryColor,
    required this.costColor,
    required this.gridColor,
    required this.textColor,
    required this.tooltipBg,
    required this.tooltipBorder,
    required this.textPrimaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (valuePts.length < 2) return;

    final w = size.width;
    final h = size.height;
    const padL = 12.0;
    const padR = 12.0;
    const padT = 8.0;
    const padB = 24.0;
    final chartW = w - padL - padR;
    final chartH = h - padT - padB;

    // Y-range across both lines
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final p in valuePts) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    for (final p in costPts) {
      if (p.value < minY) minY = p.value;
      if (p.value > maxY) maxY = p.value;
    }
    // Add 5% padding
    final range = (maxY - minY).clamp(1.0, double.infinity);
    minY -= range * 0.05;
    maxY += range * 0.05;
    final rangeY = maxY - minY;

    double toX(int i, int total) => padL + chartW * i / (total - 1);
    double toY(double val) => padT + chartH - ((val - minY) / rangeY) * chartH;

    // Grid lines (4 horizontal, very subtle)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = padT + chartH * i / 4;
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridPaint);
    }

    final drawCount =
        (valuePts.length * progress).ceil().clamp(2, valuePts.length);

    // Cost basis line (draw first, behind portfolio)
    if (costPts.length >= 2) {
      final costCount = min(drawCount, costPts.length);
      final costPath = Path();
      for (int i = 0; i < costCount; i++) {
        final x = toX(i, valuePts.length);
        final y = toY(costPts[i].value);
        if (i == 0) {
          costPath.moveTo(x, y);
        } else {
          costPath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        costPath,
        Paint()
          ..color = costColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Portfolio value line + gradient
    final linePath = Path();
    final areaPath = Path();
    for (int i = 0; i < drawCount; i++) {
      final x = toX(i, valuePts.length);
      final y = toY(valuePts[i].value);
      if (i == 0) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, padT + chartH);
        areaPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }
    final lastX = toX(drawCount - 1, valuePts.length);
    areaPath.lineTo(lastX, padT + chartH);
    areaPath.close();

    // Gradient area fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor.withValues(alpha: 0.18),
        primaryColor.withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(
      areaPath,
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Portfolio line stroke
    canvas.drawPath(
      linePath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // End dot
    if (drawCount > 0 && touchIndex == null) {
      final lastY = toY(valuePts[drawCount - 1].value);
      canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = primaryColor);
      canvas.drawCircle(Offset(lastX, lastY), 2, Paint()..color = tooltipBg);
    }

    // X-axis date labels (5 evenly spaced)
    final labelStyle =
        TextStyle(fontSize: 9, color: textColor, fontFamily: 'IBMPlexSans');
    final totalPts = valuePts.length;
    for (int i = 0; i < 5; i++) {
      final idx = (totalPts - 1) * i ~/ 4;
      if (idx >= totalPts) continue;
      final d = valuePts[idx].date;
      final label = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = toX(idx, totalPts);
      tp.paint(canvas, Offset(x - tp.width / 2, h - padB + 6));
    }

    // Crosshair
    if (touchIndex != null && touchIndex! < drawCount) {
      final ti = touchIndex!;
      final tx = toX(ti, valuePts.length);

      // Vertical line
      canvas.drawLine(
        Offset(tx, padT),
        Offset(tx, padT + chartH),
        Paint()
          ..color = gridColor.withValues(alpha: 0.4)
          ..strokeWidth = 0.5,
      );

      // Dots
      final vy = toY(valuePts[ti].value);
      canvas.drawCircle(Offset(tx, vy), 5, Paint()..color = primaryColor);
      canvas.drawCircle(Offset(tx, vy), 3, Paint()..color = tooltipBg);

      if (ti < costPts.length) {
        final cy = toY(costPts[ti].value);
        canvas.drawCircle(Offset(tx, cy), 4,
            Paint()..color = costColor.withValues(alpha: 0.8));
        canvas.drawCircle(Offset(tx, cy), 2, Paint()..color = tooltipBg);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PortfolioValuePainter old) =>
      old.progress != progress || old.touchIndex != touchIndex;
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

// ─── Welcome banner ───────────────────────────────────────────

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

// ─── Activity card ────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String date;
  final String value;
  final Color? valueColor;

  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Pressable(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: WeRoboTypography.bodySmall.copyWith(
                          color: tc.textPrimary, fontWeight: FontWeight.w500)),
                  Text(date,
                      style: WeRoboTypography.caption
                          .copyWith(fontFamily: WeRoboFonts.english)
                          .themed(context)),
                ],
              ),
            ),
            Text(
              value,
              style: WeRoboTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? tc.textPrimary,
                fontFamily: WeRoboFonts.english,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
