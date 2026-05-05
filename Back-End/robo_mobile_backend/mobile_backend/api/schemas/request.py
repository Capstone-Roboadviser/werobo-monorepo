from __future__ import annotations

from datetime import date

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
    stock_weights: dict[str, float] | None = Field(
        default=None,
        description="선택 포트폴리오의 종목 비중 맵. 주어지면 이 비중으로 변동성 추이를 계산합니다.",
    )
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
        has_stock_weights = bool(self.stock_weights)
        if not has_profile_bucket and not has_frontier_selector and not has_stock_weights:
            raise ValueError(
                "propensity_score, risk_profile, target_volatility, selected_point_index, stock_weights 중 하나는 반드시 제공해야 합니다."
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
    stock_weights: dict[str, float] | None = Field(
        default=None,
        description="현재 선택 포트폴리오의 종목 비중 맵. 주어지면 이 비중을 고정한 과거 백테스트를 계산합니다.",
    )
    portfolio_code: str | None = Field(
        default=None,
        description="현재 선택 포트폴리오 코드. 없으면 `selected` 라인 키를 사용합니다.",
    )
    start_date: date | None = Field(
        default=None,
        description="비교 백테스트 시작일 (YYYY-MM-DD). 계정 성과 비교에서는 포트폴리오 시작일을 전달합니다.",
    )

    @model_validator(mode="after")
    def validate_backtest_selector(self) -> "ComparisonBacktestRequest":
        has_frontier_selector = self.target_volatility is not None or self.selected_point_index is not None
        has_stock_weights = bool(self.stock_weights)
        if not has_frontier_selector and not has_stock_weights:
            raise ValueError("target_volatility, selected_point_index, stock_weights 중 하나는 반드시 제공해야 합니다.")
        return self


class EarningsHistoryRequest(BaseModel):
    weights: dict[str, float] = Field(..., description="종목별 비중 (ticker -> weight)")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="가격 데이터 소스",
    )
    start_date: str = Field(..., description="투자 시작일 (YYYY-MM-DD)")
    investment_amount: float = Field(default=10_000_000, gt=0, description="투자 금액 (원)")


class SectorAllocationRequest(BaseModel):
    asset_code: str = Field(..., min_length=1, description="자산군 코드")
    asset_name: str = Field(..., min_length=1, description="자산군 이름")
    weight: float = Field(..., ge=0, description="포트폴리오 내 자산군 비중")
    risk_contribution: float = Field(default=0, ge=0, description="전체 변동성 대비 위험기여도")

    @field_validator("asset_code", "asset_name")
    @classmethod
    def strip_sector_text_fields(cls, value: str) -> str:
        return value.strip()


class StockAllocationRequest(BaseModel):
    ticker: str = Field(..., min_length=1, description="종목 티커")
    name: str = Field(..., min_length=1, description="종목명")
    sector_code: str = Field(..., min_length=1, description="소속 자산군 코드")
    sector_name: str = Field(..., min_length=1, description="소속 자산군 이름")
    weight: float = Field(..., ge=0, description="포트폴리오 내 개별 종목 비중")

    @field_validator("ticker", "name", "sector_code", "sector_name")
    @classmethod
    def strip_stock_text_fields(cls, value: str) -> str:
        return value.strip()


class PortfolioAccountCreateRequest(BaseModel):
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="계정 스냅샷 계산에 사용할 종목 유니버스",
    )
    investment_horizon: InvestmentHorizon = Field(
        default=InvestmentHorizon.MEDIUM,
        description="포트폴리오 계산에 사용한 투자 기간",
    )
    portfolio_code: str = Field(..., min_length=1, description="확정 포트폴리오 코드")
    portfolio_label: str = Field(..., min_length=1, description="확정 포트폴리오 표시 이름")
    portfolio_id: str = Field(..., min_length=1, description="확정 포트폴리오 식별자")
    target_volatility: float = Field(
        ...,
        ge=TARGET_VOLATILITY_MIN,
        le=TARGET_VOLATILITY_MAX,
        description="확정 당시 목표 변동성",
    )
    expected_return: float = Field(..., description="확정 당시 연 기대수익률")
    volatility: float = Field(..., ge=0, description="확정 당시 연 변동성")
    sharpe_ratio: float = Field(..., description="확정 당시 샤프 비율")
    initial_cash_amount: float = Field(..., gt=0, description="초기 입금액")
    sector_allocations: list[SectorAllocationRequest] = Field(
        default_factory=list,
        description="자산군별 비중",
    )
    stock_allocations: list[StockAllocationRequest] = Field(
        default_factory=list,
        description="종목별 비중",
    )
    started_at: date | None = Field(
        default=None,
        description="자산 추적 시작일. 비우면 서버의 현재 날짜를 사용합니다.",
    )

    @field_validator("portfolio_code", "portfolio_label", "portfolio_id")
    @classmethod
    def strip_portfolio_text_fields(cls, value: str) -> str:
        return value.strip()

    @model_validator(mode="after")
    def validate_allocations(self) -> "PortfolioAccountCreateRequest":
        if not self.stock_allocations:
            raise ValueError("stock_allocations는 비어 있을 수 없습니다.")
        return self


class PortfolioAccountCashInRequest(BaseModel):
    amount: float = Field(..., gt=0, description="입금액")


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
