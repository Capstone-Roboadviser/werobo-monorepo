from __future__ import annotations

from pydantic import BaseModel, Field, model_validator

from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource


class ProfileResolutionRequest(BaseModel):
    propensity_score: float | None = Field(default=None, ge=0, le=100, description="사용자 투자성향 점수")
    risk_profile: RiskProfile | None = Field(default=None, description="앱이 이미 판정한 위험유형")
    investment_horizon: InvestmentHorizon = Field(default=InvestmentHorizon.MEDIUM, description="투자 기간")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="계산에 사용할 종목 유니버스",
    )

    @model_validator(mode="after")
    def validate_profile_input(self) -> "ProfileResolutionRequest":
        if self.propensity_score is None and self.risk_profile is None:
            raise ValueError("propensity_score 또는 risk_profile 중 하나는 반드시 제공해야 합니다.")
        return self


class RecommendationRequest(ProfileResolutionRequest):
    pass


class VolatilityHistoryRequest(ProfileResolutionRequest):
    rolling_window: int = Field(default=20, ge=5, le=60, description="롤링 변동성 계산 윈도우")
    weights: dict[str, float] | None = Field(default=None, description="직접 지정한 종목별 비중 (제공 시 risk_profile 대신 사용)")

    @model_validator(mode="after")
    def validate_profile_input(self) -> "VolatilityHistoryRequest":
        if self.weights is not None:
            return self
        if self.propensity_score is None and self.risk_profile is None:
            raise ValueError("weights, propensity_score, 또는 risk_profile 중 하나는 반드시 제공해야 합니다.")
        return self


class ComparisonBacktestRequest(BaseModel):
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="비교 백테스트에 사용할 종목 유니버스",
    )

