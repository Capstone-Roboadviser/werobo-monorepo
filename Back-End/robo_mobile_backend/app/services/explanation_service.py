from __future__ import annotations

from app.core.config import DISCLAIMER_TEXT
from app.domain.models import AssetClass, FrontierPoint, UserProfile


class ExplanationService:
    def build_summary(
        self,
        selected_point: FrontierPoint,
        target_volatility: float,
        assets: list[AssetClass],
        used_fallback: bool,
    ) -> str:
        asset_names = {asset.code: asset.name for asset in assets}
        top_assets = sorted(selected_point.weights.items(), key=lambda item: item[1], reverse=True)[:2]
        top_text = ", ".join(f"{asset_names[code]} {weight:.0%}" for code, weight in top_assets)
        fallback_text = " 최적화가 불안정해져 대체 포트폴리오를 사용했습니다." if used_fallback else ""
        return (
            f"이 시뮬레이션은 연 {target_volatility:.1%} 수준의 목표 변동성을 기준으로 포트폴리오를 선택했고, "
            f"예상 변동성은 {selected_point.volatility:.1%}, 예상 수익률은 {selected_point.expected_return:.1%}입니다. "
            f"가장 큰 비중은 {top_text}입니다.{fallback_text}"
        )

    def build_explanation(
        self,
        selected_point: FrontierPoint,
        target_volatility: float,
        user_profile: UserProfile,
    ) -> tuple[str, str]:
        title = "왜 이런 포트폴리오가 나왔을까?"
        body = (
            f"입력된 위험 성향은 '{_risk_profile_label(user_profile.risk_profile.value)}', 투자기간은 "
            f"'{_horizon_label(user_profile.investment_horizon.value)}'입니다. "
            f"이 입력을 바탕으로 목표 변동성을 {target_volatility:.1%}로 해석했고, "
            f"효율적 투자선 위에서 그 위험 수준과 가장 가까운 포인트를 선택했습니다. "
            f"선택된 포인트의 예상 수익률은 {selected_point.expected_return:.1%}, "
            f"예상 변동성은 {selected_point.volatility:.1%}입니다."
        )
        return title, body

    def disclaimer(self) -> str:
        return DISCLAIMER_TEXT


def _risk_profile_label(value: str) -> str:
    return {
        "conservative": "안정형",
        "balanced": "균형형",
        "growth": "성장형",
    }[value]


def _horizon_label(value: str) -> str:
    return {
        "short": "단기",
        "medium": "중기",
        "long": "장기",
    }[value]
