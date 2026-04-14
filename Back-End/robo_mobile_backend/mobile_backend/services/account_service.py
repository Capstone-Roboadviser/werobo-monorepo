from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from typing import TYPE_CHECKING

import pandas as pd

from app.core.config import DEMO_STOCK_PRICES_PATH
from app.data.stock_repository import StockDataRepository
from app.engine.rebalance import RebalanceEvent, simulate_two_stage_rebalance
from mobile_backend.data.account_repository import PortfolioAccountRepository
from mobile_backend.domain.enums import SimulationDataSource

if TYPE_CHECKING:
    from app.services.portfolio_service import PortfolioSimulationService


class PortfolioAccountValidationError(ValueError):
    pass


class PortfolioAccountConfigurationError(RuntimeError):
    pass


class PortfolioAccountNotFoundError(RuntimeError):
    pass


@dataclass(frozen=True)
class PortfolioAccountSnapshotRefreshStatus:
    status: str
    account_count: int
    success_count: int
    failure_count: int
    failed_user_ids: list[int] = field(default_factory=list)
    message: str | None = None


class PortfolioAccountService:
    def __init__(
        self,
        repository: PortfolioAccountRepository | None = None,
        portfolio_service: "PortfolioSimulationService | None" = None,
    ) -> None:
        self.repository = repository or PortfolioAccountRepository()
        if portfolio_service is None:
            from app.services.portfolio_service import PortfolioSimulationService

            portfolio_service = PortfolioSimulationService()
        self.portfolio_service = portfolio_service

    def initialize_storage(self) -> None:
        self.repository.initialize()

    def get_dashboard(self, user_id: int) -> dict[str, object]:
        self._ensure_storage_ready()
        account = self.repository.get_account_by_user_id(user_id)
        if account is None:
            return {
                "has_account": False,
                "summary": None,
                "history": [],
                "recent_activity": [],
            }
        return self._build_dashboard(account)

    def create_or_replace_account(
        self,
        *,
        user_id: int,
        data_source: SimulationDataSource,
        investment_horizon: str,
        portfolio_code: str,
        portfolio_label: str,
        portfolio_id: str,
        target_volatility: float,
        expected_return: float,
        volatility: float,
        sharpe_ratio: float,
        stock_allocations: list[dict[str, object]],
        sector_allocations: list[dict[str, object]],
        initial_cash_amount: float,
        started_at: str | None = None,
    ) -> dict[str, object]:
        self._ensure_storage_ready()
        if initial_cash_amount <= 0:
            raise PortfolioAccountValidationError("초기 입금 금액은 0보다 커야 합니다.")

        stock_weights = self._normalize_stock_weights(stock_allocations)
        started_at = started_at or datetime.now(UTC).date().isoformat()
        account = self.repository.replace_account(
            user_id=user_id,
            data_source=data_source.value,
            investment_horizon=investment_horizon,
            portfolio_code=portfolio_code,
            portfolio_label=portfolio_label,
            portfolio_id=portfolio_id,
            target_volatility=target_volatility,
            expected_return=expected_return,
            volatility=volatility,
            sharpe_ratio=sharpe_ratio,
            stock_weights=stock_weights,
            sector_allocations=sector_allocations,
            stock_allocations=stock_allocations,
            started_at=started_at,
        )
        self.repository.add_cash_flow(
            account_id=int(account["id"]),
            flow_type="initial_deposit",
            amount=float(initial_cash_amount),
            effective_date=started_at,
        )
        self._refresh_snapshots(account)
        refreshed = self.repository.get_account_by_user_id(user_id)
        if refreshed is None:
            raise PortfolioAccountNotFoundError("생성된 자산 계정을 다시 불러오지 못했습니다.")
        return self._build_dashboard(refreshed)

    def cash_in(
        self,
        *,
        user_id: int,
        amount: float,
    ) -> dict[str, object]:
        self._ensure_storage_ready()
        if amount <= 0:
            raise PortfolioAccountValidationError("입금 금액은 0보다 커야 합니다.")

        account = self.repository.get_account_by_user_id(user_id)
        if account is None:
            raise PortfolioAccountNotFoundError("먼저 포트폴리오를 확정해 자산 계정을 생성해 주세요.")

        self.repository.add_cash_flow(
            account_id=int(account["id"]),
            flow_type="cash_in",
            amount=float(amount),
            effective_date=datetime.now(UTC).date().isoformat(),
        )
        self._refresh_snapshots(account)
        refreshed = self.repository.get_account_by_user_id(user_id)
        if refreshed is None:
            raise PortfolioAccountNotFoundError("입금 후 자산 계정을 다시 불러오지 못했습니다.")
        return self._build_dashboard(refreshed)

    def refresh_managed_universe_accounts(self) -> PortfolioAccountSnapshotRefreshStatus:
        return self.refresh_accounts(data_source=SimulationDataSource.MANAGED_UNIVERSE)

    def list_managed_universe_account_tickers(self) -> list[str]:
        self._ensure_storage_ready()
        tickers: set[str] = set()
        accounts = self.repository.list_accounts(
            data_source=SimulationDataSource.MANAGED_UNIVERSE.value,
        )
        for account in accounts:
            for raw_ticker in dict(account["stock_weights"]).keys():
                ticker = str(raw_ticker).strip().upper()
                if ticker:
                    tickers.add(ticker)
        return sorted(tickers)

    def refresh_accounts(
        self,
        *,
        data_source: SimulationDataSource | None = None,
    ) -> PortfolioAccountSnapshotRefreshStatus:
        self._ensure_storage_ready()
        accounts = self.repository.list_accounts(
            data_source=None if data_source is None else data_source.value,
        )
        if not accounts:
            return PortfolioAccountSnapshotRefreshStatus(
                status="success",
                account_count=0,
                success_count=0,
                failure_count=0,
                message="갱신할 포트폴리오 계정이 없습니다.",
            )

        success_count = 0
        failed_user_ids: list[int] = []
        for account in accounts:
            try:
                self._refresh_snapshots(account)
                success_count += 1
            except Exception:
                failed_user_ids.append(int(account["user_id"]))

        failure_count = len(failed_user_ids)
        if failure_count == 0:
            status = "success"
            message = f"{success_count}개 포트폴리오 계정 snapshot 갱신 완료"
        elif success_count > 0:
            status = "partial_success"
            message = (
                f"{success_count}개 포트폴리오 계정 snapshot 갱신 성공, "
                f"{failure_count}개 실패"
            )
        else:
            status = "failed"
            message = "포트폴리오 계정 snapshot 갱신에 모두 실패했습니다."

        return PortfolioAccountSnapshotRefreshStatus(
            status=status,
            account_count=len(accounts),
            success_count=success_count,
            failure_count=failure_count,
            failed_user_ids=failed_user_ids,
            message=message,
        )

    def _build_dashboard(self, account: dict[str, object]) -> dict[str, object]:
        snapshots = self.repository.list_snapshots(int(account["id"]))
        cash_flows = self.repository.list_cash_flows(int(account["id"]))

        summary = None
        if snapshots:
            latest = snapshots[-1]
            current_sector_allocations, current_stock_allocations = (
                self._build_current_summary_allocations(
                    account=account,
                    latest_snapshot=latest,
                )
            )
            summary = {
                "portfolio_code": account["portfolio_code"],
                "portfolio_label": account["portfolio_label"],
                "portfolio_id": account["portfolio_id"],
                "data_source": account["data_source"],
                "investment_horizon": account["investment_horizon"],
                "target_volatility": account["target_volatility"],
                "expected_return": account["expected_return"],
                "volatility": account["volatility"],
                "sharpe_ratio": account["sharpe_ratio"],
                "started_at": account["started_at"],
                "last_snapshot_date": latest["snapshot_date"],
                "current_value": latest["portfolio_value"],
                "invested_amount": latest["invested_amount"],
                "profit_loss": latest["profit_loss"],
                "cash_balance": float(latest.get("cash_balance", 0.0)),
                "profit_loss_pct": latest["profit_loss_pct"],
                "sector_allocations": current_sector_allocations,
                "stock_allocations": current_stock_allocations,
            }

        history = [
            {
                "date": snapshot["snapshot_date"],
                "portfolio_value": snapshot["portfolio_value"],
                "invested_amount": snapshot["invested_amount"],
                "profit_loss": snapshot["profit_loss"],
                "profit_loss_pct": snapshot["profit_loss_pct"],
            }
            for snapshot in snapshots
        ]

        recent_activity = [
            {
                "type": "portfolio_created",
                "title": "포트폴리오 시작",
                "date": account["started_at"],
                "amount": None,
                "description": f"{account['portfolio_label']} 포트폴리오로 자산 추적 시작",
            }
        ]
        for cash_flow in reversed(cash_flows):
            flow_type = str(cash_flow["flow_type"])
            title = "초기 입금" if flow_type == "initial_deposit" else "입금"
            recent_activity.append(
                {
                    "type": flow_type,
                    "title": title,
                    "date": cash_flow["effective_date"],
                    "amount": cash_flow["amount"],
                    "description": None,
                }
            )

        recent_activity.sort(key=lambda item: str(item["date"]), reverse=True)
        return {
            "has_account": True,
            "summary": summary,
            "history": history,
            "recent_activity": recent_activity[:10],
        }

    def _build_current_summary_allocations(
        self,
        *,
        account: dict[str, object],
        latest_snapshot: dict[str, object],
    ) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
        target_sector_allocations = list(account.get("sector_allocations") or [])
        target_stock_allocations = list(account.get("stock_allocations") or [])
        asset_values = latest_snapshot.get("asset_values")
        if not isinstance(asset_values, dict) or not asset_values:
            return target_sector_allocations, target_stock_allocations

        ticker_meta: dict[str, dict[str, object]] = {}
        sector_meta: dict[str, dict[str, object]] = {}
        sector_order: list[str] = []

        for index, allocation in enumerate(target_sector_allocations):
            asset_code = str(allocation.get("asset_code", "")).strip()
            if not asset_code:
                continue
            sector_meta[asset_code] = {
                "asset_name": str(allocation.get("asset_name", "")).strip() or asset_code,
                "risk_contribution": float(allocation.get("risk_contribution", 0.0)),
                "order": index,
            }
            sector_order.append(asset_code)

        for allocation in target_stock_allocations:
            ticker = str(allocation.get("ticker", "")).strip().upper()
            if not ticker:
                continue
            sector_code = str(allocation.get("sector_code", "")).strip()
            sector_name = str(allocation.get("sector_name", "")).strip()
            ticker_meta[ticker] = {
                "name": str(allocation.get("name", "")).strip() or ticker,
                "sector_code": sector_code or ticker,
                "sector_name": sector_name or sector_code or ticker,
            }
            if sector_code and sector_code not in sector_meta:
                sector_meta[sector_code] = {
                    "asset_name": sector_name or sector_code,
                    "risk_contribution": 0.0,
                    "order": len(sector_order),
                }
                sector_order.append(sector_code)

        non_cash_values: dict[str, float] = {}
        for raw_ticker, raw_value in asset_values.items():
            ticker = str(raw_ticker).strip().upper()
            if ticker == "CASH":
                continue
            value = float(raw_value)
            if value <= 0:
                continue
            non_cash_values[ticker] = value

        total_invested_value = sum(non_cash_values.values())
        if total_invested_value <= 0:
            return target_sector_allocations, target_stock_allocations

        current_stock_allocations: list[dict[str, object]] = []
        sector_values: dict[str, float] = {}
        sector_names: dict[str, str] = {}
        for ticker, value in non_cash_values.items():
            meta = ticker_meta.get(ticker, {})
            sector_code = str(meta.get("sector_code", "")).strip() or ticker
            sector_name = str(meta.get("sector_name", "")).strip() or sector_code
            sector_names[sector_code] = sector_name
            sector_values[sector_code] = sector_values.get(sector_code, 0.0) + value
            current_stock_allocations.append(
                {
                    "ticker": ticker,
                    "name": str(meta.get("name", "")).strip() or ticker,
                    "sector_code": sector_code,
                    "sector_name": sector_name,
                    "weight": round(value / total_invested_value, 6),
                }
            )

        current_stock_allocations.sort(
            key=lambda item: (-float(item["weight"]), str(item["ticker"]))
        )

        ordered_sector_codes = [
            code for code in sector_order if sector_values.get(code, 0.0) > 0
        ]
        remaining_sector_codes = sorted(
            [code for code in sector_values if code not in ordered_sector_codes],
            key=lambda code: (-sector_values[code], code),
        )

        current_sector_allocations: list[dict[str, object]] = []
        for sector_code in ordered_sector_codes + remaining_sector_codes:
            value = sector_values.get(sector_code, 0.0)
            if value <= 0:
                continue
            meta = sector_meta.get(sector_code, {})
            current_sector_allocations.append(
                {
                    "asset_code": sector_code,
                    "asset_name": str(meta.get("asset_name", "")).strip()
                    or sector_names.get(sector_code, sector_code),
                    "weight": round(value / total_invested_value, 6),
                    "risk_contribution": float(meta.get("risk_contribution", 0.0)),
                }
            )

        return current_sector_allocations, current_stock_allocations

    def _refresh_snapshots(self, account: dict[str, object]) -> None:
        stock_weights = {
            str(key): float(value)
            for key, value in dict(account["stock_weights"]).items()
        }
        prices = self._load_price_history(
            tickers=list(stock_weights.keys()),
            data_source=SimulationDataSource(str(account["data_source"])),
        )
        cash_flows = self.repository.list_cash_flows(int(account["id"]))
        snapshots, rebalance_events = self._build_snapshots(
            prices=prices,
            stock_weights=stock_weights,
            cash_flows=cash_flows,
            started_at=str(account["started_at"]),
        )
        self.repository.replace_snapshots(int(account["id"]), snapshots)
        self._replace_rebalance_insights(
            account=account,
            rebalance_events=rebalance_events,
        )

    def _replace_rebalance_insights(
        self,
        *,
        account: dict[str, object],
        rebalance_events: list[RebalanceEvent],
    ) -> None:
        """Replace stored rebalance insights from a shared rebalance simulation."""
        from mobile_backend.services.insight_text_service import (
            NO_CHANGE_EXPLANATION,
            generate_insight_explanation,
        )

        account_id = int(account["id"])
        self.repository.delete_rebalance_insights(account_id)

        stock_allocs = list(account.get("stock_allocations") or [])
        ticker_to_sector_code: dict[str, str] = {}
        ticker_to_sector_name: dict[str, str] = {}
        for alloc in stock_allocs:
            ticker = str(alloc.get("ticker", "")).upper()
            ticker_to_sector_code[ticker] = str(alloc.get("sector_code", ""))
            ticker_to_sector_name[ticker] = str(alloc.get("sector_name", ""))

        for event in rebalance_events:
            sector_pre: dict[str, float] = {}
            sector_post: dict[str, float] = {}
            sector_code_to_name: dict[str, str] = {}
            for ticker, weight in event.pre_weights.items():
                if ticker == "CASH":
                    continue
                code = ticker_to_sector_code.get(ticker, ticker)
                name = ticker_to_sector_name.get(ticker, ticker)
                sector_code_to_name[code] = name
                sector_pre[code] = sector_pre.get(code, 0.0) + weight
            for ticker, weight in event.post_weights.items():
                if ticker == "CASH":
                    continue
                code = ticker_to_sector_code.get(ticker, ticker)
                name = ticker_to_sector_name.get(ticker, ticker)
                sector_code_to_name[code] = name
                sector_post[code] = sector_post.get(code, 0.0) + weight

            explanation = generate_insight_explanation(
                pre_weights=sector_pre,
                post_weights=sector_post,
                sector_names=sector_code_to_name,
            )

            if explanation == NO_CHANGE_EXPLANATION:
                continue

            self.repository.upsert_rebalance_insight(
                account_id=account_id,
                rebalance_date=event.date,
                pre_weights=sector_pre,
                post_weights=sector_post,
                explanation_text=explanation,
            )

    def _load_price_history(
        self,
        *,
        tickers: list[str],
        data_source: SimulationDataSource,
    ) -> pd.DataFrame:
        normalized_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
        if not normalized_tickers:
            raise PortfolioAccountValidationError("종목 비중 정보가 비어 있습니다.")

        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            managed_service = self.portfolio_service.managed_universe_service
            if not managed_service.is_configured():
                raise PortfolioAccountConfigurationError(
                    "관리자 유니버스용 DATABASE_URL이 설정되지 않아 자산 계정을 계산할 수 없습니다."
                )
            prices = managed_service.load_prices_for_active_version_tickers(normalized_tickers)
        elif data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
            prices = StockDataRepository().load_stock_prices(str(DEMO_STOCK_PRICES_PATH))
            prices["ticker"] = prices["ticker"].astype(str).str.upper()
            prices = prices[prices["ticker"].isin(normalized_tickers)].copy()
        else:
            raise PortfolioAccountValidationError("지원하지 않는 데이터 소스입니다.")

        if prices.empty:
            raise PortfolioAccountValidationError("선택한 포트폴리오의 가격 데이터를 찾지 못했습니다.")

        filtered = prices.copy()
        filtered["ticker"] = filtered["ticker"].astype(str).str.upper()
        filtered = filtered[filtered["ticker"].isin(normalized_tickers)]
        if filtered.empty:
            raise PortfolioAccountValidationError("선택한 종목들의 가격 데이터를 찾지 못했습니다.")
        return filtered

    def _build_snapshots(
        self,
        *,
        prices: pd.DataFrame,
        stock_weights: dict[str, float],
        cash_flows: list[dict[str, object]],
        started_at: str,
    ) -> tuple[list[dict[str, float | str]], list[RebalanceEvent]]:
        pivoted = (
            prices.pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last")
            .sort_index()
            .ffill()
        )
        if pivoted.empty:
            raise PortfolioAccountValidationError("가격 데이터로 자산 시계열을 만들지 못했습니다.")

        start_ts = pd.Timestamp(started_at).normalize()
        today_ts = pd.Timestamp(datetime.now(UTC).date())
        full_index = pd.date_range(start=pivoted.index.min(), end=today_ts, freq="D")
        calendar_prices = pivoted.reindex(full_index).ffill()
        calendar_prices = calendar_prices[calendar_prices.index >= start_ts]
        calendar_prices = calendar_prices.dropna(how="any")
        if calendar_prices.empty:
            raise PortfolioAccountValidationError("계좌 시작일 이후 평가 가능한 가격 데이터가 없습니다.")

        normalized_weights = {
            ticker: float(weight)
            for ticker, weight in stock_weights.items()
            if float(weight) > 0
        }
        total_weight = sum(normalized_weights.values())
        if total_weight <= 0:
            raise PortfolioAccountValidationError("포트폴리오 비중 합계가 0입니다.")
        normalized_weights = {
            ticker: weight / total_weight
            for ticker, weight in normalized_weights.items()
        }

        cash_flow_map: dict[str, float] = {}
        for cash_flow in cash_flows:
            effective_date = str(cash_flow["effective_date"])
            cash_flow_map[effective_date] = cash_flow_map.get(effective_date, 0.0) + float(cash_flow["amount"])

        first_snapshot_date = calendar_prices.index[0].strftime("%Y-%m-%d")
        initial_investment = sum(
            amount
            for effective_date, amount in cash_flow_map.items()
            if effective_date <= first_snapshot_date
        )
        if initial_investment <= 0:
            raise PortfolioAccountValidationError("초기 입금이 없어 자산 스냅샷을 만들 수 없습니다.")
        recurring_cash_flows = {
            effective_date: amount
            for effective_date, amount in cash_flow_map.items()
            if effective_date > first_snapshot_date
        }

        simulation = simulate_two_stage_rebalance(
            calendar_prices,
            normalized_weights,
            initial_investment,
            cash_flows=recurring_cash_flows,
            max_points=None,
        )

        invested_amount = initial_investment
        snapshots: list[dict[str, object]] = []
        rebalance_event_by_date = {
            event.date: event for event in simulation.rebalance_events
        }

        for point in simulation.time_series:
            invested_amount += recurring_cash_flows.get(point.date, 0.0)
            portfolio_value = point.total_value
            profit_loss = portfolio_value - invested_amount
            profit_loss_pct = 0.0 if invested_amount <= 0 else profit_loss / invested_amount
            rebalance_event = rebalance_event_by_date.get(point.date)
            if rebalance_event is None:
                asset_values = {
                    str(ticker).upper(): round(float(value), 2)
                    for ticker, value in point.asset_values.items()
                }
            else:
                asset_values = {
                    str(ticker).upper(): round(
                        float(weight) * float(rebalance_event.total_value),
                        2,
                    )
                    for ticker, weight in rebalance_event.post_weights.items()
                }
            cash_balance = float(asset_values.get("CASH", 0.0))
            snapshots.append(
                {
                    "snapshot_date": point.date,
                    "portfolio_value": round(portfolio_value, 2),
                    "invested_amount": round(invested_amount, 2),
                    "profit_loss": round(profit_loss, 2),
                    "cash_balance": round(cash_balance, 2),
                    "asset_values": asset_values,
                    "profit_loss_pct": round(profit_loss_pct, 6),
                }
            )

        return snapshots, simulation.rebalance_events

    def _normalize_stock_weights(
        self,
        stock_allocations: list[dict[str, object]],
    ) -> dict[str, float]:
        weight_map: dict[str, float] = {}
        for allocation in stock_allocations:
            ticker = str(allocation.get("ticker", "")).strip().upper()
            if not ticker:
                continue
            weight = float(allocation.get("weight", 0.0))
            if weight <= 0:
                continue
            weight_map[ticker] = weight_map.get(ticker, 0.0) + weight
        total_weight = sum(weight_map.values())
        if total_weight <= 0:
            raise PortfolioAccountValidationError("종목 비중 정보가 비어 있습니다.")
        return {
            ticker: weight / total_weight
            for ticker, weight in weight_map.items()
        }

    def _ensure_storage_ready(self) -> None:
        if not self.repository.is_configured():
            raise PortfolioAccountConfigurationError(
                "DATABASE_URL이 설정되지 않아 프로토타입 자산 계정을 사용할 수 없습니다."
            )
