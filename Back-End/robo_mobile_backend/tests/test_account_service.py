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
        self.rebalance_insights_by_account_id: dict[int, list[dict[str, object]]] = {}

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
        self.rebalance_insights_by_account_id[account["id"]] = []
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

    def upsert_rebalance_insight(
        self,
        *,
        account_id: int,
        rebalance_date: str,
        pre_weights: dict[str, float],
        post_weights: dict[str, float],
        explanation_text: str | None = None,
    ) -> dict[str, object]:
        existing = self.rebalance_insights_by_account_id.setdefault(account_id, [])
        insight = {
            "account_id": account_id,
            "rebalance_date": rebalance_date,
            "pre_weights": dict(pre_weights),
            "post_weights": dict(post_weights),
            "explanation_text": explanation_text,
        }
        for idx, current in enumerate(existing):
            if current["rebalance_date"] == rebalance_date:
                existing[idx] = insight
                return insight
        existing.append(insight)
        existing.sort(key=lambda item: str(item["rebalance_date"]), reverse=True)
        return insight

    def list_rebalance_insights(self, account_id: int) -> list[dict[str, object]]:
        return list(self.rebalance_insights_by_account_id.get(account_id, []))

    def delete_rebalance_insights(self, account_id: int) -> None:
        self.rebalance_insights_by_account_id[account_id] = []


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
            ("GLD", 200.0, 202.0),
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


class QuarterlyRebalancePortfolioAccountService(PortfolioAccountService):
    def __init__(self, repository: FakePortfolioAccountRepository) -> None:
        super().__init__(repository=repository, portfolio_service=object())

    def _load_price_history(
        self,
        *,
        tickers: list[str],
        data_source: SimulationDataSource,
    ) -> pd.DataFrame:
        if set(tickers) != {"QQQ", "TLT"}:
            raise AssertionError(f"Unexpected tickers: {tickers}")

        rows = []
        for snapshot_date, qqq_price, tlt_price in (
            (date(2026, 3, 30), 100.0, 100.0),
            (date(2026, 3, 31), 106.0, 94.0),
            (date(2026, 4, 1), 200.0, 50.0),
            (date.today(), 200.0, 50.0),
        ):
            rows.append(
                {
                    "date": pd.Timestamp(snapshot_date),
                    "ticker": "QQQ",
                    "adjusted_close": qqq_price,
                }
            )
            rows.append(
                {
                    "date": pd.Timestamp(snapshot_date),
                    "ticker": "TLT",
                    "adjusted_close": tlt_price,
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
    assert dashboard["summary"]["target_volatility"] == 0.12
    assert dashboard["summary"]["expected_return"] == 0.08
    assert dashboard["summary"]["volatility"] == 0.11
    assert dashboard["summary"]["sharpe_ratio"] == 0.72
    assert dashboard["summary"]["invested_amount"] == 10_000_000
    assert dashboard["summary"]["current_value"] == 10_000_000
    assert len(dashboard["history"]) >= 1
    assert dashboard["recent_activity"][0]["title"] in {"포트폴리오 시작", "초기 입금"}


def test_create_account_respects_started_at_override() -> None:
    repository = FakePortfolioAccountRepository()
    service = StubPortfolioAccountService(repository)
    started_at = (date.today() - timedelta(days=1)).isoformat()

    dashboard = service.create_or_replace_account(
        user_id=3,
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
        started_at=started_at,
    )

    assert dashboard["summary"] is not None
    assert dashboard["summary"]["started_at"] == started_at
    assert dashboard["history"][0]["date"] == started_at


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


def test_account_snapshots_follow_two_stage_rebalance_policy() -> None:
    repository = FakePortfolioAccountRepository()
    service = QuarterlyRebalancePortfolioAccountService(repository)

    dashboard = service.create_or_replace_account(
        user_id=9,
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
        started_at="2026-03-30",
    )

    assert dashboard["summary"] is not None
    assert dashboard["summary"]["current_value"] == 12_093_536.73
    assert [item["rebalance_date"] for item in repository.list_rebalance_insights(1)] == [
        "2026-04-01",
        "2026-03-31",
    ]


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


def test_list_managed_universe_account_tickers_returns_unique_sorted_tickers() -> None:
    repository = FakePortfolioAccountRepository()
    service = StubPortfolioAccountService(repository)
    service.create_or_replace_account(
        user_id=21,
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
                "ticker": "qqq",
                "name": "Invesco QQQ Trust",
                "sector_code": "us_growth",
                "sector_name": "미국 성장주",
                "weight": 0.5,
            },
            {
                "ticker": "tlt",
                "name": "iShares 20+ Year Treasury Bond ETF",
                "sector_code": "bond",
                "sector_name": "채권",
                "weight": 0.5,
            },
        ],
        initial_cash_amount=10_000_000,
    )
    service.create_or_replace_account(
        user_id=22,
        data_source=SimulationDataSource.MANAGED_UNIVERSE,
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
                "ticker": "GLD",
                "name": "SPDR Gold Shares",
                "sector_code": "gold",
                "sector_name": "금",
                "weight": 0.5,
            },
            {
                "ticker": "QQQ",
                "name": "Invesco QQQ Trust",
                "sector_code": "us_growth",
                "sector_name": "미국 성장주",
                "weight": 0.5,
            },
        ],
        initial_cash_amount=5_000_000,
    )
    service.create_or_replace_account(
        user_id=23,
        data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        investment_horizon="medium",
        portfolio_code="growth",
        portfolio_label="성장형",
        portfolio_id="stocks-growth-medium-0.18",
        target_volatility=0.18,
        expected_return=0.11,
        volatility=0.16,
        sharpe_ratio=0.84,
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
        initial_cash_amount=3_000_000,
    )

    assert service.list_managed_universe_account_tickers() == ["GLD", "QQQ", "TLT"]
