import math

import numpy as np
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
from app.core.config import DEMO_STOCK_PRICES_PATH, DEMO_STOCK_UNIVERSE_PATH, MINIMUM_HISTORY_ROWS, TARGET_VOLATILITY_MAX, TARGET_VOLATILITY_MIN, TARGET_VOLATILITY_STEP
from app.engine.comparison import build_comparison
from app.engine.rebalance import simulate_quarterly_rebalance
from app.data.stock_repository import StockDataRepository
from app.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from app.domain.models import PortfolioSimulationResult, UserProfile
from app.services.portfolio_service import PortfolioSimulationService


router = APIRouter(prefix="/portfolio", tags=["portfolio"])
portfolio_service = PortfolioSimulationService()


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


def _load_history_prices(
    *,
    tickers: list[str],
    data_source: SimulationDataSource,
) -> pd.DataFrame:
    normalized_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
    if not normalized_tickers:
        raise HTTPException(status_code=400, detail="비중 정보가 비어 있습니다.")

    if data_source == SimulationDataSource.MANAGED_UNIVERSE:
        if not portfolio_service.managed_universe_service.is_configured():
            raise HTTPException(status_code=400, detail="관리자 유니버스 DB가 설정되지 않았습니다.")
        prices = portfolio_service.managed_universe_service.load_prices_for_active_version_tickers(normalized_tickers)
    elif data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
        repo = StockDataRepository()
        prices = repo.load_stock_prices(str(DEMO_STOCK_PRICES_PATH))
        prices["ticker"] = prices["ticker"].astype(str).str.upper()
    else:
        raise HTTPException(
            status_code=400,
            detail="종목 히스토리 조회는 관리자 유니버스 또는 데모 종목 유니버스에서만 지원합니다.",
        )

    if prices.empty:
        raise HTTPException(status_code=400, detail="요청한 종목의 가격 데이터가 없습니다.")

    prices = prices.copy()
    prices["ticker"] = prices["ticker"].astype(str).str.upper()
    available_tickers = set(prices["ticker"].unique())
    matched = [ticker for ticker in normalized_tickers if ticker in available_tickers]
    if not matched:
        raise HTTPException(status_code=400, detail="요청한 종목의 가격 데이터가 없습니다.")

    filtered = prices[prices["ticker"].isin(matched)].copy()
    if filtered.empty:
        raise HTTPException(status_code=400, detail="요청한 종목의 가격 데이터가 없습니다.")
    return filtered


def _build_portfolio_return_series(payload: VolatilityHistoryRequest) -> tuple[pd.Series, pd.DatetimeIndex]:
    try:
        tickers = [t.upper() for t in payload.weights.keys()]
        weights_upper = {t.upper(): w for t, w in payload.weights.items()}
        prices = _load_history_prices(tickers=tickers, data_source=payload.data_source)
        pivoted = prices.pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last").sort_index()
        if pivoted.empty:
            raise HTTPException(status_code=400, detail="요청한 종목의 가격 데이터가 없습니다.")

        returns = pivoted.pct_change().dropna(how="all")
        if returns.empty:
            raise HTTPException(status_code=400, detail="요청한 종목으로 유효 수익률 시계열을 만들지 못했습니다.")

        weight_series = pd.Series(weights_upper, dtype=float).reindex(returns.columns).fillna(0.0)
        total = float(weight_series.sum())
        if total <= 0:
            raise HTTPException(status_code=400, detail="포트폴리오 비중 합계가 0보다 커야 합니다.")
        weight_series = weight_series / total

        portfolio_returns = returns.fillna(0.0).dot(weight_series)
        if portfolio_returns.empty:
            raise HTTPException(status_code=400, detail="요청한 종목으로 포트폴리오 수익률을 만들지 못했습니다.")
        return portfolio_returns, pivoted.index
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=422,
            detail=f"포트폴리오 히스토리 시계열을 만드는 중 오류가 발생했습니다: {exc}",
        ) from exc


@router.post("/volatility-history", response_model=VolatilityHistoryResponse)
def volatility_history(payload: VolatilityHistoryRequest) -> VolatilityHistoryResponse:
    try:
        portfolio_returns, all_dates = _build_portfolio_return_series(payload)
        rolling_vol = portfolio_returns.rolling(window=payload.rolling_window, min_periods=payload.rolling_window).std() * math.sqrt(252)
        rolling_vol = rolling_vol.dropna()

        points = [
            VolatilityPointResponse(date=date.strftime("%Y-%m-%d"), volatility=round(float(vol), 6))
            for date, vol in rolling_vol.items()
            if np.isfinite(vol)
        ]

        return VolatilityHistoryResponse(
            points=points,
            earliest_data_date=all_dates.min().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
            latest_data_date=all_dates.max().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"변동성 추이 계산 중 오류가 발생했습니다: {exc}") from exc


@router.post("/return-history", response_model=ReturnHistoryResponse)
def return_history(payload: VolatilityHistoryRequest) -> ReturnHistoryResponse:
    try:
        portfolio_returns, all_dates = _build_portfolio_return_series(payload)
        rolling_ret = portfolio_returns.rolling(window=payload.rolling_window, min_periods=payload.rolling_window).mean() * 252
        rolling_ret = rolling_ret.dropna()

        points = [
            ReturnPointResponse(date=date.strftime("%Y-%m-%d"), expected_return=round(float(ret), 6))
            for date, ret in rolling_ret.items()
            if np.isfinite(ret)
        ]

        return ReturnHistoryResponse(
            points=points,
            earliest_data_date=all_dates.min().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
            latest_data_date=all_dates.max().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
        )
    except HTTPException:
        raise
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
    prices = _load_history_prices(tickers=tickers, data_source=payload.data_source)

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
        sector = ticker_to_sector.get(ticker, ticker)
        aggregated[sector] = aggregated.get(sector, 0.0) + value
    return {k: round(v, 6) for k, v in aggregated.items()}


@router.post("/rebalance-simulation", response_model=RebalanceSimulationResponse)
def rebalance_simulation(payload: RebalanceSimulationRequest) -> RebalanceSimulationResponse:
    tickers = [t for t, w in payload.weights.items() if w > 0]
    prices = _load_history_prices(tickers=tickers, data_source=payload.data_source)

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
        result = simulate_quarterly_rebalance(pivoted, weight_map, payload.investment_amount)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"리밸런싱 시뮬레이션 중 오류가 발생했습니다: {exc}") from exc

    # Build sector aggregation mapping
    ticker_to_sector, sector_to_name = _build_sector_map(payload.data_source)

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
        sector_names=sector_to_name,
        time_series=aggregated_time_series,
        rebalance_events=aggregated_events,
        final_value=result.final_value,
        total_return_pct=result.total_return_pct,
        no_rebalance_final_value=result.no_rebalance_final_value,
        no_rebalance_return_pct=result.no_rebalance_return_pct,
    )


def _fetch_benchmark_prices(start_date: str) -> dict[str, pd.Series]:
    """Fetch S&P 500 and 10-year Treasury ETF prices via yfinance."""
    benchmarks: dict[str, pd.Series] = {}
    try:
        import yfinance as yf
        tickers = {"sp500": "SPY", "treasury": "IEF"}
        for key, ticker in tickers.items():
            try:
                data = yf.download(ticker, start=start_date, progress=False, auto_adjust=True)
                if data is not None and not data.empty:
                    close = data["Close"].squeeze()
                    if hasattr(close, "droplevel"):
                        close = close.droplevel(1) if close.index.nlevels > 1 else close
                    if hasattr(close.index, "tz_localize"):
                        close.index = close.index.tz_localize(None)
                    benchmarks[key] = close
            except Exception:
                continue
    except ImportError:
        pass
    return benchmarks


def _load_comparison_universe(
    data_source: SimulationDataSource,
) -> tuple[list, pd.DataFrame, str]:
    if data_source == SimulationDataSource.MANAGED_UNIVERSE:
        active_version = portfolio_service.managed_universe_service.get_active_version()
        if active_version is None:
            raise HTTPException(status_code=422, detail="활성화된 관리자 유니버스 버전이 없습니다.")
        instruments = portfolio_service.managed_universe_service.get_active_instruments()
        if not instruments:
            raise HTTPException(status_code=422, detail="활성 관리자 유니버스에 등록된 종목이 없습니다.")
        prices = portfolio_service.managed_universe_service.load_prices_for_instruments(
            instruments,
            version_id=active_version.version_id,
        )
        return instruments, prices, active_version.version_name

    if data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
        instruments = portfolio_service.list_stocks(SimulationDataSource.STOCK_COMBINATION_DEMO)
        prices = StockDataRepository().load_stock_prices(str(DEMO_STOCK_PRICES_PATH))
        return instruments, prices, "demo-stock-universe"

    raise HTTPException(
        status_code=400,
        detail="포트폴리오 비교 백테스트는 관리자 유니버스 또는 데모 종목 유니버스에서만 지원합니다.",
    )


def _split_prices_train_test(prices: pd.DataFrame, *, split_ratio: float = 0.9) -> tuple[pd.DataFrame, pd.DataFrame, pd.Timestamp, pd.Timestamp]:
    if prices.empty:
        raise HTTPException(status_code=400, detail="비교 백테스트에 사용할 가격 데이터가 없습니다.")

    unique_dates = pd.Index(sorted(pd.to_datetime(prices["date"]).dt.normalize().unique()))
    if len(unique_dates) < max(MINIMUM_HISTORY_ROWS + 1, 30):
        raise HTTPException(
            status_code=422,
            detail=f"비교 백테스트를 위해서는 최소 {max(MINIMUM_HISTORY_ROWS + 1, 30)}영업일 이상의 가격 이력이 필요합니다.",
        )

    split_index = int(len(unique_dates) * split_ratio)
    split_index = min(max(split_index, MINIMUM_HISTORY_ROWS), len(unique_dates) - 1)
    train_end_date = pd.Timestamp(unique_dates[split_index - 1]).normalize()
    test_start_date = pd.Timestamp(unique_dates[split_index]).normalize()

    train_prices = prices[pd.to_datetime(prices["date"]).dt.normalize() <= train_end_date].copy()
    test_prices = prices[pd.to_datetime(prices["date"]).dt.normalize() >= test_start_date].copy()
    if train_prices.empty or test_prices.empty:
        raise HTTPException(status_code=422, detail="train/test 분할 후 사용할 가격 데이터가 부족합니다.")
    return train_prices, test_prices, train_end_date, test_start_date


@router.post("/comparison-backtest", response_model=ComparisonBacktestResponse)
def comparison_backtest(payload: ComparisonBacktestRequest) -> ComparisonBacktestResponse:
    instruments, prices, combination_prefix = _load_comparison_universe(payload.data_source)
    prices = prices.copy()
    prices["date"] = pd.to_datetime(prices["date"]).dt.normalize()
    if prices.empty:
        raise HTTPException(status_code=400, detail="비교 백테스트에 사용할 가격 데이터가 없습니다.")

    train_prices, test_prices, train_end_date, test_start_date = _split_prices_train_test(prices, split_ratio=0.9)
    train_start_date = pd.Timestamp(train_prices["date"].min()).normalize()

    try:
        profile_data = portfolio_service.get_all_profile_weights_for_price_window(
            data_source=payload.data_source,
            instruments=instruments,
            prices=train_prices,
            combination_prefix=f"{combination_prefix}-train-{train_end_date.strftime('%Y%m%d')}",
        )
    except (ValueError, RuntimeError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    all_tickers: set[str] = set()
    for weights, _ in profile_data.values():
        all_tickers.update(weights.keys())

    pivoted = (
        test_prices[test_prices["ticker"].astype(str).str.upper().isin(all_tickers)]
        .pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last")
        .sort_index()
        .ffill()
        .dropna(how="any")
    )
    if pivoted.empty:
        raise HTTPException(status_code=422, detail="test 구간에서 공통 가격 데이터를 만들지 못했습니다.")

    portfolios = {name: weights for name, (weights, _) in profile_data.items()}
    expected_returns = {name: er for name, (_, er) in profile_data.items()}

    benchmark_series = _fetch_benchmark_prices(test_start_date.strftime("%Y-%m-%d"))

    try:
        result = build_comparison(
            pivoted,
            portfolios,
            expected_returns,
            benchmark_series,
            train_start_date=train_start_date.strftime("%Y-%m-%d"),
            train_end_date=train_end_date.strftime("%Y-%m-%d"),
            split_ratio=0.9,
        )
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
