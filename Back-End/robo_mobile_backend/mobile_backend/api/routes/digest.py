from __future__ import annotations

import logging

from datetime import date

from fastapi import APIRouter, Header, HTTPException

from mobile_backend.api.routes.auth import _extract_bearer_token
from mobile_backend.api.schemas.digest import (
    DigestResponse,
    RangeDigestRequest,
    RangeDigestResponse,
)
from mobile_backend.api.schemas.response import ErrorResponse
from mobile_backend.services.account_service import (
    PortfolioAccountNotFoundError,
    PortfolioAccountService,
)
from mobile_backend.services.auth_service import AuthService, AuthUnauthorizedError
from mobile_backend.services.digest_service import (
    DigestService,
    InsufficientDataError,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/account", tags=["digest"])
account_service = PortfolioAccountService()
auth_service = AuthService()
digest_service = DigestService()

DIGEST_ERROR_RESPONSES = {
    401: {"model": ErrorResponse, "description": "인증 실패"},
    404: {"model": ErrorResponse, "description": "자산 계정을 찾지 못함"},
    422: {"model": ErrorResponse, "description": "데이터 부족"},
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


@router.get(
    "/digest",
    response_model=DigestResponse,
    summary="포트폴리오 다이제스트 조회",
    description="AI가 생성한 기간별 포트폴리오 성과 분석을 반환합니다. 24시간 캐시, 리밸런싱 시 갱신.",
    responses=DIGEST_ERROR_RESPONSES,
)
def get_digest(
    authorization: str | None = Header(default=None),
) -> DigestResponse:
    user_id = _current_user_id(authorization)
    try:
        account = account_service.repository.get_account_by_user_id(user_id)
        if account is None:
            raise HTTPException(status_code=404, detail="자산 계정을 찾지 못했습니다.")

        digest = digest_service.generate(dict(account))
        return DigestResponse(**digest)
    except InsufficientDataError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except PortfolioAccountNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/digest/range",
    response_model=RangeDigestResponse,
    summary="선택 구간 포트폴리오 다이제스트 생성",
    description="사용자가 차트에서 선택한 구간의 성과 원인을 AI 요약과 참고 뉴스로 반환합니다.",
    responses=DIGEST_ERROR_RESPONSES,
)
def get_range_digest(
    payload: RangeDigestRequest,
    authorization: str | None = Header(default=None),
) -> RangeDigestResponse:
    user_id = _current_user_id(authorization)
    try:
        account = account_service.repository.get_account_by_user_id(user_id)
        if account is None:
            raise HTTPException(status_code=404, detail="자산 계정을 찾지 못했습니다.")

        start_date = date.fromisoformat(payload.start_date)
        end_date = date.fromisoformat(payload.end_date)
        digest = digest_service.generate_range(
            dict(account),
            start_date=start_date,
            end_date=end_date,
            start_value=payload.start_value,
            end_value=payload.end_value,
        )
        return RangeDigestResponse(**digest)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="날짜 형식이 올바르지 않습니다.") from exc
    except InsufficientDataError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except PortfolioAccountNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/digest/cache",
    summary="다이제스트 캐시 삭제",
    description="현재 사용자의 다이제스트 캐시를 삭제하여 다음 요청 시 새로 생성합니다.",
    responses=DIGEST_ERROR_RESPONSES,
)
def bust_digest_cache(
    authorization: str | None = Header(default=None),
) -> dict:
    user_id = _current_user_id(authorization)
    account = account_service.repository.get_account_by_user_id(user_id)
    if account is None:
        raise HTTPException(status_code=404, detail="자산 계정을 찾지 못했습니다.")
    digest_service.digest_repo.bust_cache(int(account["id"]))
    return {"status": "ok"}
