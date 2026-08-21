import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/mobile_backend_models.dart';
import 'package:robo_mobile/screens/onboarding/widgets/risk_return_frontier_chart.dart';

void main() {
  MobileFrontierPreviewPoint point(
    int index,
    double volatility,
    double expectedReturn,
  ) {
    return MobileFrontierPreviewPoint(
      index: index,
      volatility: volatility,
      expectedReturn: expectedReturn,
      isRecommended: false,
      representativeCode: null,
      representativeLabel: null,
      sectorAllocations: const [],
    );
  }

  test('display frontier removes downturns and locally inefficient bends', () {
    final result = efficientFrontierDisplayPoints([
      point(5, 0.15, 0.095),
      point(2, 0.09, 0.075),
      point(4, 0.13, 0.085),
      point(0, 0.05, 0.05),
      point(3, 0.11, 0.09),
      point(1, 0.07, 0.07),
      point(6, 0.17, 0.093),
    ]);

    expect(result.map((item) => item.index), [0, 1, 3, 5]);

    for (var index = 1; index < result.length; index++) {
      expect(
        result[index].volatility,
        greaterThan(result[index - 1].volatility),
      );
      expect(
        result[index].expectedReturn,
        greaterThan(result[index - 1].expectedReturn),
      );
    }

    for (var index = 2; index < result.length; index++) {
      final previousSlope = (result[index - 1].expectedReturn -
              result[index - 2].expectedReturn) /
          (result[index - 1].volatility - result[index - 2].volatility);
      final nextSlope =
          (result[index].expectedReturn - result[index - 1].expectedReturn) /
              (result[index].volatility - result[index - 1].volatility);
      expect(nextSlope, lessThanOrEqualTo(previousSlope));
    }
  });

  test('display frontier keeps the best return at duplicate volatility', () {
    final result = efficientFrontierDisplayPoints([
      point(0, 0.05, 0.05),
      point(1, 0.10, 0.07),
      point(2, 0.10, 0.08),
      point(3, 0.15, 0.09),
    ]);

    expect(result.map((item) => item.index), [0, 2, 3]);
  });

  test('normalized display curve is smooth and always rises to the right', () {
    const start = Offset(20, 180);
    const end = Offset(320, 40);
    var previous = smoothEfficientFrontierPointForT(
      0,
      start: start,
      end: end,
    );

    expect(previous, start);
    for (var step = 1; step <= 100; step++) {
      final current = smoothEfficientFrontierPointForT(
        step / 100,
        start: start,
        end: end,
      );
      expect(current.dx, greaterThan(previous.dx));
      expect(current.dy, lessThan(previous.dy));
      previous = current;
    }
    expect(previous, end);

    final early = smoothEfficientFrontierPointForT(
      0.1,
      start: start,
      end: end,
    );
    final late = smoothEfficientFrontierPointForT(
      0.9,
      start: start,
      end: end,
    );
    final earlySlope = (early.dy - start.dy).abs() / (early.dx - start.dx);
    final lateSlope = (end.dy - late.dy).abs() / (end.dx - late.dx);
    expect(earlySlope, greaterThan(lateSlope));
  });
}
