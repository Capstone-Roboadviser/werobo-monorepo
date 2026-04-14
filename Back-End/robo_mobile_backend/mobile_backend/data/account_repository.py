from __future__ import annotations

import json
from contextlib import contextmanager

from app.core.config import DATABASE_URL

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:  # pragma: no cover - optional dependency during local editing
    psycopg = None
    dict_row = None


class PortfolioAccountRepository:
    def __init__(self, database_url: str = DATABASE_URL) -> None:
        self.database_url = database_url

    def is_configured(self) -> bool:
        return bool(self.database_url)

    def initialize(self) -> None:
        if not self.is_configured():
            return

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS portfolio_accounts (
                        id BIGSERIAL PRIMARY KEY,
                        user_id BIGINT NOT NULL UNIQUE REFERENCES auth_users(id) ON DELETE CASCADE,
                        data_source TEXT NOT NULL,
                        investment_horizon TEXT NOT NULL,
                        portfolio_code TEXT NOT NULL,
                        portfolio_label TEXT NOT NULL,
                        portfolio_id TEXT NOT NULL,
                        target_volatility DOUBLE PRECISION NOT NULL,
                        expected_return DOUBLE PRECISION NOT NULL,
                        volatility DOUBLE PRECISION NOT NULL,
                        sharpe_ratio DOUBLE PRECISION NOT NULL,
                        stock_weights JSONB NOT NULL,
                        sector_allocations JSONB NOT NULL DEFAULT '[]'::jsonb,
                        stock_allocations JSONB NOT NULL DEFAULT '[]'::jsonb,
                        started_at DATE NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS portfolio_cash_flows (
                        id BIGSERIAL PRIMARY KEY,
                        account_id BIGINT NOT NULL REFERENCES portfolio_accounts(id) ON DELETE CASCADE,
                        flow_type TEXT NOT NULL,
                        amount DOUBLE PRECISION NOT NULL,
                        effective_date DATE NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS portfolio_daily_snapshots (
                        id BIGSERIAL PRIMARY KEY,
                        account_id BIGINT NOT NULL REFERENCES portfolio_accounts(id) ON DELETE CASCADE,
                        snapshot_date DATE NOT NULL,
                        portfolio_value DOUBLE PRECISION NOT NULL,
                        invested_amount DOUBLE PRECISION NOT NULL,
                        profit_loss DOUBLE PRECISION NOT NULL,
                        cash_balance DOUBLE PRECISION NOT NULL DEFAULT 0,
                        asset_values JSONB NOT NULL DEFAULT '{}'::jsonb,
                        profit_loss_pct DOUBLE PRECISION NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE(account_id, snapshot_date)
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS portfolio_rebalance_cash_ledger (
                        id BIGSERIAL PRIMARY KEY,
                        account_id BIGINT NOT NULL REFERENCES portfolio_accounts(id) ON DELETE CASCADE,
                        rebalance_date DATE NOT NULL,
                        trigger TEXT NOT NULL,
                        cash_before DOUBLE PRECISION NOT NULL DEFAULT 0,
                        cash_from_sales DOUBLE PRECISION NOT NULL DEFAULT 0,
                        cash_to_buys DOUBLE PRECISION NOT NULL DEFAULT 0,
                        cash_after DOUBLE PRECISION NOT NULL DEFAULT 0,
                        net_cash_change DOUBLE PRECISION NOT NULL DEFAULT 0,
                        trades JSONB NOT NULL DEFAULT '{}'::jsonb,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE(account_id, rebalance_date)
                    )
                    """
                )
                cursor.execute(
                    """
                    ALTER TABLE portfolio_daily_snapshots
                    ADD COLUMN IF NOT EXISTS cash_balance DOUBLE PRECISION NOT NULL DEFAULT 0
                    """
                )
                cursor.execute(
                    """
                    ALTER TABLE portfolio_daily_snapshots
                    ADD COLUMN IF NOT EXISTS asset_values JSONB NOT NULL DEFAULT '{}'::jsonb
                    """
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_portfolio_cash_flows_account_id ON portfolio_cash_flows(account_id)"
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_portfolio_cash_flows_effective_date ON portfolio_cash_flows(effective_date)"
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_portfolio_daily_snapshots_account_id ON portfolio_daily_snapshots(account_id)"
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_portfolio_daily_snapshots_snapshot_date ON portfolio_daily_snapshots(snapshot_date)"
                )
                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_portfolio_rebalance_cash_ledger_account_id
                    ON portfolio_rebalance_cash_ledger(account_id)
                    """
                )
                cursor.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_portfolio_rebalance_cash_ledger_rebalance_date
                    ON portfolio_rebalance_cash_ledger(rebalance_date)
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS rebalance_insights (
                        id BIGSERIAL PRIMARY KEY,
                        account_id BIGINT NOT NULL REFERENCES portfolio_accounts(id) ON DELETE CASCADE,
                        rebalance_date DATE NOT NULL,
                        pre_weights JSONB NOT NULL,
                        post_weights JSONB NOT NULL,
                        explanation_text TEXT,
                        read_at TIMESTAMPTZ,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE(account_id, rebalance_date)
                    )
                    """
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_rebalance_insights_account ON rebalance_insights(account_id)"
                )
            connection.commit()

    def replace_account(
        self,
        *,
        user_id: int,
        data_source: str,
        investment_horizon: str,
        portfolio_code: str,
        portfolio_label: str,
        portfolio_id: str,
        target_volatility: float,
        expected_return: float,
        volatility: float,
        sharpe_ratio: float,
        stock_weights: dict[str, float],
        sector_allocations: list[dict[str, object]],
        stock_allocations: list[dict[str, object]],
        started_at: str,
    ) -> dict[str, object]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM portfolio_accounts WHERE user_id = %s", (user_id,))
                cursor.execute(
                    """
                    INSERT INTO portfolio_accounts (
                        user_id,
                        data_source,
                        investment_horizon,
                        portfolio_code,
                        portfolio_label,
                        portfolio_id,
                        target_volatility,
                        expected_return,
                        volatility,
                        sharpe_ratio,
                        stock_weights,
                        sector_allocations,
                        stock_allocations,
                        started_at
                    )
                    VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s::jsonb, %s::jsonb, %s::jsonb, %s::date
                    )
                    RETURNING
                        id,
                        user_id,
                        data_source,
                        investment_horizon,
                        portfolio_code,
                        portfolio_label,
                        portfolio_id,
                        target_volatility,
                        expected_return,
                        volatility,
                        sharpe_ratio,
                        stock_weights,
                        sector_allocations,
                        stock_allocations,
                        TO_CHAR(started_at, 'YYYY-MM-DD') AS started_at,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at
                    """,
                    (
                        user_id,
                        data_source,
                        investment_horizon,
                        portfolio_code,
                        portfolio_label,
                        portfolio_id,
                        target_volatility,
                        expected_return,
                        volatility,
                        sharpe_ratio,
                        json.dumps(stock_weights),
                        json.dumps(sector_allocations),
                        json.dumps(stock_allocations),
                        started_at,
                    ),
                )
                row = cursor.fetchone()
            connection.commit()
        return self._account_from_row(row)

    def get_account_by_user_id(self, user_id: int) -> dict[str, object] | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        user_id,
                        data_source,
                        investment_horizon,
                        portfolio_code,
                        portfolio_label,
                        portfolio_id,
                        target_volatility,
                        expected_return,
                        volatility,
                        sharpe_ratio,
                        stock_weights,
                        sector_allocations,
                        stock_allocations,
                        TO_CHAR(started_at, 'YYYY-MM-DD') AS started_at,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at
                    FROM portfolio_accounts
                    WHERE user_id = %s
                    LIMIT 1
                    """,
                    (user_id,),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return self._account_from_row(row)

    def list_accounts(self, *, data_source: str | None = None) -> list[dict[str, object]]:
        self._ensure_ready()
        query = """
            SELECT
                id,
                user_id,
                data_source,
                investment_horizon,
                portfolio_code,
                portfolio_label,
                portfolio_id,
                target_volatility,
                expected_return,
                volatility,
                sharpe_ratio,
                stock_weights,
                sector_allocations,
                stock_allocations,
                TO_CHAR(started_at, 'YYYY-MM-DD') AS started_at,
                TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
            FROM portfolio_accounts
        """
        params: tuple[object, ...] = ()
        if data_source is not None:
            query += " WHERE data_source = %s"
            params = (data_source,)
        query += " ORDER BY user_id ASC, id ASC"

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(query, params)
                rows = cursor.fetchall()
        return [self._account_from_row(row) for row in rows]

    def add_cash_flow(
        self,
        *,
        account_id: int,
        flow_type: str,
        amount: float,
        effective_date: str,
    ) -> dict[str, object]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO portfolio_cash_flows (
                        account_id,
                        flow_type,
                        amount,
                        effective_date
                    )
                    VALUES (%s, %s, %s, %s::date)
                    RETURNING
                        id,
                        account_id,
                        flow_type,
                        amount,
                        TO_CHAR(effective_date, 'YYYY-MM-DD') AS effective_date,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at
                    """,
                    (account_id, flow_type, amount, effective_date),
                )
                row = cursor.fetchone()
            connection.commit()
        return self._cash_flow_from_row(row)

    def list_cash_flows(self, account_id: int) -> list[dict[str, object]]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        account_id,
                        flow_type,
                        amount,
                        TO_CHAR(effective_date, 'YYYY-MM-DD') AS effective_date,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at
                    FROM portfolio_cash_flows
                    WHERE account_id = %s
                    ORDER BY effective_date ASC, id ASC
                    """,
                    (account_id,),
                )
                rows = cursor.fetchall()
        return [self._cash_flow_from_row(row) for row in rows]

    def replace_snapshots(self, account_id: int, snapshots: list[dict[str, object]]) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM portfolio_daily_snapshots WHERE account_id = %s", (account_id,))
                for snapshot in snapshots:
                    cursor.execute(
                        """
                        INSERT INTO portfolio_daily_snapshots (
                            account_id,
                            snapshot_date,
                            portfolio_value,
                            invested_amount,
                            profit_loss,
                            cash_balance,
                            asset_values,
                            profit_loss_pct
                        )
                        VALUES (%s, %s::date, %s, %s, %s, %s, %s::jsonb, %s)
                        """,
                        (
                            account_id,
                            snapshot["snapshot_date"],
                            snapshot["portfolio_value"],
                            snapshot["invested_amount"],
                            snapshot["profit_loss"],
                            snapshot["cash_balance"],
                            json.dumps(snapshot["asset_values"]),
                            snapshot["profit_loss_pct"],
                        ),
                    )
            connection.commit()

    def list_snapshots(self, account_id: int) -> list[dict[str, object]]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        account_id,
                        TO_CHAR(snapshot_date, 'YYYY-MM-DD') AS snapshot_date,
                        portfolio_value,
                        invested_amount,
                        profit_loss,
                        cash_balance,
                        asset_values,
                        profit_loss_pct,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at
                    FROM portfolio_daily_snapshots
                    WHERE account_id = %s
                    ORDER BY snapshot_date ASC, id ASC
                    """,
                    (account_id,),
                )
                rows = cursor.fetchall()
        return [self._snapshot_from_row(row) for row in rows]

    def replace_rebalance_cash_entries(
        self,
        account_id: int,
        entries: list[dict[str, object]],
    ) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM portfolio_rebalance_cash_ledger WHERE account_id = %s",
                    (account_id,),
                )
                for entry in entries:
                    cursor.execute(
                        """
                        INSERT INTO portfolio_rebalance_cash_ledger (
                            account_id,
                            rebalance_date,
                            trigger,
                            cash_before,
                            cash_from_sales,
                            cash_to_buys,
                            cash_after,
                            net_cash_change,
                            trades
                        )
                        VALUES (
                            %s,
                            %s::date,
                            %s,
                            %s,
                            %s,
                            %s,
                            %s,
                            %s,
                            %s::jsonb
                        )
                        """,
                        (
                            account_id,
                            entry["rebalance_date"],
                            entry["trigger"],
                            entry["cash_before"],
                            entry["cash_from_sales"],
                            entry["cash_to_buys"],
                            entry["cash_after"],
                            entry["net_cash_change"],
                            json.dumps(entry["trades"]),
                        ),
                    )
            connection.commit()

    def list_rebalance_cash_entries(self, account_id: int) -> list[dict[str, object]]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        account_id,
                        TO_CHAR(rebalance_date, 'YYYY-MM-DD') AS rebalance_date,
                        trigger,
                        cash_before,
                        cash_from_sales,
                        cash_to_buys,
                        cash_after,
                        net_cash_change,
                        trades,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    FROM portfolio_rebalance_cash_ledger
                    WHERE account_id = %s
                    ORDER BY rebalance_date DESC, id DESC
                    """,
                    (account_id,),
                )
                rows = cursor.fetchall()
        return [self._rebalance_cash_entry_from_row(row) for row in rows]

    def upsert_rebalance_insight(
        self,
        *,
        account_id: int,
        rebalance_date: str,
        pre_weights: dict[str, float],
        post_weights: dict[str, float],
        explanation_text: str | None = None,
    ) -> dict[str, object]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO rebalance_insights (
                        account_id, rebalance_date, pre_weights, post_weights, explanation_text
                    )
                    VALUES (%s, %s::date, %s::jsonb, %s::jsonb, %s)
                    ON CONFLICT (account_id, rebalance_date) DO UPDATE SET
                        pre_weights = EXCLUDED.pre_weights,
                        post_weights = EXCLUDED.post_weights,
                        explanation_text = EXCLUDED.explanation_text
                    RETURNING
                        id,
                        account_id,
                        TO_CHAR(rebalance_date, 'YYYY-MM-DD') AS rebalance_date,
                        pre_weights,
                        post_weights,
                        explanation_text,
                        read_at,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    """,
                    (
                        account_id,
                        rebalance_date,
                        json.dumps(pre_weights),
                        json.dumps(post_weights),
                        explanation_text,
                    ),
                )
                row = cursor.fetchone()
            connection.commit()
        return self._insight_from_row(row)

    def list_rebalance_insights(self, account_id: int) -> list[dict[str, object]]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        account_id,
                        TO_CHAR(rebalance_date, 'YYYY-MM-DD') AS rebalance_date,
                        pre_weights,
                        post_weights,
                        explanation_text,
                        read_at,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    FROM rebalance_insights
                    WHERE account_id = %s
                    ORDER BY rebalance_date DESC
                    """,
                    (account_id,),
                )
                rows = cursor.fetchall()
        return [self._insight_from_row(row) for row in rows]

    def delete_rebalance_insights(self, account_id: int) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM rebalance_insights WHERE account_id = %s",
                    (account_id,),
                )
            connection.commit()

    def mark_insight_read(self, insight_id: int) -> dict[str, object] | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE rebalance_insights
                    SET read_at = NOW()
                    WHERE id = %s AND read_at IS NULL
                    RETURNING
                        id,
                        account_id,
                        TO_CHAR(rebalance_date, 'YYYY-MM-DD') AS rebalance_date,
                        pre_weights,
                        post_weights,
                        explanation_text,
                        read_at,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    """,
                    (insight_id,),
                )
                row = cursor.fetchone()
            connection.commit()
        if row is None:
            return None
        return self._insight_from_row(row)

    def _ensure_ready(self) -> None:
        if not self.is_configured():
            raise RuntimeError("DATABASE_URL이 설정되지 않아 프로토타입 자산 계정을 사용할 수 없습니다.")

    @contextmanager
    def _connect(self):
        if psycopg is None or dict_row is None:
            raise RuntimeError("psycopg가 설치되지 않아 Postgres에 연결할 수 없습니다.")
        connection = psycopg.connect(self.database_url, row_factory=dict_row)
        try:
            yield connection
        finally:
            connection.close()

    def _account_from_row(self, row: dict[str, object]) -> dict[str, object]:
        stock_weights = row["stock_weights"]
        sector_allocations = row["sector_allocations"]
        stock_allocations = row["stock_allocations"]
        if isinstance(stock_weights, str):
            stock_weights = json.loads(stock_weights)
        if isinstance(sector_allocations, str):
            sector_allocations = json.loads(sector_allocations)
        if isinstance(stock_allocations, str):
            stock_allocations = json.loads(stock_allocations)
        return {
            "id": int(row["id"]),
            "user_id": int(row["user_id"]),
            "data_source": str(row["data_source"]),
            "investment_horizon": str(row["investment_horizon"]),
            "portfolio_code": str(row["portfolio_code"]),
            "portfolio_label": str(row["portfolio_label"]),
            "portfolio_id": str(row["portfolio_id"]),
            "target_volatility": float(row["target_volatility"]),
            "expected_return": float(row["expected_return"]),
            "volatility": float(row["volatility"]),
            "sharpe_ratio": float(row["sharpe_ratio"]),
            "stock_weights": {
                str(key): float(value)
                for key, value in (stock_weights or {}).items()
            },
            "sector_allocations": list(sector_allocations or []),
            "stock_allocations": list(stock_allocations or []),
            "started_at": str(row["started_at"]),
            "created_at": str(row["created_at"]),
            "updated_at": str(row["updated_at"]),
        }

    def _cash_flow_from_row(self, row: dict[str, object]) -> dict[str, object]:
        return {
            "id": int(row["id"]),
            "account_id": int(row["account_id"]),
            "flow_type": str(row["flow_type"]),
            "amount": float(row["amount"]),
            "effective_date": str(row["effective_date"]),
            "created_at": str(row["created_at"]),
        }

    def _snapshot_from_row(self, row: dict[str, object]) -> dict[str, object]:
        asset_values = row["asset_values"]
        if isinstance(asset_values, str):
            asset_values = json.loads(asset_values)
        return {
            "id": int(row["id"]),
            "account_id": int(row["account_id"]),
            "snapshot_date": str(row["snapshot_date"]),
            "portfolio_value": float(row["portfolio_value"]),
            "invested_amount": float(row["invested_amount"]),
            "profit_loss": float(row["profit_loss"]),
            "cash_balance": float(row["cash_balance"]),
            "asset_values": {
                str(key): float(value)
                for key, value in dict(asset_values or {}).items()
            },
            "profit_loss_pct": float(row["profit_loss_pct"]),
            "created_at": str(row["created_at"]),
            "updated_at": str(row["updated_at"]),
        }

    def _insight_from_row(self, row: dict[str, object]) -> dict[str, object]:
        pre_weights = row["pre_weights"]
        post_weights = row["post_weights"]
        if isinstance(pre_weights, str):
            pre_weights = json.loads(pre_weights)
        if isinstance(post_weights, str):
            post_weights = json.loads(post_weights)
        return {
            "id": int(row["id"]),
            "account_id": int(row["account_id"]),
            "rebalance_date": str(row["rebalance_date"]),
            "pre_weights": {str(k): float(v) for k, v in (pre_weights or {}).items()},
            "post_weights": {str(k): float(v) for k, v in (post_weights or {}).items()},
            "explanation_text": row["explanation_text"],
            "is_read": row["read_at"] is not None,
            "created_at": str(row["created_at"]),
        }

    def _rebalance_cash_entry_from_row(
        self,
        row: dict[str, object],
    ) -> dict[str, object]:
        trades = row["trades"]
        if isinstance(trades, str):
            trades = json.loads(trades)
        return {
            "id": int(row["id"]),
            "account_id": int(row["account_id"]),
            "rebalance_date": str(row["rebalance_date"]),
            "trigger": str(row["trigger"]),
            "cash_before": float(row["cash_before"]),
            "cash_from_sales": float(row["cash_from_sales"]),
            "cash_to_buys": float(row["cash_to_buys"]),
            "cash_after": float(row["cash_after"]),
            "net_cash_change": float(row["net_cash_change"]),
            "trades": {
                str(key): float(value)
                for key, value in dict(trades or {}).items()
            },
            "created_at": str(row["created_at"]),
            "updated_at": str(row["updated_at"]),
        }
