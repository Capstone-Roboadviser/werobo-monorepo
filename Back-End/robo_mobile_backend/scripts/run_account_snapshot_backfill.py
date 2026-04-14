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


def _parse_bool_env(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    normalized = raw.strip().lower()
    return normalized in {"1", "true", "yes", "y", "on"}


def _parse_int_list_env(name: str) -> list[int]:
    raw = os.getenv(name, "").strip()
    if not raw:
        return []
    values: list[int] = []
    for chunk in raw.split(","):
        normalized = chunk.strip()
        if not normalized:
            continue
        values.append(int(normalized))
    return values


def main() -> int:
    base_url = _require_env("BACKEND_BASE_URL").rstrip("/")
    admin_refresh_secret = _require_env("ADMIN_REFRESH_SECRET")
    dry_run = _parse_bool_env("DRY_RUN", True)
    allow_all_matching = _parse_bool_env("ALLOW_ALL_MATCHING", False)

    payload: dict[str, object] = {
        "dry_run": dry_run,
        "data_source": os.getenv("DATA_SOURCE", "managed_universe").strip() or "managed_universe",
        "account_ids": _parse_int_list_env("ACCOUNT_IDS"),
        "user_ids": _parse_int_list_env("USER_IDS"),
        "started_from": os.getenv("STARTED_FROM", "").strip() or None,
        "started_to": os.getenv("STARTED_TO", "").strip() or None,
        "allow_all_matching": allow_all_matching,
    }

    limit_value = os.getenv("LIMIT", "").strip()
    if limit_value:
        payload["limit"] = int(limit_value)
    elif not allow_all_matching:
        payload["limit"] = 50
    else:
        payload["limit"] = None

    request = urllib.request.Request(
        f"{base_url}/admin/api/accounts/snapshots/backfill",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-Admin-Secret": admin_refresh_secret,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=300) as response:
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
