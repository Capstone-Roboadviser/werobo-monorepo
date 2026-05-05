from __future__ import annotations

from types import SimpleNamespace

from mobile_backend.api.routes import admin as admin_routes


def test_activate_universe_version_rebuilds_snapshots(monkeypatch) -> None:
    activated_version = SimpleNamespace(
        version_id=7,
        version_name="2026-04 mobile universe",
        source_type="admin_input",
        notes=None,
        is_active=True,
        created_at="2026-04-20T17:20:00Z",
        instrument_count=14,
    )
    frontier_calls: list[dict[str, object]] = []
    comparison_calls: list[dict[str, object]] = []

    monkeypatch.setattr(
        admin_routes,
        "managed_universe_service",
        SimpleNamespace(activate_version=lambda version_id: activated_version),
    )
    monkeypatch.setattr(
        admin_routes,
        "frontier_snapshot_service",
        SimpleNamespace(
            rebuild_managed_universe_snapshots=lambda **kwargs: frontier_calls.append(dict(kwargs))
        ),
    )
    monkeypatch.setattr(
        admin_routes,
        "comparison_backtest_snapshot_service",
        SimpleNamespace(
            rebuild_managed_universe_snapshots=lambda **kwargs: comparison_calls.append(dict(kwargs))
        ),
    )

    response = admin_routes.activate_universe_version(7)

    assert response.version_id == 7
    assert frontier_calls == [{"version_id": 7}]
    assert comparison_calls == [{"version_id": 7}]
