from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query

from mobile_backend.api.schemas.news import (
    AssetClassNewsResponse,
    NewsAssetClass,
)
from mobile_backend.services import news_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/news", tags=["mobile"])


@router.get(
    "/asset-class",
    response_model=AssetClassNewsResponse,
    summary="자산군별 최신 뉴스 1건 조회",
    description=(
        "Yahoo Finance RSS에서 자산군 대표 ETF의 최신 헤드라인 1건을 반환합니다. "
        "서버 측 5분 캐시를 사용합니다."
    ),
)
def get_asset_class_news(
    cls: NewsAssetClass = Query(..., description="자산군 enum 값"),
) -> AssetClassNewsResponse:
    try:
        return news_service.fetch_news(cls)
    except news_service.NewsUnavailableError as exc:
        raise HTTPException(status_code=503, detail="news_unavailable") from exc
