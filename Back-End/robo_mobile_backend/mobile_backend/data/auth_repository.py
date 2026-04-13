from __future__ import annotations

from contextlib import contextmanager

from app.core.config import DATABASE_URL
from mobile_backend.domain.auth_models import AuthSessionRecord, AuthUser, AuthUserRecord

try:
    import psycopg
    from psycopg.rows import dict_row
except ImportError:  # pragma: no cover - optional dependency during local editing
    psycopg = None
    dict_row = None


class AuthRepository:
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
                    CREATE TABLE IF NOT EXISTS auth_users (
                        id BIGSERIAL PRIMARY KEY,
                        email TEXT NOT NULL UNIQUE,
                        name TEXT NOT NULL,
                        auth_provider TEXT NOT NULL DEFAULT 'password',
                        provider_user_id TEXT,
                        password_salt TEXT,
                        password_hash TEXT,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        last_login_at TIMESTAMPTZ
                    )
                    """
                )
                cursor.execute(
                    "ALTER TABLE auth_users ADD COLUMN IF NOT EXISTS auth_provider TEXT NOT NULL DEFAULT 'password'"
                )
                cursor.execute(
                    "ALTER TABLE auth_users ADD COLUMN IF NOT EXISTS provider_user_id TEXT"
                )
                cursor.execute(
                    "ALTER TABLE auth_users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ"
                )
                cursor.execute("ALTER TABLE auth_users ALTER COLUMN password_salt DROP NOT NULL")
                cursor.execute("ALTER TABLE auth_users ALTER COLUMN password_hash DROP NOT NULL")
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS auth_sessions (
                        id UUID PRIMARY KEY,
                        user_id BIGINT NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
                        token_hash TEXT NOT NULL UNIQUE,
                        expires_at TIMESTAMPTZ NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        revoked_at TIMESTAMPTZ
                    )
                    """
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id)"
                )
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires_at ON auth_sessions(expires_at)"
                )
                cursor.execute(
                    """
                    CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_users_provider_identity
                    ON auth_users(auth_provider, provider_user_id)
                    WHERE provider_user_id IS NOT NULL
                    """
                )
            connection.commit()

    def get_user_by_email(self, email: str) -> AuthUserRecord | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        email,
                        name,
                        auth_provider,
                        provider_user_id,
                        password_salt,
                        password_hash,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    FROM auth_users
                    WHERE email = %s
                    LIMIT 1
                    """,
                    (email,),
                )
                row = cursor.fetchone()
        return None if row is None else self._user_record_from_row(row)

    def get_user_by_provider(self, auth_provider: str, provider_user_id: str) -> AuthUserRecord | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        email,
                        name,
                        auth_provider,
                        provider_user_id,
                        password_salt,
                        password_hash,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    FROM auth_users
                    WHERE auth_provider = %s
                      AND provider_user_id = %s
                    LIMIT 1
                    """,
                    (auth_provider, provider_user_id),
                )
                row = cursor.fetchone()
        return None if row is None else self._user_record_from_row(row)

    def get_user_by_id(self, user_id: int) -> AuthUser | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        id,
                        email,
                        name,
                        auth_provider,
                        provider_user_id,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    FROM auth_users
                    WHERE id = %s
                    LIMIT 1
                    """,
                    (user_id,),
                )
                row = cursor.fetchone()
        return None if row is None else self._user_from_row(row)

    def create_user(
        self,
        *,
        email: str,
        name: str,
        auth_provider: str,
        provider_user_id: str | None,
        password_salt: str | None,
        password_hash: str | None,
    ) -> AuthUser:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO auth_users (
                        email, name, auth_provider, provider_user_id, password_salt, password_hash, last_login_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, NOW())
                    RETURNING
                        id,
                        email,
                        name,
                        auth_provider,
                        provider_user_id,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at
                    """,
                    (
                        email,
                        name,
                        auth_provider,
                        provider_user_id,
                        password_salt,
                        password_hash,
                    ),
                )
                row = cursor.fetchone()
            connection.commit()
        return self._user_from_row(row)

    def touch_last_login(self, user_id: int) -> None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE auth_users
                    SET last_login_at = NOW(), updated_at = NOW()
                    WHERE id = %s
                    """,
                    (user_id,),
                )
            connection.commit()

    def create_session(
        self,
        *,
        session_id: str,
        user_id: int,
        token_hash: str,
        expires_at: str,
    ) -> AuthSessionRecord:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO auth_sessions (id, user_id, token_hash, expires_at)
                    VALUES (%s::uuid, %s, %s, %s::timestamptz)
                    RETURNING
                        id::text AS id,
                        user_id,
                        token_hash,
                        TO_CHAR(expires_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS expires_at,
                        TO_CHAR(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        CASE
                            WHEN revoked_at IS NULL THEN NULL
                            ELSE TO_CHAR(revoked_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                        END AS revoked_at
                    """,
                    (session_id, user_id, token_hash, expires_at),
                )
                row = cursor.fetchone()
            connection.commit()
        return self._session_from_row(row)

    def get_active_session(self, token_hash: str) -> tuple[AuthSessionRecord, AuthUser] | None:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        s.id::text AS id,
                        s.user_id,
                        s.token_hash,
                        TO_CHAR(s.expires_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS expires_at,
                        TO_CHAR(s.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at,
                        CASE
                            WHEN s.revoked_at IS NULL THEN NULL
                            ELSE TO_CHAR(s.revoked_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                        END AS revoked_at,
                        u.id AS auth_user_id,
                        u.email,
                        u.name,
                        u.auth_provider,
                        u.provider_user_id,
                        TO_CHAR(u.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS auth_user_created_at
                    FROM auth_sessions s
                    JOIN auth_users u ON u.id = s.user_id
                    WHERE s.token_hash = %s
                      AND s.revoked_at IS NULL
                      AND s.expires_at > NOW()
                    LIMIT 1
                    """,
                    (token_hash,),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        session = AuthSessionRecord(
            id=str(row["id"]),
            user_id=int(row["user_id"]),
            token_hash=str(row["token_hash"]),
            expires_at=str(row["expires_at"]),
            created_at=str(row["created_at"]),
            revoked_at=row["revoked_at"],
        )
        user = AuthUser(
            id=int(row["auth_user_id"]),
            email=str(row["email"]),
            name=str(row["name"]),
            provider=str(row["auth_provider"]),
            provider_user_id=row["provider_user_id"],
            created_at=str(row["auth_user_created_at"]),
        )
        return session, user

    def revoke_session(self, token_hash: str) -> bool:
        self._ensure_ready()
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    UPDATE auth_sessions
                    SET revoked_at = NOW()
                    WHERE token_hash = %s
                      AND revoked_at IS NULL
                    """,
                    (token_hash,),
                )
                updated = cursor.rowcount > 0
            connection.commit()
        return updated

    def _ensure_ready(self) -> None:
        if not self.is_configured():
            raise RuntimeError("DATABASE_URL이 설정되지 않아 인증 저장소를 사용할 수 없습니다.")

    @contextmanager
    def _connect(self):
        if psycopg is None:
            raise RuntimeError("psycopg가 설치되지 않아 Postgres에 연결할 수 없습니다.")
        connection = psycopg.connect(self.database_url, row_factory=dict_row)
        try:
            yield connection
        finally:
            connection.close()

    def _user_record_from_row(self, row: dict[str, object]) -> AuthUserRecord:
        return AuthUserRecord(
            id=int(row["id"]),
            email=str(row["email"]),
            name=str(row["name"]),
            provider=str(row["auth_provider"]),
            provider_user_id=row["provider_user_id"],
            password_salt=row["password_salt"],
            password_hash=row["password_hash"],
            created_at=str(row["created_at"]),
        )

    def _user_from_row(self, row: dict[str, object]) -> AuthUser:
        return AuthUser(
            id=int(row["id"]),
            email=str(row["email"]),
            name=str(row["name"]),
            provider=str(row["auth_provider"]),
            provider_user_id=row["provider_user_id"],
            created_at=str(row["created_at"]),
        )

    def _session_from_row(self, row: dict[str, object]) -> AuthSessionRecord:
        return AuthSessionRecord(
            id=str(row["id"]),
            user_id=int(row["user_id"]),
            token_hash=str(row["token_hash"]),
            expires_at=str(row["expires_at"]),
            created_at=str(row["created_at"]),
            revoked_at=row["revoked_at"],
        )
