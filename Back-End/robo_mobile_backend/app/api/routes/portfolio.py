import pandas as pd
from fastapi import APIRouter, HTTPException, Query

from app.api.schemas.request import ComparisonBacktestRequest, EarningsHistoryRequest, PortfolioSimulationRequest, RebalanceSimulationRequest, VolatilityHistoryRequest
from app.api.schemas.response import (
    AssetClassResponse,
    AssetEarningSummary,
    AssetUniverseResponse,
    CombinationSelectionResponse,
    ComparisonBacktestResponse,
    ComparisonLinePointResponse,
    ComparisonLineResponse,
    EarningsHistoryResponse,
    EarningsPointResponse,
    FrontierPreviewResponse,
    FrontierPointResponse,
    IndividualAssetResponse,
    PortfolioSimulationResponse,
    RandomPortfolioResponse,
    RebalanceEventResponse,
    RebalanceSimulationResponse,
    RebalanceTimePointResponse,
    StockInstrumentResponse,
    StocksBySectorResponse,
    ReturnHistoryResponse,
    ReturnPointResponse,
    VolatilityHistoryResponse,
    VolatilityPointResponse,
)
from app.core.config import DEMO_STOCK_UNIVERSE_PATH, TARGET_VOLATILITY_MAX, TARGET_VOLATILITY_MIN, TARGET_VOLATILITY_STEP
from app.engine.rebalance import (
    build_two_stage_rebalance_policy,
    serialize_rebalance_policy,
    simulate_two_stage_rebalance,
)
from app.data.stock_repository import StockDataRepository
from app.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from app.domain.models import PortfolioSimulationResult, UserProfile
from app.services.portfolio_analytics_service import PortfolioAnalyticsService
from app.services.portfolio_service import PortfolioSimulationService


router = APIRouter(prefix="/portfolio", tags=["portfolio"])
portfolio_service = PortfolioSimulationService()
portfolio_analytics_service = PortfolioAnalyticsService(
    portfolio_service=portfolio_service,
)
TWO_STAGE_REBALANCE_POLICY = build_two_stage_rebalance_policy()


@router.get("/assets", response_model=AssetUniverseResponse)
def list_assets() -> AssetUniverseResponse:
    assets = portfolio_service.list_assets()
    return AssetUniverseResponse(
        assets=[
            AssetClassResponse(
                code=asset.code,
                name=asset.name,
                category=asset.category,
                description=asset.description,
                color=asset.color,
                min_weight=asset.min_weight,
                max_weight=asset.max_weight,
                role_key=asset.role_key,
                role_name=asset.role_name,
                role_description=asset.role_description,
                selection_mode=asset.selection_mode,
                weighting_mode=asset.weighting_mode,
                return_mode=asset.return_mode,
            )
            for asset in assets
        ]
    )


@router.get("/stocks", response_model=StocksBySectorResponse)
def list_stocks(
    data_source: SimulationDataSource = Query(default=SimulationDataSource.MANAGED_UNIVERSE),
) -> StocksBySectorResponse:
    instruments = portfolio_service.list_stocks(data_source)
    sectors: dict[str, list[StockInstrumentResponse]] = {}
    for inst in instruments:
        item = StockInstrumentResponse(
            ticker=inst.ticker,
            name=inst.name,
            sector_code=inst.sector_code,
            sector_name=inst.sector_name,
        )
        sectors.setdefault(inst.sector_code, []).append(item)
    return StocksBySectorResponse(sectors=sectors)


@router.get("/frontier", response_model=FrontierPreviewResponse)
def get_frontier(
    risk_profile: RiskProfile = Query(default=RiskProfile.BALANCED),
    investment_horizon: InvestmentHorizon = Query(default=InvestmentHorizon.MEDIUM),
    data_source: SimulationDataSource = Query(default=SimulationDataSource.MANAGED_UNIVERSE),
    target_volatility: float | None = Query(default=None, ge=TARGET_VOLATILITY_MIN, le=TARGET_VOLATILITY_MAX),
) -> FrontierPreviewResponse:
    _validate_target_volatility_step(target_volatility)
    result = _simulate(
        UserProfile(
            risk_profile=risk_profile,
            investment_horizon=investment_horizon,
            target_volatility=target_volatility,
            data_source=data_source,
        )
    )
    return FrontierPreviewResponse(
        portfolio_id=result.portfolio_id,
        data_source=result.data_source.value,
        data_source_label=result.data_source_label,
        target_volatility=round(result.target_volatility, 4),
        frontier_points=[_frontier_point_response(point) for point in result.frontier_points],
        frontier_options=[_frontier_point_response(point, label=label) for label, point in result.frontier_options],
        selected_point_index=result.selected_point_index,
        selected_point=_frontier_point_response(result.frontier_points[result.selected_point_index], label="현재 포트폴리오"),
        random_portfolios=[
            RandomPortfolioResponse(volatility=round(point[0], 4), expected_return=round(point[1], 4), weights={k: round(v, 4) for k, v in point[2].items()})
            for point in result.random_portfolios
        ],
        individual_assets=[
            IndividualAssetResponse(
                code=item.code,
                name=item.name,
                volatility=round(item.volatility, 4),
                expected_return=round(item.expected_return, 4),
            )
            for item in result.individual_assets
        ],
        selected_combination=_combination_response(result.selected_combination),
    )


@router.post("/simulate", response_model=PortfolioSimulationResponse)
def simulate_portfolio(payload: PortfolioSimulationRequest) -> PortfolioSimulationResponse:
    result = _simulate(payload.to_domain())
    selected_point = result.frontier_points[result.selected_point_index]
    return PortfolioSimulationResponse(
        portfolio_id=result.portfolio_id,
        disclaimer=result.disclaimer,
        summary=result.summary,
        explanation_title=result.explanation_title,
        explanation=result.explanation_body,
        data_source=result.data_source.value,
        data_source_label=result.data_source_label,
        target_volatility=round(result.target_volatility, 4),
        expected_return=round(result.metrics.expected_return, 4),
        volatility=round(result.metrics.volatility, 4),
        sharpe_ratio=round(result.metrics.sharpe_ratio, 4),
        weights={code: round(weight, 4) for code, weight in result.weights.items()},
        allocations=[
            {
                "asset_code": item.asset_code,
                "asset_name": item.asset_name,
                "weight": round(item.weight, 4),
                "risk_contribution": round(item.risk_contribution, 4),
            }
            for item in result.allocations
        ],
        frontier_points=[_frontier_point_response(point) for point in result.frontier_points],
        frontier_options=[_frontier_point_response(point, label=label) for label, point in result.frontier_options],
        selected_point_index=result.selected_point_index,
        selected_point=_frontier_point_response(selected_point, label="현재 포트폴리오"),
        random_portfolios=[
            RandomPortfolioResponse(volatility=round(point[0], 4), expected_return=round(point[1], 4), weights={k: round(v, 4) for k, v in point[2].items()})
            for point in result.random_portfolios
        ],
        individual_assets=[
            IndividualAssetResponse(
                code=item.code,
                name=item.name,
                volatility=round(item.volatility, 4),
                expected_return=round(item.expected_return, 4),
            )
            for item in result.individual_assets
        ],
        used_fallback=result.used_fallback,
        frontier_vol_min=round(min(p.volatility for p in result.frontier_points), 4) if result.frontier_points else 0.0,
        frontier_vol_max=round(max(p.volatility for p in result.frontier_points), 4) if result.frontier_points else 0.0,
        selected_combination=_combination_response(result.selected_combination),
    )


def _simulate(user_profile: UserProfile) -> PortfolioSimulationResult:
    try:
        return portfolio_service.simulate(user_profile)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


def _validate_target_volatility_step(target_volatility: float | None) -> None:
    if target_volatility is None:
        return
    snapped = TARGET_VOLATILITY_MIN + round((target_volatility - TARGET_VOLATILITY_MIN) / TARGET_VOLATILITY_STEP) * TARGET_VOLATILITY_STEP
    if abs(target_volatility - snapped) > 1e-9:
        raise HTTPException(status_code=400, detail="목표 변동성은 4%부터 22%까지 2%p 단위로 입력해야 합니다.")


def _frontier_point_response(point, label: str | None = None) -> FrontierPointResponse:
    return FrontierPointResponse(
        label=label,
        volatility=round(point.volatility, 4),
        expected_return=round(point.expected_return, 4),
        weights={code: round(weight, 4) for code, weight in point.weights.items()},
    )


@router.post("/volatility-history", response_model=VolatilityHistoryResponse)
def volatility_history(payload: VolatilityHistoryRequest) -> VolatilityHistoryResponse:
    try:
        history = portfolio_analytics_service.build_volatility_history(
            weights=payload.weights,
            data_source=payload.data_source,
            rolling_window=payload.rolling_window,
        )
        return VolatilityHistoryResponse(
            points=[
                VolatilityPointResponse(date=point.date, volatility=point.value)
                for point in history.points
            ],
            earliest_data_date=history.earliest_data_date,
            latest_data_date=history.latest_data_date,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"변동성 추이 계산 중 오류가 발생했습니다: {exc}") from exc


@router.post("/return-history", response_model=ReturnHistoryResponse)
def return_history(payload: VolatilityHistoryRequest) -> ReturnHistoryResponse:
    try:
        history = portfolio_analytics_service.build_return_history(
            weights=payload.weights,
            data_source=payload.data_source,
            rolling_window=payload.rolling_window,
        )
        return ReturnHistoryResponse(
            points=[
                ReturnPointResponse(date=point.date, expected_return=point.value)
                for point in history.points
            ],
            earliest_data_date=history.earliest_data_date,
            latest_data_date=history.latest_data_date,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"기대수익률 추이 계산 중 오류가 발생했습니다: {exc}") from exc


def _combination_response(selection) -> CombinationSelectionResponse | None:
    if selection is None:
        return None
    return CombinationSelectionResponse(
        combination_id=selection.combination_id,
        members_by_sector=selection.members_by_sector,
        total_combinations_tested=selection.total_combinations_tested,
        successful_combinations=selection.successful_combinations,
        discard_reasons=selection.discard_reasons,
    )


@router.post("/earnings-history", response_model=EarningsHistoryResponse)
def earnings_history(payload: EarningsHistoryRequest) -> EarningsHistoryResponse:
    tickers = [t for t, w in payload.weights.items() if w > 0]
    try:
        prices = portfolio_analytics_service.load_history_prices(
            tickers=tickers,
            data_source=payload.data_source,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    # Build ticker → sector mapping
    instruments = portfolio_service.list_stocks(payload.data_source)
    ticker_to_sector: dict[str, tuple[str, str]] = {}
    for inst in instruments:
        ticker_to_sector[inst.ticker.upper()] = (inst.sector_code, inst.sector_name)

    # Pivot prices to wide format
    pivoted = prices.pivot_table(index="date", columns="ticker", values="adjusted_close")
    pivoted = pivoted.sort_index().ffill()

    # Filter from start_date
    start = pd.Timestamp(payload.start_date)
    pivoted = pivoted[pivoted.index >= start]
    if pivoted.empty:
        raise HTTPException(status_code=400, detail="시작일 이후 가격 데이터가 없습니다.")

    # Normalize weights to match available tickers
    available = set(pivoted.columns)
    weight_map = {t.upper(): w for t, w in payload.weights.items() if t.upper() in available and w > 0}
    if not weight_map:
        raise HTTPException(status_code=400, detail="요청 종목의 가격 데이터가 없습니다.")
    total_w = sum(weight_map.values())
    weight_map = {t: w / total_w for t, w in weight_map.items()}

    # Per-ticker cumulative return from first row
    base_prices = pivoted.iloc[0]
    cumret = pivoted.div(base_prices) - 1  # each cell = cumulative return of that ticker

    # Group by sector
    sector_names: dict[str, str] = {}
    sector_weights: dict[str, float] = {}
    for ticker, weight in weight_map.items():
        sc, sn = ticker_to_sector.get(ticker, ("unknown", "기타"))
        sector_names[sc] = sn
        sector_weights.setdefault(sc, 0.0)
        sector_weights[sc] += weight

    # Per-sector weighted cumulative return series
    sector_cumret: dict[str, pd.Series] = {}
    for ticker, weight in weight_map.items():
        sc = ticker_to_sector.get(ticker, ("unknown", "기타"))[0]
        contrib = cumret[ticker] * weight
        if sc in sector_cumret:
            sector_cumret[sc] = sector_cumret[sc].add(contrib, fill_value=0)
        else:
            sector_cumret[sc] = contrib.copy()

    # Total cumulative return
    total_cumret = sum(sector_cumret.values())

    # Subsample to ~250 points for smoother chart
    dates = pivoted.index.tolist()
    step = max(1, len(dates) // 250)
    sampled_indices = list(range(0, len(dates), step))
    if sampled_indices[-1] != len(dates) - 1:
        sampled_indices.append(len(dates) - 1)

    inv = payload.investment_amount
    sector_codes = sorted(sector_cumret.keys())

    points = []
    for i in sampled_indices:
        d = dates[i]
        ae = {}
        for sc in sector_codes:
            ae[sc] = round(sector_cumret[sc].iloc[i] * inv, 0)
        te = round(total_cumret.iloc[i] * inv, 0)
        tr = round(total_cumret.iloc[i] * 100, 2)
        points.append(EarningsPointResponse(
            date=d.strftime("%Y-%m-%d"),
            total_earnings=te,
            total_return_pct=tr,
            asset_earnings=ae,
        ))

    # Final summary
    final_total_ret = total_cumret.iloc[-1]
    asset_summary = []
    for sc in sector_codes:
        final_sc_ret = sector_cumret[sc].iloc[-1]
        asset_summary.append(AssetEarningSummary(
            asset_code=sc,
            asset_name=sector_names.get(sc, sc),
            weight=round(sector_weights.get(sc, 0), 4),
            earnings=round(final_sc_ret * inv, 0),
            return_pct=round(final_sc_ret / sector_weights.get(sc, 1) * 100, 2) if sector_weights.get(sc, 0) > 0 else 0,
        ))

    return EarningsHistoryResponse(
        points=points,
        investment_amount=inv,
        start_date=dates[0].strftime("%Y-%m-%d"),
        end_date=dates[-1].strftime("%Y-%m-%d"),
        total_return_pct=round(final_total_ret * 100, 2),
        total_earnings=round(final_total_ret * inv, 0),
        asset_summary=asset_summary,
    )


def _build_sector_map(data_source: SimulationDataSource) -> tuple[dict[str, str], dict[str, str]]:
    """Return (ticker_to_sector, sector_to_name) mappings."""
    if data_source == SimulationDataSource.MANAGED_UNIVERSE:
        instruments = portfolio_service.managed_universe_service.get_active_instruments()
    elif data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
        instruments = StockDataRepository().load_stock_universe(str(DEMO_STOCK_UNIVERSE_PATH))
    else:
        instruments = []

    ticker_to_sector: dict[str, str] = {}
    for inst in instruments:
        ticker_to_sector[inst.ticker.upper()] = inst.sector_code

    assets = portfolio_service.list_assets()
    sector_to_name: dict[str, str] = {a.code: a.name for a in assets}

    return ticker_to_sector, sector_to_name


def _aggregate_by_sector(
    ticker_values: dict[str, float],
    ticker_to_sector: dict[str, str],
) -> dict[str, float]:
    """Sum ticker-level values into sector-level totals."""
    aggregated: dict[str, float] = {}
    for ticker, value in ticker_values.items():
        if ticker == "CASH":
            sector = "CASH"
        else:
            sector = ticker_to_sector.get(ticker, ticker)
        aggregated[sector] = aggregated.get(sector, 0.0) + value
    return {k: round(v, 6) for k, v in aggregated.items()}


@router.post("/rebalance-simulation", response_model=RebalanceSimulationResponse)
def rebalance_simulation(payload: RebalanceSimulationRequest) -> RebalanceSimulationResponse:
    tickers = [t for t, w in payload.weights.items() if w > 0]
    try:
        prices = portfolio_analytics_service.load_history_prices(
            tickers=tickers,
            data_source=payload.data_source,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    pivoted = prices.pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last")
    pivoted = pivoted.sort_index().ffill().dropna(how="any")

    start = pd.Timestamp(payload.start_date)
    pivoted = pivoted[pivoted.index >= start]
    if pivoted.empty:
        raise HTTPException(status_code=400, detail="시작일 이후 가격 데이터가 없습니다.")

    available = set(pivoted.columns)
    weight_map = {t.upper(): w for t, w in payload.weights.items() if t.upper() in available and w > 0}
    if not weight_map:
        raise HTTPException(status_code=400, detail="요청 종목의 가격 데이터가 없습니다.")
    total_w = sum(weight_map.values())
    weight_map = {t: w / total_w for t, w in weight_map.items()}

    try:
        result = simulate_two_stage_rebalance(
            pivoted,
            weight_map,
            payload.investment_amount,
        )
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"리밸런싱 시뮬레이션 중 오류가 발생했습니다: {exc}") from exc

    # Build sector aggregation mapping
    ticker_to_sector, sector_to_name = _build_sector_map(payload.data_source)
    sector_to_name["CASH"] = "현금"

    # Aggregate time series asset_values by sector
    aggregated_time_series = []
    for p in result.time_series:
        sector_values = _aggregate_by_sector(p.asset_values, ticker_to_sector)
        aggregated_time_series.append(
            RebalanceTimePointResponse(date=p.date, total_value=p.total_value, asset_values=sector_values)
        )

    # Aggregate rebalance events by sector
    aggregated_events = []
    for e in result.rebalance_events:
        sector_trades = _aggregate_by_sector(e.trades, ticker_to_sector)
        sector_pre = _aggregate_by_sector(e.pre_weights, ticker_to_sector)
        sector_post = _aggregate_by_sector(e.post_weights, ticker_to_sector)
        aggregated_events.append(
            RebalanceEventResponse(
                date=e.date,
                total_value=e.total_value,
                pre_weights=sector_pre,
                post_weights=sector_post,
                trades=sector_trades,
            )
        )

    # Aggregate target weights by sector
    sector_target_weights = _aggregate_by_sector(result.target_weights, ticker_to_sector)

    return RebalanceSimulationResponse(
        start_date=result.start_date,
        end_date=result.end_date,
        investment_amount=result.investment_amount,
        target_weights=sector_target_weights,
        drift_threshold=result.drift_threshold,
        rebalance_policy=serialize_rebalance_policy(TWO_STAGE_REBALANCE_POLICY),
        sector_names=sector_to_name,
        time_series=aggregated_time_series,
        rebalance_events=aggregated_events,
        final_value=result.final_value,
        total_return_pct=result.total_return_pct,
        no_rebalance_final_value=result.no_rebalance_final_value,
        no_rebalance_return_pct=result.no_rebalance_return_pct,
    )


@router.post("/comparison-backtest", response_model=ComparisonBacktestResponse)
def comparison_backtest(payload: ComparisonBacktestRequest) -> ComparisonBacktestResponse:
    try:
        result = portfolio_analytics_service.build_comparison_backtest(
            data_source=payload.data_source,
            stock_weights=payload.stock_weights,
            portfolio_code=payload.portfolio_code,
            start_date=payload.start_date,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"비교 백테스트 계산 중 오류: {exc}") from exc

    return ComparisonBacktestResponse(
        train_start_date=result.train_start_date,
        train_end_date=result.train_end_date,
        test_start_date=result.test_start_date,
        start_date=result.start_date,
        end_date=result.end_date,
        split_ratio=result.split_ratio,
        rebalance_dates=result.rebalance_dates,
        rebalance_policy=serialize_rebalance_policy(TWO_STAGE_REBALANCE_POLICY),
        lines=[
            ComparisonLineResponse(
                key=line.key,
                label=line.label,
                color=line.color,
                style=line.style,
                points=[ComparisonLinePointResponse(date=d, return_pct=r) for d, r in line.points],
            )
            for line in result.lines
        ],
    )
