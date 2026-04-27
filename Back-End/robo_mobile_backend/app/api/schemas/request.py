from datetime import date

from pydantic import BaseModel, Field, model_validator

from app.core.config import TARGET_VOLATILITY_MAX, TARGET_VOLATILITY_MIN, TARGET_VOLATILITY_STEP
from app.domain.enums import InvestmentHorizon, PriceRefreshMode, RiskProfile, SimulationDataSource
from app.domain.models import ManagedUniverseAssetRoleAssignment, StockInstrument, UserProfile


class PortfolioSimulationRequest(BaseModel):
    risk_profile: RiskProfile = Field(..., description="위험 성향")
    investment_horizon: InvestmentHorizon = Field(..., description="투자 기간")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="계산에 사용할 데이터 소스. 기본값은 관리자 유니버스이며, 미설정 시 데모 종목 유니버스로 대체됩니다.",
    )
    target_volatility: float | None = Field(
        default=None,
        ge=TARGET_VOLATILITY_MIN,
        le=TARGET_VOLATILITY_MAX,
        description="선택 입력값. 없으면 위험성향과 투자기간으로 기본 목표 변동성을 계산합니다. 2%p 단위로 입력합니다.",
    )

    @model_validator(mode="after")
    def validate_profile_and_target(self) -> "PortfolioSimulationRequest":
        if self.target_volatility is not None:
            snapped = TARGET_VOLATILITY_MIN + round((self.target_volatility - TARGET_VOLATILITY_MIN) / TARGET_VOLATILITY_STEP) * TARGET_VOLATILITY_STEP
            if abs(self.target_volatility - snapped) > 1e-9:
                raise ValueError("목표 변동성은 4%부터 22%까지 2%p 단위로 입력해야 합니다.")
        if self.risk_profile == RiskProfile.CONSERVATIVE and self.target_volatility and self.target_volatility > 0.12:
            raise ValueError("안정형 성향은 목표 변동성을 12% 초과로 설정할 수 없습니다.")
        return self

    def to_domain(self) -> UserProfile:
        return UserProfile(
            risk_profile=self.risk_profile,
            investment_horizon=self.investment_horizon,
            target_volatility=self.target_volatility,
            data_source=self.data_source,
        )


class ManagedUniverseItemRequest(BaseModel):
    ticker: str = Field(..., description="종목 티커")
    name: str = Field(..., description="종목명")
    sector_code: str = Field(..., description="자산군 코드")
    sector_name: str = Field(..., description="자산군 이름")
    market: str = Field(..., description="거래 시장")
    currency: str = Field(..., description="통화")
    base_weight: float | None = Field(default=None, gt=0, description="섹터 내부 기본가중치")

    def to_domain(self) -> StockInstrument:
        return StockInstrument(
            ticker=self.ticker.strip(),
            name=self.name.strip(),
            sector_code=self.sector_code.strip(),
            sector_name=self.sector_name.strip(),
            market=self.market.strip(),
            currency=self.currency.strip(),
            base_weight=self.base_weight,
        )


class ManagedUniverseAssetRoleRequest(BaseModel):
    asset_code: str = Field(..., description="자산군 코드")
    role_key: str = Field(..., description="적용할 role 키")

    def to_domain(self) -> ManagedUniverseAssetRoleAssignment:
        return ManagedUniverseAssetRoleAssignment(
            asset_code=self.asset_code.strip(),
            role_key=self.role_key.strip(),
        )


class ManagedUniverseVersionCreateRequest(BaseModel):
    version_name: str = Field(..., description="관리자 유니버스 버전명")
    notes: str | None = Field(default=None, description="버전 메모")
    activate: bool = Field(default=True, description="생성 후 즉시 활성화 여부")
    asset_roles: list[ManagedUniverseAssetRoleRequest] = Field(
        default_factory=list,
        description="자산군별 role 지정. 비워두면 현재 기본 role 구성을 사용합니다.",
    )
    instruments: list[ManagedUniverseItemRequest] = Field(..., min_length=1, description="종목 유니버스 목록")

    def to_domain_instruments(self) -> list[StockInstrument]:
        return [item.to_domain() for item in self.instruments]

    def to_domain_asset_roles(self) -> list[ManagedUniverseAssetRoleAssignment]:
        return [item.to_domain() for item in self.asset_roles]


class ManagedUniverseVersionUpdateRequest(BaseModel):
    version_name: str = Field(..., description="수정할 관리자 유니버스 버전명")
    notes: str | None = Field(default=None, description="버전 메모")
    activate: bool = Field(default=False, description="수정 후 활성화 여부. false면 현재 active 상태를 유지합니다.")
    asset_roles: list[ManagedUniverseAssetRoleRequest] = Field(
        default_factory=list,
        description="자산군별 role 지정. 비워두면 현재 기본 role 구성을 사용합니다.",
    )
    instruments: list[ManagedUniverseItemRequest] = Field(..., min_length=1, description="수정된 종목 유니버스 목록")

    def to_domain_instruments(self) -> list[StockInstrument]:
        return [item.to_domain() for item in self.instruments]

    def to_domain_asset_roles(self) -> list[ManagedUniverseAssetRoleAssignment]:
        return [item.to_domain() for item in self.asset_roles]


class VolatilityHistoryRequest(BaseModel):
    weights: dict[str, float] = Field(..., description="종목별 비중 (ticker → weight)")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="가격 데이터 소스",
    )
    rolling_window: int = Field(default=20, ge=5, le=60, description="롤링 변동성 계산 윈도우 (거래일 수)")


class EarningsHistoryRequest(BaseModel):
    weights: dict[str, float] = Field(..., description="종목별 비중 (ticker → weight)")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="가격 데이터 소스",
    )
    start_date: str = Field(..., description="투자 시작일 (YYYY-MM-DD)")
    investment_amount: float = Field(default=10_000_000, gt=0, description="투자 금액 (원)")


class ComparisonBacktestRequest(BaseModel):
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="가격 데이터 소스",
    )
    stock_weights: dict[str, float] | None = Field(
        default=None,
        description="현재 선택 포트폴리오의 종목 비중 맵. 주어지면 이 비중을 고정한 과거 백테스트를 계산합니다.",
    )
    portfolio_code: str | None = Field(
        default=None,
        description="현재 선택 포트폴리오 코드. 없으면 `selected` 라인 키를 사용합니다.",
    )
    start_date: str | None = Field(
        default=None,
        description="비교 백테스트 시작일 (YYYY-MM-DD). 있으면 해당 날짜 이후 데이터만 사용합니다.",
    )


class RebalanceSimulationRequest(BaseModel):
    weights: dict[str, float] = Field(..., description="종목별 목표 비중 (ticker → weight)")
    data_source: SimulationDataSource = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="가격 데이터 소스",
    )
    start_date: str = Field(..., description="시뮬레이션 시작일 (YYYY-MM-DD)")
    investment_amount: float = Field(default=10_000_000, gt=0, description="투자 금액 (원)")


class PriceRefreshRequest(BaseModel):
    version_id: int | None = Field(default=None, description="가격 갱신 대상 유니버스 버전. 없으면 active 버전 사용")
    refresh_mode: PriceRefreshMode = Field(default=PriceRefreshMode.INCREMENTAL, description="증분 갱신 또는 전체 백필")
    full_lookback_years: int = Field(default=5, ge=1, le=20, description="full 모드에서 가져올 연수")


class ActivePriceRefreshRequest(BaseModel):
    refresh_mode: PriceRefreshMode = Field(default=PriceRefreshMode.INCREMENTAL, description="active 유니버스에 대한 증분 갱신 또는 전체 백필")
    full_lookback_years: int = Field(default=5, ge=1, le=20, description="full 모드에서 가져올 연수")


class AccountSnapshotBackfillRequest(BaseModel):
    dry_run: bool = Field(
        default=True,
        description="true면 대상 계정만 조회하고 실제 snapshot 재계산은 수행하지 않습니다.",
    )
    data_source: SimulationDataSource | None = Field(
        default=SimulationDataSource.MANAGED_UNIVERSE,
        description="대상 계정 데이터 소스. null이면 전체 데이터 소스를 포함합니다.",
    )
    account_ids: list[int] = Field(
        default_factory=list,
        description="특정 account_id만 대상으로 제한할 때 사용합니다.",
    )
    user_ids: list[int] = Field(
        default_factory=list,
        description="특정 user_id만 대상으로 제한할 때 사용합니다.",
    )
    started_from: str | None = Field(
        default=None,
        description="started_at 하한 (YYYY-MM-DD, inclusive)",
    )
    started_to: str | None = Field(
        default=None,
        description="started_at 상한 (YYYY-MM-DD, inclusive)",
    )
    limit: int | None = Field(
        default=50,
        ge=1,
        le=500,
        description="한 번에 처리할 최대 계정 수. null이면 제한 없이 전체 대상입니다.",
    )
    allow_all_matching: bool = Field(
        default=False,
        description="true면 별도 ID 필터 없이 매칭되는 전체 계정을 실제 backfill할 수 있습니다.",
    )

    @model_validator(mode="after")
    def validate_scope(self) -> "AccountSnapshotBackfillRequest":
        if self.started_from is not None:
            date.fromisoformat(self.started_from)
        if self.started_to is not None:
            date.fromisoformat(self.started_to)
        if (
            not self.dry_run
            and not self.allow_all_matching
            and not self.account_ids
            and not self.user_ids
            and self.started_from is None
            and self.started_to is None
            and self.limit is None
        ):
            raise ValueError(
                "실행 모드에서는 범위를 제한하거나 allow_all_matching=true 를 명시해야 합니다."
            )
        return self
