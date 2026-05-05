from __future__ import annotations

from fastapi import FastAPI
from fastapi.testclient import TestClient

from mobile_backend.api.routes import mobile as mobile_routes
from mobile_backend.domain.enums import SimulationDataSource
from mobile_backend.services.mobile_portfolio_service import MobilePortfolioService


def test_earnings_history_route_delegates_to_mobile_service(monkeypatch) -> None:
    calls: list[dict[str, object]] = []

    class StubMobilePortfolioService:
        def build_earnings_history(
            self,
            *,
            weights: dict[str, float],
            data_source: SimulationDataSource,
            start_date: str,
            investment_amount: float,
        ) -> dict[str, object]:
            calls.append(
                {
                    "weights": weights,
                    "data_source": data_source,
                    "start_date": start_date,
                    "investment_amount": investment_amount,
                }
            )
            return {
                "points": [
                    {
                        "date": "2026-03-01",
                        "total_earnings": 0,
                        "total_return_pct": 0,
                        "asset_earnings": {"gold": 0},
                    }
                ],
                "investment_amount": investment_amount,
                "start_date": "2026-03-01",
                "end_date": "2026-03-01",
                "total_return_pct": 0,
                "total_earnings": 0,
                "asset_summary": [
                    {
                        "asset_code": "gold",
                        "asset_name": "금",
                        "weight": 1,
                        "earnings": 0,
                        "return_pct": 0,
                    }
                ],
            }

    monkeypatch.setattr(
        mobile_routes,
        "mobile_portfolio_service",
        StubMobilePortfolioService(),
    )
    app = FastAPI()
    app.include_router(mobile_routes.router)
    client = TestClient(app)

    response = client.post(
        "/api/v1/portfolio/earnings-history",
        json={
            "weights": {"RAS1": 1},
            "start_date": "2026-03-01",
            "investment_amount": 10_000_000,
            "data_source": "stock_combination_demo",
        },
    )

    assert response.status_code == 200
    assert response.json()["asset_summary"][0]["asset_code"] == "gold"
    assert calls == [
        {
            "weights": {"RAS1": 1},
            "data_source": SimulationDataSource.STOCK_COMBINATION_DEMO,
            "start_date": "2026-03-01",
            "investment_amount": 10_000_000,
        }
    ]


def test_mobile_service_builds_demo_earnings_history() -> None:
    service = MobilePortfolioService()

    response = service.build_earnings_history(
        weights={"BND1": 0.5, "RAS1": 0.5},
        data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        start_date="2024-04-11",
        investment_amount=10_000_000,
    )

    assert response["start_date"] == "2024-04-11"
    assert response["points"]
    assert response["asset_summary"]
    assert {"short_term_bond", "gold"} <= {
        item["asset_code"] for item in response["asset_summary"]
    }
