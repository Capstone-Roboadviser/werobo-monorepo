from __future__ import annotations

from pathlib import Path


def _requirement_names() -> set[str]:
    requirements = Path(__file__).resolve().parents[1] / "requirements.txt"
    names: set[str] = set()
    for raw_line in requirements.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        package = line.split("[", 1)[0]
        for separator in ("==", ">=", "<=", "~=", ">", "<"):
            package = package.split(separator, 1)[0]
        names.add(package.strip().lower())
    return names


def test_news_service_runtime_dependencies_are_declared():
    names = _requirement_names()

    assert "feedparser" in names
    assert "httpx" in names
