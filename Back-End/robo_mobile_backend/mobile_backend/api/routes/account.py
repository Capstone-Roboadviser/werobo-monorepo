from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException

from mobile_backend.api.routes.auth import _extract_bearer_token
from mobile_backend.api.schemas.request import PortfolioAccountCashInRequest, PortfolioAccountCreateRequest
from mobile_backend.api.schemas.response import ErrorResponse, PortfolioAccountDashboardResponse
from mobile_backend.services.account_service import (
    PortfolioAccountConfigurationError,
    PortfolioAccountNotFoundError,
    PortfolioAccountService,
    PortfolioAccountValidationError,
)
from mobile_backend.services.auth_service import AuthService, AuthUnauthorizedError


router = APIRouter(prefix="/api/v1/account", tags=["account"])
account_service = PortfolioAccountService()
auth_service = AuthService()
ACCOUNT_ERROR_RESPONSES = {
    400: {"model": ErrorResponse, "description": "입력값 검증 오류"},
    401: {"model": ErrorResponse, "description": "인증 실패"},
    404: {"model": ErrorResponse, "description": "자산 계정을 찾지 못함"},
    503: {"model": ErrorResponse, "description": "자산 저장소 미구성"},
}


def _current_user_id(authorization: str | None) -> int:
    try:
        access_token = _extract_bearer_token(authorization)
        current_session = auth_service.get_current_session(access_token)
        user = current_session.get("user")
        if not isinstance(user, dict):
            raise HTTPException(status_code=401, detail="유효한 사용자 세션을 찾지 못했습니다.")
        return int(user.get("id", 0))
    except HTTPException:
        raise
    except AuthUnauthorizedError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


def _handle_account_error(exc: Exception) -> None:
    if isinstance(exc, PortfolioAccountValidationError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    if isinstance(exc, PortfolioAccountNotFoundError):
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    if isinstance(exc, PortfolioAccountConfigurationError):
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    raise exc


@router.get(
    "/dashboard",
    response_model=PortfolioAccountDashboardResponse,
    summary="현재 로그인 사용자의 프로토타입 자산 계정 조회",
    description="현재 로그인한 사용자의 포트폴리오 자산 요약, 일별 스냅샷, 최근 활동을 한 번에 반환합니다.",
    responses=ACCOUNT_ERROR_RESPONSES,
)
def get_account_dashboard(
    authorization: str | None = Header(default=None),
) -> PortfolioAccountDashboardResponse:
    user_id = _current_user_id(authorization)
    try:
        return PortfolioAccountDashboardResponse(**account_service.get_dashboard(user_id))
    except Exception as exc:
        _handle_account_error(exc)


@router.post(
    "",
    response_model=PortfolioAccountDashboardResponse,
    summary="프로토타입 자산 계정 생성 또는 교체",
    description="포트폴리오 확정 시점의 종목 비중과 초기 입금액을 저장하고 일별 자산 스냅샷을 생성합니다.",
    responses=ACCOUNT_ERROR_RESPONSES,
)
def create_account(
    payload: PortfolioAccountCreateRequest,
    authorization: str | None = Header(default=None),
) -> PortfolioAccountDashboardResponse:
    user_id = _current_user_id(authorization)
    try:
        return PortfolioAccountDashboardResponse(
            **account_service.create_or_replace_account(
                user_id=user_id,
                data_source=payload.data_source,
                investment_horizon=payload.investment_horizon.value,
                portfolio_code=payload.portfolio_code,
                portfolio_label=payload.portfolio_label,
                portfolio_id=payload.portfolio_id,
                target_volatility=payload.target_volatility,
                expected_return=payload.expected_return,
                volatility=payload.volatility,
                sharpe_ratio=payload.sharpe_ratio,
                stock_allocations=[item.model_dump() for item in payload.stock_allocations],
                sector_allocations=[item.model_dump() for item in payload.sector_allocations],
                initial_cash_amount=payload.initial_cash_amount,
                started_at=None if payload.started_at is None else payload.started_at.isoformat(),
            )
        )
    except Exception as exc:
        _handle_account_error(exc)


@router.post(
    "/cash-in",
    response_model=PortfolioAccountDashboardResponse,
    summary="프로토타입 입금 처리",
    description="실제 계좌 연동 없이 입금 이벤트를 저장하고 일별 자산 스냅샷을 다시 계산합니다.",
    responses=ACCOUNT_ERROR_RESPONSES,
)
def cash_in(
    payload: PortfolioAccountCashInRequest,
    authorization: str | None = Header(default=None),
) -> PortfolioAccountDashboardResponse:
    user_id = _current_user_id(authorization)
    try:
        return PortfolioAccountDashboardResponse(
            **account_service.cash_in(
                user_id=user_id,
                amount=payload.amount,
            )
        )
    except Exception as exc:
        _handle_account_error(exc)
