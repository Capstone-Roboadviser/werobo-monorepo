from __future__ import annotations

from base64 import urlsafe_b64encode
from datetime import UTC, datetime, timedelta
import hashlib
import hmac
import re
import secrets
import uuid

from mobile_backend.data.auth_repository import AuthRepository
from mobile_backend.domain.auth_models import AuthSessionRecord, AuthUser, AuthUserRecord


_EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_PASSWORD_ITERATIONS = 390000
_SESSION_TTL = timedelta(days=30)
_PASSWORD_PROVIDER = "password"


class AuthValidationError(ValueError):
    pass


class AuthConflictError(RuntimeError):
    pass


class AuthUnauthorizedError(RuntimeError):
    pass


class AuthConfigurationError(RuntimeError):
    pass


class AuthService:
    def __init__(self, repository: AuthRepository | None = None) -> None:
        self.repository = repository or AuthRepository()

    def initialize_storage(self) -> None:
        self.repository.initialize()

    def signup(self, *, email: str, password: str, name: str) -> dict[str, object]:
        self._ensure_storage_ready()
        normalized_email = self._normalize_email(email)
        normalized_name = self._normalize_name(name)
        self._validate_password(password)

        if self.repository.get_user_by_email(normalized_email) is not None:
            raise AuthConflictError("이미 가입된 이메일입니다.")

        password_salt = self._generate_salt()
        password_hash = self._hash_password(password=password, salt=password_salt)
        user = self.repository.create_user(
            email=normalized_email,
            name=normalized_name,
            auth_provider=_PASSWORD_PROVIDER,
            provider_user_id=None,
            password_salt=password_salt,
            password_hash=password_hash,
        )
        session, access_token = self._issue_session(user_id=user.id)
        return self._build_auth_response(user=user, session=session, access_token=access_token)

    def login(self, *, email: str, password: str) -> dict[str, object]:
        self._ensure_storage_ready()
        normalized_email = self._normalize_email(email)
        self._validate_password(password)

        user_record = self.repository.get_user_by_email(normalized_email)
        if user_record is None:
            raise AuthUnauthorizedError("이메일 또는 비밀번호가 올바르지 않습니다.")
        if user_record.provider != _PASSWORD_PROVIDER:
            raise AuthUnauthorizedError("이 계정은 간편로그인 전용 계정입니다. 연결된 제공자로 로그인해 주세요.")
        if user_record.password_salt is None or user_record.password_hash is None:
            raise AuthUnauthorizedError("이 계정은 비밀번호 로그인을 지원하지 않습니다.")
        if not self._verify_password(password=password, user_record=user_record):
            raise AuthUnauthorizedError("이메일 또는 비밀번호가 올바르지 않습니다.")

        user = AuthUser(
            id=user_record.id,
            email=user_record.email,
            name=user_record.name,
            provider=user_record.provider,
            provider_user_id=user_record.provider_user_id,
            created_at=user_record.created_at,
        )
        session, access_token = self._issue_session(user_id=user.id)
        return self._build_auth_response(user=user, session=session, access_token=access_token)

    def get_current_session(self, access_token: str) -> dict[str, object]:
        self._ensure_storage_ready()
        token = access_token.strip()
        if not token:
            raise AuthUnauthorizedError("인증 토큰이 필요합니다.")

        active_session = self.repository.get_active_session(self._hash_token(token))
        if active_session is None:
            raise AuthUnauthorizedError("유효하지 않거나 만료된 인증 토큰입니다.")
        session, user = active_session
        return {
            "authenticated": True,
            "expires_at": session.expires_at,
            "user": self._serialize_user(user),
        }

    def logout(self, access_token: str) -> dict[str, object]:
        self._ensure_storage_ready()
        token = access_token.strip()
        if not token:
            raise AuthUnauthorizedError("인증 토큰이 필요합니다.")
        revoked = self.repository.revoke_session(self._hash_token(token))
        if not revoked:
            raise AuthUnauthorizedError("유효하지 않거나 이미 종료된 세션입니다.")
        return {"status": "ok"}

    def _issue_session(self, *, user_id: int) -> tuple[AuthSessionRecord, str]:
        access_token = self._generate_access_token()
        expires_at = datetime.now(UTC) + _SESSION_TTL
        self.repository.touch_last_login(user_id)
        session = self.repository.create_session(
            session_id=str(uuid.uuid4()),
            user_id=user_id,
            token_hash=self._hash_token(access_token),
            expires_at=expires_at.isoformat().replace("+00:00", "Z"),
        )
        return session, access_token

    def _build_auth_response(
        self,
        *,
        user: AuthUser,
        session: AuthSessionRecord,
        access_token: str,
    ) -> dict[str, object]:
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_at": session.expires_at,
            "user": self._serialize_user(user),
        }

    def _serialize_user(self, user: AuthUser) -> dict[str, object]:
        return {
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "provider": user.provider,
            "created_at": user.created_at,
        }

    def _ensure_storage_ready(self) -> None:
        if not self.repository.is_configured():
            raise AuthConfigurationError("DATABASE_URL이 설정되지 않아 이메일 인증을 사용할 수 없습니다.")

    def _normalize_email(self, email: str) -> str:
        value = email.strip().lower()
        if not value:
            raise AuthValidationError("이메일을 입력해 주세요.")
        if not _EMAIL_PATTERN.match(value):
            raise AuthValidationError("올바른 이메일 형식을 입력해 주세요.")
        return value

    def _normalize_name(self, name: str) -> str:
        value = " ".join(name.strip().split())
        if len(value) < 2:
            raise AuthValidationError("이름은 2자 이상 입력해 주세요.")
        if len(value) > 40:
            raise AuthValidationError("이름은 40자 이하로 입력해 주세요.")
        return value

    def _validate_password(self, password: str) -> None:
        if len(password) < 8:
            raise AuthValidationError("비밀번호는 8자 이상이어야 합니다.")
        if len(password) > 72:
            raise AuthValidationError("비밀번호는 72자 이하로 입력해 주세요.")

    def _verify_password(self, *, password: str, user_record: AuthUserRecord) -> bool:
        if user_record.password_salt is None or user_record.password_hash is None:
            return False
        expected_hash = self._hash_password(password=password, salt=user_record.password_salt)
        return hmac.compare_digest(expected_hash, user_record.password_hash)

    def _generate_salt(self) -> str:
        return urlsafe_b64encode(secrets.token_bytes(16)).decode("ascii")

    def _hash_password(self, *, password: str, salt: str) -> str:
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            _PASSWORD_ITERATIONS,
        )
        return urlsafe_b64encode(digest).decode("ascii")

    def _generate_access_token(self) -> str:
        return secrets.token_urlsafe(32)

    def _hash_token(self, access_token: str) -> str:
        return hashlib.sha256(access_token.encode("utf-8")).hexdigest()
