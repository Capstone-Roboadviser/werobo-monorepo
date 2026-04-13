from __future__ import annotations

import json
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

from app.core.config import DATABASE_URL

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:
    psycopg = None
    dict_row = None


class DigestRepository:
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
                    CREATE TABLE IF NOT EXISTS digest_cache (
                        id BIGSERIAL PRIMARY KEY,
                        account_id BIGINT NOT NULL REFERENCES portfolio_accounts(id) ON DELETE CASCADE,
                        digest_json JSONB NOT NULL,
                        generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        UNIQUE(account_id)
                    )
                    """
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_digest_cache_account ON digest_cache(account_id)"
                )
            connection.commit()

    def get_cached(
        self,
        account_id: int,
        max_age_hours: int = 24,
    ) -> dict | None:
        """Return cached digest if fresh (within max_age and no newer rebalance)."""
        if not self.is_configured():
            return None
        cutoff = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT dc.digest_json, dc.generated_at
                    FROM digest_cache dc
                    WHERE dc.account_id = %s
                      AND dc.generated_at > %s
                      AND NOT EXISTS (
                          SELECT 1 FROM rebalance_insights ri
                          WHERE ri.account_id = dc.account_id
                            AND ri.created_at > dc.generated_at
                      )
                    """,
                    (account_id, cutoff),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        digest_json = row["digest_json"]
        if isinstance(digest_json, str):
            return json.loads(digest_json)
        return dict(digest_json)

    def cache(self, account_id: int, digest: dict) -> None:
        if not self.is_configured():
            return
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO digest_cache (account_id, digest_json, generated_at)
                    VALUES (%s, %s::jsonb, NOW())
                    ON CONFLICT (account_id)
                    DO UPDATE SET digest_json = EXCLUDED.digest_json,
                                  generated_at = NOW()
                    """,
                    (account_id, json.dumps(digest, ensure_ascii=False)),
                )
            connection.commit()

    @contextmanager
    def _connect(self):
        conn = psycopg.connect(self.database_url, row_factory=dict_row)
        try:
            yield conn
        finally:
            conn.close()
