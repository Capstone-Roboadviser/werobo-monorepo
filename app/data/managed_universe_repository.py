from __future__ import annotations

from contextlib import contextmanager

import pandas as pd

from app.core.config import DATABASE_URL
from app.domain.enums import PriceRefreshMode
from app.domain.models import (
    ManagedPriceRefreshJob,
    ManagedPriceRefreshJobItem,
    ManagedUniversePriceWindow,
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
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_universe_items_version_sector ON universe_items(version_id, sector_code)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_price_history_ticker_date ON price_history(ticker, date)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_refresh_jobs_version_created_at ON refresh_jobs(version_id, created_at DESC)")
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
                cursor.execute("DELETE FROM universe_items WHERE version_id = %s", (version_id,))
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

    def _price_window_from_row(self, row: dict) -> ManagedUniversePriceWindow:
        return ManagedUniversePriceWindow(
            version_id=int(row["version_id"]),
            aligned_start_date=None if row["aligned_start_date"] is None else str(row["aligned_start_date"]),
            aligned_end_date=None if row["aligned_end_date"] is None else str(row["aligned_end_date"]),
            youngest_ticker=None if row["youngest_ticker"] is None else str(row["youngest_ticker"]),
            youngest_start_date=None if row["youngest_start_date"] is None else str(row["youngest_start_date"]),
            ticker_count=int(row["ticker_count"] or 0),
        )

    def _delete_price_window(self, version_id: int) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("DELETE FROM universe_price_windows WHERE version_id = %s", (version_id,))
            connection.commit()
