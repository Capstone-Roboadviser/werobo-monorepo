from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.services.managed_universe_service import ManagedUniverseService
from mobile_backend.api.router import api_router
from mobile_backend.core.config import APP_DESCRIPTION, APP_NAME, APP_VERSION
from mobile_backend.services.account_service import PortfolioAccountService
from mobile_backend.services.auth_service import AuthService

app = FastAPI(
    title=APP_NAME,
    description=APP_DESCRIPTION,
    version=APP_VERSION,
    openapi_tags=[
        {"name": "account", "description": "프로토타입 자산 계정과 입금 이벤트 API"},
        {"name": "admin", "description": "유니버스와 가격 데이터를 관리하는 간단한 관리자 API"},
        {"name": "auth", "description": "모바일 앱 직접 회원가입/로그인 API"},
        {"name": "system", "description": "시스템 상태 확인용 엔드포인트"},
        {"name": "mobile", "description": "모바일 앱이 직접 호출할 포트폴리오 API"},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.on_event("startup")
def initialize_managed_universe_storage() -> None:
    ManagedUniverseService().initialize_storage()
    AuthService().initialize_storage()
    PortfolioAccountService().initialize_storage()
