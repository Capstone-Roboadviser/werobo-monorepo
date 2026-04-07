from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str


class AssetClassResponse(BaseModel):
    code: str
    name: str
    category: str
    description: str
    color: str
    min_weight: float
    max_weight: float
    role_key: str
    role_name: str
    role_description: str
    selection_mode: str
    weighting_mode: str
    return_mode: str


class AssetUniverseResponse(BaseModel):
    assets: list[AssetClassResponse]


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
    version_id: int
    version_name: str
    source_type: str
    notes: str | None
    is_active: bool
    created_at: str
    instrument_count: int


class ManagedUniverseItemResponse(BaseModel):
    ticker: str
    name: str
    sector_code: str
    sector_name: str
    market: str
    currency: str
    base_weight: float | None = None


class ManagedUniverseVersionDetailResponse(ManagedUniverseVersionResponse):
    instruments: list[ManagedUniverseItemResponse]


class ManagedPriceStatsResponse(BaseModel):
    total_rows: int
    ticker_count: int
    min_date: str | None
    max_date: str | None


class ManagedUniversePriceWindowResponse(BaseModel):
    version_id: int
    aligned_start_date: str | None = None
    aligned_end_date: str | None = None
    youngest_ticker: str | None = None
    youngest_start_date: str | None = None
    ticker_count: int


class ManagedPriceRefreshJobResponse(BaseModel):
    job_id: int
    version_id: int
    version_name: str
    refresh_mode: str
    status: str
    ticker_count: int
    success_count: int
    failure_count: int
    message: str | None
    created_at: str
    started_at: str | None
    finished_at: str | None


class ManagedPriceRefreshJobItemResponse(BaseModel):
    job_id: int
    ticker: str
    status: str
    rows_upserted: int
    error_message: str | None = None
    started_at: str | None = None
    finished_at: str | None = None


class ManagedUniverseStatusResponse(BaseModel):
    database_configured: bool
    active_version: ManagedUniverseVersionResponse | None = None
    price_stats: ManagedPriceStatsResponse | None = None
    price_window: ManagedUniversePriceWindowResponse | None = None
    latest_refresh_job: ManagedPriceRefreshJobResponse | None = None


class ManagedUniverseSectorReadinessResponse(BaseModel):
    sector_code: str
    sector_name: str
    required_count: int
    actual_count: int
    ready: bool


class ManagedUniverseShortHistoryInstrumentResponse(BaseModel):
    ticker: str
    sector_code: str
    sector_name: str
    aligned_return_rows: int
    raw_return_rows: int
    first_price_date: str | None = None
    last_price_date: str | None = None
    history_years: float
    is_youngest: bool


class ManagedUniverseReadinessResponse(BaseModel):
    ready: bool
    summary: str
    issues: list[str]
    active_version_name: str | None = None
    instrument_count: int
    priced_ticker_count: int
    stock_return_rows: int
    effective_history_rows: int | None = None
    minimum_history_rows: int
    sector_checks: list[ManagedUniverseSectorReadinessResponse]
    short_history_instruments: list[ManagedUniverseShortHistoryInstrumentResponse] = []
    price_window: ManagedUniversePriceWindowResponse | None = None
    selected_combination: CombinationSelectionResponse | None = None


class ManagedPriceRefreshResponse(BaseModel):
    job: ManagedPriceRefreshJobResponse
    price_stats: ManagedPriceStatsResponse
    price_window: ManagedUniversePriceWindowResponse | None = None


class TickerLookupResponse(BaseModel):
    ticker: str
    name: str
    market: str
    currency: str
    exchange: str | None = None
    quote_type: str | None = None


class TickerSearchResultResponse(BaseModel):
    ticker: str
    name: str
    exchange: str | None = None
    quote_type: str | None = None
    market: str | None = None
    currency: str | None = None


class TickerSearchResponse(BaseModel):
    query: str
    results: list[TickerSearchResultResponse]


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
