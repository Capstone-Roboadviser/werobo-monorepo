import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class DonutSegment {
  final double weight; // 0.0–1.0
  final Color color;
  /// Optional human-readable label (e.g. "단기채권"). Used when the user taps
  /// a slice to render a rich center breakdown. Defaults to null which keeps
  /// the simple [DonutChart.centerLabel] visible.
  final String? label;
  /// Constituent tickers + weights to show in the breakdown when the slice is
  /// tapped. Each entry is rendered as `{ticker} {pct}%`. Empty by default.
  final List<DonutTicker> tickers;
  const DonutSegment({
    required this.weight,
    required this.color,
    this.label,
    this.tickers = const [],
  });
}

/// One ETF inside an asset slice — rendered in the donut's tap-detail view.
class DonutTicker {
  final String symbol; // e.g. "LQD"
  final double weight; // 0.0–1.0 (share of overall portfolio, not slice)
  const DonutTicker({required this.symbol, required this.weight});
}

class DonutChart extends StatefulWidget {
  final List<DonutSegment> segments;
  final String centerLabel;
  final bool compact;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    this.compact = false,
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  /// Index of the slice the user has tapped. `null` means show the default
  /// center label.
  int? _activeSegmentIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: WeRoboMotion.chartDraw,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: WeRoboMotion.chartReveal),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Decide which slice (if any) the tap falls inside. Returns `null` when
  /// the tap is on the empty hole, the outer ring, or outside the donut.
  int? _segmentIndexForTap(Offset tapLocal, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = tapLocal.dx - center.dx;
    final dy = tapLocal.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final outerRadius = size / 2 - 16 + 14; // arc center radius + half stroke
    final innerRadius = size / 2 - 16 - 14;
    if (distance < innerRadius || distance > outerRadius) {
      return null;
    }
    // Convert atan2 (which has 0 at +x axis, increasing CCW) to our drawing
    // convention where 0 is at the top (-pi/2) and increases clockwise.
    var angle = atan2(dy, dx) + pi / 2;
    if (angle < 0) angle += 2 * pi;
    final progress = _animation.value;
    var sweepStart = 0.0;
    for (var i = 0; i < widget.segments.length; i++) {
      final sweep = 2 * pi * widget.segments[i].weight * progress;
      if (angle >= sweepStart && angle < sweepStart + sweep) {
        return i;
      }
      sweepStart += sweep;
    }
    return null;
  }

  void _handleTap(TapUpDetails details, double size) {
    final tappedIndex = _segmentIndexForTap(details.localPosition, size);
    setState(() {
      // Tapping the same slice again, or tapping outside any slice, deselects.
      if (tappedIndex == null || tappedIndex == _activeSegmentIndex) {
        _activeSegmentIndex = null;
      } else {
        _activeSegmentIndex = tappedIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 180.0 : 240.0;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _handleTap(d, size),
          child: CustomPaint(
            painter: _DonutPainter(
              progress: _animation.value,
              segments: widget.segments,
              activeIndex: _activeSegmentIndex,
            ),
            child: Center(
              child: _buildCenterLabel(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterLabel(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final activeIndex = _activeSegmentIndex;
    if (activeIndex == null ||
        activeIndex >= widget.segments.length ||
        widget.segments[activeIndex].label == null) {
      return Text(
        widget.centerLabel,
        textAlign: TextAlign.center,
        style: WeRoboTypography.heading3.themed(context),
      );
    }
    final seg = widget.segments[activeIndex];
    final pct = (seg.weight * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            seg.label!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WeRoboTypography.heading3.themed(context),
          ),
          const SizedBox(height: 2),
          Text(
            '$pct%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: WeRoboFonts.number,
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: tc.textPrimary,
              height: 1.1,
            ),
          ),
          if (seg.tickers.isNotEmpty) const SizedBox(height: 4),
          if (seg.tickers.isNotEmpty)
            for (final t in seg.tickers)
              Text(
                '${t.symbol} ${(t.weight * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WeRoboTypography.caption.copyWith(
                  color: tc.textSecondary,
                ),
              ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final List<DonutSegment> segments;
  final int? activeIndex;

  _DonutPainter({
    required this.progress,
    required this.segments,
    this.activeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 28.0;
    const gapAngle = 0.012; // ~1px gap at typical radius

    double startAngle = -pi / 2;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final sweepAngle = 2 * pi * segment.weight * progress - gapAngle;
      final isDimmed = activeIndex != null && activeIndex != i;
      final paint = Paint()
        ..color = isDimmed
            ? segment.color.withValues(alpha: 0.35)
            : segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt; // butt + gap = clean separator
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += 2 * pi * segment.weight * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.segments != segments ||
      oldDelegate.activeIndex != activeIndex;
}
