from __future__ import annotations

from dataclasses import dataclass
from itertools import product
from math import prod

import numpy as np
import pandas as pd

from app.core.config import (
    BLACK_LITTERMAN_RISK_AVERSION,
    DEMO_STOCK_PRICES_PATH,
    DEMO_STOCK_UNIVERSE_PATH,
    FALLBACK_WEIGHTS,
    FRONTIER_POINT_COUNT,
    MAX_PORTFOLIO_AVERAGE_CORRELATION,
    MINIMUM_HISTORY_ROWS,
    RANDOM_PORTFOLIO_COUNT,
    REPRESENTATIVE_COMBINATION_RANDOM_SEED,
    REPRESENTATIVE_COMBINATION_SAMPLE_COUNT,
    REPRESENTATIVE_MAX_EXHAUSTIVE_COMBINATIONS,
    RISK_FREE_RATE,
    SECTOR_MINIMUM_INSTRUMENTS,
    STOCK_MIN_WEIGHT,
    STOCK_MAX_WEIGHT,
)
from app.data.repository import StaticDataRepository
from app.data.stock_repository import StockDataRepository
from app.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from app.domain.models import (
    AllocationView,
    AssetClass,
    CombinationSelectionView,
    ExpectedReturnModelInput,
    FrontierPoint,
    IndividualAssetView,
    ManagedUniverseReadiness,
    ManagedUniverseShortHistoryInstrument,
    ManagedUniverseSectorReadiness,
    PortfolioSimulationResult,
    PortfolioComponentCandidate,
    StockInstrument,
    UserProfile,
)
from app.engine.constraints import (
    ConstraintEngine,
    average_pairwise_correlation,
    build_average_correlation_constraint,
)
from app.engine.covariance import ShrinkageCovarianceModel
from app.engine.frontier import build_frontier_options, select_frontier_point_index
from app.engine.math import portfolio_metrics_from_weights, risk_contributions
from app.engine.optimizer import EfficientFrontierOptimizer
from app.engine.returns import (
    AssumptionReturnModel,
    BlackLittermanReturnModel,
    ExpectedReturnModel,
    HistoricalMeanReturnModel,
)
from app.services.explanation_service import ExplanationService
from app.services.dividend_yield_service import DividendYieldService
from app.services.managed_universe_service import ManagedUniverseService
from app.services.mapping_service import ProfileMappingService
from app.services.portfolio_component_service import ComponentCandidateMapResult, PortfolioComponentService


@dataclass
class EngineContext:
    assets: list[AssetClass]
    instruments: list[StockInstrument]
    expected_returns: pd.Series
    covariance: pd.DataFrame
    frontier_points: list[FrontierPoint]
    random_portfolios: list[tuple[float, float, dict[str, float]]]
    used_fallback: bool
    data_source: SimulationDataSource
    data_source_label: str
    selected_combination: CombinationSelectionView | None = None


@dataclass
class RepresentativeCombinationContext:
    selected_instruments: list[StockInstrument]
    selected_candidates: dict[str, PortfolioComponentCandidate]
    selection_view: CombinationSelectionView
    expected_returns: pd.Series
    covariance: pd.DataFrame
    frontier_points: list[FrontierPoint]
    random_portfolios: list[tuple[float, float, dict[str, float]]]


class PortfolioSimulationService:
    SHORT_HISTORY_DISPLAY_ROWS = MINIMUM_HISTORY_ROWS * 3
    FIXED_TOTAL_WEIGHTING_MODE = "equal_weight_fixed_total_5pct"
    FIXED_TOTAL_WEIGHT = 0.05

    def __init__(self, return_model: ExpectedReturnModel | None = None) -> None:
        self.mapping_service = ProfileMappingService()
        self.explanation_service = ExplanationService()
        self.return_model = return_model or AssumptionReturnModel()
        self.historical_stock_return_model = HistoricalMeanReturnModel()
        self.black_litterman_stock_return_model = BlackLittermanReturnModel(
            periods_per_year=252,
            min_obs=MINIMUM_HISTORY_ROWS,
            risk_aversion=BLACK_LITTERMAN_RISK_AVERSION,
            allow_equal_weight_fallback=True,
        )
        self.stock_return_model = self.black_litterman_stock_return_model
        self.managed_universe_service = ManagedUniverseService()
        self.component_service = PortfolioComponentService()
        self.dividend_yield_service = DividendYieldService()
        self.covariance_model = ShrinkageCovarianceModel()
        self.constraint_engine = ConstraintEngine()
        self.optimizer = EfficientFrontierOptimizer()

    def list_assets(self, *, version_id: int | None = None) -> list[AssetClass]:
        if version_id is not None:
            return self.managed_universe_service.get_assets_for_version(version_id)
        return StaticDataRepository().load_asset_universe()

    def list_stocks(self, data_source: SimulationDataSource = SimulationDataSource.MANAGED_UNIVERSE):
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            instruments = self.managed_universe_service.get_active_instruments()
            if instruments:
                return instruments
        return self._load_demo_instruments()

    def inspect_managed_universe_readiness(self) -> ManagedUniverseReadiness:
        assets = self.list_assets()
        sector_checks = self._build_sector_checks(assets, [])

        if not self.managed_universe_service.is_configured():
            return ManagedUniverseReadiness(
                ready=False,
                summary="DATABASE_URL이 설정되지 않았습니다.",
                issues=["관리자 유니버스는 Postgres 연결 후에만 사용할 수 있습니다."],
                active_version_name=None,
                instrument_count=0,
                priced_ticker_count=0,
                stock_return_rows=0,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
            )

        active_version = self.managed_universe_service.get_active_version()
        if active_version is None:
            return ManagedUniverseReadiness(
                ready=False,
                summary="활성화된 관리자 유니버스 버전이 없습니다.",
                issues=["/admin 에서 유니버스 버전을 생성하고 active 로 전환해주세요."],
                active_version_name=None,
                instrument_count=0,
                priced_ticker_count=0,
                stock_return_rows=0,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
            )

        assets = self.list_assets(version_id=active_version.version_id)
        instruments = self.managed_universe_service.get_active_instruments()
        sector_checks = self._build_sector_checks(assets, instruments)
        issues: list[str] = []
        price_window = self.managed_universe_service.get_price_window(active_version.version_id, instruments) if instruments else None

        if not instruments:
            issues.append("활성 관리자 유니버스에 등록된 종목이 없습니다.")
            return ManagedUniverseReadiness(
                ready=False,
                summary="활성 버전은 있지만 종목이 비어 있습니다.",
                issues=issues,
                active_version_name=active_version.version_name,
                instrument_count=0,
                priced_ticker_count=0,
                stock_return_rows=0,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
                price_window=price_window,
            )

        shortages = [
            f"{item.sector_name} 필요 {item.required_count}개 / 현재 {item.actual_count}개"
            for item in sector_checks
            if not item.ready
        ]
        issues.extend(shortages)

        raw_prices = self.managed_universe_service.load_prices_for_tickers([instrument.ticker for instrument in instruments])
        raw_stock_returns = (
            StockDataRepository().build_stock_returns(raw_prices)
            if not raw_prices.empty
            else pd.DataFrame()
        )

        prices = self.managed_universe_service.load_prices_for_instruments(
            instruments,
            version_id=active_version.version_id,
        )
        if prices.empty:
            issues.append("가격 데이터가 아직 적재되지 않았습니다. /admin 에서 가격 갱신을 먼저 실행해주세요.")
            short_history_instruments = self._build_short_history_instruments(
                instruments=instruments,
                aligned_returns=pd.DataFrame(),
                raw_returns=raw_stock_returns,
                raw_prices=raw_prices,
                price_window=price_window,
            )
            return ManagedUniverseReadiness(
                ready=False,
                summary="가격 이력이 없어 시뮬레이션을 시작할 수 없습니다.",
                issues=issues,
                active_version_name=active_version.version_name,
                instrument_count=len(instruments),
                priced_ticker_count=0,
                stock_return_rows=0,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
                short_history_instruments=short_history_instruments,
                price_window=price_window,
            )

        priced_ticker_count = int(prices["ticker"].astype(str).str.upper().nunique())
        stock_returns = StockDataRepository().build_stock_returns(prices)
        stock_return_rows = int(len(stock_returns))
        short_history_instruments = self._build_short_history_instruments(
            instruments=instruments,
            aligned_returns=stock_returns,
            raw_returns=raw_stock_returns,
            raw_prices=raw_prices,
            price_window=price_window,
        )

        if stock_return_rows == 0:
            issues.append("가격 이력으로부터 유효 수익률을 생성하지 못했습니다.")
            return ManagedUniverseReadiness(
                ready=False,
                summary="가격은 적재됐지만 수익률 시계열이 비어 있습니다.",
                issues=issues,
                active_version_name=active_version.version_name,
                instrument_count=len(instruments),
                priced_ticker_count=priced_ticker_count,
                stock_return_rows=stock_return_rows,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
                short_history_instruments=short_history_instruments,
                price_window=price_window,
            )

        try:
            optimized_returns = self._prepare_stock_returns_for_optimization(instruments, prices)
        except (RuntimeError, ValueError) as exc:
            issues.append(str(exc))
            return ManagedUniverseReadiness(
                ready=False,
                summary="가격 적재는 완료됐지만 종목 단위 최적화 입력을 만들지 못했습니다.",
                issues=issues,
                active_version_name=active_version.version_name,
                instrument_count=len(instruments),
                priced_ticker_count=priced_ticker_count,
                stock_return_rows=stock_return_rows,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
                short_history_instruments=short_history_instruments,
                price_window=price_window,
            )

        try:
            representative_context = self._select_sector_representatives(
                assets=assets,
                instruments=instruments,
                prices=prices,
                combination_prefix=active_version.version_name,
                use_asset_min_weights=True,
            )
        except RuntimeError as exc:
            issues.append(str(exc))
            return ManagedUniverseReadiness(
                ready=False,
                summary="가격 적재는 완료됐지만 현재 role/제약으로 Efficient Frontier를 만들지 못했습니다.",
                issues=issues,
                active_version_name=active_version.version_name,
                instrument_count=len(instruments),
                priced_ticker_count=int(optimized_returns.shape[1]),
                stock_return_rows=stock_return_rows,
                effective_history_rows=None,
                minimum_history_rows=MINIMUM_HISTORY_ROWS,
                sector_checks=sector_checks,
                short_history_instruments=short_history_instruments,
                price_window=price_window,
            )

        effective_history_rows = int(optimized_returns.count().min()) if not optimized_returns.empty else 0
        return ManagedUniverseReadiness(
            ready=True,
            summary=(
                "시뮬레이션 준비 완료 · 자산군별 역할 정의와 바스켓 가중 방식에 맞춰 후보를 조립하고 "
                f"Efficient Frontier를 계산할 수 있습니다. 현재 유효 최적화 후보는 {optimized_returns.shape[1]}개입니다."
            ),
            issues=[],
            active_version_name=active_version.version_name,
            instrument_count=len(instruments),
            priced_ticker_count=int(optimized_returns.shape[1]),
            stock_return_rows=stock_return_rows,
            effective_history_rows=effective_history_rows,
            minimum_history_rows=MINIMUM_HISTORY_ROWS,
            sector_checks=sector_checks,
            short_history_instruments=short_history_instruments,
            price_window=price_window,
            selected_combination=representative_context.selection_view,
        )

    def _build_short_history_instruments(
        self,
        *,
        instruments: list[StockInstrument],
        aligned_returns: pd.DataFrame,
        raw_returns: pd.DataFrame,
        raw_prices: pd.DataFrame,
        price_window,
    ) -> list[ManagedUniverseShortHistoryInstrument]:
        aligned_counts = aligned_returns.count() if not aligned_returns.empty else pd.Series(dtype=int)
        raw_counts = raw_returns.count() if not raw_returns.empty else pd.Series(dtype=int)
        if not raw_prices.empty:
            raw_price_index = raw_prices.copy()
            raw_price_index["ticker_upper"] = raw_price_index["ticker"].astype(str).str.upper()
            first_dates = raw_price_index.groupby("ticker_upper")["date"].min()
            last_dates = raw_price_index.groupby("ticker_upper")["date"].max()
        else:
            first_dates = pd.Series(dtype="datetime64[ns]")
            last_dates = pd.Series(dtype="datetime64[ns]")
        instruments_by_ticker = {instrument.ticker.upper(): instrument for instrument in instruments}

        short_items: list[ManagedUniverseShortHistoryInstrument] = []
        for ticker, instrument in instruments_by_ticker.items():
            aligned_rows = int(aligned_counts.get(ticker, 0))
            raw_rows = int(raw_counts.get(ticker, 0))
            first_date = first_dates.get(ticker)
            last_date = last_dates.get(ticker)
            history_years = 0.0
            if not pd.isna(first_date) and not pd.isna(last_date):
                history_years = max(0.0, (pd.Timestamp(last_date) - pd.Timestamp(first_date)).days / 365.25)
            if history_years >= 3.0:
                continue
            short_items.append(
                ManagedUniverseShortHistoryInstrument(
                    ticker=ticker,
                    sector_code=instrument.sector_code,
                    sector_name=instrument.sector_name,
                    aligned_return_rows=aligned_rows,
                    raw_return_rows=raw_rows,
                    first_price_date=None if pd.isna(first_date) else pd.Timestamp(first_date).strftime("%Y-%m-%d"),
                    last_price_date=None if pd.isna(last_date) else pd.Timestamp(last_date).strftime("%Y-%m-%d"),
                    history_years=round(history_years, 2),
                    is_youngest=(
                        price_window is not None
                        and ticker == str(price_window.youngest_ticker or "").upper()
                    ),
                )
            )

        return sorted(
            short_items,
            key=lambda item: (0 if item.is_youngest else 1, item.history_years, item.ticker),
        )

    def _component_upper_bounds(self, asset_codes: list[str]) -> np.ndarray:
        asset_by_code = {asset.code: asset for asset in self.list_assets()}
        return np.array(
            [
                float(asset_by_code[asset_code].max_weight)
                if asset_code in asset_by_code
                else float(STOCK_MAX_WEIGHT)
                for asset_code in asset_codes
            ],
            dtype=float,
        )

    def _component_lower_bounds(
        self,
        asset_codes: list[str],
        *,
        use_asset_min_weights: bool,
    ) -> np.ndarray:
        if not use_asset_min_weights:
            return pd.Series(STOCK_MIN_WEIGHT, index=asset_codes, dtype=float).values

        asset_by_code = {asset.code: asset for asset in self.list_assets()}
        return np.array(
            [
                float(asset_by_code[asset_code].min_weight)
                if asset_code in asset_by_code
                else float(STOCK_MIN_WEIGHT)
                for asset_code in asset_codes
            ],
            dtype=float,
        )

    def get_all_profile_weights(
        self,
        data_source: SimulationDataSource,
    ) -> dict[str, tuple[dict[str, float], float]]:
        """Return {profile_name: (ticker_weights, expected_return)} for all 3 risk profiles.

        Builds the frontier once and selects 3 points, one per risk profile.
        Returns raw ticker-level weights (not sector-aggregated) so they can be
        used directly with price data for backtesting.
        """
        base_profile = UserProfile(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=data_source,
        )
        context = self._prepare_context(base_profile)
        return self._build_profile_weight_map(
            frontier_points=context.frontier_points,
            expected_returns=context.expected_returns,
            covariance=context.covariance,
            instruments=context.instruments,
        )

    def build_engine_context(
        self,
        *,
        risk_profile: RiskProfile,
        investment_horizon: InvestmentHorizon,
        data_source: SimulationDataSource,
    ) -> EngineContext:
        return self._prepare_context(
            UserProfile(
                risk_profile=risk_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
            )
        )

    def get_all_profile_weights_for_price_window(
        self,
        *,
        data_source: SimulationDataSource,
        instruments: list[StockInstrument],
        prices: pd.DataFrame,
        combination_prefix: str,
    ) -> dict[str, tuple[dict[str, float], float]]:
        """Return profile weights using only the provided training price window."""
        if data_source == SimulationDataSource.ASSET_ASSUMPTIONS:
            raise RuntimeError("시점 기준 비교 백테스트는 종목 유니버스 데이터 소스에서만 지원합니다.")

        assets = self.list_assets()
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            active_version = self.managed_universe_service.get_active_version()
            if active_version is not None:
                assets = self.list_assets(version_id=active_version.version_id)
        representative_context = self._select_sector_representatives(
            instruments=instruments,
            prices=prices,
            combination_prefix=combination_prefix,
            use_asset_min_weights=True,
            assets=assets,
        )
        return self._build_profile_weight_map(
            frontier_points=representative_context.frontier_points,
            expected_returns=representative_context.expected_returns,
            covariance=representative_context.covariance,
            instruments=representative_context.selected_instruments,
        )

    def _build_profile_weight_map(
        self,
        *,
        frontier_points: list[FrontierPoint],
        expected_returns: pd.Series,
        covariance: pd.DataFrame,
        instruments: list[StockInstrument],
    ) -> dict[str, tuple[dict[str, float], float]]:
        profile_keys = (
            RiskProfile.CONSERVATIVE.value,
            RiskProfile.BALANCED.value,
            RiskProfile.GROWTH.value,
        )
        option_points = build_frontier_options(frontier_points)

        results: dict[str, tuple[dict[str, float], float]] = {}
        for profile_key, (_, point) in zip(profile_keys, option_points):
            results[profile_key] = (point.weights, point.expected_return)
        return results

    def simulate(self, user_profile: UserProfile) -> PortfolioSimulationResult:
        target_volatility = self.mapping_service.resolve_target_volatility(user_profile)
        portfolio_id = self.mapping_service.build_portfolio_id(user_profile, target_volatility)
        context = self._prepare_context(user_profile)
        if context.selected_combination is not None:
            portfolio_id = f"stocks-{portfolio_id}"

        selected_point_index = select_frontier_point_index(context.frontier_points, target_volatility)
        selected_point = context.frontier_points[selected_point_index]
        optimization_weights = self._weights_for_optimization(selected_point.weights, context.instruments)
        metrics = portfolio_metrics_from_weights(
            optimization_weights,
            context.expected_returns,
            context.covariance,
            RISK_FREE_RATE,
        )
        contribution_map = risk_contributions(optimization_weights, context.covariance)
        allocations = self._build_sector_allocations(
            stock_weights=selected_point.weights,
            sector_risk_contributions=self._aggregate_sector_risk_contributions(
                contribution_map,
                context.instruments,
            ),
            assets=context.assets,
            instruments=context.instruments,
        )
        display_selected_point = self._to_sector_frontier_point(selected_point, context.instruments)

        summary = self.explanation_service.build_summary(
            selected_point=display_selected_point,
            target_volatility=target_volatility,
            assets=context.assets,
            used_fallback=context.used_fallback,
        )
        explanation_title, explanation_body = self.explanation_service.build_explanation(
            selected_point=selected_point,
            target_volatility=target_volatility,
            user_profile=user_profile,
        )
        if context.selected_combination is not None:
            mode_label = (
                "관리자 유니버스 모드"
                if context.data_source == SimulationDataSource.MANAGED_UNIVERSE
                else "개별 종목 유니버스 모드"
            )
            summary += f" {mode_label}에서는 자산군별 역할 정의에 따라 최적화 입력을 조립한 뒤 Efficient Frontier를 계산했습니다."
            explanation_body += (
                f" 현재 적용된 유니버스 ID는 '{context.selected_combination.combination_id}'이며, "
                "자산군별 역할 정의(대표 종목 1개 선택 또는 후보 종목 전체 사용, 배당 기대수익률 보정 등)에 맞춰 "
                "개별 종목 유니버스를 구성한 뒤 효율적 투자선을 계산하고 있습니다."
            )
            selected_average_correlation = self._estimate_selected_average_correlation(
                optimization_weights,
                context.covariance,
            )
            if selected_average_correlation is not None:
                summary += (
                    f" 또한 평균 종목 상관관계가 약 {selected_average_correlation:.2f} 수준이 되도록 "
                    f"상관관계 상한({MAX_PORTFOLIO_AVERAGE_CORRELATION:.2f}) 제약을 함께 적용했습니다."
                )
                explanation_body += (
                    f" 종목 간 평균 상관관계가 {MAX_PORTFOLIO_AVERAGE_CORRELATION:.2f}를 넘지 않도록 제약을 두어, "
                    "Sharpe Ratio를 추구하면서도 지나치게 비슷하게 움직이는 종목 쏠림을 줄였습니다."
                )

        return PortfolioSimulationResult(
            portfolio_id=portfolio_id,
            disclaimer=self.explanation_service.disclaimer(),
            summary=summary,
            explanation_title=explanation_title,
            explanation_body=explanation_body,
            data_source=context.data_source,
            data_source_label=context.data_source_label,
            target_volatility=target_volatility,
            metrics=metrics,
            weights=display_selected_point.weights,
            allocations=allocations,
            frontier_points=context.frontier_points,
            frontier_options=build_frontier_options(context.frontier_points),
            selected_point_index=selected_point_index,
            random_portfolios=context.random_portfolios,
            individual_assets=self._build_individual_assets(context),
            used_fallback=context.used_fallback,
            selected_combination=context.selected_combination,
        )

    def _prepare_context(self, user_profile: UserProfile) -> EngineContext:
        if user_profile.data_source == SimulationDataSource.MANAGED_UNIVERSE:
            return self._prepare_managed_universe_context()
        if user_profile.data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
            return self._prepare_demo_stock_universe_context()
        return self._prepare_assumption_context()

    def _prepare_assumption_context(self) -> EngineContext:
        repository = StaticDataRepository()
        assets = repository.load_asset_universe()
        market_assumptions = repository.load_market_assumptions()
        returns = repository.load_sample_returns()
        self._validate_returns(returns)

        asset_codes = [asset.code for asset in assets]
        expected_returns = self.return_model.calculate(
            ExpectedReturnModelInput(
                asset_codes=asset_codes,
                annual_returns=market_assumptions.annual_returns,
                returns=returns,
            )
        )
        covariance = self.covariance_model.calculate(returns)
        constraints = self.constraint_engine.build(assets)

        used_fallback = False
        try:
            frontier_points = self.optimizer.build_frontier(
                expected_returns=expected_returns,
                covariance=covariance,
                constraints=constraints,
                point_count=FRONTIER_POINT_COUNT,
            )
            random_portfolios = self.optimizer.sample_random_portfolios(
                expected_returns=expected_returns,
                covariance=covariance,
                constraints=constraints,
                sample_count=RANDOM_PORTFOLIO_COUNT,
            )
        except RuntimeError:
            frontier_points = self._fallback_frontier(expected_returns, covariance)
            random_portfolios = []
            used_fallback = True

        return EngineContext(
            assets=assets,
            instruments=[],
            expected_returns=expected_returns.reindex([asset.code for asset in assets]),
            covariance=covariance.reindex(index=[asset.code for asset in assets], columns=[asset.code for asset in assets]),
            frontier_points=sorted(frontier_points, key=lambda point: point.volatility),
            random_portfolios=random_portfolios,
            used_fallback=used_fallback,
            data_source=SimulationDataSource.ASSET_ASSUMPTIONS,
            data_source_label="자산군 가정값",
        )

    def _prepare_managed_universe_context(self) -> EngineContext:
        active_version = self.managed_universe_service.get_active_version()
        if active_version is None:
            raise RuntimeError(
                "활성 관리자 유니버스가 없습니다. /admin 에서 유니버스 버전을 active로 전환한 뒤 다시 시도해주세요."
            )

        assets = self.list_assets(version_id=active_version.version_id)
        instruments = self.managed_universe_service.get_active_instruments()
        if not instruments:
            raise RuntimeError("활성 관리자 유니버스에 등록된 종목이 없습니다. /admin 에서 종목을 추가한 뒤 다시 시도해주세요.")

        prices = self.managed_universe_service.load_prices_for_instruments(
            instruments,
            version_id=active_version.version_id,
        )
        if prices.empty:
            raise RuntimeError(
                "활성 관리자 유니버스의 가격 데이터가 없습니다. /admin 에서 가격 갱신을 먼저 실행해주세요."
            )

        representative_context = self._select_sector_representatives(
            assets=assets,
            instruments=instruments,
            prices=prices,
            combination_prefix=active_version.version_name,
            use_asset_min_weights=True,
        )
        return EngineContext(
            assets=assets,
            instruments=representative_context.selected_instruments,
            expected_returns=representative_context.expected_returns,
            covariance=representative_context.covariance,
            frontier_points=representative_context.frontier_points,
            random_portfolios=representative_context.random_portfolios,
            used_fallback=False,
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            data_source_label=f"관리자 대표 종목 유니버스 ({active_version.version_name})",
            selected_combination=representative_context.selection_view,
        )

    def _prepare_demo_stock_universe_context(
        self,
        *,
        source: SimulationDataSource = SimulationDataSource.STOCK_COMBINATION_DEMO,
        label: str = "개별 종목 대표 유니버스",
    ) -> EngineContext:
        assets = self.list_assets()
        instruments = self._load_demo_instruments()
        prices = StockDataRepository().load_stock_prices(str(DEMO_STOCK_PRICES_PATH))
        representative_context = self._select_sector_representatives(
            assets=assets,
            instruments=instruments,
            prices=prices,
            combination_prefix="demo-stock-universe",
            use_asset_min_weights=True,
        )
        return EngineContext(
            assets=assets,
            instruments=representative_context.selected_instruments,
            expected_returns=representative_context.expected_returns,
            covariance=representative_context.covariance,
            frontier_points=representative_context.frontier_points,
            random_portfolios=representative_context.random_portfolios,
            used_fallback=False,
            data_source=source,
            data_source_label=label,
            selected_combination=representative_context.selection_view,
        )

    def _load_demo_instruments(self):
        return StockDataRepository().load_stock_universe(str(DEMO_STOCK_UNIVERSE_PATH))

    def _build_component_frontier_context(
        self,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        component_returns: pd.DataFrame,
        stock_returns: pd.DataFrame,
        *,
        use_asset_min_weights: bool = False,
    ) -> tuple[pd.Series, pd.DataFrame, list[FrontierPoint], list[tuple[float, float, dict[str, float]]]]:
        asset_codes = list(component_returns.columns)
        correlation = component_returns.corr().reindex(index=asset_codes, columns=asset_codes)
        correlation = correlation.fillna(0.0).astype(float)
        for code in asset_codes:
            correlation.loc[code, code] = 1.0

        constraints = self.constraint_engine.build_for_codes(
            asset_codes,
            lower_bounds=self._component_lower_bounds(
                asset_codes,
                use_asset_min_weights=use_asset_min_weights,
            ),
            upper_bounds=self._component_upper_bounds(asset_codes),
            extra_constraints=(
                build_average_correlation_constraint(
                    correlation.values,
                    MAX_PORTFOLIO_AVERAGE_CORRELATION,
                ),
            ),
        )
        expected_returns = self._build_component_expected_returns(
            component_returns,
            selected_candidates,
            stock_returns=stock_returns,
        )
        covariance = self.covariance_model.calculate(component_returns)

        component_frontier_points = self.optimizer.build_frontier(
            expected_returns=expected_returns.reindex(constraints.asset_codes),
            covariance=covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes),
            constraints=constraints,
            point_count=FRONTIER_POINT_COUNT,
        )
        component_random_portfolios = self.optimizer.sample_random_portfolios(
            expected_returns=expected_returns.reindex(constraints.asset_codes),
            covariance=covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes),
            constraints=constraints,
            sample_count=RANDOM_PORTFOLIO_COUNT,
        )

        frontier_points = [
            FrontierPoint(
                volatility=point.volatility,
                expected_return=point.expected_return,
                weights=self.component_service.explode_component_weights(
                    point.weights,
                    selected_candidates,
                    stock_returns=stock_returns,
                ),
            )
            for point in sorted(component_frontier_points, key=lambda point: point.volatility)
        ]
        random_portfolios = [
            (
                float(point[0]),
                float(point[1]),
                self.component_service.explode_component_weights(
                    point[2],
                    selected_candidates,
                    stock_returns=stock_returns,
                ),
            )
            for point in component_random_portfolios
        ]
        return (
            expected_returns.reindex(asset_codes).astype(float),
            covariance.reindex(index=asset_codes, columns=asset_codes).astype(float),
            frontier_points,
            random_portfolios,
        )

    def _select_sector_representatives(
        self,
        *,
        assets: list[AssetClass] | None = None,
        instruments: list[StockInstrument],
        prices: pd.DataFrame,
        combination_prefix: str,
        use_asset_min_weights: bool = False,
    ) -> RepresentativeCombinationContext:
        stock_returns = StockDataRepository().build_stock_returns(prices)
        if stock_returns.empty:
            raise RuntimeError("가격 이력으로부터 유효 수익률을 생성하지 못했습니다.")

        assets = assets or self.list_assets()
        candidate_map = self._build_sector_candidate_map(assets, instruments, stock_returns)
        active_sector_codes = list(candidate_map.keys())
        combinations = self._build_representative_combinations(candidate_map)

        best_result: tuple[
            list[StockInstrument],
            dict[str, PortfolioComponentCandidate],
            pd.Series,
            pd.DataFrame,
            FrontierPoint,
            dict[str, list[str]],
            pd.DataFrame,
        ] | None = None
        successful_combinations = 0
        discard_reasons: dict[str, int] = {}

        for combination in combinations:
            try:
                selected_candidates = {
                    asset_code: combination[asset_code]
                    for asset_code in active_sector_codes
                }
                selected_stock_returns = self._prepare_selected_stock_returns(
                    stock_returns,
                    selected_candidates,
                )
                expected_returns, covariance, best_point = self._evaluate_stock_combination(
                    selected_stock_returns,
                    selected_candidates,
                    assets=assets,
                    use_asset_min_weights=use_asset_min_weights,
                )
            except RuntimeError as exc:
                reason = str(exc)
                discard_reasons[reason] = discard_reasons.get(reason, 0) + 1
                continue

            successful_combinations += 1
            members_by_sector = self.component_service.describe_members_by_asset(selected_candidates)
            selected_tickers = {
                ticker
                for candidate in selected_candidates.values()
                for ticker in candidate.member_tickers
            }
            selected_instruments = [
                instrument
                for instrument in instruments
                if instrument.ticker.upper() in selected_tickers
            ]
            if best_result is None:
                best_result = (
                    selected_instruments,
                    selected_candidates,
                    expected_returns,
                    covariance,
                    best_point,
                    members_by_sector,
                    selected_stock_returns,
                )
                continue

            current_best_point = best_result[4]
            current_metrics = portfolio_metrics_from_weights(
                current_best_point.weights,
                best_result[2],
                best_result[3],
                RISK_FREE_RATE,
            )
            candidate_metrics = portfolio_metrics_from_weights(
                best_point.weights,
                expected_returns,
                covariance,
                RISK_FREE_RATE,
            )
            if candidate_metrics.sharpe_ratio > current_metrics.sharpe_ratio:
                best_result = (
                    selected_instruments,
                    selected_candidates,
                    expected_returns,
                    covariance,
                    best_point,
                    members_by_sector,
                    selected_stock_returns,
                )

        if best_result is None:
            reason_text = ", ".join(f"{key}={value}" for key, value in sorted(discard_reasons.items()))
            raise RuntimeError(
                "대표 종목 조합을 만들지 못했습니다. "
                f"사유: {reason_text or 'unknown'}"
            )

        selected_instruments, selected_candidates, expected_returns, covariance, _, members_by_sector, selected_stock_returns = best_result
        (
            expected_returns,
            covariance,
            frontier_points,
            random_portfolios,
        ) = self._build_stock_frontier_context(
            selected_candidates=selected_candidates,
            stock_returns=selected_stock_returns,
            assets=assets,
            use_asset_min_weights=use_asset_min_weights,
        )
        selection_view = CombinationSelectionView(
            combination_id=self._build_combination_id(combination_prefix, members_by_sector),
            members_by_sector=members_by_sector,
            total_combinations_tested=len(combinations),
            successful_combinations=successful_combinations,
            discard_reasons=discard_reasons,
        )
        return RepresentativeCombinationContext(
            selected_instruments=selected_instruments,
            selected_candidates=selected_candidates,
            selection_view=selection_view,
            expected_returns=expected_returns,
            covariance=covariance,
            frontier_points=frontier_points,
            random_portfolios=random_portfolios,
        )

    def _prepare_selected_stock_returns(
        self,
        stock_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> pd.DataFrame:
        selected_tickers = sorted(
            {
                ticker.upper()
                for candidate in selected_candidates.values()
                for ticker in candidate.member_tickers
            }
        )
        selected_returns = stock_returns.reindex(columns=selected_tickers)
        selected_returns = selected_returns.dropna(axis=1, how="all")
        if selected_returns.empty:
            raise RuntimeError("활성 유니버스 종목의 수익률 시계열을 생성하지 못했습니다.")

        selected_returns = selected_returns.dropna(how="any")
        if len(selected_returns) < MINIMUM_HISTORY_ROWS:
            raise RuntimeError("insufficient_common_history")
        if selected_returns.shape[1] < 2:
            raise RuntimeError("최적화에 사용할 수 있는 종목 수가 부족합니다.")
        return selected_returns.astype(float)

    def _build_stock_frontier_context(
        self,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        stock_returns: pd.DataFrame,
        *,
        assets: list[AssetClass],
        use_asset_min_weights: bool = False,
    ) -> tuple[pd.Series, pd.DataFrame, list[FrontierPoint], list[tuple[float, float, dict[str, float]]]]:
        asset_codes = list(stock_returns.columns)
        expected_returns = self._build_selected_stock_expected_returns(
            stock_returns,
            selected_candidates,
        )
        covariance = self.covariance_model.calculate(stock_returns)
        constraints = self._build_stock_optimization_constraints(
            stock_returns,
            selected_candidates,
            assets=assets,
            use_asset_min_weights=use_asset_min_weights,
        )

        frontier_points = self.optimizer.build_frontier(
            expected_returns=expected_returns.reindex(constraints.asset_codes),
            covariance=covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes),
            constraints=constraints,
            point_count=FRONTIER_POINT_COUNT,
        )
        random_portfolios = self.optimizer.sample_random_portfolios(
            expected_returns=expected_returns.reindex(constraints.asset_codes),
            covariance=covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes),
            constraints=constraints,
            sample_count=RANDOM_PORTFOLIO_COUNT,
        )
        return (
            expected_returns.reindex(asset_codes).astype(float),
            covariance.reindex(index=asset_codes, columns=asset_codes).astype(float),
            sorted(frontier_points, key=lambda point: point.volatility),
            random_portfolios,
        )

    def _evaluate_stock_combination(
        self,
        selected_stock_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        *,
        assets: list[AssetClass],
        use_asset_min_weights: bool = False,
    ) -> tuple[pd.Series, pd.DataFrame, FrontierPoint]:
        expected_returns = self._build_selected_stock_expected_returns(
            selected_stock_returns,
            selected_candidates,
        )
        covariance = self.covariance_model.calculate(selected_stock_returns)
        constraints = self._build_stock_optimization_constraints(
            selected_stock_returns,
            selected_candidates,
            assets=assets,
            use_asset_min_weights=use_asset_min_weights,
        )
        best_point = self.optimizer.maximize_sharpe(
            expected_returns=expected_returns.reindex(constraints.asset_codes),
            covariance=covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes),
            constraints=constraints,
            risk_free_rate=RISK_FREE_RATE,
        )
        return (
            expected_returns.reindex(selected_stock_returns.columns).astype(float),
            covariance.reindex(index=selected_stock_returns.columns, columns=selected_stock_returns.columns).astype(float),
            best_point,
        )

    def _build_stock_optimization_constraints(
        self,
        stock_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        *,
        assets: list[AssetClass],
        use_asset_min_weights: bool,
    ):
        asset_codes = list(stock_returns.columns)
        lower_bounds, upper_bounds = self._build_stock_weight_bounds(
            stock_codes=asset_codes,
            selected_candidates=selected_candidates,
            assets=assets,
        )
        correlation = stock_returns.corr().reindex(index=asset_codes, columns=asset_codes)
        correlation = correlation.fillna(0.0).astype(float)
        for code in asset_codes:
            correlation.loc[code, code] = 1.0

        extra_constraints = (
            build_average_correlation_constraint(
                correlation.values,
                MAX_PORTFOLIO_AVERAGE_CORRELATION,
            ),
        ) + self._build_sector_weight_constraints(
            asset_codes,
            selected_candidates,
            assets=assets,
            use_asset_min_weights=use_asset_min_weights,
        )

        return self.constraint_engine.build_for_codes(
            asset_codes,
            lower_bounds=lower_bounds,
            upper_bounds=upper_bounds,
            extra_constraints=extra_constraints,
        )

    def _build_stock_weight_bounds(
        self,
        *,
        stock_codes: list[str],
        selected_candidates: dict[str, PortfolioComponentCandidate],
        assets: list[AssetClass],
    ) -> tuple[np.ndarray, np.ndarray]:
        if not stock_codes:
            return (
                np.array([], dtype=float),
                np.array([], dtype=float),
            )

        lower_bounds = np.full(len(stock_codes), float(STOCK_MIN_WEIGHT), dtype=float)
        upper_bounds = np.full(len(stock_codes), float(STOCK_MAX_WEIGHT), dtype=float)
        asset_by_code = {asset.code: asset for asset in assets}
        stock_index = {code.upper(): index for index, code in enumerate(stock_codes)}
        stock_code_set = {code.upper() for code in stock_codes}
        for asset_code, candidate in selected_candidates.items():
            member_indices = [
                stock_index[ticker.upper()]
                for ticker in candidate.member_tickers
                if ticker.upper() in stock_code_set
            ]
            member_count = len(member_indices)
            if member_count == 0:
                continue

            if candidate.weighting_mode == self.FIXED_TOTAL_WEIGHTING_MODE:
                fixed_stock_weight = float(self.FIXED_TOTAL_WEIGHT) / float(member_count)
                if fixed_stock_weight > float(STOCK_MAX_WEIGHT) + 1e-9:
                    raise RuntimeError(
                        f"{candidate.asset_name} 자산군은 종목 {member_count}개를 동일비중으로 나누면 "
                        f"종목당 {fixed_stock_weight:.2%}가 되어 종목 최대 비중 {float(STOCK_MAX_WEIGHT):.2%}를 초과합니다."
                    )
                for index in member_indices:
                    lower_bounds[index] = fixed_stock_weight
                    upper_bounds[index] = fixed_stock_weight
                continue

            asset = asset_by_code.get(asset_code)
            minimum_sector_weight = member_count * float(STOCK_MIN_WEIGHT)
            asset_max_weight = float(asset.max_weight) if asset is not None else 1.0
            if minimum_sector_weight > asset_max_weight + 1e-9:
                raise RuntimeError(
                    f"{candidate.asset_name} 자산군은 현재 후보 {member_count}개라 최소 비중만 합쳐도 "
                    f"{minimum_sector_weight:.2%}인데, 자산군 최대 비중은 {asset_max_weight:.2%}입니다. "
                    "후보 종목 수를 줄이거나 자산군 최대 비중을 조정해주세요."
                )

        minimum_total_weight = float(lower_bounds.sum())
        if minimum_total_weight > 1 + 1e-9:
            raise RuntimeError(
                "선택된 종목 수와 고정 비중 role 때문에 전체 최소 비중 합이 100%를 초과합니다. "
                f"현재 필요한 최소 비중 합 {minimum_total_weight:.2%}입니다."
            )
        return lower_bounds, upper_bounds

    def _build_sector_weight_constraints(
        self,
        stock_codes: list[str],
        selected_candidates: dict[str, PortfolioComponentCandidate],
        *,
        assets: list[AssetClass],
        use_asset_min_weights: bool,
    ) -> tuple[dict[str, object], ...]:
        asset_by_code = {asset.code: asset for asset in assets}
        stock_index = {code: index for index, code in enumerate(stock_codes)}
        constraints: list[dict[str, object]] = []

        for asset_code, candidate in selected_candidates.items():
            indices = np.array(
                [
                    stock_index[ticker.upper()]
                    for ticker in candidate.member_tickers
                    if ticker.upper() in stock_index
                ],
                dtype=int,
            )
            if indices.size == 0:
                continue

            if candidate.weighting_mode == self.FIXED_TOTAL_WEIGHTING_MODE:
                continue

            asset = asset_by_code.get(asset_code)
            max_weight = float(asset.max_weight) if asset is not None else 1.0
            constraints.append(
                {
                    "type": "ineq",
                    "fun": lambda weights, indices=indices, max_weight=max_weight: (
                        max_weight - float(np.sum(weights[indices]))
                    ),
                }
            )

            if use_asset_min_weights:
                min_weight = float(asset.min_weight) if asset is not None else 0.0
                if min_weight > 0:
                    constraints.append(
                        {
                            "type": "ineq",
                            "fun": lambda weights, indices=indices, min_weight=min_weight: (
                                float(np.sum(weights[indices])) - min_weight
                            ),
                        }
                    )

        return tuple(constraints)

    def _build_sector_candidate_map(
        self,
        assets: list[AssetClass],
        instruments: list[StockInstrument],
        stock_returns: pd.DataFrame,
    ) -> dict[str, list[PortfolioComponentCandidate]]:
        result: ComponentCandidateMapResult = self.component_service.build_candidate_map(
            assets,
            instruments,
            stock_returns,
        )
        if not result.candidate_map:
            raise RuntimeError("참여 가능한 섹터가 없습니다. /admin 에서 종목을 등록한 뒤 다시 시도해주세요.")

        if result.shortages:
            raise RuntimeError(
                "종목이 등록된 자산군에는 역할 정의에 맞는 유효 후보가 최소 1개씩 필요합니다. "
                + " | ".join(result.shortages)
            )
        return result.candidate_map

    def _build_representative_combinations(
        self,
        candidate_map: dict[str, list[PortfolioComponentCandidate]],
    ) -> list[dict[str, PortfolioComponentCandidate]]:
        sector_codes = list(candidate_map.keys())
        total_combinations = prod(len(candidate_map[sector_code]) for sector_code in sector_codes)

        if total_combinations <= REPRESENTATIVE_MAX_EXHAUSTIVE_COMBINATIONS:
            combinations: list[dict[str, PortfolioComponentCandidate]] = []
            for picks in product(*(candidate_map[sector_code] for sector_code in sector_codes)):
                combinations.append({sector_code: candidate for sector_code, candidate in zip(sector_codes, picks)})
            return combinations

        random_generator = np.random.default_rng(REPRESENTATIVE_COMBINATION_RANDOM_SEED)
        signatures: set[tuple[tuple[str, tuple[str, ...]], ...]] = set()
        combinations: list[dict[str, PortfolioComponentCandidate]] = []
        attempts = 0
        max_attempts = max(REPRESENTATIVE_COMBINATION_SAMPLE_COUNT * 20, 200)

        while len(combinations) < REPRESENTATIVE_COMBINATION_SAMPLE_COUNT and attempts < max_attempts:
            attempts += 1
            combination = {
                sector_code: candidate_map[sector_code][int(random_generator.integers(0, len(candidate_map[sector_code])))]
                for sector_code in sector_codes
            }
            signature = tuple(
                sorted((sector_code, tuple(candidate.member_tickers)) for sector_code, candidate in combination.items())
            )
            if signature in signatures:
                continue
            signatures.add(signature)
            combinations.append(combination)
        return combinations

    def _prepare_component_returns(
        self,
        stock_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> pd.DataFrame:
        frames: dict[str, pd.Series] = {}
        for asset_code, candidate in selected_candidates.items():
            frames[asset_code] = self.component_service.build_component_series(stock_returns, candidate)

        component_returns = pd.DataFrame(frames).dropna(how="any")
        if len(component_returns) < MINIMUM_HISTORY_ROWS:
            raise RuntimeError("insufficient_common_history")
        return component_returns.astype(float)

    def _evaluate_component_combination(
        self,
        component_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        *,
        stock_returns: pd.DataFrame,
        use_asset_min_weights: bool = False,
    ) -> tuple[pd.Series, pd.DataFrame, FrontierPoint]:
        asset_codes = list(component_returns.columns)
        correlation = component_returns.corr().reindex(index=asset_codes, columns=asset_codes)
        correlation = correlation.fillna(0.0).astype(float)
        for code in asset_codes:
            correlation.loc[code, code] = 1.0

        constraints = self.constraint_engine.build_for_codes(
            asset_codes,
            lower_bounds=self._component_lower_bounds(
                asset_codes,
                use_asset_min_weights=use_asset_min_weights,
            ),
            upper_bounds=self._component_upper_bounds(asset_codes),
            extra_constraints=(
                build_average_correlation_constraint(
                    correlation.values,
                    MAX_PORTFOLIO_AVERAGE_CORRELATION,
                ),
            ),
        )
        expected_returns = self._build_component_expected_returns(
            component_returns,
            selected_candidates,
            stock_returns=stock_returns,
        )
        covariance = self.covariance_model.calculate(component_returns)
        best_point = self.optimizer.maximize_sharpe(
            expected_returns=expected_returns.reindex(constraints.asset_codes),
            covariance=covariance.reindex(index=constraints.asset_codes, columns=constraints.asset_codes),
            constraints=constraints,
            risk_free_rate=RISK_FREE_RATE,
        )
        return (
            expected_returns.reindex(asset_codes).astype(float),
            covariance.reindex(index=asset_codes, columns=asset_codes).astype(float),
            best_point,
        )

    def _prepare_stock_returns_for_optimization(
        self,
        instruments: list[StockInstrument],
        prices: pd.DataFrame,
    ) -> pd.DataFrame:
        stock_returns = StockDataRepository().build_stock_returns(prices)
        if stock_returns.empty:
            raise RuntimeError("가격 이력으로부터 유효 수익률을 생성하지 못했습니다.")

        instrument_codes = [instrument.ticker.upper() for instrument in instruments]
        stock_returns = stock_returns.reindex(columns=instrument_codes)
        non_empty_returns = stock_returns.dropna(axis=1, how="all")
        if non_empty_returns.empty:
            raise RuntimeError("활성 유니버스 종목의 수익률 시계열을 생성하지 못했습니다.")

        valid_counts = non_empty_returns.count()
        eligible_codes = sorted(valid_counts[valid_counts >= MINIMUM_HISTORY_ROWS].index.tolist())
        if len(eligible_codes) < 2:
            available_text = ", ".join(
                f"{code}({int(valid_counts.get(code, 0))}행)"
                for code in valid_counts.sort_values(ascending=False).index[:8]
            )
            raise RuntimeError(
                "최소 252영업일 이상의 수익률 이력이 있는 종목이 2개 이상 필요합니다. "
                f"현재 유효 후보: {available_text or '없음'}"
            )

        eligible_returns = non_empty_returns[eligible_codes].copy()
        if eligible_returns.isna().all(axis=1).all():
            raise RuntimeError("유효 종목들의 공통 수익률 구간을 만들지 못했습니다.")
        return eligible_returns

    def _build_stock_expected_returns(self, stock_returns: pd.DataFrame) -> pd.Series:
        instrument_codes = list(stock_returns.columns)
        prior_weights = (
            pd.Series(1.0 / len(instrument_codes), index=instrument_codes, dtype=float)
            if instrument_codes
            else None
        )
        return self.black_litterman_stock_return_model.calculate(
            ExpectedReturnModelInput(
                asset_codes=instrument_codes,
                returns=stock_returns,
                prior_weights=prior_weights,
            )
        )

    def _build_selected_stock_expected_returns(
        self,
        stock_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> pd.Series:
        stock_codes = list(stock_returns.columns)
        return_modes = {
            candidate.return_mode
            for candidate in selected_candidates.values()
        }
        historical_expected_returns: pd.Series | None = None
        black_litterman_expected_returns: pd.Series | None = None

        if return_modes.intersection({"historical_mean", "historical_mean_plus_dividend_yield"}):
            historical_expected_returns = self.historical_stock_return_model.calculate(
                ExpectedReturnModelInput(
                    asset_codes=stock_codes,
                    returns=stock_returns,
                )
            )

        if return_modes.intersection({"black_litterman", "black_litterman_plus_dividend_yield"}):
            black_litterman_expected_returns = self._build_stock_expected_returns(stock_returns)

        ticker_return_mode: dict[str, str] = {}
        for candidate in selected_candidates.values():
            for ticker in candidate.member_tickers:
                ticker_return_mode[ticker.upper()] = candidate.return_mode

        expected_returns: dict[str, float] = {}
        for ticker in stock_codes:
            return_mode = ticker_return_mode.get(ticker.upper(), "black_litterman")
            if return_mode in {"historical_mean", "historical_mean_plus_dividend_yield"}:
                if historical_expected_returns is None:
                    raise RuntimeError("historical_mean 기대수익률 계산 결과를 찾을 수 없습니다.")
                expected_returns[ticker] = float(historical_expected_returns.loc[ticker])
                continue
            if return_mode in {"black_litterman", "black_litterman_plus_dividend_yield"}:
                if black_litterman_expected_returns is None:
                    raise RuntimeError("black_litterman 기대수익률 계산 결과를 찾을 수 없습니다.")
                expected_returns[ticker] = float(black_litterman_expected_returns.loc[ticker])
                continue
            raise RuntimeError(f"지원하지 않는 return_mode 입니다: {return_mode}")

        dividend_overlay = self._build_stock_dividend_return_overlay(
            stock_codes,
            selected_candidates,
        )
        return (
            pd.Series(expected_returns, dtype=float)
            .add(dividend_overlay.reindex(stock_codes).fillna(0.0), fill_value=0.0)
            .astype(float)
        )

    def _build_stock_dividend_return_overlay(
        self,
        stock_codes: list[str],
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> pd.Series:
        overlays = {code: 0.0 for code in stock_codes}
        for candidate in selected_candidates.values():
            for ticker in candidate.member_tickers:
                normalized = ticker.upper()
                if normalized in overlays:
                    overlays[normalized] = float(self.dividend_yield_service.get_annual_yield(normalized))
        return pd.Series(overlays, dtype=float)

    def _build_component_expected_returns(
        self,
        component_returns: pd.DataFrame,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        *,
        stock_returns: pd.DataFrame,
    ) -> pd.Series:
        asset_codes = list(component_returns.columns)
        prior_weights = self.component_service.component_prior_weight_series(selected_candidates)
        return_modes = {
            candidate.return_mode
            for candidate in selected_candidates.values()
        }
        historical_expected_returns: pd.Series | None = None
        black_litterman_expected_returns: pd.Series | None = None

        if return_modes.intersection({"historical_mean", "historical_mean_plus_dividend_yield"}):
            historical_expected_returns = self.historical_stock_return_model.calculate(
                ExpectedReturnModelInput(
                    asset_codes=asset_codes,
                    returns=component_returns,
                    prior_weights=prior_weights,
                )
            )

        if return_modes.intersection({"black_litterman", "black_litterman_plus_dividend_yield"}):
            black_litterman_expected_returns = self.black_litterman_stock_return_model.calculate(
                ExpectedReturnModelInput(
                    asset_codes=asset_codes,
                    returns=component_returns,
                    prior_weights=prior_weights,
                )
            )

        resolved_expected_returns: dict[str, float] = {}
        for asset_code in asset_codes:
            candidate = selected_candidates[asset_code]
            if candidate.return_mode in {"historical_mean", "historical_mean_plus_dividend_yield"}:
                if historical_expected_returns is None:
                    raise RuntimeError("historical_mean 기대수익률 계산 결과를 찾을 수 없습니다.")
                resolved_expected_returns[asset_code] = float(historical_expected_returns.loc[asset_code])
                continue

            if candidate.return_mode in {"black_litterman", "black_litterman_plus_dividend_yield"}:
                if black_litterman_expected_returns is None:
                    raise RuntimeError("black_litterman 기대수익률 계산 결과를 찾을 수 없습니다.")
                resolved_expected_returns[asset_code] = float(black_litterman_expected_returns.loc[asset_code])
                continue

            raise RuntimeError(f"지원하지 않는 return_mode 입니다: {candidate.return_mode}")

        expected_returns = pd.Series(resolved_expected_returns, dtype=float)
        dividend_overlay = self._build_component_dividend_return_overlay(
            selected_candidates,
            stock_returns=stock_returns,
        )
        return expected_returns.add(dividend_overlay.reindex(asset_codes).fillna(0.0), fill_value=0.0).astype(float)

    def _build_component_dividend_return_overlay(
        self,
        selected_candidates: dict[str, PortfolioComponentCandidate],
        *,
        stock_returns: pd.DataFrame,
    ) -> pd.Series:
        overlays: dict[str, float] = {}
        for asset_code, candidate in selected_candidates.items():
            member_tickers = list(candidate.member_tickers)
            if not member_tickers:
                overlays[asset_code] = 0.0
                continue

            member_weights = self.component_service.resolve_member_weights(
                stock_returns=stock_returns,
                candidate=candidate,
            )
            member_yields = [
                (
                    ticker,
                    self.dividend_yield_service.get_annual_yield(ticker),
                )
                for ticker in member_tickers
            ]
            overlays[asset_code] = float(
                sum(
                    float(member_weights.get(ticker, 0.0)) * float(annual_yield)
                    for ticker, annual_yield in member_yields
                )
            )
        return pd.Series(overlays, dtype=float)

    def _build_universe_selection(
        self,
        *,
        combination_id: str,
        instruments: list[StockInstrument],
    ) -> CombinationSelectionView:
        members_by_sector: dict[str, list[str]] = {}
        by_sector: dict[str, list[str]] = {}
        for instrument in instruments:
            by_sector.setdefault(instrument.sector_code, []).append(instrument.ticker)
        for sector_code, tickers in by_sector.items():
            members_by_sector[sector_code] = sorted(set(tickers))
        return CombinationSelectionView(
            combination_id=combination_id,
            members_by_sector=members_by_sector,
            total_combinations_tested=1,
            successful_combinations=1,
            discard_reasons={},
        )

    def _weights_for_optimization(
        self,
        weights: dict[str, float],
        instruments: list[StockInstrument],
    ) -> dict[str, float]:
        return {str(code).upper(): float(weight) for code, weight in weights.items()}

    def weights_for_optimization(
        self,
        weights: dict[str, float],
        instruments: list[StockInstrument],
    ) -> dict[str, float]:
        return self._weights_for_optimization(weights, instruments)

    def _build_individual_assets(self, context: EngineContext) -> list[IndividualAssetView]:
        instrument_by_ticker = {instrument.ticker.upper(): instrument for instrument in context.instruments}
        if instrument_by_ticker:
            points: list[IndividualAssetView] = []
            for code in context.expected_returns.index.astype(str).tolist():
                instrument = instrument_by_ticker.get(code.upper())
                if instrument is None or code not in context.covariance.index:
                    continue
                variance = float(context.covariance.loc[code, code])
                points.append(
                    IndividualAssetView(
                        code=instrument.ticker.upper(),
                        name=instrument.name,
                        volatility=max(variance, 0.0) ** 0.5,
                        expected_return=float(context.expected_returns.loc[code]),
                    )
                )
            if points:
                return points

        points: list[IndividualAssetView] = []
        selected_assets = (
            set(context.selected_combination.members_by_sector.keys())
            if context.selected_combination is not None
            else set(context.expected_returns.index.astype(str).tolist())
        )
        for asset in context.assets:
            if asset.code not in selected_assets:
                continue
            if asset.code not in context.expected_returns.index or asset.code not in context.covariance.index:
                continue
            variance = float(context.covariance.loc[asset.code, asset.code])
            points.append(
                IndividualAssetView(
                    code=asset.code,
                    name=asset.name,
                    volatility=max(variance, 0.0) ** 0.5,
                    expected_return=float(context.expected_returns.loc[asset.code]),
                )
            )
        return points

    def _build_combination_id(
        self,
        combination_prefix: str,
        members_by_sector: dict[str, list[str]],
    ) -> str:
        chunks: list[str] = []
        for sector_code, tickers in sorted(members_by_sector.items()):
            chunks.append(f"{sector_code}:{'-'.join(tickers)}")
        joined = "|".join(chunks)
        return f"{combination_prefix}|{joined}" if combination_prefix else joined

    def _aggregate_sector_weights(
        self,
        stock_weights: dict[str, float],
        instruments: list[StockInstrument],
    ) -> dict[str, float]:
        if not instruments:
            return {str(code): float(weight) for code, weight in stock_weights.items()}
        sector_by_ticker = {instrument.ticker.upper(): instrument.sector_code for instrument in instruments}
        aggregated: dict[str, float] = {}
        for ticker, weight in stock_weights.items():
            sector_code = sector_by_ticker.get(str(ticker).upper())
            if sector_code is None:
                continue
            aggregated[sector_code] = aggregated.get(sector_code, 0.0) + float(weight)
        return aggregated

    def _aggregate_sector_risk_contributions(
        self,
        stock_contributions: dict[str, float],
        instruments: list[StockInstrument],
    ) -> dict[str, float]:
        if not instruments:
            return {str(code): float(value) for code, value in stock_contributions.items()}
        sector_by_ticker = {instrument.ticker.upper(): instrument.sector_code for instrument in instruments}
        aggregated: dict[str, float] = {}
        for ticker, contribution in stock_contributions.items():
            sector_code = sector_by_ticker.get(str(ticker).upper())
            if sector_code is None:
                continue
            aggregated[sector_code] = aggregated.get(sector_code, 0.0) + float(contribution)
        return aggregated

    def aggregate_sector_risk_contributions(
        self,
        stock_contributions: dict[str, float],
        instruments: list[StockInstrument],
    ) -> dict[str, float]:
        return self._aggregate_sector_risk_contributions(stock_contributions, instruments)

    def _build_sector_allocations(
        self,
        *,
        stock_weights: dict[str, float],
        sector_risk_contributions: dict[str, float],
        assets: list[AssetClass],
        instruments: list[StockInstrument],
    ) -> list[AllocationView]:
        sector_weights = self._aggregate_sector_weights(stock_weights, instruments)
        asset_by_code = {asset.code: asset for asset in assets}
        allocations: list[AllocationView] = []
        for sector_code, weight in sorted(sector_weights.items(), key=lambda item: item[1], reverse=True):
            asset = asset_by_code.get(sector_code)
            if asset is None:
                continue
            allocations.append(
                AllocationView(
                    asset_code=asset.code,
                    asset_name=asset.name,
                    weight=float(weight),
                    risk_contribution=float(sector_risk_contributions.get(sector_code, 0.0)),
                )
            )
        return allocations

    def build_sector_allocations(
        self,
        *,
        stock_weights: dict[str, float],
        sector_risk_contributions: dict[str, float],
        assets: list[AssetClass],
        instruments: list[StockInstrument],
    ) -> list[AllocationView]:
        return self._build_sector_allocations(
            stock_weights=stock_weights,
            sector_risk_contributions=sector_risk_contributions,
            assets=assets,
            instruments=instruments,
        )

    def _to_sector_frontier_point(
        self,
        point: FrontierPoint,
        instruments: list[StockInstrument],
    ) -> FrontierPoint:
        return FrontierPoint(
            volatility=point.volatility,
            expected_return=point.expected_return,
            weights=self._aggregate_sector_weights(point.weights, instruments),
        )

    def _build_sector_checks(
        self,
        assets: list[AssetClass],
        instruments,
    ) -> list[ManagedUniverseSectorReadiness]:
        counts_by_sector: dict[str, int] = {}
        for instrument in instruments:
            counts_by_sector[instrument.sector_code] = counts_by_sector.get(instrument.sector_code, 0) + 1

        return [
            ManagedUniverseSectorReadiness(
                sector_code=asset.code,
                sector_name=asset.name,
                required_count=SECTOR_MINIMUM_INSTRUMENTS if int(counts_by_sector.get(asset.code, 0)) > 0 else 0,
                actual_count=int(counts_by_sector.get(asset.code, 0)),
                ready=(
                    int(counts_by_sector.get(asset.code, 0)) >= SECTOR_MINIMUM_INSTRUMENTS
                    if int(counts_by_sector.get(asset.code, 0)) > 0
                    else True
                ),
            )
            for asset in assets
        ]

    def _estimate_selected_average_correlation(
        self,
        stock_weights: dict[str, float],
        covariance: pd.DataFrame,
    ) -> float | None:
        if covariance.empty or len(covariance.index) < 2:
            return None

        variances = pd.Series(covariance.values.diagonal(), index=covariance.index, dtype=float)
        standard_deviations = variances.clip(lower=0.0).pow(0.5)
        denominator = standard_deviations.values[:, None] * standard_deviations.values[None, :]
        if (denominator <= 0).all():
            return None

        correlation = covariance.divide(standard_deviations, axis=0).divide(standard_deviations, axis=1)
        correlation = correlation.replace([float("inf"), float("-inf")], 0.0).fillna(0.0)
        for code in correlation.index:
            correlation.loc[code, code] = 1.0

        ordered_weights = pd.Series(stock_weights, dtype=float).reindex(correlation.index).fillna(0.0).values
        return float(average_pairwise_correlation(ordered_weights, correlation.values))

    def _fallback_frontier(self, expected_returns: pd.Series, covariance: pd.DataFrame) -> list[FrontierPoint]:
        fallback_points: list[FrontierPoint] = []
        for profile in (RiskProfile.CONSERVATIVE, RiskProfile.BALANCED, RiskProfile.GROWTH):
            weights = FALLBACK_WEIGHTS[profile]
            metrics = portfolio_metrics_from_weights(weights, expected_returns, covariance, RISK_FREE_RATE)
            fallback_points.append(
                FrontierPoint(
                    volatility=metrics.volatility,
                    expected_return=metrics.expected_return,
                    weights=weights,
                )
            )
        return fallback_points

    def _validate_returns(self, returns: pd.DataFrame) -> None:
        if returns.isna().any().any():
            raise RuntimeError("샘플 수익률 데이터에 결측치가 포함되어 있습니다.")
        if returns.shape[0] < MINIMUM_HISTORY_ROWS:
            raise RuntimeError("최소 1년 이상의 샘플 데이터가 필요합니다.")
