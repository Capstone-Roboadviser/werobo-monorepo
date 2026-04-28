from __future__ import annotations

from datetime import date

import pandas as pd
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.core.config import MINIMUM_HISTORY_ROWS
from app.services.portfolio_analytics_service import PortfolioAnalyticsService
from app.services.portfolio_service import PortfolioSimulationService
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource


router = APIRouter(prefix="/admin/api/comparison", tags=["admin"])

portfolio_simulation_service = PortfolioSimulationService()
managed_universe_service = portfolio_simulation_service.managed_universe_service
analytics_service = PortfolioAnalyticsService(
    portfolio_service=portfolio_simulation_service,
)


# ── Request models ──


class FrontierRequest(BaseModel):
    version_id: int = Field(..., description="대상 유니버스 버전 ID")
    as_of_date: date | None = Field(
        default=None,
        description="이 날짜까지의 가격 데이터로 frontier 계산",
    )
    investment_horizon: InvestmentHorizon = Field(
        default=InvestmentHorizon.MEDIUM,
        description="투자 기간",
    )
    sample_points: int = Field(default=61, ge=3, le=500, description="frontier 샘플 포인트 수")


class SelectionRequest(BaseModel):
    version_id: int = Field(..., description="대상 유니버스 버전 ID")
    point_index: int = Field(..., ge=0, description="frontier 위에서 선택한 인덱스")
    as_of_date: date | None = None
    investment_horizon: InvestmentHorizon = Field(default=InvestmentHorizon.MEDIUM)


class BacktestRequest(BaseModel):
    version_id: int = Field(..., description="대상 유니버스 버전 ID")
    stock_weights: dict[str, float] = Field(..., description="선택 포트폴리오의 종목 비중")
    portfolio_code: str | None = Field(default=None, description="라인 키로 사용할 코드")
    rebalance_enabled: bool = Field(default=True, description="리밸런싱 적용 여부")
    start_date: date | None = Field(
        default=None,
        description="백테스트 시작일. 이 날짜 이후 가격만 사용합니다.",
    )


class SnapshotCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    folder: str | None = Field(default=None, max_length=120)
    payload: dict = Field(default_factory=dict)


class SnapshotUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    # Use a sentinel: omit folder to keep, send null/"" to clear, send string to set.
    folder: str | None = Field(default=None, max_length=120)
    folder_set: bool = Field(default=False, description="true이면 folder 필드를 적용합니다.")
    payload: dict | None = None


# ── Helpers ──


def _http_422(exc: Exception) -> HTTPException:
    return HTTPException(status_code=422, detail=str(exc))


def _serialize_assets() -> list[dict[str, object]]:
    return [
        {
            "code": asset.code,
            "name": asset.name,
            "color": asset.color,
        }
        for asset in managed_universe_service.list_assets()
    ]


def _build_preview_indices(total_point_count: int, sample_points: int) -> list[int]:
    if total_point_count <= 0:
        return []
    target = max(2, min(sample_points, total_point_count))
    if target >= total_point_count:
        return list(range(total_point_count))
    step = (total_point_count - 1) / (target - 1)
    indices = sorted({round(i * step) for i in range(target)})
    return [min(idx, total_point_count - 1) for idx in indices]


def _representative_indices(total_point_count: int) -> dict[str, int]:
    if total_point_count <= 0:
        return {}
    return {
        "conservative": 0,
        "balanced": (total_point_count - 1) // 2,
        "growth": total_point_count - 1,
    }


def _basis_date_window(version_id: int) -> dict[str, object] | None:
    instruments = managed_universe_service.get_instruments_for_version(version_id)
    if not instruments:
        return None

    prices = managed_universe_service.load_prices_for_instruments(
        instruments,
        version_id=version_id,
    )
    if prices.empty:
        return None

    common_prices = (
        prices.assign(
            ticker=prices["ticker"].astype(str).str.upper(),
            date=pd.to_datetime(prices["date"]).dt.normalize(),
        )
        .pivot_table(
            index="date",
            columns="ticker",
            values="adjusted_close",
            aggfunc="last",
        )
        .sort_index()
        .ffill()
        .dropna(how="any")
    )
    if len(common_prices.index) < MINIMUM_HISTORY_ROWS + 2:
        return None

    min_basis_date = common_prices.index[MINIMUM_HISTORY_ROWS]
    max_basis_date = common_prices.index[-2]
    if min_basis_date > max_basis_date:
        return None

    return {
        "first_price_date": common_prices.index[0].strftime("%Y-%m-%d"),
        "last_price_date": common_prices.index[-1].strftime("%Y-%m-%d"),
        "min_basis_date": min_basis_date.strftime("%Y-%m-%d"),
        "max_basis_date": max_basis_date.strftime("%Y-%m-%d"),
        "train_return_rows": MINIMUM_HISTORY_ROWS,
        "common_price_rows": int(len(common_prices.index)),
    }


# ── Catalog ──


@router.get("/catalog")
def get_comparison_catalog() -> dict[str, object]:
    """Returns asset color/label catalog and version list for the admin UI."""
    try:
        versions = [
            {
                "version_id": v.version_id,
                "version_name": v.version_name,
                "is_active": v.is_active,
                "notes": v.notes,
                "basis_date_window": _basis_date_window(v.version_id),
            }
            for v in managed_universe_service.list_versions()
        ]
    except RuntimeError as exc:
        raise _http_422(exc) from exc
    return {
        "assets": _serialize_assets(),
        "versions": versions,
    }


# ── Frontier preview (live, per version) ──


@router.post("/frontier")
def get_frontier(payload: FrontierRequest) -> dict[str, object]:
    try:
        context = portfolio_simulation_service.build_engine_context(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=payload.investment_horizon,
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            as_of_date=payload.as_of_date,
            version_id=payload.version_id,
        )
    except RuntimeError as exc:
        raise _http_422(exc) from exc
    except ValueError as exc:
        raise _http_422(exc) from exc

    total = len(context.frontier_points)
    if total == 0:
        raise HTTPException(status_code=422, detail="frontier 포인트를 만들지 못했습니다.")
    representative_indices = _representative_indices(total)
    representative_lookup = {idx: code for code, idx in representative_indices.items()}
    representative_labels = {
        "conservative": "안정형",
        "balanced": "균형형",
        "growth": "성장형",
    }

    preview_indices = _build_preview_indices(total, payload.sample_points)
    for idx in representative_indices.values():
        if idx not in preview_indices:
            preview_indices.append(idx)
    preview_indices = sorted(set(preview_indices))

    instrument_lookup = {
        instrument.ticker.upper(): instrument for instrument in context.instruments
    }

    points = []
    for idx in preview_indices:
        fp = context.frontier_points[idx]
        rep_code = representative_lookup.get(idx)
        weights = {
            str(ticker).upper(): round(float(weight), 6)
            for ticker, weight in fp.weights.items()
            if float(weight) > 0
        }
        sector_totals: dict[str, float] = {}
        for ticker, weight in weights.items():
            instrument = instrument_lookup.get(ticker)
            if instrument is None:
                continue
            sector_totals[instrument.sector_code] = (
                sector_totals.get(instrument.sector_code, 0.0) + weight
            )
        sector_breakdown = [
            {"asset_code": code, "weight": round(w, 4)}
            for code, w in sorted(sector_totals.items(), key=lambda x: -x[1])
        ]
        points.append(
            {
                "index": idx,
                "volatility": round(float(fp.volatility), 4),
                "expected_return": round(float(fp.expected_return), 4),
                "representative_code": rep_code,
                "representative_label": (
                    representative_labels.get(rep_code) if rep_code else None
                ),
                "stock_weights": weights,
                "sector_breakdown": sector_breakdown,
            }
        )

    return {
        "version_id": payload.version_id,
        "as_of_date": None if payload.as_of_date is None else payload.as_of_date.isoformat(),
        "investment_horizon": payload.investment_horizon.value,
        "total_point_count": total,
        "min_volatility": round(float(context.frontier_points[0].volatility), 4),
        "max_volatility": round(float(context.frontier_points[-1].volatility), 4),
        "points": points,
    }


# ── Frontier selection (returns stock_weights for backtest) ──


@router.post("/selection")
def get_selection(payload: SelectionRequest) -> dict[str, object]:
    try:
        context = portfolio_simulation_service.build_engine_context(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=payload.investment_horizon,
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            as_of_date=payload.as_of_date,
            version_id=payload.version_id,
        )
    except RuntimeError as exc:
        raise _http_422(exc) from exc
    except ValueError as exc:
        raise _http_422(exc) from exc

    total = len(context.frontier_points)
    if total == 0:
        raise HTTPException(status_code=422, detail="frontier 포인트를 만들지 못했습니다.")
    if payload.point_index >= total:
        raise HTTPException(
            status_code=422,
            detail=f"point_index ({payload.point_index})가 frontier 포인트 수 ({total})를 초과합니다.",
        )

    selected = context.frontier_points[payload.point_index]
    sector_totals: dict[str, float] = {}
    instrument_lookup = {
        instrument.ticker.upper(): instrument for instrument in context.instruments
    }
    for ticker, weight in selected.weights.items():
        instrument = instrument_lookup.get(str(ticker).upper())
        if instrument is None:
            continue
        sector_totals[instrument.sector_code] = (
            sector_totals.get(instrument.sector_code, 0.0) + float(weight)
        )

    sector_breakdown = [
        {
            "asset_code": code,
            "weight": round(weight, 4),
        }
        for code, weight in sorted(sector_totals.items(), key=lambda x: -x[1])
    ]

    return {
        "version_id": payload.version_id,
        "point_index": payload.point_index,
        "volatility": round(float(selected.volatility), 4),
        "expected_return": round(float(selected.expected_return), 4),
        "stock_weights": {
            str(ticker).upper(): round(float(weight), 6)
            for ticker, weight in selected.weights.items()
            if float(weight) > 0
        },
        "sector_breakdown": sector_breakdown,
    }


# ── Backtest with per-asset-class lines ──


@router.post("/backtest")
def get_backtest(payload: BacktestRequest) -> dict[str, object]:
    if not payload.stock_weights:
        raise HTTPException(status_code=422, detail="stock_weights가 비어 있습니다.")
    try:
        result = analytics_service.build_comparison_backtest(
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            stock_weights=payload.stock_weights,
            portfolio_code=payload.portfolio_code,
            version_id=payload.version_id,
            start_date=None if payload.start_date is None else payload.start_date.isoformat(),
            per_asset_lines=True,
            rebalance_enabled=payload.rebalance_enabled,
        )
    except RuntimeError as exc:
        raise _http_422(exc) from exc
    except ValueError as exc:
        raise _http_422(exc) from exc

    return {
        "version_id": payload.version_id,
        "start_date": result.start_date,
        "end_date": result.end_date,
        "lines": [
            {
                "key": line.key,
                "label": line.label,
                "color": line.color,
                "style": line.style,
                "points": [
                    {"date": pt[0], "return_pct": float(pt[1])}
                    for pt in line.points
                ],
            }
            for line in result.lines
        ],
    }


# ── Snapshot CRUD ──


def _ensure_db_configured() -> None:
    if not managed_universe_service.is_configured():
        raise HTTPException(status_code=422, detail="DATABASE_URL이 설정되지 않아 스냅샷을 사용할 수 없습니다.")


@router.get("/snapshots")
def list_snapshots() -> dict[str, object]:
    _ensure_db_configured()
    return {
        "snapshots": managed_universe_service.repository.list_admin_comparison_snapshots()
    }


@router.get("/snapshots/{snapshot_id}")
def get_snapshot(snapshot_id: int) -> dict[str, object]:
    _ensure_db_configured()
    snap = managed_universe_service.repository.get_admin_comparison_snapshot(snapshot_id)
    if snap is None:
        raise HTTPException(status_code=404, detail=f"스냅샷 {snapshot_id}을(를) 찾을 수 없습니다.")
    return snap


@router.post("/snapshots")
def create_snapshot(payload: SnapshotCreateRequest) -> dict[str, object]:
    _ensure_db_configured()
    return managed_universe_service.repository.create_admin_comparison_snapshot(
        name=payload.name,
        payload=payload.payload or {},
        folder=payload.folder,
    )


@router.put("/snapshots/{snapshot_id}")
def update_snapshot(
    snapshot_id: int, payload: SnapshotUpdateRequest
) -> dict[str, object]:
    _ensure_db_configured()
    kwargs: dict[str, object] = {
        "snapshot_id": snapshot_id,
        "name": payload.name,
        "payload": payload.payload,
    }
    if payload.folder_set:
        kwargs["folder"] = payload.folder
    snap = managed_universe_service.repository.update_admin_comparison_snapshot(**kwargs)
    if snap is None:
        raise HTTPException(status_code=404, detail=f"스냅샷 {snapshot_id}을(를) 찾을 수 없습니다.")
    return snap


@router.delete("/snapshots/{snapshot_id}")
def delete_snapshot(snapshot_id: int) -> dict[str, object]:
    _ensure_db_configured()
    deleted = managed_universe_service.repository.delete_admin_comparison_snapshot(snapshot_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"스냅샷 {snapshot_id}을(를) 찾을 수 없습니다.")
    return {"deleted": True, "id": snapshot_id}
