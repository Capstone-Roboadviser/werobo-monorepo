from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date

import pandas as pd

from app.domain.enums import InvestmentHorizon, PriceRefreshMode, RiskProfile, SimulationDataSource


@dataclass(frozen=True)
class AssetClass:
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


@dataclass(frozen=True)
class AssetRoleTemplate:
    key: str
    name: str
    description: str
    selection_mode: str
    weighting_mode: str
    return_mode: str


@dataclass(frozen=True)
class UserProfile:
    risk_profile: RiskProfile
    investment_horizon: InvestmentHorizon
    target_volatility: float | None = None
    data_source: SimulationDataSource = SimulationDataSource.MANAGED_UNIVERSE
    as_of_date: date | None = None


@dataclass(frozen=True)
class MarketAssumptions:
    seed: int
    years: int
    annual_returns: dict[str, float]
    annual_volatilities: dict[str, float]
    correlations: dict[str, dict[str, float]]


@dataclass(frozen=True)
class ExpectedReturnModelInput:
    asset_codes: list[str]
    returns: pd.DataFrame | None = None
    annual_returns: dict[str, float] | None = None
    prior_weights: pd.Series | None = None


@dataclass(frozen=True)
class PortfolioMetrics:
    expected_return: float
    volatility: float
    sharpe_ratio: float


@dataclass(frozen=True)
class FrontierPoint:
    volatility: float
    expected_return: float
    weights: dict[str, float]


@dataclass(frozen=True)
class AllocationView:
    asset_code: str
    asset_name: str
    weight: float
    risk_contribution: float


@dataclass(frozen=True)
class IndividualAssetView:
    code: str
    name: str
    volatility: float
    expected_return: float


@dataclass(frozen=True)
class StockInstrument:
    ticker: str
    name: str
    sector_code: str
    sector_name: str
    market: str
    currency: str
    base_weight: float | None = None


@dataclass(frozen=True)
class ManagedUniverseVersion:
    version_id: int
    version_name: str
    source_type: str
    notes: str | None
    is_active: bool
    created_at: str
    instrument_count: int


@dataclass(frozen=True)
class ManagedUniverseAssetRoleAssignment:
    asset_code: str
    role_key: str


@dataclass(frozen=True)
class ManagedPriceStats:
    total_rows: int
    ticker_count: int
    min_date: str | None
    max_date: str | None


@dataclass(frozen=True)
class ManagedUniversePriceWindow:
    version_id: int
    aligned_start_date: str | None
    aligned_end_date: str | None
    youngest_ticker: str | None
    youngest_start_date: str | None
    ticker_count: int


@dataclass(frozen=True)
class ManagedPriceRefreshJob:
    job_id: int
    version_id: int
    version_name: str
    refresh_mode: PriceRefreshMode
    status: str
    ticker_count: int
    success_count: int
    failure_count: int
    message: str | None
    created_at: str
    started_at: str | None
    finished_at: str | None


@dataclass(frozen=True)
class ManagedPriceRefreshJobItem:
    job_id: int
    ticker: str
    status: str
    rows_upserted: int
    error_message: str | None
    started_at: str | None
    finished_at: str | None


@dataclass(frozen=True)
class DividendYieldEstimate:
    ticker: str
    annualized_dividend: float
    annual_yield: float
    payments_per_year: int
    frequency_label: str
    last_payment_date: str | None
    source: str = "unknown"
    updated_at: str | None = None


@dataclass(frozen=True)
class ManagedFrontierSnapshot:
    snapshot_id: int
    version_id: int
    data_source: SimulationDataSource
    investment_horizon: InvestmentHorizon
    aligned_start_date: str | None
    aligned_end_date: str | None
    total_point_count: int
    source_refresh_job_id: int | None
    payload: dict[str, object]
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class ManagedComparisonBacktestSnapshot:
    snapshot_id: int
    version_id: int
    data_source: SimulationDataSource
    aligned_start_date: str | None
    aligned_end_date: str | None
    line_count: int
    source_refresh_job_id: int | None
    payload: dict[str, object]
    created_at: str
    updated_at: str


@dataclass(frozen=True)
class ManagedFrontierSnapshotBuildStatus:
    status: str
    snapshot_count: int
    horizons: list[str] = field(default_factory=list)
    failed_horizons: list[str] = field(default_factory=list)
    message: str | None = None


@dataclass(frozen=True)
class ManagedComparisonBacktestSnapshotBuildStatus:
    status: str
    snapshot_count: int
    line_count: int = 0
    message: str | None = None


@dataclass(frozen=True)
class ManagedPriceRefreshResult:
    job: ManagedPriceRefreshJob
    price_stats: ManagedPriceStats
    price_window: ManagedUniversePriceWindow | None = None
    frontier_snapshot_status: ManagedFrontierSnapshotBuildStatus | None = None
    comparison_backtest_snapshot_status: ManagedComparisonBacktestSnapshotBuildStatus | None = None


@dataclass(frozen=True)
class ManagedUniverseSectorReadiness:
    sector_code: str
    sector_name: str
    required_count: int
    actual_count: int
    ready: bool


@dataclass(frozen=True)
class ManagedUniverseShortHistoryInstrument:
    ticker: str
    sector_code: str
    sector_name: str
    aligned_return_rows: int
    raw_return_rows: int
    first_price_date: str | None
    last_price_date: str | None
    history_years: float
    is_youngest: bool


@dataclass(frozen=True)
class PortfolioComponentCandidate:
    asset_code: str
    asset_name: str
    role_key: str
    selection_mode: str
    weighting_mode: str
    return_mode: str
    member_tickers: tuple[str, ...]
    member_base_weights: dict[str, float] = field(default_factory=dict)


@dataclass(frozen=True)
class CombinationEvaluation:
    combination_id: str
    members_by_sector: dict[str, list[str]]
    sector_returns_shape: tuple[int, int]
    best_point: FrontierPoint
    metrics: PortfolioMetrics


@dataclass(frozen=True)
class CombinationSearchResult:
    total_combinations_tested: int
    successful_combinations: int
    discard_reasons: dict[str, int]
    best_evaluation: CombinationEvaluation
    top_evaluations: list[CombinationEvaluation]


@dataclass(frozen=True)
class CombinationSelectionView:
    combination_id: str
    members_by_sector: dict[str, list[str]]
    total_combinations_tested: int
    successful_combinations: int
    discard_reasons: dict[str, int]


@dataclass(frozen=True)
class PortfolioHistoryPoint:
    date: str
    value: float


@dataclass(frozen=True)
class PortfolioHistorySeries:
    points: list[PortfolioHistoryPoint]
    earliest_data_date: str
    latest_data_date: str


@dataclass(frozen=True)
class ManagedUniverseReadiness:
    ready: bool
    summary: str
    issues: list[str]
    active_version_name: str | None
    instrument_count: int
    priced_ticker_count: int
    stock_return_rows: int
    effective_history_rows: int | None
    minimum_history_rows: int
    sector_checks: list[ManagedUniverseSectorReadiness]
    short_history_instruments: list[ManagedUniverseShortHistoryInstrument] = field(default_factory=list)
    price_window: ManagedUniversePriceWindow | None = None
    selected_combination: CombinationSelectionView | None = None


@dataclass(frozen=True)
class PortfolioSimulationResult:
    portfolio_id: str
    disclaimer: str
    summary: str
    explanation_title: str
    explanation_body: str
    data_source: SimulationDataSource
    data_source_label: str
    target_volatility: float
    metrics: PortfolioMetrics
    weights: dict[str, float]
    allocations: list[AllocationView]
    frontier_points: list[FrontierPoint]
    frontier_options: list[tuple[str, FrontierPoint]]
    selected_point_index: int
    random_portfolios: list[tuple[float, float, dict[str, float]]]
    individual_assets: list[IndividualAssetView]
    used_fallback: bool
    selected_combination: CombinationSelectionView | None = None
