from __future__ import annotations

# Sector asset_code → hex color (matches Flutter CategoryColors)
SECTOR_COLOR_MAP: dict[str, str] = {
    "us_value": "#20A7DB",
    "value_stock": "#20A7DB",
    "us_growth": "#7B8CDE",
    "growth_stock": "#7B8CDE",
    "new_growth": "#9B7FCC",
    "innovation": "#9B7FCC",
    "short_term_bond": "#3D5A80",
    "bond": "#3D5A80",
    "treasury": "#3D5A80",
    "cash": "#A8D8EA",
    "cash_equivalent": "#A8D8EA",
    "gold": "#293241",
    "commodity_gold": "#293241",
    "infra": "#98C1D9",
    "infrastructure": "#98C1D9",
    "infrastructure_bond": "#98C1D9",
}

# Fallback palette for unknown sector codes
_FALLBACK_COLORS = [
    "#20A7DB", "#3D5A80", "#7B8CDE", "#9B7FCC",
    "#293241", "#A8D8EA", "#98C1D9",
]


def color_for_sector(asset_code: str, index: int = 0) -> str:
    return SECTOR_COLOR_MAP.get(asset_code, _FALLBACK_COLORS[index % len(_FALLBACK_COLORS)])


def generate_insight_explanation(
    pre_weights: dict[str, float],
    post_weights: dict[str, float],
    sector_names: dict[str, str] | None = None,
) -> str:
    """Generate a template-based Korean explanation for a rebalancing event.

    ``sector_names`` maps asset_code → Korean display name.
    ``pre_weights`` and ``post_weights`` map asset_code → weight (0-1 range).
    """
    deltas: list[tuple[str, float, float, float]] = []
    all_codes = set(pre_weights) | set(post_weights)
    for code in all_codes:
        before = pre_weights.get(code, 0.0)
        after = post_weights.get(code, 0.0)
        delta = after - before
        if abs(delta) > 0.001:
            name = (sector_names or {}).get(code, code)
            deltas.append((name, before, after, delta))

    deltas.sort(key=lambda x: abs(x[3]), reverse=True)

    if not deltas:
        return "포트폴리오 비중이 목표와 일치하여 조정이 필요하지 않았어요."

    parts: list[str] = []
    for name, before, after, delta in deltas[:2]:
        before_pct = f"{before * 100:.1f}%"
        after_pct = f"{after * 100:.1f}%"
        if delta > 0:
            parts.append(f"{name} 비중을 {before_pct}에서 {after_pct}로 늘렸어요")
        else:
            parts.append(f"{name} 비중을 {before_pct}에서 {after_pct}로 줄였어요")

    explanation = ", ".join(parts) + "."
    explanation += " 시장 변동으로 목표 비중에서 벗어난 자산군을 조정했어요."
    return explanation
