import '../models/chart_data.dart';
import '../models/mobile_backend_models.dart';

List<ChartLine> comparisonChartLinesFromResponse(
  MobileComparisonBacktestResponse response,
) {
  return response.lines
      .map(
        (line) => ChartLine(
          key: line.key,
          label: line.label,
          color: parseBackendHexColor(line.color),
          dashed: line.style != 'solid',
          points: line.points
              .map(
                (point) => ChartPoint(
                  date: point.date,
                  value: point.returnPct,
                ),
              )
              .toList(),
        ),
      )
      .toList();
}
