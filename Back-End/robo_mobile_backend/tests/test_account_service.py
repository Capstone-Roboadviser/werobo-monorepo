from __future__ import annotations

from datetime import date, timedelta

import pandas as pd

from mobile_backend.domain.enums import SimulationDataSource
from mobile_backend.services.account_service import PortfolioAccountService


class FakePortfolioAccountRepository:
    def __init__(self) -> None:
        self.ready = True
        self.initialized = False
        self.next_account_id = 1
        self.accounts_by_user_id: dict[int, dict[str, object]] = {}
        self.cash_flows_by_account_id: dict[int, list[dict[str, object]]] = {}
        self.snapshots_by_account_id: dict[int, list[dict[str, object]]] = {}

    def is_configured(self) -> bool:
        return self.ready

    def initialize(self) -> None:
        self.initialized = True

    def replace_account(self, **kwargs) -> dict[str, object]:
        user_id = int(kwargs["user_id"])
        account = {
            "id": self.next_account_id,
            "user_id": user_id,
            "data_source": kwargs["data_source"],
            "investment_horizon": kwargs["investment_horizon"],
            "portfolio_code": kwargs["portfolio_code"],
            "portfolio_label": kwargs["portfolio_label"],
            "portfolio_id": kwargs["portfolio_id"],
            "target_volatility": kwargs["target_volatility"],
            "expected_return": kwargs["expected_return"],
            "volatility": kwargs["volatility"],
            "sharpe_ratio": kwargs["sharpe_ratio"],
            "stock_weights": kwargs["stock_weights"],
            "sector_allocations": kwargs["sector_allocations"],
            "stock_allocations": kwargs["stock_allocations"],
            "started_at": kwargs["started_at"],
            "created_at": f"{kwargs['started_at']}T00:00:00Z",
            "updated_at": f"{kwargs['started_at']}T00:00:00Z",
        }
        self.accounts_by_user_id[user_id] = account
        self.cash_flows_by_account_id[account["id"]] = []
        self.snapshots_by_account_id[account["id"]] = []
        self.next_account_id += 1
        return account

    def get_account_by_user_id(self, user_id: int) -> dict[str, object] | None:
        return self.accounts_by_user_id.get(user_id)

    def list_accounts(self, *, data_source: str | None = None) -> list[dict[str, object]]:
        accounts = list(self.accounts_by_user_id.values())
        if data_source is None:
            return accounts
        return [account for account in accounts if account["data_source"] == data_source]

    def add_cash_flow(
        self,
        *,
        account_id: int,
        flow_type: str,
        amount: float,
        effective_date: str,
    ) -> dict[str, object]:
        cash_flow = {
            "id": len(self.cash_flows_by_account_id[account_id]) + 1,
            "account_id": account_id,
            "flow_type": flow_type,
            "amount": amount,
            "effective_date": effective_date,
            "created_at": f"{effective_date}T00:00:00Z",
        }
        self.cash_flows_by_account_id[account_id].append(cash_flow)
        return cash_flow

    def list_cash_flows(self, account_id: int) -> list[dict[str, object]]:
        return list(self.cash_flows_by_account_id.get(account_id, []))

    def replace_snapshots(self, account_id: int, snapshots: list[dict[str, float | str]]) -> None:
        self.snapshots_by_account_id[account_id] = [dict(snapshot) for snapshot in snapshots]

    def list_snapshots(self, account_id: int) -> list[dict[str, object]]:
        return list(self.snapshots_by_account_id.get(account_id, []))


class StubPortfolioAccountService(PortfolioAccountService):
    def __init__(self, repository: FakePortfolioAccountRepository) -> None:
        super().__init__(repository=repository, portfolio_service=object())

    def _load_price_history(
        self,
        *,
        tickers: list[str],
        data_source: SimulationDataSource,
    ) -> pd.DataFrame:
        today = date.today()
        yesterday = today - timedelta(days=1)
        rows = []
        for ticker, yesterday_price, today_price in (
            ("QQQ", 100.0, 102.0),
            ("TLT", 50.0, 51.0),
        ):
            if ticker not in tickers:
                continue
            rows.append(
                {
                    "date": pd.Timestamp(yesterday),
                    "ticker": ticker,
                    "adjusted_close": yesterday_price,
                }
            )
            rows.append(
                {
                    "date": pd.Timestamp(today),
                    "ticker": ticker,
                    "adjusted_close": today_price,
                }
            )
        return pd.DataFrame(rows)


def test_create_account_builds_dashboard_and_snapshots() -> None:
    repository = FakePortfolioAccountRepository()
    service = StubPortfolioAccountService(repository)

    dashboard = service.create_or_replace_account(
        user_id=1,
        data_source=SimulationDataSource.MANAGED_UNIVERSE,
        investment_horizon="medium",
        portfolio_code="balanced",
        portfolio_label="균형형",
        portfolio_id="stocks-balanced-medium-0.12",
        target_volatility=0.12,
        expected_return=0.08,
        volatility=0.11,
        sharpe_ratio=0.72,
        sector_allocations=[],
        stock_allocations=[
            {
                "ticker": "QQQ",
                "name": "Invesco QQQ Trust",
                "sector_code": "us_growth",
                "sector_name": "미국 성장주",
                "weight": 0.6,
            },
            {
                "ticker": "TLT",
                "name": "iShares 20+ Year Treasury Bond ETF",
                "sector_code": "bond",
                "sector_name": "채권",
                "weight": 0.4,
            },
        ],
        initial_cash_amount=10_000_000,
    )

    assert dashboard["has_account"] is True
    assert dashboard["summary"] is not None
    assert dashboard["summary"]["invested_amount"] == 10_000_000
    assert dashboard["summary"]["current_value"] == 10_000_000
    assert len(dashboard["history"]) >= 1
    assert dashboard["recent_activity"][0]["title"] in {"포트폴리오 시작", "초기 입금"}


def test_cash_in_updates_invested_amount_and_activity() -> None:
    repository = FakePortfolioAccountRepository()
    service = StubPortfolioAccountService(repository)
    service.create_or_replace_account(
        user_id=7,
        data_source=SimulationDataSource.MANAGED_UNIVERSE,
        investment_horizon="medium",
        portfolio_code="balanced",
        portfolio_label="균형형",
        portfolio_id="stocks-balanced-medium-0.12",
        target_volatility=0.12,
        expected_return=0.08,
        volatility=0.11,
        sharpe_ratio=0.72,
        sector_allocations=[],
        stock_allocations=[
            {
                "ticker": "QQQ",
                "name": "Invesco QQQ Trust",
                "sector_code": "us_growth",
                "sector_name": "미국 성장주",
                "weight": 0.5,
            },
            {
                "ticker": "TLT",
                "name": "iShares 20+ Year Treasury Bond ETF",
                "sector_code": "bond",
                "sector_name": "채권",
                "weight": 0.5,
            },
        ],
        initial_cash_amount=10_000_000,
    )

    dashboard = service.cash_in(user_id=7, amount=500_000)

    assert dashboard["summary"] is not None
    assert dashboard["summary"]["invested_amount"] == 10_500_000
    assert any(
        activity["type"] == "cash_in" and activity["amount"] == 500_000
        for activity in dashboard["recent_activity"]
    )


def test_refresh_managed_universe_accounts_filters_target_accounts() -> None:
    repository = FakePortfolioAccountRepository()
    service = StubPortfolioAccountService(repository)
    service.create_or_replace_account(
        user_id=11,
        data_source=SimulationDataSource.MANAGED_UNIVERSE,
        investment_horizon="medium",
        portfolio_code="balanced",
        portfolio_label="균형형",
        portfolio_id="stocks-balanced-medium-0.12",
        target_volatility=0.12,
        expected_return=0.08,
        volatility=0.11,
        sharpe_ratio=0.72,
        sector_allocations=[],
        stock_allocations=[
            {
                "ticker": "QQQ",
                "name": "Invesco QQQ Trust",
                "sector_code": "us_growth",
                "sector_name": "미국 성장주",
                "weight": 1.0,
            },
        ],
        initial_cash_amount=10_000_000,
    )
    service.create_or_replace_account(
        user_id=12,
        data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        investment_horizon="medium",
        portfolio_code="growth",
        portfolio_label="성장형",
        portfolio_id="stocks-growth-medium-0.16",
        target_volatility=0.16,
        expected_return=0.1,
        volatility=0.14,
        sharpe_ratio=0.8,
        sector_allocations=[],
        stock_allocations=[
            {
                "ticker": "QQQ",
                "name": "Invesco QQQ Trust",
                "sector_code": "us_growth",
                "sector_name": "미국 성장주",
                "weight": 1.0,
            },
        ],
        initial_cash_amount=5_000_000,
    )

    status = service.refresh_managed_universe_accounts()

    assert status.status == "success"
    assert status.account_count == 1
    assert status.success_count == 1
    assert status.failure_count == 0
