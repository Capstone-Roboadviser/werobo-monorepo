import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Step 2 visual: a single high-amplitude red volatility polyline.
///
/// The line spans the central width with large, sine-like swings (several
/// peaks and troughs). On entrance it draws left to right: the drawn fraction
/// is driven by the orchestrator's [entrance] animation (0 to 1). The whole
/// visual also fades and translates/scales in off the same animation so it
/// feels of a piece with the rest of the flow.
///
/// Illustrative only: no data, no interactivity. Sits in the [Expanded] region
/// below the scaffold-rendered headline + caption.
class VolatilityLineView extends StatelessWidget {
  /// 0 to 1 entrance animation, driven by the orchestrator when this page is
  /// active.
  final Animation<double> entrance;

  const VolatilityLineView({
    super.key,
    required this.entrance,
  });

  @override
  Widget build(BuildContext context) {
    // Volatile red line. Korean convention reds (gain/danger) read as the
    // "market lurch" warning the copy describes.
    const lineColor = WeRoboColors.gainRed;

    return AnimatedBuilder(
      animation: entrance,
      builder: (context, child) {
        final t = entrance.value.clamp(0.0, 1.0);
        // The container fades + rises + scales in over the first ~70% of the
        // entrance; the draw fraction (handled in the painter) consumes the
        // whole 0 to 1 so the stroke keeps extending after the fade settles.
        final fadeT = (t / 0.7).clamp(0.0, 1.0);
        final opacity = Curves.easeOut.transform(fadeT);
        final translateY = (1 - opacity) * 16.0;
        final scale = 0.96 + 0.04 * opacity;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: scale,
              child: CustomPaint(
                painter: _VolatilityLinePainter(
                  drawFraction: t,
                  lineColor: lineColor,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the red volatility polyline, revealing it left to right up to
/// [drawFraction] of its length.
class _VolatilityLinePainter extends CustomPainter {
  /// 0 to 1 fraction of the full path length to reveal (left to right).
  final double drawFraction;
  final Color lineColor;

  _VolatilityLinePainter({
    required this.drawFraction,
    required this.lineColor,
  });

  // Normalized waypoints (x, y) in [0, 1], y measured top to bottom. A
  // moderate-amplitude, sine-like run with ~5 peaks centered on the band,
  // ending on an upswing (per the Figma — no crash tail). Kept as data so the
  // shape is stable and easy to tweak in code.
  static const List<Offset> _waypoints = [
    Offset(0.00, 0.50),
    Offset(0.09, 0.30),
    Offset(0.19, 0.64),
    Offset(0.30, 0.24),
    Offset(0.41, 0.70),
    Offset(0.52, 0.34),
    Offset(0.63, 0.64),
    Offset(0.74, 0.32),
    Offset(0.85, 0.62),
    Offset(1.00, 0.34),
  ];

  // Horizontal inset so the swings don't touch the panel edges, and a vertical
  // inset so peaks/troughs stay clear of the headline/footer seams.
  static const double _hInsetFraction = 0.04;
  static const double _vInsetFraction = 0.10;

  /// Builds the smooth volatility path mapped into [size]. Uses Catmull-Rom
  /// to cubic segments so the swings read as rounded sine-like waves rather
  /// than a jagged zig-zag.
  Path _buildPath(Size size) {
    final left = size.width * _hInsetFraction;
    final right = size.width * (1 - _hInsetFraction);
    final top = size.height * _vInsetFraction;
    final bottom = size.height * (1 - _vInsetFraction);
    final usableW = math.max(right - left, 0.0);
    final usableH = math.max(bottom - top, 0.0);

    Offset map(Offset n) =>
        Offset(left + n.dx * usableW, top + n.dy * usableH);

    final pts = _waypoints.map(map).toList(growable: false);
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);

    // Catmull-Rom spline through the waypoints, converted to Bézier control
    // points. Endpoints are duplicated so the curve passes through first/last.
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i == 0 ? 0 : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 >= pts.length ? pts.length - 1 : i + 2];

      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6.0,
        p1.dy + (p2.dy - p0.dy) / 6.0,
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6.0,
        p2.dy - (p3.dy - p1.dy) / 6.0,
      );
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || drawFraction <= 0) return;

    final leftX = size.width * _hInsetFraction;
    final rightX = size.width * (1 - _hInsetFraction);
    final topY = size.height * _vInsetFraction;
    final bottomY = size.height * (1 - _vInsetFraction);

    final fullPath = _buildPath(size);

    // Revealed stroke (left→right by drawFraction) and where it currently ends.
    final Path strokePath;
    final double endX;
    if (drawFraction >= 1.0) {
      strokePath = fullPath;
      endX = rightX;
    } else {
      final metric = fullPath.computeMetrics().first;
      final len = metric.length * drawFraction;
      strokePath = metric.extractPath(0, len);
      endX = metric.getTangentForOffset(len)?.position.dx ?? leftX;
    }

    // Soft red→transparent gradient fill under the revealed line.
    final fillPath = Path.from(strokePath)
      ..lineTo(endX, bottomY)
      ..lineTo(leftX, bottomY)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.22),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(leftX, topY, rightX, bottomY));
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(
      strokePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VolatilityLinePainter old) =>
      old.drawFraction != drawFraction || old.lineColor != lineColor;
}
