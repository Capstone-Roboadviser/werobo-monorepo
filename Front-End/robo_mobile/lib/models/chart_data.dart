import 'package:flutter/material.dart';

/// A single data point on a time-series chart
class ChartPoint {
  final DateTime date;
  final double value;
  const ChartPoint({required this.date, required this.value});
}

/// A line in a multi-line chart
class ChartLine {
  final String key;
  final String label;
  final Color color;
  final bool dashed;
  final List<ChartPoint> points;
  const ChartLine({
    required this.key,
    required this.label,
    required this.color,
    this.dashed = false,
    required this.points,
  });
}
