from fastapi import APIRouter

from mobile_backend.api.routes.admin import router as admin_router
from mobile_backend.api.routes.admin_web import router as admin_web_router
from mobile_backend.api.routes.auth import router as auth_router
from mobile_backend.api.routes.health import router as health_router
from mobile_backend.api.routes.mobile import router as mobile_router


api_router = APIRouter()
api_router.include_router(admin_web_router)
api_router.include_router(admin_router)
api_router.include_router(auth_router)
api_router.include_router(health_router)
api_router.include_router(mobile_router)
