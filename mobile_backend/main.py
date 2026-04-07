from fastapi import FastAPI

from app.services.managed_universe_service import ManagedUniverseService
from mobile_backend.api.router import api_router
from mobile_backend.core.config import APP_DESCRIPTION, APP_NAME, APP_VERSION

app = FastAPI(
    title=APP_NAME,
    description=APP_DESCRIPTION,
    version=APP_VERSION,
    openapi_tags=[
        {"name": "admin", "description": "유니버스와 가격 데이터를 관리하는 간단한 관리자 API"},
        {"name": "system", "description": "시스템 상태 확인용 엔드포인트"},
        {"name": "mobile", "description": "모바일 앱이 직접 호출할 포트폴리오 API"},
    ],
)

app.include_router(api_router)


@app.on_event("startup")
def initialize_managed_universe_storage() -> None:
    ManagedUniverseService().initialize_storage()
