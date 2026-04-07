from fastapi import APIRouter

from mobile_backend.admin_web import render_admin_page


router = APIRouter()


@router.get("/admin", include_in_schema=False)
def admin_page():
    return render_admin_page()
