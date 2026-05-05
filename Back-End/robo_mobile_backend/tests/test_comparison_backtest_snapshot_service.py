from __future__ import annotations

from types import SimpleNamespace

from mobile_backend.services.comparison_backtest_snapshot_service import (
    ComparisonBacktestSnapshotService,
)


class _FakeRepository:
    def __init__(self) -> None:
        self.upsert_calls: list[dict[str, object]] = []
        self.deleted_version_ids: list[int] = []

    def upsert_comparison_backtest_snapshot(self, **kwargs):
        self.upsert_calls.append(dict(kwargs))

    def delete_comparison_backtest_snapshots(self, version_id: int) -> None:
        self.deleted_version_ids.append(version_id)


class _FakeManagedUniverseService:
    def __init__(self) -> None:
        self.repository = _FakeRepository()
        self.initialized = False

    def is_configured(self) -> bool:
        return True

    def initialize_storage(self) -> None:
        self.initialized = True

    def get_active_version(self):
        return SimpleNamespace(version_id=7, version_name="2026-04 active")

    def get_version(self, version_id: int):
        return SimpleNamespace(version_id=version_id, version_name=f"version-{version_id}")

    def get_instruments_for_version(self, version_id: int):
        return [SimpleNamespace(ticker="QQQ")]

    def get_price_window(self, version_id: int, instruments):
        return SimpleNamespace(
            aligned_start_date="2020-01-02",
            aligned_end_date="2026-04-14",
        )


def test_rebuild_managed_universe_snapshots_upserts_snapshot() -> None:
    managed_universe_service = _FakeManagedUniverseService()
    calculation_adapter = SimpleNamespace(
        build_materialized_comparison_backtest=lambda **kwargs: {
            "train_start_date": "2024-01-01",
            "train_end_date": "2024-12-31",
            "test_start_date": "2025-01-01",
            "start_date": "2025-01-01",
            "end_date": "2026-04-14",
            "split_ratio": 0.9,
            "rebalance_dates": ["2025-02-01"],
            "lines": [
                {
                    "key": "balanced",
                    "label": "균형형",
                    "color": "#3b82f6",
                    "style": "solid",
                    "points": [
                        {"date": "2025-01-01", "return_pct": 0.0},
                        {"date": "2025-01-31", "return_pct": 1.25},
                    ],
                }
            ],
        }
    )
    service = ComparisonBacktestSnapshotService(
        managed_universe_service=managed_universe_service,
        calculation_adapter=calculation_adapter,
    )

    status = service.rebuild_managed_universe_snapshots(
        version_id=7,
        source_refresh_job_id=19,
    )

    assert managed_universe_service.initialized is True
    assert status.status == "success"
    assert status.snapshot_count == 1
    assert status.line_count == 1
    assert managed_universe_service.repository.deleted_version_ids == []
    assert len(managed_universe_service.repository.upsert_calls) == 1
    assert managed_universe_service.repository.upsert_calls[0]["version_id"] == 7
    assert managed_universe_service.repository.upsert_calls[0]["line_count"] == 1
