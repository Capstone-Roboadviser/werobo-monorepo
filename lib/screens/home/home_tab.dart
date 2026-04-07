import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/portfolio_data.dart';
import '../onboarding/widgets/vestor_pie_chart.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;

  // TODO: Get from user state
  static const _type = InvestmentType.balanced;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  /// Creates a staggered fade+slide animation for index
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
    final categories = PortfolioData.categoriesFor(_type);
    final (risk, returnRate) = PortfolioData.statsFor(_type);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Hero: asset value
            _stagger(0, _AssetHero()),
            const SizedBox(height: 28),

            // Quick stats
            _stagger(1, Row(
              children: [
                Expanded(child: _QuickStat(
                    label: '위험도', value: risk, icon: Icons.shield_outlined)),
                const SizedBox(width: 16),
                Expanded(child: _QuickStat(
                    label: '수익률', value: returnRate, icon: Icons.trending_up_rounded)),
              ],
            )),
            const SizedBox(height: 28),

            // Portfolio chart
            _stagger(2, Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('포트폴리오 비중', style: WeRoboTypography.heading3),
                const SizedBox(height: 16),
                Center(
                  child: VestorPieChart(
                    categories: categories,
                    size: 200,
                    ringWidth: 26,
                    selectedRingWidth: 32,
                  ),
                ),
              ],
            )),
            const SizedBox(height: 28),

            // Asset trend
            _stagger(3, Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('자산 추이', style: WeRoboTypography.heading3),
                const SizedBox(height: 12),
                _AssetTrendCard(),
              ],
            )),
            const SizedBox(height: 28),

            // Recent activity
            _stagger(4, Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('최근 활동', style: WeRoboTypography.heading3),
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
                  iconColor: WeRoboColors.accent,
                  title: '입금',
                  date: '2026-03-15',
                  value: '+₩500,000',
                  valueColor: WeRoboColors.accent,
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

/// Hero section — large asset number with animated count-up
class _AssetHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '현재 자산',
          style: WeRoboTypography.caption.copyWith(
            color: WeRoboColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 15826400),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            final formatted = _formatCurrency(val.toInt());
            return Text(
              '₩$formatted',
              style: TextStyle(
                fontFamily: WeRoboFonts.english,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: WeRoboColors.textPrimary,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: WeRoboColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '+3.2% 지난 달 대비',
            style: TextStyle(
              fontFamily: WeRoboFonts.english,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WeRoboColors.accent,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatCurrency(int amount) {
    final str = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

/// Minimal stat card with icon
class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeRoboColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: WeRoboColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: WeRoboTypography.caption.copyWith(
                  color: WeRoboColors.textSecondary)),
              Text(value, style: WeRoboTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: WeRoboColors.textPrimary,
                fontFamily: WeRoboFonts.english,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asset trend line chart with gradient area fill
class _AssetTrendCard extends StatefulWidget {
  @override
  State<_AssetTrendCard> createState() => _AssetTrendCardState();
}

class _AssetTrendCardState extends State<_AssetTrendCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _drawCtrl;

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: WeRoboColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _drawCtrl,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(progress: _drawCtrl.value),
          );
        },
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final double progress;
  _TrendPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const padH = 16.0;
    const padB = 28.0;
    const padT = 16.0;
    final chartW = w - padH * 2;
    final chartH = h - padT - padB;

    final rng = Random(55);
    final pts = <double>[];
    double val = 14200000;
    for (int i = 0; i < 30; i++) {
      val += (rng.nextDouble() - 0.38) * 180000;
      pts.add(val);
    }
    final minY = pts.reduce(min);
    final maxY = pts.reduce(max);
    final rangeY = maxY - minY;

    final drawCount = (pts.length * progress).ceil().clamp(0, pts.length);
    if (drawCount < 2) return;

    final linePath = Path();
    final areaPath = Path();

    for (int i = 0; i < drawCount; i++) {
      final x = padH + chartW * i / (pts.length - 1);
      final y = padT + chartH - ((pts[i] - minY) / rangeY) * chartH;
      if (i == 0) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, padT + chartH);
        areaPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }

    final lastX = padH + chartW * (drawCount - 1) / (pts.length - 1);
    areaPath.lineTo(lastX, padT + chartH);
    areaPath.close();

    // Gradient fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        WeRoboColors.primary.withValues(alpha: 0.12),
        WeRoboColors.primary.withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(areaPath,
        Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // Line
    canvas.drawPath(linePath, Paint()
      ..color = WeRoboColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // End dot
    if (drawCount > 0) {
      final lastY = padT + chartH -
          ((pts[drawCount - 1] - minY) / rangeY) * chartH;
      canvas.drawCircle(Offset(lastX, lastY), 4,
          Paint()..color = WeRoboColors.primary);
      canvas.drawCircle(Offset(lastX, lastY), 2,
          Paint()..color = WeRoboColors.white);
    }

    // X labels
    final months = ['1월', '2월', '3월', '4월'];
    final labelStyle = TextStyle(
        fontSize: 10, color: WeRoboColors.textTertiary);
    for (int i = 0; i < months.length; i++) {
      final x = padH + chartW * i / (months.length - 1);
      final tp = TextPainter(
        text: TextSpan(text: months[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, h - padB + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.progress != progress;
}

/// Activity row with press feedback (Emil: scale 0.97 on active)
class _ActivityCard extends StatefulWidget {
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
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: WeRoboColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon,
                    size: 20, color: widget.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: WeRoboTypography.bodySmall.copyWith(
                            color: WeRoboColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                    Text(widget.date,
                        style: WeRoboTypography.caption.copyWith(
                            fontFamily: WeRoboFonts.english)),
                  ],
                ),
              ),
              Text(
                widget.value,
                style: WeRoboTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.valueColor ?? WeRoboColors.textPrimary,
                  fontFamily: WeRoboFonts.english,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
