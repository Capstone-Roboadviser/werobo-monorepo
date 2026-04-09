from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = Field(..., description="서버 상태", examples=["ok"])


class ErrorResponse(BaseModel):
    detail: str = Field(..., description="오류 상세 메시지", examples=["유니버스 버전 3를 찾을 수 없습니다."])


class AssetClassResponse(BaseModel):
    code: str = Field(..., description="자산군 코드", examples=["us_growth"])
    name: str = Field(..., description="자산군 이름", examples=["미국 성장주"])
    category: str = Field(..., description="자산군 카테고리", examples=["growth_equity"])
    description: str = Field(..., description="자산군 설명")
    color: str = Field(..., description="UI 표시 색상", examples=["#7B6ED6"])
    min_weight: float = Field(..., description="포트폴리오 최소 비중", examples=[0.0])
    max_weight: float = Field(..., description="포트폴리오 최대 비중", examples=[0.3])
    role_key: str = Field(..., description="현재 적용 role key", examples=["single_representative"])
    role_name: str = Field(..., description="현재 적용 role 이름", examples=["대표 종목 1개"])
    role_description: str = Field(..., description="role 설명")
    selection_mode: str = Field(..., description="후보 종목을 컴포넌트 후보로 만드는 방식", examples=["single_representative"])
    weighting_mode: str = Field(..., description="컴포넌트 내부 바스켓 가중 방식", examples=["single"])
    return_mode: str = Field(..., description="기대수익률/배당 반영 모드", examples=["black_litterman_plus_dividend_yield"])


class AssetUniverseResponse(BaseModel):
    assets: list[AssetClassResponse]


class AssetRoleTemplateResponse(BaseModel):
    key: str = Field(..., description="role key", examples=["equal_weight_basket"])
    name: str = Field(..., description="role 이름", examples=["동일비중 바스켓"])
    description: str = Field(..., description="role 설명")
    selection_mode: str = Field(..., description="후보 선택 방식", examples=["all_members"])
    weighting_mode: str = Field(..., description="바스켓 내부 가중 방식", examples=["inverse_volatility"])
    return_mode: str = Field(..., description="기대수익률/배당 반영 방식", examples=["black_litterman_plus_dividend_yield"])


class FrontierPointResponse(BaseModel):
    label: str | None = None
    volatility: float
    expected_return: float
    weights: dict[str, float] | None = None


class RandomPortfolioResponse(BaseModel):
    volatility: float
    expected_return: float
    weights: dict[str, float] = {}


class IndividualAssetResponse(BaseModel):
    code: str
    name: str
    volatility: float
    expected_return: float


class AllocationResponse(BaseModel):
    asset_code: str
    asset_name: str
    weight: float
    risk_contribution: float


class StockInstrumentResponse(BaseModel):
    ticker: str
    name: str
    sector_code: str
    sector_name: str


class StocksBySectorResponse(BaseModel):
    sectors: dict[str, list[StockInstrumentResponse]]


class ComparisonLinePointResponse(BaseModel):
    date: str
    return_pct: float


class ComparisonLineResponse(BaseModel):
    key: str
    label: str
    color: str
    style: str
    points: list[ComparisonLinePointResponse]


class ComparisonBacktestResponse(BaseModel):
    train_start_date: str
    train_end_date: str
    test_start_date: str
    start_date: str
    end_date: str
    split_ratio: float
    rebalance_dates: list[str]
    lines: list[ComparisonLineResponse]


class EarningsPointResponse(BaseModel):
    date: str
    total_earnings: float
    total_return_pct: float
    asset_earnings: dict[str, float]


class AssetEarningSummary(BaseModel):
    asset_code: str
    asset_name: str
    weight: float
    earnings: float
    return_pct: float


class EarningsHistoryResponse(BaseModel):
    points: list[EarningsPointResponse]
    investment_amount: float
    start_date: str
    end_date: str
    total_return_pct: float
    total_earnings: float
    asset_summary: list[AssetEarningSummary]


class CombinationSelectionResponse(BaseModel):
    combination_id: str
    members_by_sector: dict[str, list[str]]
    total_combinations_tested: int
    successful_combinations: int
    discard_reasons: dict[str, int]


class ManagedUniverseVersionResponse(BaseModel):
    version_id: int = Field(..., description="유니버스 버전 ID", examples=[12])
    version_name: str = Field(..., description="버전 이름", examples=["2026-04 mobile universe"])
    source_type: str = Field(..., description="버전 생성 출처", examples=["admin_input"])
    notes: str | None = Field(default=None, description="운영 메모", examples=["4월 승인 유니버스"])
    is_active: bool = Field(..., description="현재 active 여부", examples=[True])
    created_at: str = Field(..., description="생성 시각 (UTC)", examples=["2026-04-07T08:41:12Z"])
    instrument_count: int = Field(..., description="등록 종목 수", examples=[14])


class ManagedUniverseItemResponse(BaseModel):
    ticker: str = Field(..., description="종목 티커", examples=["QQQ"])
    name: str = Field(..., description="종목명", examples=["Invesco QQQ Trust"])
    sector_code: str = Field(..., description="자산군 코드", examples=["us_growth"])
    sector_name: str = Field(..., description="자산군 이름", examples=["미국 성장주"])
    market: str = Field(..., description="거래 시장", examples=["NASDAQ"])
    currency: str = Field(..., description="통화", examples=["USD"])
    base_weight: float | None = Field(default=None, description="자산군 내부 기본 가중치", examples=[0.5])


class ManagedUniverseAssetRoleResponse(BaseModel):
    asset_code: str = Field(..., description="자산군 코드", examples=["gold"])
    asset_name: str = Field(..., description="자산군 이름", examples=["금"])
    role_key: str = Field(..., description="적용된 role key", examples=["equal_weight_basket"])
    role_name: str = Field(..., description="적용된 role 이름", examples=["동일비중 바스켓"])
    role_description: str = Field(..., description="role 설명")
    selection_mode: str = Field(..., description="선택 방식", examples=["all_members"])
    weighting_mode: str = Field(..., description="바스켓 내부 가중 방식", examples=["base_weight"])
    return_mode: str = Field(..., description="기대수익률/배당 반영 방식", examples=["black_litterman_plus_dividend_yield"])


class ManagedUniverseAssetRoleCatalogResponse(BaseModel):
    assets: list[AssetClassResponse]
    role_templates: list[AssetRoleTemplateResponse]


class ManagedUniverseVersionDetailResponse(ManagedUniverseVersionResponse):
    asset_roles: list[ManagedUniverseAssetRoleResponse] = []
    instruments: list[ManagedUniverseItemResponse]


class ManagedPriceStatsResponse(BaseModel):
    total_rows: int = Field(..., description="가격 테이블 총 row 수", examples=[12458])
    ticker_count: int = Field(..., description="가격이 적재된 종목 수", examples=[14])
    min_date: str | None = Field(default=None, description="가장 이른 가격 일자", examples=["2020-01-02"])
    max_date: str | None = Field(default=None, description="가장 최근 가격 일자", examples=["2026-04-05"])


class ManagedUniversePriceWindowResponse(BaseModel):
    version_id: int = Field(..., description="대상 버전 ID", examples=[12])
    aligned_start_date: str | None = None
    aligned_end_date: str | None = None
    youngest_ticker: str | None = None
    youngest_start_date: str | None = None
    ticker_count: int = Field(..., description="공통 구간 계산에 사용된 종목 수", examples=[14])


class ManagedPriceRefreshJobResponse(BaseModel):
    job_id: int = Field(..., description="가격 갱신 작업 ID", examples=[27])
    version_id: int = Field(..., description="대상 유니버스 버전 ID", examples=[12])
    version_name: str = Field(..., description="대상 유니버스 버전 이름", examples=["2026-04 mobile universe"])
    refresh_mode: str = Field(..., description="갱신 모드", examples=["incremental"])
    status: str = Field(..., description="작업 상태", examples=["completed"])
    ticker_count: int = Field(..., description="대상 종목 수", examples=[14])
    success_count: int = Field(..., description="성공 종목 수", examples=[14])
    failure_count: int = Field(..., description="실패 종목 수", examples=[0])
    message: str | None = Field(default=None, description="작업 메시지", examples=["incremental refresh completed"])
    created_at: str = Field(..., description="생성 시각 (UTC)", examples=["2026-04-07T08:50:00Z"])
    started_at: str | None = Field(default=None, description="시작 시각 (UTC)")
    finished_at: str | None = Field(default=None, description="완료 시각 (UTC)")


class ManagedPriceRefreshJobItemResponse(BaseModel):
    job_id: int
    ticker: str
    status: str
    rows_upserted: int
    error_message: str | None = None
    started_at: str | None = None
    finished_at: str | None = None


class ManagedUniverseStatusResponse(BaseModel):
    database_configured: bool = Field(..., description="DATABASE_URL 설정 여부", examples=[True])
    active_version: ManagedUniverseVersionResponse | None = Field(default=None, description="현재 active 유니버스 버전")
    price_stats: ManagedPriceStatsResponse | None = Field(default=None, description="active 유니버스 기준 가격 통계")
    price_window: ManagedUniversePriceWindowResponse | None = Field(default=None, description="active 유니버스의 공통 가격 구간")
    latest_refresh_job: ManagedPriceRefreshJobResponse | None = Field(default=None, description="최근 가격 갱신 작업")


class ManagedUniverseSectorReadinessResponse(BaseModel):
    sector_code: str = Field(..., description="자산군 코드", examples=["us_growth"])
    sector_name: str = Field(..., description="자산군 이름", examples=["미국 성장주"])
    required_count: int = Field(..., description="필요 최소 종목 수", examples=[1])
    actual_count: int = Field(..., description="현재 등록 종목 수", examples=[2])
    ready: bool = Field(..., description="해당 자산군이 계산 준비를 만족하는지 여부", examples=[True])


class ManagedUniverseShortHistoryInstrumentResponse(BaseModel):
    ticker: str = Field(..., description="종목 티커", examples=["IBTK"])
    sector_code: str = Field(..., description="자산군 코드", examples=["short_term_bond"])
    sector_name: str = Field(..., description="자산군 이름", examples=["단기 채권"])
    aligned_return_rows: int = Field(..., description="공통 구간 기준 수익률 row 수", examples=[170])
    raw_return_rows: int = Field(..., description="원본 가격 기준 수익률 row 수", examples=[170])
    first_price_date: str | None = None
    last_price_date: str | None = None
    history_years: float = Field(..., description="확보된 가격 이력 연수", examples=[0.68])
    is_youngest: bool = Field(..., description="유니버스에서 가장 늦게 시작한 종목 여부", examples=[True])


class ManagedUniverseReadinessResponse(BaseModel):
    ready: bool = Field(..., description="현재 active 유니버스로 시뮬레이션 가능한지 여부", examples=[False])
    summary: str = Field(..., description="준비 상태 요약")
    issues: list[str] = Field(..., description="시뮬레이션 불가 사유 또는 경고 목록")
    active_version_name: str | None = Field(default=None, description="검사 대상 active 버전 이름")
    instrument_count: int = Field(..., description="active 버전에 등록된 전체 종목 수", examples=[14])
    priced_ticker_count: int = Field(..., description="가격 이력이 확인된 종목 수", examples=[13])
    stock_return_rows: int = Field(..., description="생성된 수익률 시계열 row 수", examples=[756])
    effective_history_rows: int | None = Field(default=None, description="실제 최적화에 사용할 수 있는 공통 row 수", examples=[730])
    minimum_history_rows: int = Field(..., description="최소 필요 수익률 row 수", examples=[252])
    sector_checks: list[ManagedUniverseSectorReadinessResponse] = Field(..., description="자산군별 준비 상태")
    short_history_instruments: list[ManagedUniverseShortHistoryInstrumentResponse] = Field(default_factory=list, description="이력이 짧은 종목 목록")
    price_window: ManagedUniversePriceWindowResponse | None = Field(default=None, description="active 버전 공통 가격 구간")
    selected_combination: CombinationSelectionResponse | None = Field(default=None, description="현재 대표 종목 조합 요약")


class ManagedPriceRefreshResponse(BaseModel):
    job: ManagedPriceRefreshJobResponse = Field(..., description="갱신 작업 결과")
    price_stats: ManagedPriceStatsResponse = Field(..., description="갱신 후 가격 통계")
    price_window: ManagedUniversePriceWindowResponse | None = Field(default=None, description="갱신 후 공통 가격 구간")


class TickerLookupResponse(BaseModel):
    ticker: str = Field(..., description="정규화된 티커", examples=["QQQ"])
    name: str = Field(..., description="종목명", examples=["Invesco QQQ Trust"])
    market: str = Field(..., description="거래 시장", examples=["NASDAQ"])
    currency: str = Field(..., description="통화", examples=["USD"])
    exchange: str | None = Field(default=None, description="원본 거래소 코드", examples=["NMS"])
    quote_type: str | None = Field(default=None, description="시세 타입", examples=["ETF"])


class TickerSearchResultResponse(BaseModel):
    ticker: str = Field(..., description="검색된 티커", examples=["QQQ"])
    name: str = Field(..., description="검색된 종목명", examples=["Invesco QQQ Trust"])
    exchange: str | None = Field(default=None, description="거래소 코드", examples=["NMS"])
    quote_type: str | None = Field(default=None, description="시세 타입", examples=["ETF"])
    market: str | None = Field(default=None, description="거래 시장", examples=["NASDAQ"])
    currency: str | None = Field(default=None, description="통화", examples=["USD"])


class TickerSearchResponse(BaseModel):
    query: str = Field(..., description="입력한 검색어", examples=["qqq"])
    results: list[TickerSearchResultResponse] = Field(..., description="검색 후보 목록")


class ManagedUniverseDeleteResponse(BaseModel):
    deleted: bool = Field(..., description="삭제 성공 여부", examples=[True])
    version_id: int = Field(..., description="삭제한 유니버스 버전 ID", examples=[12])
    version_name: str = Field(..., description="삭제한 유니버스 버전 이름", examples=["2026-04 mobile universe"])


class FrontierPreviewResponse(BaseModel):
    portfolio_id: str
    data_source: str
    data_source_label: str
    target_volatility: float
    frontier_points: list[FrontierPointResponse]
    frontier_options: list[FrontierPointResponse]
    selected_point_index: int
    selected_point: FrontierPointResponse
    random_portfolios: list[RandomPortfolioResponse]
    individual_assets: list[IndividualAssetResponse] = []
    selected_combination: CombinationSelectionResponse | None = None


class VolatilityPointResponse(BaseModel):
    date: str
    volatility: float


class VolatilityHistoryResponse(BaseModel):
    points: list[VolatilityPointResponse]
    earliest_data_date: str
    latest_data_date: str


class ReturnPointResponse(BaseModel):
    date: str
    expected_return: float


class ReturnHistoryResponse(BaseModel):
    points: list[ReturnPointResponse]
    earliest_data_date: str
    latest_data_date: str


class RebalanceTimePointResponse(BaseModel):
    date: str
    total_value: float
    asset_values: dict[str, float]


class RebalanceEventResponse(BaseModel):
    date: str
    total_value: float
    pre_weights: dict[str, float]
    post_weights: dict[str, float]
    trades: dict[str, float]


class RebalanceSimulationResponse(BaseModel):
    start_date: str
    end_date: str
    investment_amount: float
    target_weights: dict[str, float]
    sector_names: dict[str, str] = {}
    time_series: list[RebalanceTimePointResponse]
    rebalance_events: list[RebalanceEventResponse]
    final_value: float
    total_return_pct: float
    no_rebalance_final_value: float
    no_rebalance_return_pct: float


class PortfolioSimulationResponse(BaseModel):
    portfolio_id: str
    disclaimer: str
    summary: str
    explanation_title: str
    explanation: str
    data_source: str
    data_source_label: str
    target_volatility: float
    expected_return: float
    volatility: float
    sharpe_ratio: float
    weights: dict[str, float]
    allocations: list[AllocationResponse]
    frontier_points: list[FrontierPointResponse]
    frontier_options: list[FrontierPointResponse]
    selected_point_index: int
    selected_point: FrontierPointResponse
    random_portfolios: list[RandomPortfolioResponse]
    individual_assets: list[IndividualAssetResponse] = []
    used_fallback: bool
    frontier_vol_min: float = 0.0
    frontier_vol_max: float = 0.0
    selected_combination: CombinationSelectionResponse | None = None
