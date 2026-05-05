import '../models/chart_data.dart';

List<ChartPoint> filterChartPointsFromStartDate(
  List<ChartPoint> points, {
  DateTime? startDate,
}) {
  if (points.isEmpty || startDate == null) {
    return points;
  }

  final normalizedStart = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );

  return points.where((point) {
    final normalizedPoint = DateTime(
      point.date.year,
      point.date.month,
      point.date.day,
    );
    return !normalizedPoint.isBefore(normalizedStart);
  }).toList();
}

List<ChartLine> filterChartLinesFromStartDate(
  List<ChartLine> lines, {
  DateTime? startDate,
  bool rebaseToZero = false,
}) {
  if (lines.isEmpty || startDate == null) {
    return lines;
  }

  return lines
      .map(
        (line) {
          final filteredPoints = filterChartPointsFromStartDate(
            line.points,
            startDate: startDate,
          );
          final rebasedPoints = rebaseToZero
              ? rebaseChartPointsToFirstValue(filteredPoints)
              : filteredPoints;
          return ChartLine(
            key: line.key,
            label: line.label,
            color: line.color,
            dashed: line.dashed,
            points: rebasedPoints,
          );
        },
      )
      .where((line) => line.points.isNotEmpty)
      .toList();
}

List<ChartPoint> rebaseChartPointsToFirstValue(List<ChartPoint> points) {
  if (points.isEmpty) {
    return points;
  }

  final baseValue = points.first.value;
  return points
      .map(
        (point) => ChartPoint(
          date: point.date,
          value: _rebaseCumulativeReturn(point.value, baseValue),
        ),
      )
      .toList();
}

double _rebaseCumulativeReturn(double value, double baseValue) {
  final baseGrowth = 1 + baseValue;
  if (baseGrowth <= 0) {
    return value - baseValue;
  }
  return ((1 + value) / baseGrowth) - 1;
}

List<DateTime> filterDatesFromStartDate(
  List<DateTime> dates, {
  DateTime? startDate,
}) {
  if (dates.isEmpty || startDate == null) {
    return dates;
  }

  final normalizedStart = DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  );

  return dates.where((date) {
    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );
    return !normalizedDate.isBefore(normalizedStart);
  }).toList();
}
