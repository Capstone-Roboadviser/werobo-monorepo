from fastapi import APIRouter

from mobile_backend.admin_comparison_web import render_admin_comparison_page
from mobile_backend.admin_web import render_admin_page


router = APIRouter()


@router.get("/admin", include_in_schema=False)
def admin_page():
    return render_admin_page()


@router.get("/admin/comparison", include_in_schema=False)
def admin_comparison_page():
    return render_admin_comparison_page()
