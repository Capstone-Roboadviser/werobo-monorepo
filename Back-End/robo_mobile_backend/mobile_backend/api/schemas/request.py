from __future__ import annotations

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.config import TARGET_VOLATILITY_MAX, TARGET_VOLATILITY_MIN
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource


class CalculationContextRequest(BaseModel):
    propensity_score: float | None = Field(default=None, ge=0, le=100, description="사용자 투자성향 점수")
    risk_profile: RiskProfile | None = Field(default=None, description="앱이 이미 판정한 위험유형")
    investment_horizon: InvestmentHorizon = Field(default=InvestmentHorizon.MEDIUM, description="투자 기간")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="계산에 사용할 종목 유니버스",
    )


class ProfileResolutionRequest(CalculationContextRequest):
    @model_validator(mode="after")
    def validate_profile_input(self) -> "ProfileResolutionRequest":
        if self.propensity_score is None and self.risk_profile is None:
            raise ValueError("propensity_score 또는 risk_profile 중 하나는 반드시 제공해야 합니다.")
        return self


class RecommendationRequest(ProfileResolutionRequest):
    pass


class FrontierPreviewRequest(ProfileResolutionRequest):
    sample_points: int | None = Field(
        default=None,
        ge=3,
        le=1000,
        description="모바일 차트에 내려줄 frontier preview 포인트 수. 비우면 전체 frontier를 반환합니다.",
    )


class FrontierSelectionRequest(CalculationContextRequest):
    target_volatility: float | None = Field(
        default=None,
        ge=TARGET_VOLATILITY_MIN,
        le=TARGET_VOLATILITY_MAX,
        description="사용자가 차트에서 선택한 목표 변동성",
    )
    selected_point_index: int | None = Field(
        default=None,
        ge=0,
        description="전체 frontier 목록 기준으로 사용자가 선택한 정확한 포인트 인덱스",
    )

    @model_validator(mode="after")
    def validate_frontier_selector(self) -> "FrontierSelectionRequest":
        if self.target_volatility is None and self.selected_point_index is None:
            raise ValueError("target_volatility 또는 selected_point_index 중 하나는 반드시 제공해야 합니다.")
        return self


class VolatilityHistoryRequest(CalculationContextRequest):
    rolling_window: int = Field(default=20, ge=5, le=60, description="롤링 변동성 계산 윈도우")
    target_volatility: float | None = Field(
        default=None,
        ge=TARGET_VOLATILITY_MIN,
        le=TARGET_VOLATILITY_MAX,
        description="연속형 frontier 선택 포인트의 목표 변동성",
    )
    selected_point_index: int | None = Field(
        default=None,
        ge=0,
        description="전체 frontier 목록 기준으로 사용자가 선택한 정확한 포인트 인덱스",
    )

    @model_validator(mode="after")
    def validate_history_selector(self) -> "VolatilityHistoryRequest":
        has_profile_bucket = self.propensity_score is not None or self.risk_profile is not None
        has_frontier_selector = self.target_volatility is not None or self.selected_point_index is not None
        if not has_profile_bucket and not has_frontier_selector:
            raise ValueError(
                "propensity_score, risk_profile, target_volatility, selected_point_index 중 하나는 반드시 제공해야 합니다."
            )
        return self


class ComparisonBacktestRequest(CalculationContextRequest):
    target_volatility: float | None = Field(
        default=None,
        ge=TARGET_VOLATILITY_MIN,
        le=TARGET_VOLATILITY_MAX,
        description="연속형 frontier 선택 포인트의 목표 변동성",
    )
    selected_point_index: int | None = Field(
        default=None,
        ge=0,
        description="전체 frontier 목록 기준으로 사용자가 선택한 정확한 포인트 인덱스",
    )

    @model_validator(mode="after")
    def validate_backtest_selector(self) -> "ComparisonBacktestRequest":
        if self.target_volatility is None and self.selected_point_index is None:
            raise ValueError("target_volatility 또는 selected_point_index 중 하나는 반드시 제공해야 합니다.")
        return self


class SignupRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=40, description="사용자 이름")
    email: str = Field(..., description="로그인에 사용할 이메일")
    password: str = Field(..., min_length=8, max_length=72, description="로그인 비밀번호")

    @field_validator("name", "email", "password")
    @classmethod
    def strip_text_fields(cls, value: str) -> str:
        return value.strip()


class LoginRequest(BaseModel):
    email: str = Field(..., description="로그인 이메일")
    password: str = Field(..., min_length=8, max_length=72, description="로그인 비밀번호")

    @field_validator("email", "password")
    @classmethod
    def strip_login_fields(cls, value: str) -> str:
        return value.strip()
