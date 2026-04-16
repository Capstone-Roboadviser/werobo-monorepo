from __future__ import annotations

import math

import numpy as np
import pandas as pd

from app.core.config import (
    DEMO_STOCK_PRICES_PATH,
    ENABLE_LIVE_MARKET_DATA_FETCH,
    MINIMUM_HISTORY_ROWS,
    RISK_FREE_RATE,
)
from app.data.stock_repository import StockDataRepository
from app.domain.enums import SimulationDataSource
from app.domain.models import AssetClass, PortfolioHistoryPoint, PortfolioHistorySeries, StockInstrument
from app.engine.comparison import ComparisonLine, ComparisonResult, build_comparison
from app.services.portfolio_service import PortfolioSimulationService


class PortfolioAnalyticsService:
    """Reusable analytics for history and comparison endpoints.

    Route modules and mobile adapters both rely on these calculations, so they
    live here instead of behind FastAPI route functions.
    """

    def __init__(
        self,
        *,
        portfolio_service: PortfolioSimulationService | None = None,
    ) -> None:
        self.portfolio_service = portfolio_service or PortfolioSimulationService()

    def load_history_prices(
        self,
        *,
        tickers: list[str],
        data_source: SimulationDataSource,
    ) -> pd.DataFrame:
        normalized_tickers = sorted({str(ticker).strip().upper() for ticker in tickers if ticker})
        if not normalized_tickers:
            raise ValueError("비중 정보가 비어 있습니다.")

        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            if not self.portfolio_service.managed_universe_service.is_configured():
                raise ValueError("관리자 유니버스 DB가 설정되지 않았습니다.")
            prices = self.portfolio_service.managed_universe_service.load_prices_for_active_version_tickers(
                normalized_tickers
            )
        elif data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
            repo = StockDataRepository()
            prices = repo.load_stock_prices(str(DEMO_STOCK_PRICES_PATH))
            prices["ticker"] = prices["ticker"].astype(str).str.upper()
        else:
            raise ValueError("종목 히스토리 조회는 관리자 유니버스 또는 데모 종목 유니버스에서만 지원합니다.")

        if prices.empty:
            raise ValueError("요청한 종목의 가격 데이터가 없습니다.")

        prices = prices.copy()
        prices["ticker"] = prices["ticker"].astype(str).str.upper()
        available_tickers = set(prices["ticker"].unique())
        matched = [ticker for ticker in normalized_tickers if ticker in available_tickers]
        if not matched:
            raise ValueError("요청한 종목의 가격 데이터가 없습니다.")

        filtered = prices[prices["ticker"].isin(matched)].copy()
        if filtered.empty:
            raise ValueError("요청한 종목의 가격 데이터가 없습니다.")
        return filtered

    def build_portfolio_return_series(
        self,
        *,
        weights: dict[str, float],
        data_source: SimulationDataSource,
    ) -> tuple[pd.Series, pd.DatetimeIndex]:
        try:
            tickers = [ticker.upper() for ticker in weights.keys()]
            weights_upper = {ticker.upper(): weight for ticker, weight in weights.items()}
            prices = self.load_history_prices(tickers=tickers, data_source=data_source)
            pivoted = (
                prices.pivot_table(
                    index="date",
                    columns="ticker",
                    values="adjusted_close",
                    aggfunc="last",
                )
                .sort_index()
            )
            if pivoted.empty:
                raise ValueError("요청한 종목의 가격 데이터가 없습니다.")

            returns = pivoted.pct_change().dropna(how="all")
            if returns.empty:
                raise ValueError("요청한 종목으로 유효 수익률 시계열을 만들지 못했습니다.")

            weight_series = pd.Series(weights_upper, dtype=float).reindex(returns.columns).fillna(0.0)
            total = float(weight_series.sum())
            if total <= 0:
                raise ValueError("포트폴리오 비중 합계가 0보다 커야 합니다.")
            weight_series = weight_series / total

            portfolio_returns = returns.fillna(0.0).dot(weight_series)
            if portfolio_returns.empty:
                raise ValueError("요청한 종목으로 포트폴리오 수익률을 만들지 못했습니다.")
            return portfolio_returns, pivoted.index
        except ValueError:
            raise
        except Exception as exc:
            raise RuntimeError(f"포트폴리오 히스토리 시계열을 만드는 중 오류가 발생했습니다: {exc}") from exc

    def build_volatility_history(
        self,
        *,
        weights: dict[str, float],
        data_source: SimulationDataSource,
        rolling_window: int,
    ) -> PortfolioHistorySeries:
        try:
            portfolio_returns, all_dates = self.build_portfolio_return_series(
                weights=weights,
                data_source=data_source,
            )
            rolling_vol = (
                portfolio_returns
                .rolling(window=rolling_window, min_periods=rolling_window)
                .std()
                * math.sqrt(252)
            ).dropna()
            return PortfolioHistorySeries(
                points=[
                    PortfolioHistoryPoint(
                        date=date.strftime("%Y-%m-%d"),
                        value=round(float(vol), 6),
                    )
                    for date, vol in rolling_vol.items()
                    if np.isfinite(vol)
                ],
                earliest_data_date=all_dates.min().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
                latest_data_date=all_dates.max().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
            )
        except ValueError:
            raise
        except RuntimeError:
            raise
        except Exception as exc:
            raise RuntimeError(f"변동성 추이 계산 중 오류가 발생했습니다: {exc}") from exc

    def build_return_history(
        self,
        *,
        weights: dict[str, float],
        data_source: SimulationDataSource,
        rolling_window: int,
    ) -> PortfolioHistorySeries:
        try:
            portfolio_returns, all_dates = self.build_portfolio_return_series(
                weights=weights,
                data_source=data_source,
            )
            rolling_ret = (
                portfolio_returns
                .rolling(window=rolling_window, min_periods=rolling_window)
                .mean()
                * 252
            ).dropna()
            return PortfolioHistorySeries(
                points=[
                    PortfolioHistoryPoint(
                        date=date.strftime("%Y-%m-%d"),
                        value=round(float(ret), 6),
                    )
                    for date, ret in rolling_ret.items()
                    if np.isfinite(ret)
                ],
                earliest_data_date=all_dates.min().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
                latest_data_date=all_dates.max().strftime("%Y-%m-%d") if len(all_dates) > 0 else "",
            )
        except ValueError:
            raise
        except RuntimeError:
            raise
        except Exception as exc:
            raise RuntimeError(f"기대수익률 추이 계산 중 오류가 발생했습니다: {exc}") from exc

    def build_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
        stock_weights: dict[str, float] | None = None,
        portfolio_code: str | None = None,
    ) -> ComparisonResult:
        if stock_weights:
            return self._build_fixed_weight_comparison_backtest(
                data_source=data_source,
                stock_weights=stock_weights,
                portfolio_code=portfolio_code,
            )

        assets = self._load_comparison_assets(data_source)
        instruments, prices, combination_prefix = self._load_comparison_universe(data_source)
        prices = prices.copy()
        prices["date"] = pd.to_datetime(prices["date"]).dt.normalize()
        if prices.empty:
            raise ValueError("비교 백테스트에 사용할 가격 데이터가 없습니다.")

        train_prices, test_prices, train_end_date, test_start_date = self._split_prices_train_test(
            prices,
            split_ratio=0.9,
        )
        train_start_date = pd.Timestamp(train_prices["date"].min()).normalize()

        profile_data = self.portfolio_service.get_all_profile_weights_for_price_window(
            data_source=data_source,
            instruments=instruments,
            prices=train_prices,
            combination_prefix=f"{combination_prefix}-train-{train_end_date.strftime('%Y%m%d')}",
        )

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
            raise RuntimeError("test 구간에서 공통 가격 데이터를 만들지 못했습니다.")

        portfolios = {name: weights for name, (weights, _) in profile_data.items()}
        expected_returns = {name: expected_return for name, (_, expected_return) in profile_data.items()}
        benchmark_series = self._fetch_benchmark_prices(test_start_date.strftime("%Y-%m-%d"))
        extra_lines = self._build_comparison_extra_lines(
            assets=assets,
            instruments=instruments,
            prices=test_prices,
            date_index=pivoted.index,
        )

        try:
            return build_comparison(
                pivoted,
                portfolios,
                expected_returns,
                benchmark_series,
                extra_lines=extra_lines,
                train_start_date=train_start_date.strftime("%Y-%m-%d"),
                train_end_date=train_end_date.strftime("%Y-%m-%d"),
                split_ratio=0.9,
            )
        except Exception as exc:
            raise RuntimeError(f"비교 백테스트 계산 중 오류: {exc}") from exc

    def _build_fixed_weight_comparison_backtest(
        self,
        *,
        data_source: SimulationDataSource,
        stock_weights: dict[str, float],
        portfolio_code: str | None = None,
    ) -> ComparisonResult:
        assets = self._load_comparison_assets(data_source)
        instruments, prices, _ = self._load_comparison_universe(data_source)
        prices = prices.copy()
        prices["date"] = pd.to_datetime(prices["date"]).dt.normalize()
        if prices.empty:
            raise ValueError("비교 백테스트에 사용할 가격 데이터가 없습니다.")

        normalized_weights = {
            str(ticker).upper(): float(weight)
            for ticker, weight in stock_weights.items()
            if float(weight) > 0
        }
        if not normalized_weights:
            raise ValueError("stock_weights에 0보다 큰 비중이 하나 이상 있어야 합니다.")

        pivoted = (
            prices[prices["ticker"].astype(str).str.upper().isin(normalized_weights.keys())]
            .assign(
                ticker=lambda frame: frame["ticker"].astype(str).str.upper(),
                date=lambda frame: pd.to_datetime(frame["date"]).dt.normalize(),
            )
            .pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last")
            .sort_index()
            .ffill()
            .dropna(how="any")
        )
        if pivoted.empty:
            raise RuntimeError("선택 포트폴리오의 공통 가격 데이터를 만들지 못했습니다.")

        available_weights = {
            ticker: weight
            for ticker, weight in normalized_weights.items()
            if ticker in pivoted.columns
        }
        if not available_weights:
            raise RuntimeError("선택 포트폴리오의 가격 데이터가 없습니다.")
        total_weight = sum(available_weights.values())
        portfolio_weights = {
            ticker: weight / total_weight
            for ticker, weight in available_weights.items()
        }

        benchmark_series = self._fetch_benchmark_prices(
            pivoted.index[0].strftime("%Y-%m-%d"),
        )
        extra_lines = self._build_comparison_extra_lines(
            assets=assets,
            instruments=instruments,
            prices=prices,
            date_index=pivoted.index,
        )

        line_key = str(portfolio_code or "selected").strip() or "selected"
        try:
            start_date = pivoted.index[0].strftime("%Y-%m-%d")
            return build_comparison(
                pivoted,
                {line_key: portfolio_weights},
                {},
                benchmark_series,
                extra_lines=extra_lines,
                train_start_date=start_date,
                train_end_date=start_date,
                split_ratio=1.0,
            )
        except Exception as exc:
            raise RuntimeError(f"선택 포트폴리오 비교 백테스트 계산 중 오류: {exc}") from exc

    def _load_comparison_assets(
        self,
        data_source: SimulationDataSource,
    ) -> list:
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            active_version = self.portfolio_service.managed_universe_service.get_active_version()
            if active_version is None:
                raise RuntimeError("활성화된 관리자 유니버스 버전이 없습니다.")
            return self.portfolio_service.list_assets(version_id=active_version.version_id)
        return self.portfolio_service.list_assets()

    def _load_comparison_universe(
        self,
        data_source: SimulationDataSource,
    ) -> tuple[list, pd.DataFrame, str]:
        if data_source == SimulationDataSource.MANAGED_UNIVERSE:
            active_version = self.portfolio_service.managed_universe_service.get_active_version()
            if active_version is None:
                raise RuntimeError("활성화된 관리자 유니버스 버전이 없습니다.")
            instruments = self.portfolio_service.managed_universe_service.get_active_instruments()
            if not instruments:
                raise RuntimeError("활성 관리자 유니버스에 등록된 종목이 없습니다.")
            prices = self.portfolio_service.managed_universe_service.load_prices_for_instruments(
                instruments,
                version_id=active_version.version_id,
            )
            return instruments, prices, active_version.version_name

        if data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
            instruments = self.portfolio_service.list_stocks(SimulationDataSource.STOCK_COMBINATION_DEMO)
            prices = StockDataRepository().load_stock_prices(str(DEMO_STOCK_PRICES_PATH))
            return instruments, prices, "demo-stock-universe"

        raise ValueError("포트폴리오 비교 백테스트는 관리자 유니버스 또는 데모 종목 유니버스에서만 지원합니다.")

    def _split_prices_train_test(
        self,
        prices: pd.DataFrame,
        *,
        split_ratio: float,
    ) -> tuple[pd.DataFrame, pd.DataFrame, pd.Timestamp, pd.Timestamp]:
        if prices.empty:
            raise ValueError("비교 백테스트에 사용할 가격 데이터가 없습니다.")

        unique_dates = pd.Index(sorted(pd.to_datetime(prices["date"]).dt.normalize().unique()))
        required_rows = max(MINIMUM_HISTORY_ROWS + 1, 30)
        if len(unique_dates) < required_rows:
            raise RuntimeError(f"비교 백테스트를 위해서는 최소 {required_rows}영업일 이상의 가격 이력이 필요합니다.")

        split_index = int(len(unique_dates) * split_ratio)
        split_index = min(max(split_index, MINIMUM_HISTORY_ROWS), len(unique_dates) - 1)
        train_end_date = pd.Timestamp(unique_dates[split_index - 1]).normalize()
        test_start_date = pd.Timestamp(unique_dates[split_index]).normalize()

        train_prices = prices[pd.to_datetime(prices["date"]).dt.normalize() <= train_end_date].copy()
        test_prices = prices[pd.to_datetime(prices["date"]).dt.normalize() >= test_start_date].copy()
        if train_prices.empty or test_prices.empty:
            raise RuntimeError("train/test 분할 후 사용할 가격 데이터가 부족합니다.")
        return train_prices, test_prices, train_end_date, test_start_date

    def _fetch_benchmark_prices(self, start_date: str) -> dict[str, pd.Series]:
        benchmarks: dict[str, pd.Series] = {}
        if not ENABLE_LIVE_MARKET_DATA_FETCH:
            return benchmarks
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

    def _build_comparison_extra_lines(
        self,
        *,
        assets: list,
        instruments: list[StockInstrument],
        prices: pd.DataFrame,
        date_index: pd.DatetimeIndex,
    ) -> list[ComparisonLine]:
        lines: list[ComparisonLine] = []

        benchmark_line = self._build_equal_weight_asset_benchmark_line(
            assets=assets,
            instruments=instruments,
            prices=prices,
            date_index=date_index,
        )
        if benchmark_line is not None:
            lines.append(benchmark_line)

        bond_line = self._build_fixed_bond_line(
            date_index=date_index,
            annual_yield=RISK_FREE_RATE,
        )
        if bond_line is not None:
            lines.append(bond_line)

        return lines

    def _build_equal_weight_asset_benchmark_line(
        self,
        *,
        assets: list[AssetClass],
        instruments: list[StockInstrument],
        prices: pd.DataFrame,
        date_index: pd.DatetimeIndex,
    ) -> ComparisonLine | None:
        if prices.empty or len(date_index) < 2:
            return None

        benchmark_assets = [
            asset for asset in assets
            if not self._exclude_from_equal_weight_asset_benchmark(asset)
        ]
        if not benchmark_assets:
            return None

        grouped: dict[str, list[StockInstrument]] = {}
        for instrument in instruments:
            grouped.setdefault(instrument.sector_code, []).append(instrument)

        price_table = (
            prices.assign(
                ticker=prices["ticker"].astype(str).str.upper(),
                date=pd.to_datetime(prices["date"]).dt.normalize(),
            )
            .pivot_table(index="date", columns="ticker", values="adjusted_close", aggfunc="last")
            .sort_index()
        )

        if price_table.empty:
            return None

        sector_paths: dict[str, pd.Series] = {}
        for asset in benchmark_assets:
            sector_path = self._build_sector_basket_path(
                asset=asset,
                sector_instruments=grouped.get(asset.code, []),
                price_table=price_table,
                date_index=date_index,
            )
            if sector_path is None:
                return None
            sector_paths[asset.code] = sector_path

        expected_asset_codes = [asset.code for asset in benchmark_assets]
        if not expected_asset_codes:
            return None

        benchmark_path = pd.DataFrame(
            {
                asset_code: sector_paths[asset_code]
                for asset_code in expected_asset_codes
            }
        ).mean(axis=1)
        benchmark_path = benchmark_path.replace([np.inf, -np.inf], np.nan).dropna()
        if benchmark_path.empty:
            return None

        return ComparisonLine(
            key="benchmark_avg",
            label=f"{len(expected_asset_codes)}자산 단순평균",
            color="#999999",
            style="dashed",
            points=[
                (
                    date.strftime("%Y-%m-%d"),
                    round((float(value) - 1.0) * 100, 4),
                )
                for date, value in benchmark_path.items()
            ],
        )

    def _exclude_from_equal_weight_asset_benchmark(self, asset: AssetClass) -> bool:
        return self._uses_fixed_five_percent_conservative_return(asset)

    def _build_sector_basket_path(
        self,
        *,
        asset: AssetClass,
        sector_instruments: list[StockInstrument],
        price_table: pd.DataFrame,
        date_index: pd.DatetimeIndex,
    ) -> pd.Series | None:
        realized_path = self._build_realized_sector_basket_path(
            asset=asset,
            sector_instruments=sector_instruments,
            price_table=price_table,
            date_index=date_index,
        )
        if realized_path is None:
            return None

        if not self._uses_fixed_five_percent_conservative_return(asset):
            return realized_path

        conservative_cap_path = self._build_conservative_cap_path(
            date_index=realized_path.index,
        )
        capped_path = pd.concat(
            [realized_path.astype(float), conservative_cap_path.astype(float)],
            axis=1,
            join="inner",
        ).min(axis=1)
        capped_path = capped_path.replace([np.inf, -np.inf], np.nan).dropna()
        if capped_path.empty:
            return None
        return capped_path.astype(float)

    def _build_realized_sector_basket_path(
        self,
        *,
        asset: AssetClass,
        sector_instruments: list[StockInstrument],
        price_table: pd.DataFrame,
        date_index: pd.DatetimeIndex,
    ) -> pd.Series | None:
        tickers = [
            instrument.ticker.upper()
            for instrument in sector_instruments
            if instrument.ticker.upper() in price_table.columns
        ]
        if not tickers:
            return None

        aligned = price_table.reindex(index=date_index, columns=tickers).ffill().bfill()
        aligned = aligned.dropna(axis=1, how="all")
        if aligned.empty:
            return None

        aligned = aligned.loc[:, aligned.notna().all(axis=0)]
        if aligned.empty:
            return None

        weights = self._normalize_sector_member_weights(
            asset=asset,
            sector_instruments=sector_instruments,
            tickers=list(aligned.columns),
        )
        base = aligned.iloc[0].replace(0.0, np.nan)
        if base.isna().any():
            return None

        relative = aligned.divide(base, axis=1)
        path = relative.mul(weights.reindex(relative.columns), axis=1).sum(axis=1)
        path = path.replace([np.inf, -np.inf], np.nan).dropna()
        if path.empty:
            return None
        return path.astype(float)

    def _build_conservative_cap_path(
        self,
        *,
        date_index: pd.DatetimeIndex,
    ) -> pd.Series:
        annual_return = (
            self.portfolio_service
            .fixed_five_percent_role_return_service
            .conservative_expected_return()
        )
        trading_years = np.arange(len(date_index), dtype=float) / 252.0
        cumulative = np.power(1.0 + annual_return, trading_years)
        return pd.Series(cumulative, index=pd.DatetimeIndex(date_index), dtype=float)

    def _uses_fixed_five_percent_conservative_return(self, asset: AssetClass) -> bool:
        return (
            asset.role_key == "fixed_five_percent_equal_weight"
            or asset.weighting_mode == self.portfolio_service.FIXED_TOTAL_WEIGHTING_MODE
            or asset.return_mode
            == self.portfolio_service.fixed_five_percent_role_return_service.RETURN_MODE
        )

    def _normalize_sector_member_weights(
        self,
        *,
        asset: AssetClass,
        sector_instruments: list[StockInstrument],
        tickers: list[str],
    ) -> pd.Series:
        if asset.weighting_mode == self.portfolio_service.FIXED_TOTAL_WEIGHTING_MODE:
            equal_weight = 1.0 / len(tickers)
            return pd.Series({ticker: equal_weight for ticker in tickers}, dtype=float)

        weights = pd.Series(
            {
                instrument.ticker.upper(): (
                    float(instrument.base_weight)
                    if instrument.base_weight is not None
                    else 0.0
                )
                for instrument in sector_instruments
                if instrument.ticker.upper() in tickers
            },
            dtype=float,
        ).clip(lower=0.0)
        total = float(weights.sum())
        if total <= 0:
            equal_weight = 1.0 / len(tickers)
            return pd.Series({ticker: equal_weight for ticker in tickers}, dtype=float)
        return (weights / total).reindex(tickers).fillna(0.0).astype(float)

    def _build_fixed_bond_line(
        self,
        *,
        date_index: pd.DatetimeIndex,
        annual_yield: float,
    ) -> ComparisonLine | None:
        if len(date_index) < 2:
            return None

        start_date = date_index[0]
        points = []
        for date in date_index:
            years_elapsed = (date - start_date).days / 365.25
            cumulative_return = annual_yield * years_elapsed * 100
            points.append((date.strftime("%Y-%m-%d"), round(float(cumulative_return), 4)))

        return ComparisonLine(
            key="treasury",
            label="채권 수익률",
            color="#78716c",
            style="dashed",
            points=points,
        )
