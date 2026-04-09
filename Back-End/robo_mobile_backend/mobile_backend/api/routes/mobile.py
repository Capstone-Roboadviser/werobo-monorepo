from __future__ import annotations

from fastapi import APIRouter, HTTPException

from mobile_backend.api.schemas.request import (
    ComparisonBacktestRequest,
    ProfileResolutionRequest,
    RecommendationRequest,
    VolatilityHistoryRequest,
)
from mobile_backend.api.schemas.response import (
    ComparisonBacktestResponse,
    ErrorResponse,
    ProfileResolutionResponse,
    RecommendationResponse,
    VolatilityHistoryResponse,
)
from mobile_backend.services.mobile_portfolio_service import MobilePortfolioService


router = APIRouter(prefix="/api/v1", tags=["mobile"])
mobile_portfolio_service = MobilePortfolioService()
COMMON_ERROR_RESPONSES = {
    400: {
        "model": ErrorResponse,
        "description": "입력값이 잘못되었거나 필수 조건이 충족되지 않았습니다.",
    },
    422: {
        "model": ErrorResponse,
        "description": "계산에 필요한 데이터가 없거나 현재 유니버스 상태로 요청을 처리할 수 없습니다.",
    },
}


def _handle_runtime_error(exc: Exception) -> None:
    if isinstance(exc, ValueError):
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post(
    "/profile/resolve",
    response_model=ProfileResolutionResponse,
    summary="투자성향 판정",
    description="사용자 점수 또는 명시된 위험유형을 기준으로 모바일 표준 위험유형과 목표 변동성을 반환합니다.",
    responses=COMMON_ERROR_RESPONSES,
)
def resolve_profile(payload: ProfileResolutionRequest) -> ProfileResolutionResponse:
    try:
        resolved_profile = mobile_portfolio_service.resolve_profile(
            propensity_score=payload.propensity_score,
            explicit_profile=payload.risk_profile,
            investment_horizon=payload.investment_horizon,
        )
        return ProfileResolutionResponse(resolved_profile=resolved_profile)
    except Exception as exc:
        _handle_runtime_error(exc)


@router.post(
    "/portfolios/recommendation",
    response_model=RecommendationResponse,
    summary="대표 포트폴리오 추천",
    description=(
        "모바일 앱이 바로 사용할 수 있도록 안정형, 균형형, 성장형 3개 대표 포트폴리오와 "
        "사용자에게 매핑된 추천 유형을 한 번에 반환합니다."
    ),
    responses=COMMON_ERROR_RESPONSES,
)
def get_recommendation(payload: RecommendationRequest) -> RecommendationResponse:
    try:
        response = mobile_portfolio_service.build_recommendation(
            propensity_score=payload.propensity_score,
            explicit_profile=payload.risk_profile,
            investment_horizon=payload.investment_horizon,
            data_source=payload.data_source,
        )
        return RecommendationResponse(**response)
    except Exception as exc:
        _handle_runtime_error(exc)


@router.post(
    "/portfolios/volatility-history",
    response_model=VolatilityHistoryResponse,
    summary="포트폴리오 변동성 추이",
    description="선택된 위험유형의 대표 포트폴리오에 대해 과거 실현 변동성 추이를 반환합니다.",
    responses=COMMON_ERROR_RESPONSES,
)
def get_volatility_history(payload: VolatilityHistoryRequest) -> VolatilityHistoryResponse:
    try:
        response = mobile_portfolio_service.build_volatility_history(
            propensity_score=payload.propensity_score,
            explicit_profile=payload.risk_profile,
            investment_horizon=payload.investment_horizon,
            data_source=payload.data_source,
            rolling_window=payload.rolling_window,
            weights=payload.weights,
        )
        return VolatilityHistoryResponse(**response)
    except Exception as exc:
        _handle_runtime_error(exc)


@router.post(
    "/portfolios/comparison-backtest",
    response_model=ComparisonBacktestResponse,
    summary="포트폴리오 유형별 성과 비교",
    description="안정형, 균형형, 성장형 대표 포트폴리오와 벤치마크의 비교 백테스트 결과를 반환합니다.",
    responses=COMMON_ERROR_RESPONSES,
)
def get_comparison_backtest(
    payload: ComparisonBacktestRequest,
) -> ComparisonBacktestResponse:
    try:
        response = mobile_portfolio_service.build_comparison_backtest(
            data_source=payload.data_source,
        )
        return ComparisonBacktestResponse(**response)
    except Exception as exc:
        _handle_runtime_error(exc)
