from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from app.core.config import MINIMUM_HISTORY_ROWS, RISK_FREE_RATE
from app.data.stock_repository import StockDataRepository
from app.domain.models import AssetClass, FrontierPoint, StockInstrument
from app.engine.constraints import ConstraintEngine
from app.engine.optimizer import EfficientFrontierOptimizer


OVERLAY_CODE = "usmv_overlay"
OVERLAY_TICKER = "USMV_OVERLAY"
OVERLAY_LABEL = "USMV Overlay"
OVERLAY_COLOR = "#38bdf8"
DEFAULT_OVERLAY_MAX_WEIGHT = 0.30
DEFAULT_SAMPLE_POINTS = 61
DEFAULT_CSV_PATH = (
    Path(__file__).resolve().parents[2]
    / "app"
    / "data"
    / "experiments"
    / "daily_performance_normalized.csv"
)


@dataclass(frozen=True)
class _FrontierBundle:
    frontier_points: list[FrontierPoint]
    returns: pd.DataFrame
    labels: dict[str, str]
    colors: dict[str, str]


class UsmvOverlayComparisonService:
    """Compares a managed universe with and without a synthetic USMV overlay asset."""

    def __init__(
        self,
        *,
        managed_universe_service,
        csv_path: str | Path = DEFAULT_CSV_PATH,
        optimizer: EfficientFrontierOptimizer | None = None,
        constraint_engine: ConstraintEngine | None = None,
        stock_repository: StockDataRepository | None = None,
    ) -> None:
        self.managed_universe_service = managed_universe_service
        self.csv_path = Path(csv_path)
        self.optimizer = optimizer or EfficientFrontierOptimizer()
        self.constraint_engine = constraint_engine or ConstraintEngine()
        self.stock_repository = stock_repository or StockDataRepository()

    def build_overlay_impact(
        self,
        *,
        version_id: int,
        start_date: str | None = None,
        end_date: str | None = None,
        sample_points: int = DEFAULT_SAMPLE_POINTS,
        overlay_max_weight: float = DEFAULT_OVERLAY_MAX_WEIGHT,
    ) -> dict[str, object]:
        sample_points = max(3, min(int(sample_points), 101))
        overlay_max_weight = max(0.0, min(float(overlay_max_weight), 1.0))

        assets = self.managed_universe_service.get_assets_for_version(version_id)
        instruments = self.managed_universe_service.get_instruments_for_version(
            version_id
        )
        prices = self.managed_universe_service.load_prices_for_instruments(
            instruments,
            version_id=version_id,
        )
        if not assets:
            raise RuntimeError("비교할 자산군이 없습니다.")
        if not instruments:
            raise RuntimeError("비교할 유니버스 종목이 없습니다.")
        if prices.empty:
            raise RuntimeError("비교할 유니버스 가격 데이터가 없습니다.")

        baseline_returns, labels, colors, max_weights = self._asset_class_returns(
            assets=assets,
            instruments=instruments,
            prices=prices,
        )
        overlay_returns = self._overlay_returns()

        baseline_returns = self._filter_date_window(
            baseline_returns,
            start_date=start_date,
            end_date=end_date,
        )
        overlay_returns = self._filter_date_window(
            overlay_returns,
            start_date=start_date,
            end_date=end_date,
        )

        augmented_returns = baseline_returns.join(
            overlay_returns.rename(OVERLAY_CODE),
            how="inner",
        ).dropna(how="any")
        baseline_returns = baseline_returns.reindex(augmented_returns.index).dropna(
            how="any"
        )
        augmented_returns = augmented_returns.reindex(baseline_returns.index).dropna(
            how="any"
        )
        if len(augmented_returns.index) < MINIMUM_HISTORY_ROWS:
            raise RuntimeError(
                f"공통 수익률 이력이 부족합니다. 필요 {MINIMUM_HISTORY_ROWS}개 / 현재 {len(augmented_returns.index)}개"
            )

        baseline_bundle = self._build_frontier_bundle(
            returns=baseline_returns,
            labels=labels,
            colors=colors,
            max_weights=max_weights,
            sample_points=sample_points,
        )
        augmented_labels = {**labels, OVERLAY_CODE: OVERLAY_LABEL}
        augmented_colors = {**colors, OVERLAY_CODE: OVERLAY_COLOR}
        augmented_max_weights = {**max_weights, OVERLAY_CODE: overlay_max_weight}
        augmented_bundle = self._build_frontier_bundle(
            returns=augmented_returns,
            labels=augmented_labels,
            colors=augmented_colors,
            max_weights=augmented_max_weights,
            sample_points=sample_points,
        )

        frontier_comparison = self._frontier_comparison(
            baseline_bundle.frontier_points,
            augmented_bundle.frontier_points,
            labels=augmented_labels,
            colors=augmented_colors,
            instruments=instruments,
        )
        performance_lines = self._performance_lines(
            returns=augmented_returns,
            comparison_summary=frontier_comparison["summary"],
        )

        return {
            "version_id": version_id,
            "period": {
                "start_date": augmented_returns.index[0].strftime("%Y-%m-%d"),
                "end_date": augmented_returns.index[-1].strftime("%Y-%m-%d"),
                "return_rows": int(len(augmented_returns.index)),
            },
            "overlay": {
                "code": OVERLAY_CODE,
                "ticker": OVERLAY_TICKER,
                "label": OVERLAY_LABEL,
                "color": OVERLAY_COLOR,
                "source_column": "portfolio_USMV_overlay",
                "max_weight": round(overlay_max_weight, 4),
            },
            "baseline": self._serialize_bundle(baseline_bundle),
            "with_overlay": self._serialize_bundle(augmented_bundle),
            "frontier_comparison": frontier_comparison,
            "performance_lines": performance_lines,
        }

    def _asset_class_returns(
        self,
        *,
        assets: list[AssetClass],
        instruments: list[StockInstrument],
        prices: pd.DataFrame,
    ) -> tuple[pd.DataFrame, dict[str, str], dict[str, str], dict[str, float]]:
        stock_returns = self.stock_repository.build_stock_returns(prices)
        if stock_returns.empty:
            raise RuntimeError("유니버스 수익률 데이터를 만들지 못했습니다.")

        instruments_by_asset: dict[str, list[str]] = {}
        for instrument in instruments:
            instruments_by_asset.setdefault(instrument.sector_code, []).append(
                instrument.ticker.upper()
            )

        asset_return_columns: dict[str, pd.Series] = {}
        labels: dict[str, str] = {}
        colors: dict[str, str] = {}
        max_weights: dict[str, float] = {}
        for asset in assets:
            tickers = [
                ticker
                for ticker in instruments_by_asset.get(asset.code, [])
                if ticker in stock_returns.columns
            ]
            if not tickers:
                continue
            asset_return_columns[asset.code] = stock_returns[tickers].mean(axis=1)
            labels[asset.code] = asset.name
            colors[asset.code] = asset.color
            max_weights[asset.code] = max(0.0, min(float(asset.max_weight), 1.0))

        if len(asset_return_columns) < 2:
            raise RuntimeError("frontier 비교에는 최소 2개 이상의 자산군 수익률이 필요합니다.")
        asset_returns = pd.DataFrame(asset_return_columns).dropna(how="any")
        if asset_returns.empty:
            raise RuntimeError("자산군 공통 수익률 구간이 비어 있습니다.")
        return asset_returns, labels, colors, max_weights

    def _overlay_returns(self) -> pd.Series:
        if not self.csv_path.exists():
            raise RuntimeError(f"overlay CSV 파일을 찾을 수 없습니다: {self.csv_path}")
        frame = pd.read_csv(self.csv_path)
        required = {"date", "portfolio_USMV_overlay"}
        missing = required.difference(frame.columns)
        if missing:
            raise RuntimeError(
                "overlay CSV에 필요한 컬럼이 없습니다: " + ", ".join(sorted(missing))
            )
        prices = pd.DataFrame(
            {
                "date": frame["date"],
                "ticker": OVERLAY_TICKER,
                "adjusted_close": frame["portfolio_USMV_overlay"],
            }
        )
        returns = self.stock_repository.build_stock_returns(prices)
        if OVERLAY_TICKER not in returns.columns:
            raise RuntimeError("overlay 수익률을 만들지 못했습니다.")
        return returns[OVERLAY_TICKER].dropna()

    @staticmethod
    def _filter_date_window(
        returns: pd.DataFrame | pd.Series,
        *,
        start_date: str | None,
        end_date: str | None,
    ) -> pd.DataFrame | pd.Series:
        filtered = returns.copy()
        if start_date:
            filtered = filtered[filtered.index >= pd.Timestamp(start_date).normalize()]
        if end_date:
            filtered = filtered[filtered.index <= pd.Timestamp(end_date).normalize()]
        return filtered

    def _build_frontier_bundle(
        self,
        *,
        returns: pd.DataFrame,
        labels: dict[str, str],
        colors: dict[str, str],
        max_weights: dict[str, float],
        sample_points: int,
    ) -> _FrontierBundle:
        expected_returns = returns.mean() * 252
        covariance = returns.cov() * 252
        asset_codes = list(returns.columns)
        upper_bounds = np.array(
            [max_weights.get(code, 1.0) for code in asset_codes],
            dtype=float,
        )
        if upper_bounds.sum() < 1.0 - 1e-9:
            raise RuntimeError("자산군 최대 비중 합이 1보다 작아 frontier를 만들 수 없습니다.")
        constraints = self.constraint_engine.build_for_codes(
            asset_codes,
            lower_bounds=np.zeros(len(asset_codes), dtype=float),
            upper_bounds=upper_bounds,
        )
        frontier_points = self.optimizer.build_frontier(
            expected_returns=expected_returns,
            covariance=covariance,
            constraints=constraints,
            point_count=sample_points,
        )
        return _FrontierBundle(
            frontier_points=frontier_points,
            returns=returns,
            labels=labels,
            colors=colors,
        )

    def _serialize_bundle(self, bundle: _FrontierBundle) -> dict[str, object]:
        return {
            "frontier_points": [
                self._serialize_frontier_point(point, index=index)
                for index, point in enumerate(bundle.frontier_points)
            ],
            "assets": [
                {
                    "code": code,
                    "label": bundle.labels.get(code, code),
                    "color": bundle.colors.get(code, "#64748b"),
                }
                for code in bundle.returns.columns
            ],
        }

    def _frontier_comparison(
        self,
        baseline_points: list[FrontierPoint],
        augmented_points: list[FrontierPoint],
        *,
        labels: dict[str, str],
        colors: dict[str, str],
        instruments: list[StockInstrument],
    ) -> dict[str, object]:
        if not baseline_points or not augmented_points:
            return {
                "same_risk_points": [],
                "max_sharpe_composition": {
                    "basis": "asset_max_sharpe_equal_weight_members",
                    "assets": [],
                },
                "summary": {
                    "matched_point_count": 0,
                    "improved_point_count": 0,
                    "improved_point_share": 0.0,
                    "average_delta_expected_return": 0.0,
                    "best_delta_expected_return": 0.0,
                    "average_delta_sharpe": 0.0,
                    "average_overlay_weight": 0.0,
                    "max_overlay_weight": 0.0,
                    "baseline_max_sharpe": None,
                    "with_overlay_max_sharpe": None,
                    "delta_max_sharpe": 0.0,
                    "best_point": None,
                },
            }

        same_risk_points: list[dict[str, object]] = []
        for index, baseline in enumerate(baseline_points):
            augmented = min(
                augmented_points,
                key=lambda point: abs(point.volatility - baseline.volatility),
            )
            baseline_payload = self._serialize_frontier_point(
                baseline,
                index=index,
                include_overlay_weight=True,
            )
            augmented_payload = self._serialize_frontier_point(
                augmented,
                index=augmented_points.index(augmented),
                include_overlay_weight=True,
            )
            same_risk_points.append(
                {
                    "baseline_index": index,
                    "with_overlay_index": augmented_points.index(augmented),
                    "baseline": baseline_payload,
                    "with_overlay": augmented_payload,
                    "delta_expected_return": round(
                        augmented.expected_return - baseline.expected_return,
                        6,
                    ),
                    "delta_volatility": round(
                        augmented.volatility - baseline.volatility,
                        6,
                    ),
                    "delta_sharpe": round(
                        self._sharpe(augmented) - self._sharpe(baseline),
                        6,
                    ),
                }
            )

        expected_deltas = [
            float(point["delta_expected_return"]) for point in same_risk_points
        ]
        sharpe_deltas = [float(point["delta_sharpe"]) for point in same_risk_points]
        overlay_weights = [
            float(point["with_overlay"]["overlay_weight"])
            for point in same_risk_points
        ]
        best_point = max(
            same_risk_points,
            key=lambda point: float(point["delta_expected_return"]),
        )
        baseline_max_index, baseline_max_point = max(
            enumerate(baseline_points),
            key=lambda item: self._sharpe(item[1]),
        )
        augmented_max_index, augmented_max_point = max(
            enumerate(augmented_points),
            key=lambda item: self._sharpe(item[1]),
        )
        baseline_max_payload = self._serialize_frontier_point(
            baseline_max_point,
            index=baseline_max_index,
        )
        augmented_max_payload = self._serialize_frontier_point(
            augmented_max_point,
            index=augmented_max_index,
            include_overlay_weight=True,
        )
        max_sharpe_composition = self._max_sharpe_composition(
            baseline_point=baseline_max_payload,
            augmented_point=augmented_max_payload,
            labels=labels,
            colors=colors,
            instruments=instruments,
        )
        improved_count = sum(delta > 1e-8 for delta in expected_deltas)

        return {
            "same_risk_points": same_risk_points,
            "max_sharpe_composition": max_sharpe_composition,
            "summary": {
                "matched_point_count": len(same_risk_points),
                "improved_point_count": int(improved_count),
                "improved_point_share": round(
                    improved_count / len(same_risk_points),
                    6,
                ),
                "average_delta_expected_return": round(
                    float(np.mean(expected_deltas)),
                    6,
                ),
                "best_delta_expected_return": round(
                    float(best_point["delta_expected_return"]),
                    6,
                ),
                "average_delta_sharpe": round(float(np.mean(sharpe_deltas)), 6),
                "average_overlay_weight": round(float(np.mean(overlay_weights)), 6),
                "max_overlay_weight": round(float(np.max(overlay_weights)), 6),
                "baseline_max_sharpe": baseline_max_payload,
                "with_overlay_max_sharpe": augmented_max_payload,
                "delta_max_sharpe": round(
                    float(augmented_max_payload["sharpe_ratio"])
                    - float(baseline_max_payload["sharpe_ratio"]),
                    6,
                ),
                "best_point": best_point,
            },
        }

    def _max_sharpe_composition(
        self,
        *,
        baseline_point: dict[str, object],
        augmented_point: dict[str, object],
        labels: dict[str, str],
        colors: dict[str, str],
        instruments: list[StockInstrument],
    ) -> dict[str, object]:
        baseline_weights = dict(baseline_point.get("weights") or {})
        augmented_weights = dict(augmented_point.get("weights") or {})
        instruments_by_asset: dict[str, list[StockInstrument]] = {}
        for instrument in instruments:
            instruments_by_asset.setdefault(instrument.sector_code, []).append(
                instrument
            )
        for members in instruments_by_asset.values():
            members.sort(key=lambda instrument: instrument.ticker.upper())

        ordered_codes = list(
            dict.fromkeys(
                [
                    *labels.keys(),
                    *baseline_weights.keys(),
                    *augmented_weights.keys(),
                    OVERLAY_CODE,
                ]
            )
        )
        rows: list[dict[str, object]] = []
        for code in ordered_codes:
            baseline_weight = round(float(baseline_weights.get(code, 0.0)), 6)
            augmented_weight = round(float(augmented_weights.get(code, 0.0)), 6)
            if baseline_weight <= 1e-8 and augmented_weight <= 1e-8:
                continue
            rows.append(
                {
                    "code": code,
                    "label": labels.get(code, code),
                    "color": colors.get(code, "#64748b"),
                    "baseline_weight": baseline_weight,
                    "with_overlay_weight": augmented_weight,
                    "delta_weight": round(augmented_weight - baseline_weight, 6),
                    "instruments": self._instrument_composition_rows(
                        asset_code=code,
                        baseline_weight=baseline_weight,
                        augmented_weight=augmented_weight,
                        instruments=instruments_by_asset.get(code, []),
                    ),
                }
            )

        rows.sort(
            key=lambda row: max(
                float(row["baseline_weight"]),
                float(row["with_overlay_weight"]),
            ),
            reverse=True,
        )
        return {
            "basis": "asset_max_sharpe_equal_weight_members",
            "assets": rows,
        }

    @staticmethod
    def _instrument_composition_rows(
        *,
        asset_code: str,
        baseline_weight: float,
        augmented_weight: float,
        instruments: list[StockInstrument],
    ) -> list[dict[str, object]]:
        if asset_code == OVERLAY_CODE:
            return [
                {
                    "ticker": OVERLAY_TICKER,
                    "name": OVERLAY_LABEL,
                    "baseline_weight": 0.0,
                    "with_overlay_weight": augmented_weight,
                    "delta_weight": augmented_weight,
                    "synthetic": True,
                }
            ]
        if not instruments:
            return []
        member_count = len(instruments)
        baseline_member_weight = round(baseline_weight / member_count, 6)
        augmented_member_weight = round(augmented_weight / member_count, 6)
        return [
            {
                "ticker": instrument.ticker.upper(),
                "name": instrument.name,
                "baseline_weight": baseline_member_weight,
                "with_overlay_weight": augmented_member_weight,
                "delta_weight": round(
                    augmented_member_weight - baseline_member_weight,
                    6,
                ),
                "synthetic": False,
            }
            for instrument in instruments
        ]

    def _performance_lines(
        self,
        *,
        returns: pd.DataFrame,
        comparison_summary: dict[str, object],
    ) -> list[dict[str, object]]:
        best_point = comparison_summary.get("best_point")
        if not isinstance(best_point, dict):
            return []
        baseline = best_point.get("baseline")
        augmented = best_point.get("with_overlay")
        if not isinstance(baseline, dict) or not isinstance(augmented, dict):
            return []
        return [
            self._performance_line(
                key="baseline_same_risk",
                label="기존 유니버스",
                color="#f97316",
                style="solid",
                returns=returns,
                weights=dict(baseline["weights"]),
            ),
            self._performance_line(
                key="with_overlay_same_risk",
                label="Overlay 포함 유니버스",
                color=OVERLAY_COLOR,
                style="solid",
                returns=returns,
                weights=dict(augmented["weights"]),
            ),
        ]

    @staticmethod
    def _performance_line(
        *,
        key: str,
        label: str,
        color: str,
        style: str,
        returns: pd.DataFrame,
        weights: dict[str, float],
    ) -> dict[str, object]:
        available_weights = {
            code: float(weight)
            for code, weight in weights.items()
            if code in returns.columns and float(weight) > 0
        }
        total = sum(available_weights.values())
        if total <= 0:
            points: list[dict[str, object]] = []
        else:
            normalized_weights = {
                code: weight / total for code, weight in available_weights.items()
            }
            daily = returns[list(normalized_weights)].mul(
                pd.Series(normalized_weights),
                axis=1,
            ).sum(axis=1)
            path = (1.0 + daily).cumprod()
            base = float(path.iloc[0])
            points = [
                {
                    "date": date.strftime("%Y-%m-%d"),
                    "return_pct": round((float(value) / base - 1.0) * 100, 4),
                }
                for date, value in path.items()
            ]
        return {
            "key": key,
            "label": label,
            "color": color,
            "style": style,
            "points": points,
        }

    def _serialize_frontier_point(
        self,
        point: FrontierPoint,
        *,
        index: int,
        include_overlay_weight: bool = False,
    ) -> dict[str, object]:
        payload = {
            "index": index,
            "volatility": round(float(point.volatility), 6),
            "expected_return": round(float(point.expected_return), 6),
            "sharpe_ratio": round(self._sharpe(point), 6),
            "weights": {
                code: round(float(weight), 6)
                for code, weight in point.weights.items()
                if float(weight) > 1e-8
            },
        }
        if include_overlay_weight:
            payload["overlay_weight"] = round(
                float(point.weights.get(OVERLAY_CODE, 0.0)),
                6,
            )
        return payload

    @staticmethod
    def _sharpe(point: FrontierPoint) -> float:
        if point.volatility <= 0:
            return 0.0
        return float((point.expected_return - RISK_FREE_RATE) / point.volatility)
