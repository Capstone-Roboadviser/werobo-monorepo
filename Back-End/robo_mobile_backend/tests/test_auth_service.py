from __future__ import annotations

from mobile_backend.domain.auth_models import AuthSessionRecord, AuthUser, AuthUserRecord
from mobile_backend.services.auth_service import (
    AuthConflictError,
    AuthService,
    AuthUnauthorizedError,
    AuthValidationError,
)


class FakeAuthRepository:
    def __init__(self) -> None:
        self.ready = True
        self.initialized = False
        self._next_user_id = 1
        self.users_by_email: dict[str, AuthUserRecord] = {}
        self.sessions_by_hash: dict[str, tuple[AuthSessionRecord, AuthUser]] = {}

    def is_configured(self) -> bool:
        return self.ready

    def initialize(self) -> None:
        self.initialized = True

    def get_user_by_email(self, email: str) -> AuthUserRecord | None:
        return self.users_by_email.get(email)

    def get_user_by_id(self, user_id: int) -> AuthUser | None:
        for user in self.users_by_email.values():
            if user.id == user_id:
                return AuthUser(
                    id=user.id,
                    email=user.email,
                    name=user.name,
                    provider=user.provider,
                    provider_user_id=user.provider_user_id,
                    created_at=user.created_at,
                )
        return None

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
        user_record = AuthUserRecord(
            id=self._next_user_id,
            email=email,
            name=name,
            provider=auth_provider,
            provider_user_id=provider_user_id,
            password_salt=password_salt,
            password_hash=password_hash,
            created_at="2026-04-13T00:00:00Z",
        )
        self._next_user_id += 1
        self.users_by_email[email] = user_record
        return AuthUser(
            id=user_record.id,
            email=user_record.email,
            name=user_record.name,
            provider=user_record.provider,
            provider_user_id=user_record.provider_user_id,
            created_at=user_record.created_at,
        )

    def create_session(
        self,
        *,
        session_id: str,
        user_id: int,
        token_hash: str,
        expires_at: str,
    ) -> AuthSessionRecord:
        session = AuthSessionRecord(
            id=session_id,
            user_id=user_id,
            token_hash=token_hash,
            expires_at=expires_at,
            created_at="2026-04-13T00:00:00Z",
        )
        user = self.get_user_by_id(user_id)
        assert user is not None
        self.sessions_by_hash[token_hash] = (session, user)
        return session

    def get_active_session(self, token_hash: str) -> tuple[AuthSessionRecord, AuthUser] | None:
        return self.sessions_by_hash.get(token_hash)

    def touch_last_login(self, user_id: int) -> None:
        return None

    def revoke_session(self, token_hash: str) -> bool:
        return self.sessions_by_hash.pop(token_hash, None) is not None


def test_signup_creates_user_and_session() -> None:
    repository = FakeAuthRepository()
    service = AuthService(repository=repository)

    response = service.signup(
        email="User@Example.com",
        password="securepass1",
        name="홍길동",
    )

    assert response["token_type"] == "bearer"
    assert response["user"]["email"] == "user@example.com"
    assert response["user"]["provider"] == "password"
    assert len(repository.sessions_by_hash) == 1


def test_signup_rejects_duplicate_email() -> None:
    repository = FakeAuthRepository()
    service = AuthService(repository=repository)
    service.signup(
        email="user@example.com",
        password="securepass1",
        name="홍길동",
    )

    try:
        service.signup(
            email="user@example.com",
            password="securepass1",
            name="홍길동",
        )
        assert False, "expected AuthConflictError"
    except AuthConflictError:
        pass


def test_login_rejects_wrong_password() -> None:
    repository = FakeAuthRepository()
    service = AuthService(repository=repository)
    service.signup(
        email="user@example.com",
        password="securepass1",
        name="홍길동",
    )

    try:
        service.login(
            email="user@example.com",
            password="wrongpass1",
        )
        assert False, "expected AuthUnauthorizedError"
    except AuthUnauthorizedError:
        pass


def test_get_current_user_from_token() -> None:
    repository = FakeAuthRepository()
    service = AuthService(repository=repository)
    auth_response = service.signup(
        email="user@example.com",
        password="securepass1",
        name="홍길동",
    )

    current_user = service.get_current_session(auth_response["access_token"])

    assert current_user["user"]["name"] == "홍길동"
    assert current_user["authenticated"] is True


def test_logout_revokes_session() -> None:
    repository = FakeAuthRepository()
    service = AuthService(repository=repository)
    auth_response = service.signup(
        email="user@example.com",
        password="securepass1",
        name="홍길동",
    )

    result = service.logout(auth_response["access_token"])

    assert result["status"] == "ok"
    try:
        service.get_current_session(auth_response["access_token"])
        assert False, "expected AuthUnauthorizedError"
    except AuthUnauthorizedError:
        pass


def test_password_validation_requires_minimum_length() -> None:
    repository = FakeAuthRepository()
    service = AuthService(repository=repository)

    try:
        service.signup(
            email="user@example.com",
            password="short",
            name="홍길동",
        )
        assert False, "expected AuthValidationError"
    except AuthValidationError:
        pass
