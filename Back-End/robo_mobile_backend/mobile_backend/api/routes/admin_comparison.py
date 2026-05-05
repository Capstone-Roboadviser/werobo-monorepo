from __future__ import annotations

from collections import OrderedDict
from contextlib import ExitStack, contextmanager
from copy import deepcopy
from datetime import date
import logging
from threading import Event, Lock
import time

import pandas as pd
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.config import MINIMUM_HISTORY_ROWS
from app.data.stock_repository import StockDataRepository
from app.services.portfolio_analytics_service import PortfolioAnalyticsService
from app.services.portfolio_service import PortfolioSimulationService
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource


router = APIRouter(prefix="/admin/api/comparison", tags=["admin"])

portfolio_simulation_service = PortfolioSimulationService()
managed_universe_service = portfolio_simulation_service.managed_universe_service
analytics_service = PortfolioAnalyticsService(
    portfolio_service=portfolio_simulation_service,
)
logger = logging.getLogger(__name__)

_FRONTIER_CACHE_TTL_SECONDS = 120
_FRONTIER_CACHE_MAX_ITEMS = 24
_FRONTIER_DB_CACHE_VERSION = "admin-comparison-frontier-v1"
_FRONTIER_INFLIGHT_WAIT_SECONDS = 85
_FrontierCacheKey = tuple[int, str | None, str, int, str | None]
_frontier_cache: OrderedDict[_FrontierCacheKey, tuple[float, dict[str, object]]] = OrderedDict()
_frontier_cache_lock = Lock()
_frontier_inflight: dict[_FrontierCacheKey, tuple[float, Event]] = {}
_frontier_inflight_lock = Lock()
_BASIS_DATE_WINDOW_CACHE_TTL_SECONDS = 300
_BASIS_DATE_WINDOW_CACHE_MAX_ITEMS = 64
_BASIS_DATE_WINDOW_DB_CACHE_VERSION = "admin-comparison-basis-date-window-v1"
_BasisDateWindowCacheKey = tuple[int, str | None]
_basis_date_window_cache: OrderedDict[
    _BasisDateWindowCacheKey,
    tuple[float, dict[str, object] | None],
] = OrderedDict()
_basis_date_window_cache_lock = Lock()


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


def _frontier_cache_key(
    payload: FrontierRequest,
    *,
    price_signature: str | None,
) -> _FrontierCacheKey:
    return (
        payload.version_id,
        None if payload.as_of_date is None else payload.as_of_date.isoformat(),
        payload.investment_horizon.value,
        payload.sample_points,
        price_signature,
    )


def _get_cached_frontier(key: _FrontierCacheKey) -> dict[str, object] | None:
    now = time.monotonic()
    with _frontier_cache_lock:
        cached = _frontier_cache.get(key)
        if cached is None:
            return None
        cached_at, payload = cached
        if now - cached_at > _FRONTIER_CACHE_TTL_SECONDS:
            del _frontier_cache[key]
            return None
        _frontier_cache.move_to_end(key)
        return deepcopy(payload)


def _store_cached_frontier(key: _FrontierCacheKey, payload: dict[str, object]) -> None:
    with _frontier_cache_lock:
        _frontier_cache[key] = (time.monotonic(), deepcopy(payload))
        _frontier_cache.move_to_end(key)
        while len(_frontier_cache) > _FRONTIER_CACHE_MAX_ITEMS:
            _frontier_cache.popitem(last=False)


def _begin_frontier_calculation(key: _FrontierCacheKey) -> tuple[bool, Event]:
    with _frontier_inflight_lock:
        current = _frontier_inflight.get(key)
        if current is not None:
            return False, current[1]
        event = Event()
        _frontier_inflight[key] = (time.monotonic(), event)
        return True, event


def _finish_frontier_calculation(key: _FrontierCacheKey, event: Event) -> None:
    with _frontier_inflight_lock:
        current = _frontier_inflight.get(key)
        if current is not None and current[1] is event:
            del _frontier_inflight[key]
    event.set()


def _with_frontier_cache_metadata(
    payload: dict[str, object],
    *,
    cache_source: str,
) -> dict[str, object]:
    response = deepcopy(payload)
    response["cache_status"] = "hit"
    response["cache_source"] = cache_source
    return response


def _raise_if_refresh_running(version_id: int) -> None:
    if not managed_universe_service.repository.is_configured():
        return
    try:
        running_job = managed_universe_service.repository.get_running_refresh_job(version_id)
    except Exception:
        logger.warning(
            "admin_comparison.frontier refresh guard lookup failed version_id=%s",
            version_id,
            exc_info=True,
        )
        return
    if running_job is None:
        return
    raise HTTPException(
        status_code=409,
        detail=(
            "가격 데이터 갱신이 진행 중이라 관리자 비교 계산을 잠시 막았습니다. "
            f"refresh_job_id={running_job.job_id}"
        ),
    )


@contextmanager
def _frontier_distributed_calculation_lock(key: _FrontierCacheKey):
    repository = managed_universe_service.repository
    lock_context = getattr(
        repository,
        "admin_comparison_frontier_calculation_lock",
        None,
    )
    if not repository.is_configured() or lock_context is None:
        yield True
        return

    lock_name = "|".join("" if part is None else str(part) for part in key)
    stack = ExitStack()
    try:
        acquired = stack.enter_context(
            lock_context(f"{_FRONTIER_DB_CACHE_VERSION}|{lock_name}")
        )
    except Exception:
        stack.close()
        logger.warning(
            "admin_comparison.frontier distributed lock failed key=%s",
            key,
            exc_info=True,
        )
        yield True
        return
    with stack:
        yield bool(acquired)


def _frontier_basis_date(payload: FrontierRequest) -> str | None:
    return None if payload.as_of_date is None else payload.as_of_date.isoformat()


def _get_frontier_price_signature(payload: FrontierRequest) -> str | None:
    if not managed_universe_service.repository.is_configured():
        return None
    basis_date = _frontier_basis_date(payload)
    try:
        return managed_universe_service.repository.get_admin_comparison_frontier_price_signature(
            version_id=payload.version_id,
            basis_date=basis_date,
        )
    except Exception:
        logger.warning(
            "admin_comparison.frontier price signature lookup failed version_id=%s as_of_date=%s",
            payload.version_id,
            payload.as_of_date,
            exc_info=True,
        )
        return None


def _get_persistent_cached_frontier(
    payload: FrontierRequest,
    *,
    price_signature: str | None,
) -> dict[str, object] | None:
    if not price_signature or not managed_universe_service.repository.is_configured():
        return None
    basis_date = _frontier_basis_date(payload)
    try:
        cached = managed_universe_service.repository.get_admin_comparison_frontier_cache(
            version_id=payload.version_id,
            basis_date=basis_date,
            investment_horizon=payload.investment_horizon.value,
            sample_points=payload.sample_points,
            cache_version=_FRONTIER_DB_CACHE_VERSION,
            price_signature=price_signature,
        )
    except Exception:
        logger.warning(
            "admin_comparison.frontier persistent cache lookup failed version_id=%s as_of_date=%s",
            payload.version_id,
            payload.as_of_date,
            exc_info=True,
        )
        return None
    return cached


def _store_persistent_cached_frontier(
    payload: FrontierRequest,
    response_payload: dict[str, object],
    *,
    price_signature: str | None,
) -> None:
    if not price_signature or not managed_universe_service.repository.is_configured():
        return
    basis_date = _frontier_basis_date(payload)
    try:
        managed_universe_service.repository.upsert_admin_comparison_frontier_cache(
            version_id=payload.version_id,
            basis_date=basis_date,
            investment_horizon=payload.investment_horizon.value,
            sample_points=payload.sample_points,
            cache_version=_FRONTIER_DB_CACHE_VERSION,
            price_signature=price_signature,
            payload=response_payload,
        )
    except Exception:
        logger.warning(
            "admin_comparison.frontier persistent cache store failed version_id=%s as_of_date=%s",
            payload.version_id,
            payload.as_of_date,
            exc_info=True,
        )


def _get_basis_date_window_price_signature(version_id: int) -> str | None:
    repository = getattr(managed_universe_service, "repository", None)
    if repository is None or not repository.is_configured():
        return None
    try:
        return repository.get_admin_comparison_frontier_price_signature(
            version_id=version_id,
            basis_date=None,
        )
    except Exception:
        logger.warning(
            "admin_comparison.basis_date_window price signature lookup failed version_id=%s",
            version_id,
            exc_info=True,
        )
        return None


def _get_persistent_cached_basis_date_window(
    version_id: int,
    *,
    price_signature: str | None,
) -> tuple[bool, dict[str, object] | None]:
    repository = getattr(managed_universe_service, "repository", None)
    if not price_signature or repository is None or not repository.is_configured():
        return False, None
    try:
        cached = repository.get_admin_comparison_basis_date_window_cache(
            version_id=version_id,
            cache_version=_BASIS_DATE_WINDOW_DB_CACHE_VERSION,
            price_signature=price_signature,
        )
    except Exception:
        logger.warning(
            "admin_comparison.basis_date_window persistent cache lookup failed version_id=%s",
            version_id,
            exc_info=True,
        )
        return False, None
    if cached is None or "basis_date_window" not in cached:
        return False, None
    window = cached.get("basis_date_window")
    return True, dict(window) if isinstance(window, dict) else None


def _store_persistent_cached_basis_date_window(
    version_id: int,
    window: dict[str, object] | None,
    *,
    price_signature: str | None,
) -> None:
    repository = getattr(managed_universe_service, "repository", None)
    if not price_signature or repository is None or not repository.is_configured():
        return
    try:
        repository.upsert_admin_comparison_basis_date_window_cache(
            version_id=version_id,
            cache_version=_BASIS_DATE_WINDOW_DB_CACHE_VERSION,
            price_signature=price_signature,
            payload={"basis_date_window": window},
        )
    except Exception:
        logger.warning(
            "admin_comparison.basis_date_window persistent cache store failed version_id=%s",
            version_id,
            exc_info=True,
        )


def _cached_basis_date_window(version_id: int) -> dict[str, object] | None:
    price_signature = _get_basis_date_window_price_signature(version_id)
    cache_key = (version_id, price_signature)
    now = time.monotonic()
    with _basis_date_window_cache_lock:
        cached = _basis_date_window_cache.get(cache_key)
        if cached is not None:
            cached_at, payload = cached
            if now - cached_at <= _BASIS_DATE_WINDOW_CACHE_TTL_SECONDS:
                _basis_date_window_cache.move_to_end(cache_key)
                return deepcopy(payload)
            del _basis_date_window_cache[cache_key]

    persistent_found, persistent_payload = _get_persistent_cached_basis_date_window(
        version_id,
        price_signature=price_signature,
    )
    if persistent_found:
        with _basis_date_window_cache_lock:
            _basis_date_window_cache[cache_key] = (
                time.monotonic(),
                deepcopy(persistent_payload),
            )
            _basis_date_window_cache.move_to_end(cache_key)
            while len(_basis_date_window_cache) > _BASIS_DATE_WINDOW_CACHE_MAX_ITEMS:
                _basis_date_window_cache.popitem(last=False)
        logger.info(
            "admin_comparison.basis_date_window db cache hit version_id=%s",
            version_id,
        )
        return persistent_payload

    payload = _basis_date_window(version_id)
    _store_persistent_cached_basis_date_window(
        version_id,
        payload,
        price_signature=price_signature,
    )
    with _basis_date_window_cache_lock:
        _basis_date_window_cache[cache_key] = (time.monotonic(), deepcopy(payload))
        _basis_date_window_cache.move_to_end(cache_key)
        while len(_basis_date_window_cache) > _BASIS_DATE_WINDOW_CACHE_MAX_ITEMS:
            _basis_date_window_cache.popitem(last=False)
    return payload


def _basis_date_has_representative_history(
    *,
    version_id: int,
    instruments: list[object],
    prices: pd.DataFrame,
) -> bool:
    try:
        stock_returns = StockDataRepository().build_stock_returns(prices)
    except RuntimeError:
        return False
    if stock_returns.empty:
        return False

    try:
        assets = portfolio_simulation_service.list_assets(version_id=version_id)
        candidate_map = portfolio_simulation_service._build_sector_candidate_map(
            assets,
            instruments,
            stock_returns,
        )
        combinations = portfolio_simulation_service._build_representative_combinations(candidate_map)
    except RuntimeError:
        return False

    for combination in combinations:
        try:
            portfolio_simulation_service._prepare_selected_stock_returns(
                stock_returns,
                combination,
            )
        except RuntimeError:
            continue
        return True
    return False


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

    normalized_prices = prices.assign(
        ticker=prices["ticker"].astype(str).str.upper(),
        date=pd.to_datetime(prices["date"]).dt.normalize(),
    )
    common_prices = (
        normalized_prices
        .pivot_table(
            index="date",
            columns="ticker",
            values="adjusted_close",
            aggfunc="last",
        )
        .sort_index()
        .dropna(how="any")
    )
    if len(common_prices.index) < MINIMUM_HISTORY_ROWS + 2:
        return None

    min_index = MINIMUM_HISTORY_ROWS
    max_index = len(common_prices.index) - 2
    if min_index > max_index:
        return None

    def can_build_at(index: int) -> bool:
        basis_date = common_prices.index[index]
        window_prices = normalized_prices[normalized_prices["date"] <= basis_date].copy()
        return _basis_date_has_representative_history(
            version_id=version_id,
            instruments=instruments,
            prices=window_prices,
        )

    if not can_build_at(max_index):
        return None

    best_index = max_index
    low_index = min_index
    high_index = max_index
    while low_index <= high_index:
        candidate_index = (low_index + high_index) // 2
        if can_build_at(candidate_index):
            best_index = candidate_index
            high_index = candidate_index - 1
        else:
            low_index = candidate_index + 1

    min_basis_date = common_prices.index[best_index]
    max_basis_date = common_prices.index[max_index]
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
                "basis_date_window": None,
                "basis_date_window_loaded": False,
            }
            for v in managed_universe_service.list_versions()
        ]
    except RuntimeError as exc:
        raise _http_422(exc) from exc
    return {
        "assets": _serialize_assets(),
        "versions": versions,
    }


@router.get("/basis-date-windows")
def get_basis_date_windows(
    version_ids: str | None = Query(
        default=None,
        description="쉼표로 구분한 유니버스 버전 ID 목록. 없으면 전체 버전을 계산합니다.",
    ),
) -> dict[str, object]:
    try:
        if version_ids:
            requested_ids = [
                int(item)
                for item in version_ids.split(",")
                if item.strip()
            ]
        else:
            requested_ids = [version.version_id for version in managed_universe_service.list_versions()]
        known_ids = {version.version_id for version in managed_universe_service.list_versions()}
        windows = [
            {
                "version_id": version_id,
                "basis_date_window": _cached_basis_date_window(version_id),
                "basis_date_window_loaded": True,
            }
            for version_id in requested_ids
            if version_id in known_ids
        ]
    except RuntimeError as exc:
        raise _http_422(exc) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"version_ids 형식이 올바르지 않습니다: {exc}") from exc
    return {"windows": windows}


# ── Frontier preview (live, per version) ──


def _calculate_frontier_response(payload: FrontierRequest) -> dict[str, object]:
    try:
        context = portfolio_simulation_service.build_engine_context(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=payload.investment_horizon,
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            as_of_date=payload.as_of_date,
            version_id=payload.version_id,
            include_random_portfolios=False,
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


@router.post("/frontier")
def get_frontier(payload: FrontierRequest) -> dict[str, object]:
    _raise_if_refresh_running(payload.version_id)
    price_signature = _get_frontier_price_signature(payload)
    cache_key = _frontier_cache_key(payload, price_signature=price_signature)
    cached = _get_cached_frontier(cache_key)
    if cached is not None:
        logger.info(
            "admin_comparison.frontier memory cache hit version_id=%s as_of_date=%s sample_points=%s",
            payload.version_id,
            payload.as_of_date,
            payload.sample_points,
        )
        return _with_frontier_cache_metadata(cached, cache_source="memory")

    persistent_cached = _get_persistent_cached_frontier(
        payload,
        price_signature=price_signature,
    )
    if persistent_cached is not None:
        _store_cached_frontier(cache_key, persistent_cached)
        logger.info(
            "admin_comparison.frontier db cache hit version_id=%s as_of_date=%s sample_points=%s",
            payload.version_id,
            payload.as_of_date,
            payload.sample_points,
        )
        return _with_frontier_cache_metadata(persistent_cached, cache_source="db")

    owns_calculation, inflight_event = _begin_frontier_calculation(cache_key)
    if not owns_calculation:
        if inflight_event.wait(_FRONTIER_INFLIGHT_WAIT_SECONDS):
            cached = _get_cached_frontier(cache_key)
            if cached is not None:
                return _with_frontier_cache_metadata(cached, cache_source="memory")
            persistent_cached = _get_persistent_cached_frontier(
                payload,
                price_signature=price_signature,
            )
            if persistent_cached is not None:
                _store_cached_frontier(cache_key, persistent_cached)
                return _with_frontier_cache_metadata(persistent_cached, cache_source="db")
        raise HTTPException(
            status_code=409,
            detail="동일한 Frontier 계산이 이미 진행 중입니다. 잠시 후 다시 시도해주세요.",
        )

    started_at = time.monotonic()
    try:
        with _frontier_distributed_calculation_lock(cache_key) as lock_acquired:
            if not lock_acquired:
                persistent_cached = _get_persistent_cached_frontier(
                    payload,
                    price_signature=price_signature,
                )
                if persistent_cached is not None:
                    _store_cached_frontier(cache_key, persistent_cached)
                    return _with_frontier_cache_metadata(persistent_cached, cache_source="db")
                raise HTTPException(
                    status_code=409,
                    detail="동일한 Frontier 계산이 이미 진행 중입니다. 잠시 후 다시 시도해주세요.",
                )

            response_payload = _calculate_frontier_response(payload)
            _store_cached_frontier(cache_key, response_payload)
            _store_persistent_cached_frontier(
                payload,
                response_payload,
                price_signature=price_signature,
            )
            logger.info(
                "admin_comparison.frontier calculated version_id=%s as_of_date=%s sample_points=%s duration=%.2fs",
                payload.version_id,
                payload.as_of_date,
                payload.sample_points,
                time.monotonic() - started_at,
            )
            return response_payload
    finally:
        _finish_frontier_calculation(cache_key, inflight_event)


# ── Frontier selection (returns stock_weights for backtest) ──


@router.post("/selection")
def get_selection(payload: SelectionRequest) -> dict[str, object]:
    _raise_if_refresh_running(payload.version_id)
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
    _raise_if_refresh_running(payload.version_id)
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
