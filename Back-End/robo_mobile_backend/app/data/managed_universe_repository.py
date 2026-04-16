from __future__ import annotations

from contextlib import contextmanager
import json

import pandas as pd

from app.core.config import DATABASE_URL
from app.domain.enums import InvestmentHorizon, PriceRefreshMode, SimulationDataSource
from app.domain.models import (
    DividendYieldEstimate,
    ManagedComparisonBacktestSnapshot,
    ManagedFrontierSnapshot,
    ManagedPriceRefreshJob,
    ManagedPriceRefreshJobItem,
    ManagedUniversePriceWindow,
    ManagedUniverseAssetRoleAssignment,
    ManagedPriceStats,
    ManagedUniverseVersion,
    StockInstrument,
)

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:  # pragma: no cover - optional dependency during local editing
    psycopg = None
    dict_row = None


class ManagedUniverseRepository:
    """Persists admin-managed stock universe snapshots and cumulative prices in Postgres."""

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
                    CREATE TABLE IF NOT EXISTS universe_versions (
                        id BIGSERIAL PRIMARY KEY,
                        version_name TEXT NOT NULL,
                        source_type TEXT NOT NULL,
                        notes TEXT,
                        is_active BOOLEAN NOT NULL DEFAULT FALSE,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS universe_items (
                        id BIGSERIAL PRIMARY KEY,
                        version_id BIGINT NOT NULL REFERENCES universe_versions(id) ON DELETE CASCADE,
                        ticker TEXT NOT NULL,
                        name TEXT NOT NULL,
                        sector_code TEXT NOT NULL,
                        sector_name TEXT NOT NULL,
                        market TEXT NOT NULL,
                        currency TEXT NOT NULL,
                        base_weight DOUBLE PRECISION,
                        UNIQUE (version_id, ticker)
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS universe_asset_roles (
                        version_id BIGINT NOT NULL REFERENCES universe_versions(id) ON DELETE CASCADE,
                        asset_code TEXT NOT NULL,
                        role_key TEXT NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        PRIMARY KEY (version_id, asset_code)
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS price_history (
                        date DATE NOT NULL,
                        ticker TEXT NOT NULL,
                        adjusted_close DOUBLE PRECISION NOT NULL,
                        source TEXT NOT NULL DEFAULT 'unknown',
                        ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        PRIMARY KEY (date, ticker)
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS refresh_jobs (
                        id BIGSERIAL PRIMARY KEY,
                        version_id BIGINT NOT NULL REFERENCES universe_versions(id) ON DELETE CASCADE,
                        refresh_mode TEXT NOT NULL,
                        status TEXT NOT NULL,
                        ticker_count INTEGER NOT NULL DEFAULT 0,
                        message TEXT,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        finished_at TIMESTAMPTZ
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS refresh_job_items (
                        id BIGSERIAL PRIMARY KEY,
                        job_id BIGINT NOT NULL REFERENCES refresh_jobs(id) ON DELETE CASCADE,
                        ticker TEXT NOT NULL,
                        status TEXT NOT NULL,
                        rows_upserted INTEGER NOT NULL DEFAULT 0,
                        error_message TEXT,
                        started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        finished_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS universe_price_windows (
                        version_id BIGINT PRIMARY KEY REFERENCES universe_versions(id) ON DELETE CASCADE,
                        aligned_start_date DATE,
                        aligned_end_date DATE,
                        youngest_ticker TEXT,
                        youngest_start_date DATE,
                        ticker_count INTEGER NOT NULL DEFAULT 0,
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS frontier_snapshots (
                        id BIGSERIAL PRIMARY KEY,
                        version_id BIGINT NOT NULL REFERENCES universe_versions(id) ON DELETE CASCADE,
                        data_source TEXT NOT NULL,
                        investment_horizon TEXT NOT NULL,
                        aligned_start_date DATE,
                        aligned_end_date DATE,
                        total_point_count INTEGER NOT NULL DEFAULT 0,
                        source_refresh_job_id BIGINT REFERENCES refresh_jobs(id) ON DELETE SET NULL,
                        payload JSONB NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE (version_id, data_source, investment_horizon)
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS comparison_backtest_snapshots (
                        id BIGSERIAL PRIMARY KEY,
                        version_id BIGINT NOT NULL REFERENCES universe_versions(id) ON DELETE CASCADE,
                        data_source TEXT NOT NULL,
                        aligned_start_date DATE,
                        aligned_end_date DATE,
                        line_count INTEGER NOT NULL DEFAULT 0,
                        source_refresh_job_id BIGINT REFERENCES refresh_jobs(id) ON DELETE SET NULL,
                        payload JSONB NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE (version_id, data_source)
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS dividend_yield_estimates (
                        ticker TEXT PRIMARY KEY,
                        annualized_dividend DOUBLE PRECISION NOT NULL DEFAULT 0,
                        annual_yield DOUBLE PRECISION NOT NULL DEFAULT 0,
                        payments_per_year INTEGER NOT NULL DEFAULT 0,
                        frequency_label TEXT NOT NULL DEFAULT 'unknown',
                        last_payment_date DATE,
                        source TEXT NOT NULL DEFAULT 'unknown',
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS admin_comparison_snapshots (
                        id BIGSERIAL PRIMARY KEY,
                        name TEXT NOT NULL,
                        folder TEXT,
                        payload JSONB NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cursor.execute(
                    "ALTER TABLE admin_comparison_snapshots ADD COLUMN IF NOT EXISTS folder TEXT"
                )
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_universe_items_version_sector ON universe_items(version_id, sector_code)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_universe_asset_roles_version ON universe_asset_roles(version_id)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_price_history_ticker_date ON price_history(ticker, date)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_refresh_jobs_version_created_at ON refresh_jobs(version_id, created_at DESC)")
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_frontier_snapshots_version_horizon ON frontier_snapshots(version_id, investment_horizon)"
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_comparison_backtest_snapshots_version ON comparison_backtest_snapshots(version_id)"
                )
            connection.commit()

    def list_universe_versions(self) -> list[ManagedUniverseVersion]:
        if not self.is_configured():
            return []

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        v.id,
                        v.version_name,
                        v.source_type,
                        v.notes,
                        v.is_active,
                        TO_CHAR(v.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        COUNT(i.id) AS instrument_count
                    FROM universe_versions v
                    LEFT JOIN universe_items i ON i.version_id = v.id
                    GROUP BY v.id
                    ORDER BY v.id DESC
                    """
                )
                rows = cursor.fetchall()
        return [self._version_from_row(row) for row in rows]

    def get_active_version(self) -> ManagedUniverseVersion | None:
        if not self.is_configured():
            return None

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        v.id,
                        v.version_name,
                        v.source_type,
                        v.notes,
                        v.is_active,
                        TO_CHAR(v.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        COUNT(i.id) AS instrument_count
                    FROM universe_versions v
                    LEFT JOIN universe_items i ON i.version_id = v.id
                    WHERE v.is_active = TRUE
                    GROUP BY v.id
                    ORDER BY v.id DESC
                    LIMIT 1
                    """
                )
                row = cursor.fetchone()
        return None if row is None else self._version_from_row(row)

    def create_universe_version(
        self,
        *,
        version_name: str,
        source_type: str,
        instruments: list[StockInstrument],
        asset_role_assignments: list[ManagedUniverseAssetRoleAssignment] | None = None,
        notes: str | None = None,
        activate: bool = False,
    ) -> ManagedUniverseVersion:
        self._ensure_ready()
        if not instruments:
            raise RuntimeError("비어 있는 종목 유니버스는 저장할 수 없습니다.")

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO universe_versions (version_name, source_type, notes, is_active)
                    VALUES (%s, %s, %s, FALSE)
                    RETURNING id
                    """,
                    (version_name, source_type, notes),
                )
                version_id = int(cursor.fetchone()["id"])
                cursor.executemany(
                    """
                    INSERT INTO universe_items (
                        version_id, ticker, name, sector_code, sector_name, market, currency, base_weight
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    [
                        (
                            version_id,
                            item.ticker,
                            item.name,
                            item.sector_code,
                            item.sector_name,
                            item.market,
                            item.currency,
                            item.base_weight,
                        )
                        for item in instruments
                    ],
                )
                self._insert_asset_role_assignments(
                    cursor,
                    version_id=version_id,
                    asset_role_assignments=asset_role_assignments,
                )
                if activate:
                    cursor.execute("UPDATE universe_versions SET is_active = FALSE")
                    cursor.execute("UPDATE universe_versions SET is_active = TRUE WHERE id = %s", (version_id,))
            connection.commit()

        version = self.get_version(version_id)
        if version is None:
            raise RuntimeError("생성한 유니버스 버전을 다시 읽지 못했습니다.")
        return version

    def get_version(self, version_id: int) -> ManagedUniverseVersion | None:
        if not self.is_configured():
            return None

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        v.id,
                        v.version_name,
                        v.source_type,
                        v.notes,
                        v.is_active,
                        TO_CHAR(v.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        COUNT(i.id) AS instrument_count
                    FROM universe_versions v
                    LEFT JOIN universe_items i ON i.version_id = v.id
                    WHERE v.id = %s
                    GROUP BY v.id
                    """,
                    (version_id,),
                )
                row = cursor.fetchone()
        return None if row is None else self._version_from_row(row)

    def activate_version(self, version_id: int) -> ManagedUniverseVersion:
        self._ensure_ready()
        version = self.get_version(version_id)
        if version is None:
            raise RuntimeError(f"유니버스 버전 {version_id}를 찾을 수 없습니다.")

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("UPDATE universe_versions SET is_active = FALSE")
                cursor.execute("UPDATE universe_versions SET is_active = TRUE WHERE id = %s", (version_id,))
            connection.commit()

        activated = self.get_version(version_id)
        if activated is None:
            raise RuntimeError("활성화한 유니버스 버전을 다시 읽지 못했습니다.")
        return activated

    def update_universe_version(
        self,
        *,
        version_id: int,
        version_name: str,
        instruments: list[StockInstrument],
        asset_role_assignments: list[ManagedUniverseAssetRoleAssignment] | None = None,
        notes: str | None = None,
        activate: bool = False,
    ) -> ManagedUniverseVersion:
        self._ensure_ready()
        current = self.get_version(version_id)
        if current is None:
            raise RuntimeError(f"유니버스 버전 {version_id}를 찾을 수 없습니다.")
        if not instruments:
            raise RuntimeError("비어 있는 종목 유니버스는 저장할 수 없습니다.")

        should_activate = activate or current.is_active
        with self._connect() as connection:
            with connection.cursor() as cursor:
                if should_activate:
                    cursor.execute("UPDATE universe_versions SET is_active = FALSE")
                cursor.execute(
                    """
                    UPDATE universe_versions
                    SET version_name = %s,
                        notes = %s,
                        is_active = %s
                    WHERE id = %s
                    """,
                    (version_name, notes, should_activate, version_id),
                )
                cursor.execute("DELETE FROM universe_price_windows WHERE version_id = %s", (version_id,))
                cursor.execute("DELETE FROM frontier_snapshots WHERE version_id = %s", (version_id,))
                cursor.execute("DELETE FROM universe_items WHERE version_id = %s", (version_id,))
                cursor.execute("DELETE FROM universe_asset_roles WHERE version_id = %s", (version_id,))
                cursor.executemany(
                    """
                    INSERT INTO universe_items (
                        version_id, ticker, name, sector_code, sector_name, market, currency, base_weight
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    [
                        (
                            version_id,
                            item.ticker,
                            item.name,
                            item.sector_code,
                            item.sector_name,
                            item.market,
                            item.currency,
                            item.base_weight,
                        )
                        for item in instruments
                    ],
                )
                self._insert_asset_role_assignments(
                    cursor,
                    version_id=version_id,
                    asset_role_assignments=asset_role_assignments,
                )
            connection.commit()

        updated = self.get_version(version_id)
        if updated is None:
            raise RuntimeError("수정한 유니버스 버전을 다시 읽지 못했습니다.")
        return updated

    def delete_universe_version(self, version_id: int) -> None:
        self._ensure_ready()
        current = self.get_version(version_id)
        if current is None:
            raise RuntimeError(f"유니버스 버전 {version_id}를 찾을 수 없습니다.")

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM universe_versions WHERE id = %s", (version_id,))
            connection.commit()

    def get_active_instruments(self) -> list[StockInstrument]:
        active = self.get_active_version()
        if active is None:
            return []
        return self.get_instruments_for_version(active.version_id)

    def get_instruments_for_version(self, version_id: int) -> list[StockInstrument]:
        if not self.is_configured():
            return []

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT ticker, name, sector_code, sector_name, market, currency, base_weight
                    FROM universe_items
                    WHERE version_id = %s
                    ORDER BY sector_code, ticker
                    """,
                    (version_id,),
                )
                rows = cursor.fetchall()
        return [
            StockInstrument(
                ticker=str(row["ticker"]).strip().upper(),
                name=str(row["name"]),
                sector_code=str(row["sector_code"]),
                sector_name=str(row["sector_name"]),
                market=str(row["market"]),
                currency=str(row["currency"]),
                base_weight=None if row["base_weight"] is None else float(row["base_weight"]),
            )
            for row in rows
        ]

    def get_asset_role_assignments_for_version(self, version_id: int) -> dict[str, str]:
        if not self.is_configured():
            return {}

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT asset_code, role_key
                    FROM universe_asset_roles
                    WHERE version_id = %s
                    ORDER BY asset_code
                    """,
                    (version_id,),
                )
                rows = cursor.fetchall()
        return {
            str(row["asset_code"]): str(row["role_key"])
            for row in rows
        }

    def upsert_prices(self, prices: pd.DataFrame, *, source: str = "unknown") -> int:
        self._ensure_ready()
        if prices.empty:
            return 0

        normalized = prices.copy()
        normalized["date"] = pd.to_datetime(normalized["date"]).dt.date
        normalized["ticker"] = normalized["ticker"].astype(str).str.strip().str.upper()
        normalized["adjusted_close"] = pd.to_numeric(normalized["adjusted_close"], errors="coerce")
        normalized = normalized.dropna(subset=["date", "ticker", "adjusted_close"])
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.executemany(
                    """
                    INSERT INTO price_history (date, ticker, adjusted_close, source)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (date, ticker) DO UPDATE
                    SET adjusted_close = EXCLUDED.adjusted_close,
                        source = EXCLUDED.source,
                        ingested_at = NOW()
                    """,
                    [
                        (row.date, row.ticker, float(row.adjusted_close), source)
                        for row in normalized.itertuples(index=False)
                    ],
                )
            connection.commit()
        return len(normalized)

    def load_prices_for_tickers(
        self,
        tickers: list[str],
        *,
        start_date: str | None = None,
        end_date: str | None = None,
    ) -> pd.DataFrame:
        self._ensure_ready()
        unique_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
        if not unique_tickers:
            return pd.DataFrame(columns=["date", "ticker", "adjusted_close"])

        params: list[object] = [unique_tickers]
        filters = ["UPPER(ticker) = ANY(%s)"]
        if start_date:
            filters.append("date >= %s")
            params.append(start_date)
        if end_date:
            filters.append("date <= %s")
            params.append(end_date)

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT date, UPPER(ticker) AS ticker, adjusted_close
                    FROM price_history
                    WHERE {' AND '.join(filters)}
                    ORDER BY UPPER(ticker), date
                    """,
                    tuple(params),
                )
                rows = cursor.fetchall()
        frame = pd.DataFrame(rows)
        if frame.empty:
            return frame
        frame["ticker"] = frame["ticker"].astype(str).str.strip().str.upper()
        frame["date"] = pd.to_datetime(frame["date"], errors="coerce").dt.normalize()
        frame["adjusted_close"] = pd.to_numeric(frame["adjusted_close"], errors="coerce")
        frame = frame.dropna(subset=["date", "ticker", "adjusted_close"])
        frame = frame.sort_values(["ticker", "date"]).drop_duplicates(subset=["date", "ticker"], keep="last")
        return frame[["date", "ticker", "adjusted_close"]]

    def get_price_stats(
        self,
        tickers: list[str] | None = None,
        *,
        start_date: str | None = None,
        end_date: str | None = None,
    ) -> ManagedPriceStats:
        if not self.is_configured():
            return ManagedPriceStats(total_rows=0, ticker_count=0, min_date=None, max_date=None)

        params: list[object] = []
        where_parts: list[str] = []
        if tickers:
            unique_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
            where_parts.append("UPPER(ticker) = ANY(%s)")
            params.append(unique_tickers)
        if start_date:
            where_parts.append("date >= %s")
            params.append(start_date)
        if end_date:
            where_parts.append("date <= %s")
            params.append(end_date)
        where_clause = f"WHERE {' AND '.join(where_parts)}" if where_parts else ""

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT
                        COUNT(*) AS total_rows,
                        COUNT(DISTINCT UPPER(ticker)) AS ticker_count,
                        MIN(date)::TEXT AS min_date,
                        MAX(date)::TEXT AS max_date
                    FROM price_history
                    {where_clause}
                    """,
                    tuple(params),
                )
                row = cursor.fetchone()
        return ManagedPriceStats(
            total_rows=int(row["total_rows"] or 0),
            ticker_count=int(row["ticker_count"] or 0),
            min_date=None if row["min_date"] is None else str(row["min_date"]),
            max_date=None if row["max_date"] is None else str(row["max_date"]),
        )

    def get_latest_price_dates(self, tickers: list[str]) -> dict[str, str]:
        self._ensure_ready()
        unique_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
        if not unique_tickers:
            return {}

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT UPPER(ticker) AS ticker, MAX(date)::TEXT AS max_date
                    FROM price_history
                    WHERE UPPER(ticker) = ANY(%s)
                    GROUP BY UPPER(ticker)
                    """,
                    (unique_tickers,),
                )
                rows = cursor.fetchall()
        return {str(row["ticker"]): str(row["max_date"]) for row in rows if row["max_date"] is not None}

    def sync_price_window(self, *, version_id: int, tickers: list[str]) -> ManagedUniversePriceWindow | None:
        self._ensure_ready()
        unique_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
        if not unique_tickers:
            self._delete_price_window(version_id)
            return None

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        UPPER(ticker) AS ticker,
                        MIN(date)::TEXT AS min_date,
                        MAX(date)::TEXT AS max_date
                    FROM price_history
                    WHERE UPPER(ticker) = ANY(%s)
                    GROUP BY UPPER(ticker)
                    ORDER BY UPPER(ticker)
                    """,
                    (unique_tickers,),
                )
                rows = cursor.fetchall()

                if not rows:
                    cursor.execute("DELETE FROM universe_price_windows WHERE version_id = %s", (version_id,))
                    connection.commit()
                    return None

                aligned_start_date = max(str(row["min_date"]) for row in rows if row["min_date"] is not None)
                aligned_end_date = min(str(row["max_date"]) for row in rows if row["max_date"] is not None)
                youngest_row = max(
                    rows,
                    key=lambda row: (str(row["min_date"] or ""), str(row["ticker"])),
                )
                cursor.execute(
                    """
                    INSERT INTO universe_price_windows (
                        version_id,
                        aligned_start_date,
                        aligned_end_date,
                        youngest_ticker,
                        youngest_start_date,
                        ticker_count,
                        updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (version_id) DO UPDATE
                    SET aligned_start_date = EXCLUDED.aligned_start_date,
                        aligned_end_date = EXCLUDED.aligned_end_date,
                        youngest_ticker = EXCLUDED.youngest_ticker,
                        youngest_start_date = EXCLUDED.youngest_start_date,
                        ticker_count = EXCLUDED.ticker_count,
                        updated_at = NOW()
                    """,
                    (
                        version_id,
                        aligned_start_date,
                        aligned_end_date,
                        str(youngest_row["ticker"]),
                        str(youngest_row["min_date"]),
                        len(rows),
                    ),
                )
            connection.commit()
        return self.get_price_window(version_id)

    def get_price_window(self, version_id: int) -> ManagedUniversePriceWindow | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        version_id,
                        aligned_start_date::TEXT AS aligned_start_date,
                        aligned_end_date::TEXT AS aligned_end_date,
                        youngest_ticker,
                        youngest_start_date::TEXT AS youngest_start_date,
                        ticker_count
                    FROM universe_price_windows
                    WHERE version_id = %s
                    """,
                    (version_id,),
                )
                row = cursor.fetchone()
        return None if row is None else self._price_window_from_row(row)

    def create_refresh_job(self, *, version_id: int, refresh_mode: PriceRefreshMode, ticker_count: int) -> ManagedPriceRefreshJob:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO refresh_jobs (version_id, refresh_mode, status, ticker_count)
                    VALUES (%s, %s, 'running', %s)
                    RETURNING id
                    """,
                    (version_id, refresh_mode.value, ticker_count),
                )
                job_id = int(cursor.fetchone()["id"])
            connection.commit()
        job = self.get_refresh_job(job_id)
        if job is None:
            raise RuntimeError("생성한 가격 갱신 잡을 다시 읽지 못했습니다.")
        return job

    def record_refresh_job_item(
        self,
        *,
        job_id: int,
        ticker: str,
        status: str,
        rows_upserted: int = 0,
        error_message: str | None = None,
    ) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO refresh_job_items (job_id, ticker, status, rows_upserted, error_message)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    (job_id, ticker, status, rows_upserted, error_message),
                )
            connection.commit()

    def finish_refresh_job(self, *, job_id: int, status: str, message: str | None = None) -> ManagedPriceRefreshJob:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE refresh_jobs
                    SET status = %s,
                        message = %s,
                        finished_at = NOW()
                    WHERE id = %s
                    """,
                    (status, message, job_id),
                )
            connection.commit()
        job = self.get_refresh_job(job_id)
        if job is None:
            raise RuntimeError("완료한 가격 갱신 잡을 다시 읽지 못했습니다.")
        return job

    def get_refresh_job(self, job_id: int) -> ManagedPriceRefreshJob | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        j.id,
                        j.version_id,
                        v.version_name,
                        j.refresh_mode,
                        j.status,
                        j.ticker_count,
                        COALESCE(SUM(CASE WHEN i.status = 'success' THEN 1 ELSE 0 END), 0) AS success_count,
                        COALESCE(SUM(CASE WHEN i.status = 'failed' THEN 1 ELSE 0 END), 0) AS failure_count,
                        j.message,
                        TO_CHAR(j.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(j.started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS started_at,
                        CASE
                            WHEN j.finished_at IS NULL THEN NULL
                            ELSE TO_CHAR(j.finished_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
                        END AS finished_at
                    FROM refresh_jobs j
                    JOIN universe_versions v ON v.id = j.version_id
                    LEFT JOIN refresh_job_items i ON i.job_id = j.id
                    WHERE j.id = %s
                    GROUP BY j.id, v.version_name
                    """,
                    (job_id,),
                )
                row = cursor.fetchone()
        return None if row is None else self._refresh_job_from_row(row)

    def get_latest_refresh_job(self, version_id: int | None = None) -> ManagedPriceRefreshJob | None:
        self._ensure_ready()
        params: tuple[object, ...] = ()
        where_clause = ""
        if version_id is not None:
            where_clause = "WHERE j.version_id = %s"
            params = (version_id,)

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT
                        j.id,
                        j.version_id,
                        v.version_name,
                        j.refresh_mode,
                        j.status,
                        j.ticker_count,
                        COALESCE(SUM(CASE WHEN i.status = 'success' THEN 1 ELSE 0 END), 0) AS success_count,
                        COALESCE(SUM(CASE WHEN i.status = 'failed' THEN 1 ELSE 0 END), 0) AS failure_count,
                        j.message,
                        TO_CHAR(j.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(j.started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS started_at,
                        CASE
                            WHEN j.finished_at IS NULL THEN NULL
                            ELSE TO_CHAR(j.finished_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
                        END AS finished_at
                    FROM refresh_jobs j
                    JOIN universe_versions v ON v.id = j.version_id
                    LEFT JOIN refresh_job_items i ON i.job_id = j.id
                    {where_clause}
                    GROUP BY j.id, v.version_name
                    ORDER BY j.created_at DESC
                    LIMIT 1
                    """,
                    params,
                )
                row = cursor.fetchone()
        return None if row is None else self._refresh_job_from_row(row)

    def get_refresh_job_items(
        self,
        job_id: int,
        *,
        failed_only: bool = False,
        limit: int = 100,
    ) -> list[ManagedPriceRefreshJobItem]:
        self._ensure_ready()
        where_clause = "WHERE job_id = %s"
        params: list[object] = [job_id]
        if failed_only:
            where_clause += " AND status = 'failed'"
        limit = max(1, min(limit, 500))
        params.append(limit)

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                    SELECT
                        job_id,
                        ticker,
                        status,
                        rows_upserted,
                        error_message,
                        TO_CHAR(started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS started_at,
                        TO_CHAR(finished_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS finished_at
                    FROM refresh_job_items
                    {where_clause}
                    ORDER BY
                        CASE WHEN status = 'failed' THEN 0 ELSE 1 END,
                        ticker ASC
                    LIMIT %s
                    """,
                    tuple(params),
                )
                rows = cursor.fetchall()
        return [self._refresh_job_item_from_row(row) for row in rows]

    def upsert_dividend_yield_estimate(
        self,
        estimate: DividendYieldEstimate,
    ) -> DividendYieldEstimate:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO dividend_yield_estimates (
                        ticker,
                        annualized_dividend,
                        annual_yield,
                        payments_per_year,
                        frequency_label,
                        last_payment_date,
                        source,
                        updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (ticker) DO UPDATE
                    SET annualized_dividend = EXCLUDED.annualized_dividend,
                        annual_yield = EXCLUDED.annual_yield,
                        payments_per_year = EXCLUDED.payments_per_year,
                        frequency_label = EXCLUDED.frequency_label,
                        last_payment_date = EXCLUDED.last_payment_date,
                        source = EXCLUDED.source,
                        updated_at = NOW()
                    RETURNING
                        ticker,
                        annualized_dividend,
                        annual_yield,
                        payments_per_year,
                        frequency_label,
                        last_payment_date::TEXT AS last_payment_date,
                        source,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    """,
                    (
                        estimate.ticker,
                        estimate.annualized_dividend,
                        estimate.annual_yield,
                        estimate.payments_per_year,
                        estimate.frequency_label,
                        estimate.last_payment_date,
                        estimate.source,
                    ),
                )
                row = cursor.fetchone()
            connection.commit()
        if row is None:
            raise RuntimeError("dividend yield estimate 저장 결과를 다시 읽지 못했습니다.")
        return self._dividend_yield_estimate_from_row(row)

    def get_dividend_yield_estimate(self, ticker: str) -> DividendYieldEstimate | None:
        normalized = str(ticker).strip().upper()
        return self.get_dividend_yield_estimates([normalized]).get(normalized)

    def get_dividend_yield_estimates(
        self,
        tickers: list[str],
    ) -> dict[str, DividendYieldEstimate]:
        self._ensure_ready()
        normalized_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if str(ticker).strip()})
        if not normalized_tickers:
            return {}

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        ticker,
                        annualized_dividend,
                        annual_yield,
                        payments_per_year,
                        frequency_label,
                        last_payment_date::TEXT AS last_payment_date,
                        source,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    FROM dividend_yield_estimates
                    WHERE ticker = ANY(%s)
                    """,
                    (normalized_tickers,),
                )
                rows = cursor.fetchall()
        return {
            estimate.ticker.upper(): estimate
            for estimate in (self._dividend_yield_estimate_from_row(row) for row in rows)
        }

    def upsert_frontier_snapshot(
        self,
        *,
        version_id: int,
        data_source: str,
        investment_horizon: str,
        aligned_start_date: str | None,
        aligned_end_date: str | None,
        total_point_count: int,
        payload: dict[str, object],
        source_refresh_job_id: int | None = None,
    ) -> ManagedFrontierSnapshot:
        self._ensure_ready()
        payload_json = json.dumps(payload, ensure_ascii=False)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO frontier_snapshots (
                        version_id,
                        data_source,
                        investment_horizon,
                        aligned_start_date,
                        aligned_end_date,
                        total_point_count,
                        source_refresh_job_id,
                        payload,
                        updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, NOW())
                    ON CONFLICT (version_id, data_source, investment_horizon) DO UPDATE
                    SET aligned_start_date = EXCLUDED.aligned_start_date,
                        aligned_end_date = EXCLUDED.aligned_end_date,
                        total_point_count = EXCLUDED.total_point_count,
                        source_refresh_job_id = EXCLUDED.source_refresh_job_id,
                        payload = EXCLUDED.payload,
                        updated_at = NOW()
                    RETURNING
                        id,
                        version_id,
                        data_source,
                        investment_horizon,
                        aligned_start_date::TEXT AS aligned_start_date,
                        aligned_end_date::TEXT AS aligned_end_date,
                        total_point_count,
                        source_refresh_job_id,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    """,
                    (
                        version_id,
                        data_source,
                        investment_horizon,
                        aligned_start_date,
                        aligned_end_date,
                        total_point_count,
                        source_refresh_job_id,
                        payload_json,
                    ),
                )
                row = cursor.fetchone()
            connection.commit()
        if row is None:
            raise RuntimeError("frontier snapshot 저장 결과를 다시 읽지 못했습니다.")
        return self._frontier_snapshot_from_row(row)

    def get_frontier_snapshot(
        self,
        *,
        version_id: int,
        data_source: str,
        investment_horizon: str,
    ) -> ManagedFrontierSnapshot | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        version_id,
                        data_source,
                        investment_horizon,
                        aligned_start_date::TEXT AS aligned_start_date,
                        aligned_end_date::TEXT AS aligned_end_date,
                        total_point_count,
                        source_refresh_job_id,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    FROM frontier_snapshots
                    WHERE version_id = %s
                      AND data_source = %s
                      AND investment_horizon = %s
                    """,
                    (version_id, data_source, investment_horizon),
                )
                row = cursor.fetchone()
        return None if row is None else self._frontier_snapshot_from_row(row)

    def delete_frontier_snapshots(self, version_id: int) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM frontier_snapshots WHERE version_id = %s", (version_id,))
            connection.commit()

    def upsert_comparison_backtest_snapshot(
        self,
        *,
        version_id: int,
        data_source: str,
        aligned_start_date: str | None,
        aligned_end_date: str | None,
        line_count: int,
        payload: dict[str, object],
        source_refresh_job_id: int | None = None,
    ) -> ManagedComparisonBacktestSnapshot:
        self._ensure_ready()
        payload_json = json.dumps(payload, ensure_ascii=False)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO comparison_backtest_snapshots (
                        version_id,
                        data_source,
                        aligned_start_date,
                        aligned_end_date,
                        line_count,
                        source_refresh_job_id,
                        payload,
                        updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, NOW())
                    ON CONFLICT (version_id, data_source) DO UPDATE
                    SET aligned_start_date = EXCLUDED.aligned_start_date,
                        aligned_end_date = EXCLUDED.aligned_end_date,
                        line_count = EXCLUDED.line_count,
                        source_refresh_job_id = EXCLUDED.source_refresh_job_id,
                        payload = EXCLUDED.payload,
                        updated_at = NOW()
                    RETURNING
                        id,
                        version_id,
                        data_source,
                        aligned_start_date::TEXT AS aligned_start_date,
                        aligned_end_date::TEXT AS aligned_end_date,
                        line_count,
                        source_refresh_job_id,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at
                    """,
                    (
                        version_id,
                        data_source,
                        aligned_start_date,
                        aligned_end_date,
                        line_count,
                        source_refresh_job_id,
                        payload_json,
                    ),
                )
                row = cursor.fetchone()
            connection.commit()
        if row is None:
            raise RuntimeError("comparison backtest snapshot 저장 결과를 다시 읽지 못했습니다.")
        return self._comparison_backtest_snapshot_from_row(row)

    def get_comparison_backtest_snapshot(
        self,
        *,
        version_id: int,
        data_source: str,
    ) -> ManagedComparisonBacktestSnapshot | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        version_id,
                        data_source,
                        aligned_start_date::TEXT AS aligned_start_date,
                        aligned_end_date::TEXT AS aligned_end_date,
                        line_count,
                        source_refresh_job_id,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS updated_at
                    FROM comparison_backtest_snapshots
                    WHERE version_id = %s
                      AND data_source = %s
                    """,
                    (version_id, data_source),
                )
                row = cursor.fetchone()
        return None if row is None else self._comparison_backtest_snapshot_from_row(row)

    def delete_comparison_backtest_snapshots(self, version_id: int) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM comparison_backtest_snapshots WHERE version_id = %s", (version_id,))
            connection.commit()

    def is_empty(self) -> bool:
        if not self.is_configured():
            return True

        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        (SELECT COUNT(*) FROM universe_versions) AS version_count,
                        (SELECT COUNT(*) FROM price_history) AS price_count
                    """
                )
                row = cursor.fetchone()
        return int(row["version_count"]) == 0 and int(row["price_count"]) == 0

    @contextmanager
    def _connect(self):
        self._ensure_ready()
        connection = psycopg.connect(self.database_url, row_factory=dict_row)
        try:
            yield connection
        finally:
            connection.close()

    def _ensure_ready(self) -> None:
        if not self.is_configured():
            raise RuntimeError("DATABASE_URL이 설정되지 않아 관리자 유니버스를 사용할 수 없습니다.")
        if psycopg is None or dict_row is None:
            raise RuntimeError("Postgres 연결을 위해 psycopg 패키지가 필요합니다. requirements.txt를 설치하세요.")

    def _version_from_row(self, row: dict) -> ManagedUniverseVersion:
        return ManagedUniverseVersion(
            version_id=int(row["id"]),
            version_name=str(row["version_name"]),
            source_type=str(row["source_type"]),
            notes=None if row["notes"] is None else str(row["notes"]),
            is_active=bool(row["is_active"]),
            created_at=str(row["created_at"]),
            instrument_count=int(row["instrument_count"] or 0),
        )

    def _refresh_job_from_row(self, row: dict) -> ManagedPriceRefreshJob:
        return ManagedPriceRefreshJob(
            job_id=int(row["id"]),
            version_id=int(row["version_id"]),
            version_name=str(row["version_name"]),
            refresh_mode=PriceRefreshMode(str(row["refresh_mode"])),
            status=str(row["status"]),
            ticker_count=int(row["ticker_count"] or 0),
            success_count=int(row["success_count"] or 0),
            failure_count=int(row["failure_count"] or 0),
            message=None if row["message"] is None else str(row["message"]),
            created_at=str(row["created_at"]),
            started_at=None if row["started_at"] is None else str(row["started_at"]),
            finished_at=None if row["finished_at"] is None else str(row["finished_at"]),
        )

    def _refresh_job_item_from_row(self, row: dict) -> ManagedPriceRefreshJobItem:
        return ManagedPriceRefreshJobItem(
            job_id=int(row["job_id"]),
            ticker=str(row["ticker"]),
            status=str(row["status"]),
            rows_upserted=int(row["rows_upserted"] or 0),
            error_message=None if row["error_message"] is None else str(row["error_message"]),
            started_at=None if row["started_at"] is None else str(row["started_at"]),
            finished_at=None if row["finished_at"] is None else str(row["finished_at"]),
        )

    def _dividend_yield_estimate_from_row(self, row: dict) -> DividendYieldEstimate:
        return DividendYieldEstimate(
            ticker=str(row["ticker"]).upper(),
            annualized_dividend=float(row["annualized_dividend"] or 0.0),
            annual_yield=float(row["annual_yield"] or 0.0),
            payments_per_year=int(row["payments_per_year"] or 0),
            frequency_label=str(row["frequency_label"]),
            last_payment_date=None if row["last_payment_date"] is None else str(row["last_payment_date"]),
            source=str(row["source"]),
            updated_at=None if row["updated_at"] is None else str(row["updated_at"]),
        )

    def _price_window_from_row(self, row: dict) -> ManagedUniversePriceWindow:
        return ManagedUniversePriceWindow(
            version_id=int(row["version_id"]),
            aligned_start_date=None if row["aligned_start_date"] is None else str(row["aligned_start_date"]),
            aligned_end_date=None if row["aligned_end_date"] is None else str(row["aligned_end_date"]),
            youngest_ticker=None if row["youngest_ticker"] is None else str(row["youngest_ticker"]),
            youngest_start_date=None if row["youngest_start_date"] is None else str(row["youngest_start_date"]),
            ticker_count=int(row["ticker_count"] or 0),
        )

    def _frontier_snapshot_from_row(self, row: dict) -> ManagedFrontierSnapshot:
        payload = row["payload"]
        if isinstance(payload, str):
            payload = json.loads(payload)
        return ManagedFrontierSnapshot(
            snapshot_id=int(row["id"]),
            version_id=int(row["version_id"]),
            data_source=SimulationDataSource(str(row["data_source"])),
            investment_horizon=InvestmentHorizon(str(row["investment_horizon"])),
            aligned_start_date=None if row["aligned_start_date"] is None else str(row["aligned_start_date"]),
            aligned_end_date=None if row["aligned_end_date"] is None else str(row["aligned_end_date"]),
            total_point_count=int(row["total_point_count"] or 0),
            source_refresh_job_id=None
            if row["source_refresh_job_id"] is None
            else int(row["source_refresh_job_id"]),
            payload=dict(payload),
            created_at=str(row["created_at"]),
            updated_at=str(row["updated_at"]),
        )

    def _comparison_backtest_snapshot_from_row(self, row: dict) -> ManagedComparisonBacktestSnapshot:
        payload = row["payload"]
        if isinstance(payload, str):
            payload = json.loads(payload)
        return ManagedComparisonBacktestSnapshot(
            snapshot_id=int(row["id"]),
            version_id=int(row["version_id"]),
            data_source=SimulationDataSource(str(row["data_source"])),
            aligned_start_date=None if row["aligned_start_date"] is None else str(row["aligned_start_date"]),
            aligned_end_date=None if row["aligned_end_date"] is None else str(row["aligned_end_date"]),
            line_count=int(row["line_count"] or 0),
            source_refresh_job_id=None
            if row["source_refresh_job_id"] is None
            else int(row["source_refresh_job_id"]),
            payload=dict(payload),
            created_at=str(row["created_at"]),
            updated_at=str(row["updated_at"]),
        )

    def _delete_price_window(self, version_id: int) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM universe_price_windows WHERE version_id = %s", (version_id,))
            connection.commit()

    def _insert_asset_role_assignments(
        self,
        cursor,
        *,
        version_id: int,
        asset_role_assignments: list[ManagedUniverseAssetRoleAssignment] | None,
    ) -> None:
        if not asset_role_assignments:
            return

        cursor.executemany(
            """
            INSERT INTO universe_asset_roles (version_id, asset_code, role_key)
            VALUES (%s, %s, %s)
            """,
            [
                (
                    version_id,
                    item.asset_code,
                    item.role_key,
                )
                for item in asset_role_assignments
            ],
        )

    # ── Admin comparison snapshots ──

    def list_admin_comparison_snapshots(self) -> list[dict[str, object]]:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        name,
                        folder,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    FROM admin_comparison_snapshots
                    ORDER BY updated_at DESC
                    """
                )
                rows = cursor.fetchall()
        return [self._admin_comparison_snapshot_from_row(row) for row in rows]

    def get_admin_comparison_snapshot(self, snapshot_id: int) -> dict[str, object] | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        name,
                        folder,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    FROM admin_comparison_snapshots
                    WHERE id = %s
                    """,
                    (snapshot_id,),
                )
                row = cursor.fetchone()
        return None if row is None else self._admin_comparison_snapshot_from_row(row)

    def create_admin_comparison_snapshot(
        self,
        *,
        name: str,
        payload: dict[str, object],
        folder: str | None = None,
    ) -> dict[str, object]:
        self._ensure_ready()
        payload_json = json.dumps(payload, ensure_ascii=False)
        normalized_folder = folder.strip() if folder and folder.strip() else None
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO admin_comparison_snapshots (name, folder, payload)
                    VALUES (%s, %s, %s::jsonb)
                    RETURNING
                        id,
                        name,
                        folder,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    """,
                    (name, normalized_folder, payload_json),
                )
                row = cursor.fetchone()
            connection.commit()
        if row is None:
            raise RuntimeError("admin comparison snapshot 저장 결과를 다시 읽지 못했습니다.")
        return self._admin_comparison_snapshot_from_row(row)

    def update_admin_comparison_snapshot(
        self,
        *,
        snapshot_id: int,
        name: str | None = None,
        payload: dict[str, object] | None = None,
        folder: str | None | object = ...,
    ) -> dict[str, object] | None:
        self._ensure_ready()
        sets: list[str] = []
        values: list[object] = []
        if name is not None:
            sets.append("name = %s")
            values.append(name)
        if payload is not None:
            sets.append("payload = %s::jsonb")
            values.append(json.dumps(payload, ensure_ascii=False))
        if folder is not ...:
            sets.append("folder = %s")
            normalized_folder = (
                folder.strip()
                if isinstance(folder, str) and folder.strip()
                else None
            )
            values.append(normalized_folder)
        if not sets:
            return self.get_admin_comparison_snapshot(snapshot_id)
        sets.append("updated_at = NOW()")
        values.append(snapshot_id)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    f"""
                    UPDATE admin_comparison_snapshots
                    SET {', '.join(sets)}
                    WHERE id = %s
                    RETURNING
                        id,
                        name,
                        folder,
                        payload,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        TO_CHAR(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at
                    """,
                    values,
                )
                row = cursor.fetchone()
            connection.commit()
        return None if row is None else self._admin_comparison_snapshot_from_row(row)

    def delete_admin_comparison_snapshot(self, snapshot_id: int) -> bool:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM admin_comparison_snapshots WHERE id = %s",
                    (snapshot_id,),
                )
                deleted = cursor.rowcount or 0
            connection.commit()
        return deleted > 0

    @staticmethod
    def _admin_comparison_snapshot_from_row(row: dict[str, object]) -> dict[str, object]:
        payload = row["payload"]
        if isinstance(payload, str):
            try:
                payload = json.loads(payload)
            except (TypeError, ValueError):
                payload = {}
        folder_value = row.get("folder")
        return {
            "id": int(row["id"]),
            "name": str(row["name"]),
            "folder": str(folder_value) if folder_value else None,
            "payload": payload if isinstance(payload, dict) else {},
            "created_at": str(row["created_at"]) if row.get("created_at") is not None else None,
            "updated_at": str(row["updated_at"]) if row.get("updated_at") is not None else None,
        }
