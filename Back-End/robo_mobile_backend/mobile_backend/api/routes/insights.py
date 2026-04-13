from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException

from mobile_backend.api.routes.auth import _extract_bearer_token
from mobile_backend.api.schemas.response import (
    ErrorResponse,
    RebalanceInsightAllocationResponse,
    RebalanceInsightResponse,
    RebalanceInsightsListResponse,
)
from mobile_backend.services.account_service import (
    PortfolioAccountNotFoundError,
    PortfolioAccountService,
)
from mobile_backend.services.auth_service import AuthService, AuthUnauthorizedError
from mobile_backend.services.insight_text_service import color_for_sector

router = APIRouter(prefix="/api/v1/insights", tags=["insights"])
account_service = PortfolioAccountService()
auth_service = AuthService()

INSIGHT_ERROR_RESPONSES = {
    401: {"model": ErrorResponse, "description": "인증 실패"},
    404: {"model": ErrorResponse, "description": "자산 계정을 찾지 못함"},
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


def _build_insight_response(insight: dict[str, object]) -> RebalanceInsightResponse:
    pre_weights = dict(insight.get("pre_weights") or {})
    post_weights = dict(insight.get("post_weights") or {})
    all_codes = list(dict.fromkeys(list(pre_weights.keys()) + list(post_weights.keys())))

    allocations = []
    for i, code in enumerate(all_codes):
        before = float(pre_weights.get(code, 0.0))
        after = float(post_weights.get(code, 0.0))
        allocations.append(
            RebalanceInsightAllocationResponse(
                asset_code=code,
                asset_name=code,
                color=color_for_sector(code, i),
                before_pct=round(before, 4),
                after_pct=round(after, 4),
            )
        )

    return RebalanceInsightResponse(
        id=int(insight["id"]),
        rebalance_date=str(insight["rebalance_date"]),
        allocations=allocations,
        explanation_text=insight.get("explanation_text"),
        is_read=bool(insight.get("is_read", False)),
        created_at=str(insight["created_at"]),
    )


@router.get(
    "",
    response_model=RebalanceInsightsListResponse,
    summary="리밸런싱 인사이트 목록 조회",
    description="현재 로그인한 사용자의 포트폴리오 리밸런싱 인사이트를 반환합니다.",
    responses=INSIGHT_ERROR_RESPONSES,
)
def list_insights(
    authorization: str | None = Header(default=None),
) -> RebalanceInsightsListResponse:
    user_id = _current_user_id(authorization)
    try:
        account = account_service.repository.get_account_by_user_id(user_id)
        if account is None:
            return RebalanceInsightsListResponse(insights=[], unread_count=0)

        raw_insights = account_service.repository.list_rebalance_insights(int(account["id"]))
        insights = [_build_insight_response(row) for row in raw_insights]
        unread_count = sum(1 for i in insights if not i.is_read)
        return RebalanceInsightsListResponse(insights=insights, unread_count=unread_count)
    except PortfolioAccountNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/{insight_id}/read",
    response_model=RebalanceInsightResponse,
    summary="리밸런싱 인사이트 읽음 처리",
    description="지정된 인사이트를 읽음으로 표시합니다.",
    responses=INSIGHT_ERROR_RESPONSES,
)
def mark_insight_read(
    insight_id: int,
    authorization: str | None = Header(default=None),
) -> RebalanceInsightResponse:
    _current_user_id(authorization)
    result = account_service.repository.mark_insight_read(insight_id)
    if result is None:
        raise HTTPException(status_code=404, detail="인사이트를 찾지 못했거나 이미 읽음 처리되었습니다.")
    return _build_insight_response(result)
