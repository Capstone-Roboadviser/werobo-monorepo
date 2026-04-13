from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException

from mobile_backend.api.schemas.request import LoginRequest, SignupRequest
from mobile_backend.api.schemas.response import (
    AuthCurrentSessionResponse,
    AuthLogoutResponse,
    AuthSessionResponse,
    ErrorResponse,
)
from mobile_backend.services.auth_service import (
    AuthConfigurationError,
    AuthConflictError,
    AuthService,
    AuthUnauthorizedError,
    AuthValidationError,
)


router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
auth_service = AuthService()
AUTH_ERROR_RESPONSES = {
    400: {"model": ErrorResponse, "description": "입력값 검증 오류"},
    401: {"model": ErrorResponse, "description": "인증 실패"},
    409: {"model": ErrorResponse, "description": "이미 존재하는 사용자"},
    503: {"model": ErrorResponse, "description": "인증 저장소 미구성"},
}


def _handle_auth_error(exc: Exception) -> None:
    if isinstance(exc, AuthValidationError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if isinstance(exc, AuthUnauthorizedError):
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    if isinstance(exc, AuthConflictError):
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if isinstance(exc, AuthConfigurationError):
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    raise exc


def _extract_bearer_token(authorization: str | None) -> str:
    if authorization is None:
        raise HTTPException(status_code=401, detail="Authorization 헤더가 필요합니다.")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise HTTPException(status_code=401, detail="Bearer 토큰 형식이 올바르지 않습니다.")
    return token.strip()


@router.post(
    "/signup",
    response_model=AuthSessionResponse,
    summary="이메일 회원가입",
    description="이름, 이메일, 비밀번호로 계정을 생성하고 바로 로그인 세션을 발급합니다.",
    responses=AUTH_ERROR_RESPONSES,
)
def signup(payload: SignupRequest) -> AuthSessionResponse:
    try:
        return AuthSessionResponse(
            **auth_service.signup(
                email=payload.email,
                password=payload.password,
                name=payload.name,
            )
        )
    except Exception as exc:
        _handle_auth_error(exc)


@router.post(
    "/login",
    response_model=AuthSessionResponse,
    summary="이메일 로그인",
    description="이메일과 비밀번호를 검증하고 bearer access token을 발급합니다.",
    responses=AUTH_ERROR_RESPONSES,
)
def login(payload: LoginRequest) -> AuthSessionResponse:
    try:
        return AuthSessionResponse(
            **auth_service.login(
                email=payload.email,
                password=payload.password,
            )
        )
    except Exception as exc:
        _handle_auth_error(exc)


@router.get(
    "/me",
    response_model=AuthCurrentSessionResponse,
    summary="현재 로그인 세션 조회",
    description="Authorization Bearer 토큰을 검증하고 현재 세션과 사용자 정보를 반환합니다.",
    responses=AUTH_ERROR_RESPONSES,
)
def get_current_user(authorization: str | None = Header(default=None)) -> AuthCurrentSessionResponse:
    try:
        access_token = _extract_bearer_token(authorization)
        return AuthCurrentSessionResponse(**auth_service.get_current_session(access_token))
    except HTTPException:
        raise
    except Exception as exc:
        _handle_auth_error(exc)


@router.post(
    "/logout",
    response_model=AuthLogoutResponse,
    summary="현재 세션 로그아웃",
    description="Authorization Bearer 토큰에 해당하는 현재 세션을 종료합니다.",
    responses=AUTH_ERROR_RESPONSES,
)
def logout(authorization: str | None = Header(default=None)) -> AuthLogoutResponse:
    try:
        access_token = _extract_bearer_token(authorization)
        return AuthLogoutResponse(**auth_service.logout(access_token))
    except HTTPException:
        raise
    except Exception as exc:
        _handle_auth_error(exc)
