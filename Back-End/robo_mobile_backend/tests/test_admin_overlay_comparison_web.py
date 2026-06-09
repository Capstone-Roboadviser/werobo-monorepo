from mobile_backend.admin_overlay_comparison_web import (
    render_admin_overlay_comparison_page,
)


def test_overlay_page_focuses_on_included_vs_excluded_universe() -> None:
    response = render_admin_overlay_comparison_page()
    html = response.body.decode("utf-8")

    assert "넣었을 때와 넣지 않았을 때" in html
    assert "프론티어 전체 비교" in html
    assert "기존 Max Sharpe" in html
    assert "포함 Max Sharpe" in html
    assert "Max Sharpe 개선폭" in html
    assert "Max Sharpe 구성 비교" in html
    assert "자산군 단위" in html
    assert "종목 단위" in html
    assert "max_sharpe_composition" in html
    assert "frontier_comparison" in html
    assert "performance-svg" not in html
    assert "renderPerformanceChart" not in html
    assert "Sharpe 변화" not in html
    assert "균형형 기준" not in html
    assert "안정형" not in html
    assert "균형형" not in html
    assert "성장형" not in html
