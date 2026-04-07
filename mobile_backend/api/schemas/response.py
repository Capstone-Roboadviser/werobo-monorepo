from __future__ import annotations

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str
    app: str
    version: str


class ResolvedProfileItemResponse(BaseModel):
    code: str
    label: str
    propensity_score: float | None = None
    target_volatility: float
    investment_horizon: str


class ProfileResolutionResponse(BaseModel):
    resolved_profile: ResolvedProfileItemResponse


class SectorAllocationResponse(BaseModel):
    asset_code: str
    asset_name: str
    weight: float
    risk_contribution: float


class StockAllocationResponse(BaseModel):
    ticker: str
    name: str
    sector_code: str
    sector_name: str
    weight: float


class PortfolioRecommendationItemResponse(BaseModel):
    code: str
    label: str
    portfolio_id: str
    target_volatility: float
    expected_return: float
    volatility: float
    sharpe_ratio: float
    sector_allocations: list[SectorAllocationResponse] = Field(default_factory=list)
    stock_allocations: list[StockAllocationResponse] = Field(default_factory=list)


class RecommendationResponse(BaseModel):
    resolved_profile: ResolvedProfileItemResponse
    recommended_portfolio_code: str
    data_source: str
    portfolios: list[PortfolioRecommendationItemResponse] = Field(default_factory=list)


class VolatilityPointResponse(BaseModel):
    date: str
    volatility: float


class VolatilityHistoryResponse(BaseModel):
    portfolio_code: str
    portfolio_label: str
    rolling_window: int
    earliest_data_date: str
    latest_data_date: str
    points: list[VolatilityPointResponse] = Field(default_factory=list)


class ComparisonLinePointResponse(BaseModel):
    date: str
    return_pct: float


class ComparisonLineResponse(BaseModel):
    key: str
    label: str
    color: str
    style: str
    points: list[ComparisonLinePointResponse] = Field(default_factory=list)


class ComparisonBacktestResponse(BaseModel):
    train_start_date: str
    train_end_date: str
    test_start_date: str
    start_date: str
    end_date: str
    split_ratio: float
    rebalance_dates: list[str] = Field(default_factory=list)
    lines: list[ComparisonLineResponse] = Field(default_factory=list)

