from __future__ import annotations

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.config import TARGET_VOLATILITY_MAX, TARGET_VOLATILITY_MIN
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


class FrontierPreviewRequest(ProfileResolutionRequest):
    sample_points: int = Field(
        default=61,
        ge=3,
        le=121,
        description="모바일 차트에 내려줄 frontier preview 포인트 수",
    )


class FrontierSelectionRequest(ProfileResolutionRequest):
    target_volatility: float = Field(
        ...,
        ge=TARGET_VOLATILITY_MIN,
        le=TARGET_VOLATILITY_MAX,
        description="사용자가 차트에서 선택한 목표 변동성",
    )


class VolatilityHistoryRequest(ProfileResolutionRequest):
    rolling_window: int = Field(default=20, ge=5, le=60, description="롤링 변동성 계산 윈도우")


class ComparisonBacktestRequest(BaseModel):
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="비교 백테스트에 사용할 종목 유니버스",
    )


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


class PortfolioAccountStockAllocationRequest(BaseModel):
    ticker: str = Field(..., description="종목 티커")
    name: str = Field(..., description="종목명")
    sector_code: str = Field(..., description="자산군 코드")
    sector_name: str = Field(..., description="자산군 이름")
    weight: float = Field(..., gt=0, description="포트폴리오 내 종목 비중")


class PortfolioAccountSectorAllocationRequest(BaseModel):
    asset_code: str = Field(..., description="자산군 코드")
    asset_name: str = Field(..., description="자산군 이름")
    weight: float = Field(..., ge=0, description="포트폴리오 내 자산군 비중")
    risk_contribution: float = Field(..., ge=0, description="자산군 위험 기여도")


class PortfolioAccountCreateRequest(BaseModel):
    data_source: SimulationDataSource = Field(..., description="계산에 사용한 데이터 소스")
    investment_horizon: InvestmentHorizon = Field(..., description="포트폴리오가 계산된 투자 기간")
    portfolio_code: str = Field(..., description="대표 포트폴리오 코드")
    portfolio_label: str = Field(..., description="대표 포트폴리오 표시 이름")
    portfolio_id: str = Field(..., description="포트폴리오 내부 식별자")
    target_volatility: float = Field(..., ge=0, description="선택된 포트폴리오 목표 변동성")
    expected_return: float = Field(..., description="연 기대수익률")
    volatility: float = Field(..., ge=0, description="연 변동성")
    sharpe_ratio: float = Field(..., description="샤프 비율")
    initial_cash_amount: float = Field(..., gt=0, description="초기 입금 금액")
    sector_allocations: list[PortfolioAccountSectorAllocationRequest] = Field(
        default_factory=list,
        description="자산군 비중 정보",
    )
    stock_allocations: list[PortfolioAccountStockAllocationRequest] = Field(
        ...,
        min_length=1,
        description="종목별 비중 정보",
    )


class PortfolioAccountCashInRequest(BaseModel):
    amount: float = Field(..., gt=0, description="추가 입금 금액")
