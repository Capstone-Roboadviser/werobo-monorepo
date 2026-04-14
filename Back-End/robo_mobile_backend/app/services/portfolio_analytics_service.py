from __future__ import annotations

import math

import numpy as np
import pandas as pd

from app.core.config import DEMO_STOCK_PRICES_PATH, ENABLE_LIVE_MARKET_DATA_FETCH, MINIMUM_HISTORY_ROWS
from app.data.stock_repository import StockDataRepository
from app.domain.enums import SimulationDataSource
from app.domain.models import PortfolioHistoryPoint, PortfolioHistorySeries
from app.engine.comparison import ComparisonResult, build_comparison
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
    ) -> ComparisonResult:
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

        try:
            return build_comparison(
                pivoted,
                portfolios,
                expected_returns,
                benchmark_series,
                train_start_date=train_start_date.strftime("%Y-%m-%d"),
                train_end_date=train_end_date.strftime("%Y-%m-%d"),
                split_ratio=0.9,
            )
        except Exception as exc:
            raise RuntimeError(f"비교 백테스트 계산 중 오류: {exc}") from exc

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
