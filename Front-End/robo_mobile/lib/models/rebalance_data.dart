import 'package:flutter/material.dart';
import 'portfolio_data.dart';

class AllocationChange {
  final String sectorName;
  final Color color;
  final double beforePct;
  final double afterPct;

  const AllocationChange({
    required this.sectorName,
    required this.color,
    required this.beforePct,
    required this.afterPct,
  });

  double get delta => afterPct - beforePct;
}

class RebalanceEvent {
  final DateTime date;
  final String status;
  final List<AllocationChange> changes;

  const RebalanceEvent({
    required this.date,
    required this.status,
    required this.changes,
  });

  double get netDelta =>
      changes.fold<double>(0, (sum, c) => sum + c.delta.abs()) / 2;
}

class MockRebalanceData {
  MockRebalanceData._();

  static List<RebalanceEvent> eventsFor(InvestmentType type) {
    switch (type) {
      case InvestmentType.safe:
        return _safeEvents;
      case InvestmentType.growth:
        return _growthEvents;
      case InvestmentType.balanced:
      case InvestmentType.lowerReturn:
      case InvestmentType.higherReturn:
        return _balancedEvents;
    }
  }

  static final _balancedEvents = [
    RebalanceEvent(
      date: DateTime(2026, 4, 1),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 21.2, afterPct: 20.0),
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 18.8, afterPct: 20.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 19.5, afterPct: 18.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 11.3, afterPct: 12.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 12.4, afterPct: 12.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 9.2, afterPct: 10.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 7.6, afterPct: 8.0),
      ],
    ),
    RebalanceEvent(
      date: DateTime(2026, 1, 2),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 20.8, afterPct: 20.0),
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 19.4, afterPct: 20.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 18.6, afterPct: 18.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 12.5, afterPct: 12.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 11.5, afterPct: 12.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 9.8, afterPct: 10.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 7.4, afterPct: 8.0),
      ],
    ),
    RebalanceEvent(
      date: DateTime(2025, 10, 1),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 22.1, afterPct: 20.0),
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 18.2, afterPct: 20.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 19.8, afterPct: 18.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 10.8, afterPct: 12.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 12.8, afterPct: 12.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 9.0, afterPct: 10.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 7.3, afterPct: 8.0),
      ],
    ),
  ];

  static final _safeEvents = [
    RebalanceEvent(
      date: DateTime(2026, 4, 1),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 34.2, afterPct: 35.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 20.5, afterPct: 20.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 15.8, afterPct: 15.0),
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 10.4, afterPct: 10.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 8.3, afterPct: 8.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 6.5, afterPct: 7.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 4.3, afterPct: 5.0),
      ],
    ),
    RebalanceEvent(
      date: DateTime(2026, 1, 2),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 33.8, afterPct: 35.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 20.8, afterPct: 20.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 16.2, afterPct: 15.0),
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 10.2, afterPct: 10.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 8.1, afterPct: 8.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 6.8, afterPct: 7.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 4.1, afterPct: 5.0),
      ],
    ),
  ];

  static final _growthEvents = [
    RebalanceEvent(
      date: DateTime(2026, 4, 1),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 26.8, afterPct: 25.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 26.2, afterPct: 25.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 18.5, afterPct: 20.0),
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 9.4, afterPct: 10.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 10.6, afterPct: 10.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 4.2, afterPct: 5.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 4.3, afterPct: 5.0),
      ],
    ),
    RebalanceEvent(
      date: DateTime(2026, 1, 2),
      status: '완료',
      changes: [
        AllocationChange(sectorName: '미국 가치주', color: CategoryColors.valueStock, beforePct: 27.1, afterPct: 25.0),
        AllocationChange(sectorName: '미국 성장주', color: CategoryColors.growthStock, beforePct: 25.8, afterPct: 25.0),
        AllocationChange(sectorName: '신성장주', color: CategoryColors.newGrowth, beforePct: 18.2, afterPct: 20.0),
        AllocationChange(sectorName: '단기 채권', color: CategoryColors.bond, beforePct: 9.6, afterPct: 10.0),
        AllocationChange(sectorName: '금', color: CategoryColors.gold, beforePct: 10.8, afterPct: 10.0),
        AllocationChange(sectorName: '현금성자산', color: CategoryColors.cash, beforePct: 4.0, afterPct: 5.0),
        AllocationChange(sectorName: '인프라 채권', color: CategoryColors.infra, beforePct: 4.5, afterPct: 5.0),
      ],
    ),
  ];
}
