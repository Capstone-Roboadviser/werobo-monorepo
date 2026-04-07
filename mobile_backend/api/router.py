from fastapi import APIRouter

from mobile_backend.api.routes.health import router as health_router
from mobile_backend.api.routes.mobile import router as mobile_router


api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(mobile_router)

