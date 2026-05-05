from __future__ import annotations

from mobile_backend import main as mobile_main
from mobile_backend.api.router import api_router


def test_mobile_account_routes_are_registered() -> None:
    route_paths = {
        getattr(route, "path", None)
        for route in api_router.routes
    }

    assert "/api/v1/account/dashboard" in route_paths
    assert "/api/v1/account" in route_paths
    assert "/api/v1/account/cash-in" in route_paths
    assert "/api/v1/account/digest" in route_paths
    assert "/api/v1/insights" in route_paths


def test_startup_initializes_account_storage(monkeypatch) -> None:
    calls: list[str] = []

    class StubManagedUniverseService:
        def initialize_storage(self) -> None:
            calls.append("managed_universe")

    class StubAuthService:
        def initialize_storage(self) -> None:
            calls.append("auth")

    class StubPortfolioAccountService:
        def initialize_storage(self) -> None:
            calls.append("account")

    class StubDigestService:
        def initialize_storage(self) -> None:
            calls.append("digest")

    monkeypatch.setattr(
        mobile_main,
        "ManagedUniverseService",
        lambda: StubManagedUniverseService(),
    )
    monkeypatch.setattr(mobile_main, "AuthService", lambda: StubAuthService())
    monkeypatch.setattr(
        mobile_main,
        "PortfolioAccountService",
        lambda: StubPortfolioAccountService(),
        raising=False,
    )
    monkeypatch.setattr(
        mobile_main,
        "DigestService",
        lambda: StubDigestService(),
        raising=False,
    )

    mobile_main.initialize_managed_universe_storage()

    assert calls == ["managed_universe", "auth", "account", "digest"]
