from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} 환경변수가 필요합니다.")
    return value


def main() -> int:
    base_url = _require_env("BACKEND_BASE_URL").rstrip("/")
    admin_refresh_secret = _require_env("ADMIN_REFRESH_SECRET")
    refresh_mode = os.getenv("REFRESH_MODE", "incremental").strip() or "incremental"
    full_lookback_years = int(os.getenv("FULL_LOOKBACK_YEARS", "5"))

    payload = json.dumps(
        {
            "refresh_mode": refresh_mode,
            "full_lookback_years": full_lookback_years,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}/admin/api/prices/refresh/active",
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-Admin-Secret": admin_refresh_secret,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            body = response.read().decode("utf-8")
            print(body)
            return 0
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(detail, file=sys.stderr)
        return 1
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
