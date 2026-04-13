from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class AuthUser:
    id: int
    email: str
    name: str
    provider: str
    provider_user_id: str | None
    created_at: str


@dataclass(frozen=True)
class AuthUserRecord(AuthUser):
    password_salt: str | None
    password_hash: str | None


@dataclass(frozen=True)
class AuthSessionRecord:
    id: str
    user_id: int
    token_hash: str
    expires_at: str
    created_at: str
    revoked_at: str | None = None
