import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/chart_data.dart';

// ── Empty chart placeholder ──

class EmptyChartState extends StatelessWidget {
  final String message;

  const EmptyChartState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: WeRoboTypography.bodySmall.themed(context),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Area chart painter (volatility / single-line) ──

class AreaChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final double progress;
  final Color color;
  final int? touchIndex;
  final String valueLabel;
  final double? baselineValue;
  final String? baselineLabel;
  final Color gridColor;
  final Color textTertiaryColor;
  final Color textPrimaryColor;
  final Color tooltipBackground;
  final Color tooltipBorder;

  AreaChartPainter({
    required this.points,
    required this.progress,
    required this.color,
    this.touchIndex,
    required this.valueLabel,
    this.baselineValue,
    this.baselineLabel,
    required this.gridColor,
    required this.textTertiaryColor,
    required this.textPrimaryColor,
    required this.tooltipBackground,
    required this.tooltipBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const padL = 36.0;
    const padR = 12.0;
    const padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padB;

    final values = points.map((p) => p.value).toList();
    var minY = values.reduce(min);
    var maxY = values.reduce(max);
    if (baselineValue != null) {
      if (baselineValue! < minY) minY = baselineValue!;
      if (baselineValue! > maxY) maxY = baselineValue!;
    }
    final rangeY = (maxY - minY).clamp(0.001, double.infinity);

    // Grid
    _drawGrid(canvas, size, padL, padR, padB, h, minY, rangeY);

    if (baselineValue != null) {
      final y = h - ((baselineValue! - minY) / rangeY) * h;
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (double x = padL; x < size.width - padR; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 4).clamp(0, size.width - padR), y),
          dashPaint,
        );
      }
      final labelStyle = TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w600,
        fontFamily: WeRoboFonts.english,
      );
      _drawText(
          canvas, baselineLabel ?? '', Offset(padL + 4, y - 14), labelStyle);
    }

    // Build path
    final drawCount =
        (points.length * progress).ceil().clamp(0, points.length);
    if (drawCount < 2) return;

    final linePath = Path();
    final areaPath = Path();

    for (int i = 0; i < drawCount; i++) {
      final x = padL + w * i / (points.length - 1);
      final y = h - ((values[i] - minY) / rangeY) * h;
      if (i == 0) {
        linePath.moveTo(x, y);
        areaPath.moveTo(x, h);
        areaPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }

    // Area fill gradient
    final lastX = padL + w * (drawCount - 1) / (points.length - 1);
    areaPath.lineTo(lastX, h);
    areaPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.25),
        color.withValues(alpha: 0.0),
      ],
    );
    final areaPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(padL, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Crosshair + tooltip
    if (touchIndex != null && touchIndex! < points.length) {
      final ti = touchIndex!;
      final tx = padL + w * ti / (points.length - 1);
      final ty = h - ((values[ti] - minY) / rangeY) * h;

      final crossPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      canvas.drawLine(Offset(tx, 0), Offset(tx, h), crossPaint);

      canvas.drawCircle(Offset(tx, ty), 5, Paint()..color = color);
      canvas.drawCircle(
          Offset(tx, ty), 3, Paint()..color = tooltipBackground);

      final date = points[ti].date;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final valStr = '${(values[ti] * 100).toStringAsFixed(1)}%';
      _drawTooltip(canvas, Offset(tx, ty - 28),
          '$dateStr\n$valueLabel: $valStr', size.width);
    }

    // X-axis date labels
    _drawDateLabels(canvas, size, padL, w, h, padB);
  }

  void _drawGrid(Canvas canvas, Size size, double padL, double padR,
      double padB, double h, double minY, double rangeY) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: textTertiaryColor,
      fontFamily: WeRoboFonts.english,
    );

    for (int i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(
          Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      final val = minY + rangeY * i / 4;
      _drawText(canvas, '${(val * 100).toStringAsFixed(1)}%',
          Offset(0, y - 6), labelStyle);
    }
  }

  void _drawDateLabels(Canvas canvas, Size size, double padL, double w,
      double h, double padB) {
    if (points.length < 2) return;
    final style = TextStyle(
      fontSize: 8,
      color: textTertiaryColor,
      fontFamily: WeRoboFonts.english,
    );
    for (int i = 0; i < 5; i++) {
      final idx = (points.length - 1) * i ~/ 4;
      final d = points[idx].date;
      final label = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final x = padL + w * idx / (points.length - 1);
      _drawText(canvas, label, Offset(x - 16, h + 4), style);
    }
  }

  void _drawTooltip(
      Canvas canvas, Offset pos, String text, double maxW) {
    final style = TextStyle(
      fontSize: 10,
      color: textPrimaryColor,
      fontFamily: WeRoboFonts.english,
      height: 1.4,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    var x = pos.dx - tp.width / 2 - 8;
    x = x.clamp(0, maxW - tp.width - 16);
    final y = pos.dy - tp.height - 8;

    final rect = RRect.fromLTRBR(x, y, x + tp.width + 16,
        y + tp.height + 8, const Radius.circular(6));
    canvas.drawRRect(
        rect,
        Paint()
          ..color = tooltipBackground
          ..style = PaintingStyle.fill);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = tooltipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    tp.paint(canvas, Offset(x + 8, y + 4));
  }

  void _drawText(
      Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant AreaChartPainter old) =>
      old.progress != progress || old.touchIndex != touchIndex;
}

// ── Multi-line chart painter (comparison) ──

class MultiLineChartPainter extends CustomPainter {
  final List<ChartLine> lines;
  final double progress;
  final List<DateTime> rebalanceDates;
  final int? touchIndex;
  final Color gridColor;
  final Color textTertiaryColor;
  final Color textPrimaryColor;
  final Color tooltipBackground;
  final Color tooltipBorder;

  MultiLineChartPainter({
    required this.lines,
    required this.progress,
    required this.rebalanceDates,
    this.touchIndex,
    required this.gridColor,
    required this.textTertiaryColor,
    required this.textPrimaryColor,
    required this.tooltipBackground,
    required this.tooltipBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    const padL = 36.0;
    const padR = 12.0;
    const padB = 18.0;
    final w = size.width - padL - padR;
    final h = size.height - padB;

    // Y range across all lines
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final p in line.points) {
        if (p.value < minY) minY = p.value;
        if (p.value > maxY) maxY = p.value;
      }
    }
    final rangeY = (maxY - minY).clamp(0.001, double.infinity);

    // Grid
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: textTertiaryColor,
      fontFamily: WeRoboFonts.english,
    );

    for (int i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      canvas.drawLine(
          Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      final val = minY + rangeY * i / 4;
      _drawText(canvas, '${(val * 100).toStringAsFixed(1)}%',
          Offset(0, y - 6), labelStyle);
    }

    // Rebalance vertical dashed lines
    if (lines.isNotEmpty && lines[0].points.length > 1) {
      final firstDate = lines[0].points.first.date;
      final lastDate = lines[0].points.last.date;
      final totalDays =
          lastDate.difference(firstDate).inDays.clamp(1, 99999);

      for (final rd in rebalanceDates) {
        final dayOff = rd.difference(firstDate).inDays;
        if (dayOff < 0 || dayOff > totalDays) continue;
        final x = padL + w * dayOff / totalDays;
        final dashPaint = Paint()
          ..color = const Color(0xFFFBBF24).withValues(alpha: 0.5)
          ..strokeWidth = 1;
        for (double y0 = 0; y0 < h; y0 += 6) {
          canvas.drawLine(
              Offset(x, y0), Offset(x, (y0 + 3).clamp(0, h)), dashPaint);
        }
      }
    }

    // Draw lines
    for (final line in lines) {
      final pts = line.points;
      final count = pts.length;
      final drawCount = (count * progress).ceil().clamp(0, count);
      if (drawCount < 2) continue;

      final path = Path();
      for (int i = 0; i < drawCount; i++) {
        final x = padL + w * i / (count - 1);
        final y = h - ((pts[i].value - minY) / rangeY) * h;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final paint = Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      if (line.dashed) {
        final metric = path.computeMetrics().first;
        double dist = 0;
        while (dist < metric.length) {
          final end = (dist + 6).clamp(0, metric.length);
          final seg = metric.extractPath(dist, end.toDouble());
          canvas.drawPath(seg, paint);
          dist += 10;
        }
      } else {
        canvas.drawPath(path, paint);
      }
    }

    // Crosshair
    if (touchIndex != null && lines.isNotEmpty) {
      final pts = lines[0].points;
      if (touchIndex! < pts.length) {
        final tx = padL + w * touchIndex! / (pts.length - 1);
        canvas.drawLine(
            Offset(tx, 0),
            Offset(tx, h),
            Paint()
              ..color = gridColor
              ..strokeWidth = 1);

        for (final line in lines) {
          if (touchIndex! < line.points.length) {
            final val = line.points[touchIndex!].value;
            final ty = h - ((val - minY) / rangeY) * h;
            canvas.drawCircle(
                Offset(tx, ty), 4, Paint()..color = line.color);
            canvas.drawCircle(
                Offset(tx, ty), 2, Paint()..color = tooltipBackground);
          }
        }

        final date = pts[touchIndex!].date;
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        var tooltipLines = dateStr;
        for (final line in lines) {
          if (touchIndex! < line.points.length) {
            tooltipLines +=
                '\n${line.label}: ${(line.points[touchIndex!].value * 100).toStringAsFixed(1)}%';
          }
        }
        _drawTooltip(canvas, Offset(tx, 10), tooltipLines, size.width);
      }
    }

    // X-axis labels
    if (lines.isNotEmpty && lines[0].points.length > 1) {
      final pts = lines[0].points;
      final dateStyle = TextStyle(
        fontSize: 8,
        color: textTertiaryColor,
        fontFamily: WeRoboFonts.english,
      );
      for (int i = 0; i < 5; i++) {
        final idx = (pts.length - 1) * i ~/ 4;
        final d = pts[idx].date;
        final label = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        final x = padL + w * idx / (pts.length - 1);
        _drawText(canvas, label, Offset(x - 16, h + 4), dateStyle);
      }
    }
  }

  void _drawTooltip(
      Canvas canvas, Offset pos, String text, double maxW) {
    final style = TextStyle(
      fontSize: 10,
      color: textPrimaryColor,
      fontFamily: WeRoboFonts.english,
      height: 1.4,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    var x = pos.dx - tp.width / 2 - 8;
    x = x.clamp(0, maxW - tp.width - 16);

    final rect = RRect.fromLTRBR(x, pos.dy, x + tp.width + 16,
        pos.dy + tp.height + 8, const Radius.circular(6));
    canvas.drawRRect(rect, Paint()..color = tooltipBackground);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = tooltipBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    tp.paint(canvas, Offset(x + 8, pos.dy + 4));
  }

  void _drawText(
      Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant MultiLineChartPainter old) =>
      old.progress != progress || old.touchIndex != touchIndex;
}
