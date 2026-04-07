from __future__ import annotations

from dataclasses import dataclass

import pandas as pd
import yfinance as yf

from app.core.config import MINIMUM_HISTORY_ROWS, SECTOR_MINIMUM_INSTRUMENTS
from app.domain.models import AssetClass, PortfolioComponentCandidate, StockInstrument


@dataclass(frozen=True)
class ComponentCandidateMapResult:
    candidate_map: dict[str, list[PortfolioComponentCandidate]]
    shortages: list[str]


class PortfolioComponentService:
    """Builds optimizer input components from asset-class role metadata."""

    def __init__(self) -> None:
        self._market_cap_cache: dict[str, float | None] = {}

    def build_candidate_map(
        self,
        assets: list[AssetClass],
        instruments: list[StockInstrument],
        stock_returns: pd.DataFrame,
    ) -> ComponentCandidateMapResult:
        available_codes = set(stock_returns.columns.astype(str).str.upper().tolist())
        by_asset: dict[str, list[str]] = {}
        for instrument in instruments:
            by_asset.setdefault(instrument.sector_code, []).append(instrument.ticker.upper())

        shortages: list[str] = []
        candidate_map: dict[str, list[PortfolioComponentCandidate]] = {}
        for asset in assets:
            registered_codes = sorted(set(by_asset.get(asset.code, [])))
            if not registered_codes:
                continue

            available_tickers = [ticker for ticker in registered_codes if ticker in available_codes]
            if len(available_tickers) < SECTOR_MINIMUM_INSTRUMENTS:
                shortages.append(
                    f"{asset.name}({asset.code}) 가격 이력이 있는 후보 {len(available_tickers)}개 / 등록 종목 {len(registered_codes)}개"
                )
                continue

            candidates = self._build_candidates_for_asset(asset, available_tickers)
            if not candidates:
                shortages.append(
                    f"{asset.name}({asset.code})의 역할 '{asset.role_key}'에 맞는 구성 후보를 만들지 못했습니다."
                )
                continue
            candidate_map[asset.code] = candidates

        return ComponentCandidateMapResult(candidate_map=candidate_map, shortages=shortages)

    def build_component_series(
        self,
        stock_returns: pd.DataFrame,
        candidate: PortfolioComponentCandidate,
    ) -> pd.Series:
        tickers = [ticker.upper() for ticker in candidate.member_tickers]
        component_returns = stock_returns.reindex(columns=tickers)
        if component_returns.empty:
            raise RuntimeError(f"{candidate.asset_code} 자산군의 수익률 시계열을 만들지 못했습니다.")

        if candidate.weighting_mode == "single":
            series = component_returns[tickers[0]]
        elif candidate.weighting_mode == "equal_weight":
            component_returns = component_returns.dropna(how="any")
            if component_returns.empty:
                raise RuntimeError(f"{candidate.asset_code} 자산군의 바스켓 공통 수익률 구간이 없습니다.")
            series = component_returns.mean(axis=1)
        else:
            raise RuntimeError(f"지원하지 않는 weighting_mode 입니다: {candidate.weighting_mode}")

        series = series.dropna().astype(float)
        if len(series) < MINIMUM_HISTORY_ROWS:
            raise RuntimeError("insufficient_common_history")
        return series

    def explode_component_weights(
        self,
        component_weights: dict[str, float],
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> dict[str, float]:
        stock_weights: dict[str, float] = {}
        for asset_code, component_weight in component_weights.items():
            candidate = selected_candidates.get(asset_code)
            if candidate is None:
                continue
            member_tickers = list(candidate.member_tickers)
            if not member_tickers:
                continue

            if candidate.weighting_mode == "single":
                allocations = {member_tickers[0]: float(component_weight)}
            elif candidate.weighting_mode == "equal_weight":
                split = float(component_weight) / len(member_tickers)
                allocations = {ticker: split for ticker in member_tickers}
            else:
                raise RuntimeError(f"지원하지 않는 weighting_mode 입니다: {candidate.weighting_mode}")

            for ticker, weight in allocations.items():
                stock_weights[ticker] = stock_weights.get(ticker, 0.0) + float(weight)
        return stock_weights

    def describe_members_by_asset(
        self,
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> dict[str, list[str]]:
        return {
            asset_code: list(candidate.member_tickers)
            for asset_code, candidate in selected_candidates.items()
        }

    def component_prior_weight_series(
        self,
        selected_candidates: dict[str, PortfolioComponentCandidate],
    ) -> pd.Series:
        market_caps: dict[str, float] = {}
        positive_count = 0

        for asset_code, candidate in selected_candidates.items():
            market_cap = self._resolve_component_market_cap(candidate)
            if market_cap is not None and market_cap > 0:
                market_caps[asset_code] = float(market_cap)
                positive_count += 1
            else:
                market_caps[asset_code] = 0.0

        if positive_count == 0 and selected_candidates:
            equal_weight = 1.0 / len(selected_candidates)
            return pd.Series(
                {asset_code: equal_weight for asset_code in selected_candidates.keys()},
                dtype=float,
            )

        weights = pd.Series(market_caps, dtype=float)
        total = float(weights.sum())
        if total <= 0 and selected_candidates:
            equal_weight = 1.0 / len(selected_candidates)
            return pd.Series(
                {asset_code: equal_weight for asset_code in selected_candidates.keys()},
                dtype=float,
            )
        return (weights / total).astype(float)

    def _build_candidates_for_asset(
        self,
        asset: AssetClass,
        available_tickers: list[str],
    ) -> list[PortfolioComponentCandidate]:
        if asset.selection_mode == "single_representative":
            return [
                PortfolioComponentCandidate(
                    asset_code=asset.code,
                    asset_name=asset.name,
                    role_key=asset.role_key,
                    selection_mode=asset.selection_mode,
                    weighting_mode=asset.weighting_mode,
                    return_mode=asset.return_mode,
                    member_tickers=(ticker,),
                )
                for ticker in available_tickers
            ]

        if asset.selection_mode == "all_members":
            return [
                PortfolioComponentCandidate(
                    asset_code=asset.code,
                    asset_name=asset.name,
                    role_key=asset.role_key,
                    selection_mode=asset.selection_mode,
                    weighting_mode=asset.weighting_mode,
                    return_mode=asset.return_mode,
                    member_tickers=tuple(available_tickers),
                )
            ]

        raise RuntimeError(f"지원하지 않는 selection_mode 입니다: {asset.selection_mode}")

    def _resolve_component_market_cap(
        self,
        candidate: PortfolioComponentCandidate,
    ) -> float | None:
        resolved_caps = [
            self._fetch_single_market_cap(ticker)
            for ticker in candidate.member_tickers
        ]
        positive_caps = [cap for cap in resolved_caps if cap is not None and cap > 0]
        if not positive_caps:
            return None
        return float(sum(positive_caps))

    def _fetch_single_market_cap(
        self,
        ticker: str,
    ) -> float | None:
        cached = self._market_cap_cache.get(ticker)
        if ticker in self._market_cap_cache:
            return cached

        market_cap: float | None = None
        try:
            instrument = yf.Ticker(ticker)

            try:
                fast_info = instrument.fast_info
                if fast_info is not None:
                    value = (
                        fast_info.get("market_cap")
                        if isinstance(fast_info, dict)
                        else getattr(fast_info, "market_cap", None)
                    )
                    if value is not None and pd.notna(value):
                        market_cap = float(value)
            except Exception:
                market_cap = None

            if market_cap is None:
                try:
                    info = instrument.info
                    value = info.get("marketCap")
                    if value is not None and pd.notna(value):
                        market_cap = float(value)
                except Exception:
                    market_cap = None

            if market_cap is None:
                shares = None
                latest_price = None
                try:
                    shares_df = instrument.get_shares_full(start="1900-01-01")
                    if shares_df is not None and len(shares_df) > 0:
                        shares = float(shares_df.dropna().iloc[-1])
                except Exception:
                    shares = None

                try:
                    history = instrument.history(period="7d", auto_adjust=False, actions=False)
                    if history is not None and not history.empty:
                        close_col = "Adj Close" if "Adj Close" in history.columns else "Close"
                        latest_price = float(pd.to_numeric(history[close_col], errors="coerce").dropna().iloc[-1])
                except Exception:
                    latest_price = None

                if shares is not None and latest_price is not None:
                    market_cap = float(shares * latest_price)
        except Exception:  # pragma: no cover - network/data-source dependent
            market_cap = None

        self._market_cap_cache[ticker] = market_cap
        return market_cap
