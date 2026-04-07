from fastapi import APIRouter

from mobile_backend.api.schemas.response import HealthResponse
from mobile_backend.core.config import APP_NAME, APP_VERSION


router = APIRouter(tags=["system"])


@router.get(
    "/health",
    response_model=HealthResponse,
    summary="헬스체크",
    description="모바일 백엔드 서버가 정상 기동 중인지 확인합니다.",
)
def health_check() -> HealthResponse:
    return HealthResponse(
        status="ok",
        app=APP_NAME,
        version=APP_VERSION,
    )

