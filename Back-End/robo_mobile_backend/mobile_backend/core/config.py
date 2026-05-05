import os


APP_NAME = "Robo Mobile Backend"
APP_VERSION = "0.1.0"
APP_DESCRIPTION = (
    "Mobile-only portfolio recommendation backend. "
    "This project exposes a clean mobile API and embeds its own portfolio "
    "calculation core for mobile clients."
)
API_PREFIX = "/api/v1"
ADMIN_REFRESH_SECRET = os.getenv("ADMIN_REFRESH_SECRET", "").strip()
MOBILE_REQUIRE_MANAGED_UNIVERSE_SNAPSHOTS = os.getenv(
    "MOBILE_REQUIRE_MANAGED_UNIVERSE_SNAPSHOTS",
    "true",
).strip().lower() not in {
    "0",
    "false",
    "no",
    "off",
}

PROFILE_LABELS = {
    "conservative": "안정형",
    "balanced": "균형형",
    "growth": "성장형",
}
