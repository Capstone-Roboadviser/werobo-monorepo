import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/projection_data.dart';

/// Custom painter for Monte Carlo projection fan chart.
///
/// X-axis: current year → current year + 30 (two labels only).
/// Y-axis: starts from 0, rounded to nearest 천만원 (10,000,000).
/// Confidence bands spread open via [progress] animation.
class FanChartPainter extends CustomPainter {
  final ProjectionResult data;
  final double progress;
  final int? touchIndex;
  final int startYear;
  final Color outerBandColor;
  final Color innerBandColor;
  final Color medianColor;
  final Color gridColor;
  final Color textColor;
  final Color todayDotColor;

  FanChartPainter({
    required this.data,
    this.progress = 1.0,
    this.touchIndex,
    int? startYear,
    this.outerBandColor = const Color(0xFFCFECF7),
    this.innerBandColor = const Color(0xFFA0D9EF),
    this.medianColor = const Color(0xFF20A7DB),
    this.gridColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF8E8E8E),
    this.todayDotColor = const Color(0xFF20A7DB),
  }) : startYear = startYear ?? DateTime.now().year;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final w = size.width;
    final h = size.height;
    const padL = 52.0;
    const padR = 16.0;
    const padT = 12.0;
    const padB = 28.0;
    final chartW = w - padL - padR;
    final chartH = h - padT - padB;

    final n = data.length;
    final drawCount = (n * progress).ceil().clamp(1, n);

    // Y range: start from 0, max rounded up to nearest 천만
    const minY = 0.0;
    double rawMax = 0;
    for (int i = 0; i < drawCount; i++) {
      if (data.p90[i] > rawMax) rawMax = data.p90[i];
    }
    // Round up to nearest 천만 (10,000,000)
    const cheonman = 10000000.0;
    final maxY = (rawMax / cheonman).ceil() * cheonman;
    final rangeY = maxY - minY;
    if (rangeY <= 0) return;

    double toX(int i) => padL + chartW * i / (n - 1);
    double toY(double val) =>
        padT + chartH - ((val - minY) / rangeY) * chartH;

    // Grid lines + Y-axis labels (rounded 천만 steps)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.10)
      ..strokeWidth = 0.5;

    final gridSteps = (maxY / cheonman).round().clamp(1, 10);
    final stepSize = maxY / gridSteps;

    for (int i = 0; i <= gridSteps; i++) {
      final val = stepSize * i;
      final y = toY(val);
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridPaint);

      // Y-axis label
      final label = _formatYAxis(val);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontFamily: 'GothicA1',
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 6, y - tp.height / 2));
    }

    // Outer band (p10-p90)
    _drawBand(
      canvas, drawCount, data.p10, data.p90, toX, toY,
      outerBandColor.withValues(alpha: 0.15),
    );

    // Inner band (p25-p75)
    _drawBand(
      canvas, drawCount, data.p25, data.p75, toX, toY,
      innerBandColor.withValues(alpha: 0.30),
    );

    // Median line
    final medianPath = Path();
    for (int i = 0; i < drawCount; i++) {
      final x = toX(i);
      final y = toY(data.median[i]);
      if (i == 0) {
        medianPath.moveTo(x, y);
      } else {
        medianPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      medianPath,
      Paint()
        ..color = medianColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Today dot (glowing)
    final dotX = toX(0);
    final dotY = toY(data.median[0]);
    canvas.drawCircle(
      Offset(dotX, dotY),
      6,
      Paint()..color = todayDotColor.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      3,
      Paint()..color = todayDotColor,
    );

    // X-axis: just two labels — start year and end year
    final endYear = startYear + 30;
    _drawXLabel(canvas, '$startYear', toX(0), padT + chartH);
    _drawXLabel(canvas, '$endYear', toX(n - 1), padT + chartH);

    // Crosshair on touch
    if (touchIndex != null && touchIndex! >= 0 && touchIndex! < n) {
      _drawCrosshair(canvas, touchIndex!, toX, toY, padT, chartH);
    }
  }

  void _drawXLabel(Canvas canvas, String text, double x, double top) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontFamily: 'GothicA1',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, top + 8));
  }

  void _drawCrosshair(
    Canvas canvas,
    int ti,
    double Function(int) toX,
    double Function(double) toY,
    double padT,
    double chartH,
  ) {
    final cx = toX(ti);

    canvas.drawLine(
      Offset(cx, padT),
      Offset(cx, padT + chartH),
      Paint()
        ..color = gridColor.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );

    canvas.drawCircle(
      Offset(cx, toY(data.median[ti])),
      4,
      Paint()..color = medianColor,
    );

    // Calculate year from index
    final yearAtTouch = startYear + (ti / (data.length - 1) * 30).round();
    final medVal = _formatWon(data.median[ti]);
    final rangeStr =
        '${_formatWon(data.p10[ti])} ~ ${_formatWon(data.p90[ti])}';
    final tooltipText = '$yearAtTouch년: $medVal\n$rangeStr';
    final tp = TextPainter(
      text: TextSpan(
        text: tooltipText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontFamily: 'GothicA1',
          height: 1.4,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final tooltipW = tp.width + 16;
    final tooltipH = tp.height + 12;
    final maxLeft = toX(data.length - 1) - tooltipW;
    var tooltipX = cx - tooltipW / 2;
    tooltipX = tooltipX.clamp(toX(0), maxLeft);
    final tooltipY = padT + 4.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xDD1A1A1A),
    );
    tp.paint(canvas, Offset(tooltipX + 8, tooltipY + 6));
  }

  void _drawBand(
    Canvas canvas,
    int count,
    List<double> lower,
    List<double> upper,
    double Function(int) toX,
    double Function(double) toY,
    Color color,
  ) {
    if (count < 2) return;
    final path = Path();
    path.moveTo(toX(0), toY(upper[0]));
    for (int i = 1; i < count; i++) {
      path.lineTo(toX(i), toY(upper[i]));
    }
    for (int i = count - 1; i >= 0; i--) {
      path.lineTo(toX(i), toY(lower[i]));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Format for Y-axis labels: 0, 1천만, 2천만, 1억, etc.
  static String _formatYAxis(double value) {
    if (value <= 0) return '0';
    if (value >= 1e8) {
      final eok = value / 1e8;
      return eok == eok.roundToDouble()
          ? '${eok.round()}억'
          : '${eok.toStringAsFixed(1)}억';
    }
    // In 천만 units
    final cheonman = (value / 1e7).round();
    return '$cheonman천만';
  }

  /// Format for tooltip values.
  static String _formatWon(double value) {
    if (value.isNaN || value.isInfinite) return '₩0';
    final abs = value.abs();
    if (abs >= 1e8) {
      return '₩${(value / 1e8).toStringAsFixed(1)}억';
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

  @override
  bool shouldRepaint(covariant FanChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.progress != progress ||
      oldDelegate.touchIndex != touchIndex;
}
