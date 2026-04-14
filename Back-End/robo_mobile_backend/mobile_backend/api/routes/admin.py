import secrets

from fastapi import APIRouter, Header, HTTPException, Query

from app.api.schemas.request import (
    AccountSnapshotBackfillRequest,
    ActivePriceRefreshRequest,
    ManagedUniverseVersionCreateRequest,
    ManagedUniverseVersionUpdateRequest,
    PriceRefreshRequest,
)
from app.api.schemas.response import (
    AssetClassResponse,
    AssetRoleTemplateResponse,
    CombinationSelectionResponse,
    ErrorResponse,
    ManagedComparisonBacktestSnapshotStatusResponse,
    ManagedFrontierSnapshotStatusResponse,
    ManagedPortfolioAccountSnapshotBackfillResponse,
    ManagedPortfolioAccountSnapshotStatusResponse,
    ManagedPriceRefreshJobResponse,
    ManagedPriceRefreshResponse,
    ManagedUniverseAssetRoleCatalogResponse,
    ManagedUniverseAssetRoleResponse,
    ManagedUniverseDeleteResponse,
    ManagedPriceStatsResponse,
    ManagedUniverseItemResponse,
    ManagedUniversePriceWindowResponse,
    ManagedUniverseReadinessResponse,
    ManagedUniverseSectorReadinessResponse,
    ManagedUniverseShortHistoryInstrumentResponse,
    ManagedUniverseStatusResponse,
    ManagedUniverseVersionDetailResponse,
    ManagedUniverseVersionResponse,
    TickerLookupResponse,
    TickerSearchResponse,
    TickerSearchResultResponse,
)
from app.domain.models import (
    ManagedPriceRefreshJob,
    ManagedPriceRefreshResult,
    ManagedPriceStats,
    ManagedUniversePriceWindow,
    ManagedUniverseVersion,
)
from app.services.managed_universe_service import ManagedUniverseService
from app.services.portfolio_service import PortfolioSimulationService
from app.services.price_refresh_service import PriceRefreshService
from app.services.ticker_discovery_service import TickerDiscoveryService
from mobile_backend.services.account_service import PortfolioAccountService
from mobile_backend.services.comparison_backtest_snapshot_service import ComparisonBacktestSnapshotService
from mobile_backend.services.frontier_snapshot_service import FrontierSnapshotService
from mobile_backend.core.config import ADMIN_REFRESH_SECRET


router = APIRouter(prefix="/admin/api", tags=["admin"])
managed_universe_service = ManagedUniverseService()
portfolio_simulation_service = PortfolioSimulationService()
ticker_discovery_service = TickerDiscoveryService()
frontier_snapshot_service = FrontierSnapshotService(managed_universe_service=managed_universe_service)
comparison_backtest_snapshot_service = ComparisonBacktestSnapshotService(
    managed_universe_service=managed_universe_service
)
portfolio_account_service = PortfolioAccountService()
price_refresh_service = PriceRefreshService(
    managed_universe_service,
    extra_ticker_provider=lambda version: (
        portfolio_account_service.list_managed_universe_account_tickers()
        if version.is_active
        else []
    ),
)
COMMON_ADMIN_422 = {
    422: {
        "model": ErrorResponse,
        "description": "현재 데이터 상태나 도메인 제약으로 요청을 처리할 수 없습니다.",
    }
}
COMMON_ADMIN_404 = {
    404: {
        "model": ErrorResponse,
        "description": "요청한 유니버스 버전을 찾을 수 없습니다.",
    }
}
COMMON_ADMIN_401 = {
    401: {
        "model": ErrorResponse,
        "description": "관리자 secret이 없거나 일치하지 않습니다.",
    }
}


@router.get(
    "/universe/asset-role-config",
    response_model=ManagedUniverseAssetRoleCatalogResponse,
    summary="자산군 role 설정 목록",
    description="관리자 웹에서 자산군별 role 드롭다운을 그릴 때 사용하는 기본 자산군/role 템플릿 목록입니다.",
    responses=COMMON_ADMIN_422,
)
def get_asset_role_config() -> ManagedUniverseAssetRoleCatalogResponse:
    assets = managed_universe_service.list_assets()
    role_templates = managed_universe_service.list_asset_role_templates()
    return ManagedUniverseAssetRoleCatalogResponse(
        assets=[_asset_response(asset) for asset in assets],
        role_templates=[
            AssetRoleTemplateResponse(
                key=item.key,
                name=item.name,
                description=item.description,
                selection_mode=item.selection_mode,
                weighting_mode=item.weighting_mode,
                return_mode=item.return_mode,
            )
            for item in role_templates
        ],
    )


@router.get(
    "/universe/status",
    response_model=ManagedUniverseStatusResponse,
    summary="유니버스 상태",
    description="현재 active 유니버스와 가격 데이터 상태를 간단히 반환합니다.",
    responses=COMMON_ADMIN_422,
)
def get_managed_universe_status() -> ManagedUniverseStatusResponse:
    try:
        active_version = managed_universe_service.get_active_version() if managed_universe_service.is_configured() else None
        instruments = managed_universe_service.get_active_instruments() if active_version is not None else []
        price_window = (
            managed_universe_service.get_price_window(active_version.version_id, instruments)
            if active_version is not None and instruments
            else None
        )
        price_stats = None
        if active_version is not None and instruments:
            stats = managed_universe_service.get_price_stats_for_instruments(
                instruments,
                version_id=active_version.version_id,
            )
            price_stats = _price_stats_response(stats)
        latest_refresh_job = price_refresh_service.get_latest_job(active_version.version_id) if active_version is not None else None
        return ManagedUniverseStatusResponse(
            database_configured=managed_universe_service.is_configured(),
            active_version=None if active_version is None else _version_response(active_version),
            price_stats=price_stats,
            price_window=None if price_window is None else _price_window_response(price_window),
            latest_refresh_job=None if latest_refresh_job is None else _price_refresh_job_response(latest_refresh_job),
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get(
    "/universe/versions",
    response_model=list[ManagedUniverseVersionResponse],
    summary="유니버스 버전 목록",
    description="관리자가 저장해둔 유니버스 버전 목록을 최신순으로 반환합니다.",
    responses=COMMON_ADMIN_422,
)
def list_managed_universe_versions() -> list[ManagedUniverseVersionResponse]:
    try:
        return [_version_response(item) for item in managed_universe_service.list_versions()]
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get(
    "/universe/versions/{version_id}",
    response_model=ManagedUniverseVersionDetailResponse,
    summary="유니버스 버전 상세",
    description="특정 유니버스 버전의 종목 목록과 자산군별 role 스냅샷을 반환합니다.",
    responses={**COMMON_ADMIN_404, **COMMON_ADMIN_422},
)
def get_universe_version_detail(version_id: int) -> ManagedUniverseVersionDetailResponse:
    try:
        version = managed_universe_service.get_version(version_id)
        if version is None:
            raise HTTPException(status_code=404, detail=f"유니버스 버전 {version_id}를 찾을 수 없습니다.")
        instruments = managed_universe_service.get_version_instruments(version_id)
        assets = managed_universe_service.get_assets_for_version(version_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _version_detail_response(version, instruments, assets)


@router.post(
    "/universe/versions",
    response_model=ManagedUniverseVersionResponse,
    summary="유니버스 버전 생성",
    description="등록한 종목 목록으로 새 유니버스 버전을 생성합니다.",
    responses=COMMON_ADMIN_422,
)
def create_universe_version(payload: ManagedUniverseVersionCreateRequest) -> ManagedUniverseVersionResponse:
    try:
        version = managed_universe_service.create_version(
            version_name=payload.version_name,
            notes=payload.notes,
            activate=payload.activate,
            asset_roles=payload.to_domain_asset_roles(),
            instruments=payload.to_domain_instruments(),
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _version_response(version)


@router.put(
    "/universe/versions/{version_id}",
    response_model=ManagedUniverseVersionResponse,
    summary="유니버스 버전 수정",
    description="기존 유니버스 버전의 종목 구성과 자산군별 role 설정을 수정합니다.",
    responses={**COMMON_ADMIN_404, **COMMON_ADMIN_422},
)
def update_universe_version(
    version_id: int,
    payload: ManagedUniverseVersionUpdateRequest,
) -> ManagedUniverseVersionResponse:
    try:
        version = managed_universe_service.get_version(version_id)
        if version is None:
            raise HTTPException(status_code=404, detail=f"유니버스 버전 {version_id}를 찾을 수 없습니다.")
        updated = managed_universe_service.update_version(
            version_id=version_id,
            version_name=payload.version_name,
            notes=payload.notes,
            activate=payload.activate,
            asset_roles=payload.to_domain_asset_roles(),
            instruments=payload.to_domain_instruments(),
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _version_response(updated)


@router.delete(
    "/universe/versions/{version_id}",
    response_model=ManagedUniverseDeleteResponse,
    summary="유니버스 버전 삭제",
    description="지정한 유니버스 버전을 삭제합니다. active 버전도 삭제할 수 있으며, 이후 active 상태는 비게 됩니다.",
    responses={**COMMON_ADMIN_404, **COMMON_ADMIN_422},
)
def delete_universe_version(version_id: int) -> ManagedUniverseDeleteResponse:
    try:
        version = managed_universe_service.get_version(version_id)
        if version is None:
            raise HTTPException(status_code=404, detail=f"유니버스 버전 {version_id}를 찾을 수 없습니다.")
        managed_universe_service.delete_version(version_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return ManagedUniverseDeleteResponse(
        deleted=True,
        version_id=version_id,
        version_name=version.version_name,
    )


@router.post(
    "/universe/versions/{version_id}/activate",
    response_model=ManagedUniverseVersionResponse,
    summary="유니버스 버전 활성화",
    description="지정한 유니버스 버전을 active 상태로 전환합니다.",
    responses=COMMON_ADMIN_422,
)
def activate_universe_version(version_id: int) -> ManagedUniverseVersionResponse:
    try:
        version = managed_universe_service.activate_version(version_id)
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return _version_response(version)


@router.post(
    "/prices/refresh",
    response_model=ManagedPriceRefreshResponse,
    summary="가격 데이터 갱신",
    description=(
        "active 유니버스 또는 지정 버전에 대해 가격 데이터를 증분/전체 갱신합니다. "
        "active 버전을 갱신할 때는 managed_universe 사용자 계정이 이미 보유 중인 티커도 함께 최신화합니다."
    ),
    responses=COMMON_ADMIN_422,
)
def refresh_prices(payload: PriceRefreshRequest) -> ManagedPriceRefreshResponse:
    try:
        result = price_refresh_service.refresh_prices(
            version_id=payload.version_id,
            refresh_mode=payload.refresh_mode,
            full_lookback_years=payload.full_lookback_years,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    snapshot_status = None
    comparison_snapshot_status = None
    account_snapshot_status = None
    if result.job.status in {"success", "partial_success"}:
        snapshot_status = frontier_snapshot_service.rebuild_managed_universe_snapshots(
            version_id=result.job.version_id,
            source_refresh_job_id=result.job.job_id,
        )
        comparison_snapshot_status = comparison_backtest_snapshot_service.rebuild_managed_universe_snapshots(
            version_id=result.job.version_id,
            source_refresh_job_id=result.job.job_id,
        )
        account_snapshot_status = portfolio_account_service.refresh_managed_universe_accounts()
        result = ManagedPriceRefreshResult(
            job=result.job,
            price_stats=result.price_stats,
            price_window=result.price_window,
            frontier_snapshot_status=snapshot_status,
            comparison_backtest_snapshot_status=comparison_snapshot_status,
        )
    return _price_refresh_response(result, account_snapshot_status=account_snapshot_status)


@router.post(
    "/prices/refresh/active",
    response_model=ManagedPriceRefreshResponse,
    summary="active 유니버스 가격 갱신",
    description=(
        "cron/job에서 호출하기 위한 active 유니버스 전용 가격 갱신 엔드포인트입니다. "
        "active 유니버스 종목과 managed_universe 사용자 계정이 보유 중인 티커를 함께 갱신합니다. "
        "ADMIN_REFRESH_SECRET 환경변수와 X-Admin-Secret 헤더가 일치해야 실행됩니다."
    ),
    responses={**COMMON_ADMIN_401, **COMMON_ADMIN_422},
)
def refresh_active_prices(
    payload: ActivePriceRefreshRequest,
    x_admin_secret: str | None = Header(default=None, alias="X-Admin-Secret"),
) -> ManagedPriceRefreshResponse:
    _verify_admin_refresh_secret(x_admin_secret)
    try:
        result = price_refresh_service.refresh_prices(
            version_id=None,
            refresh_mode=payload.refresh_mode,
            full_lookback_years=payload.full_lookback_years,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    account_snapshot_status = None
    if result.job.status in {"success", "partial_success"}:
        result = ManagedPriceRefreshResult(
            job=result.job,
            price_stats=result.price_stats,
            price_window=result.price_window,
            frontier_snapshot_status=frontier_snapshot_service.rebuild_managed_universe_snapshots(
                version_id=result.job.version_id,
                source_refresh_job_id=result.job.job_id,
            ),
            comparison_backtest_snapshot_status=comparison_backtest_snapshot_service.rebuild_managed_universe_snapshots(
                version_id=result.job.version_id,
                source_refresh_job_id=result.job.job_id,
            ),
        )
        account_snapshot_status = portfolio_account_service.refresh_managed_universe_accounts()
    return _price_refresh_response(result, account_snapshot_status=account_snapshot_status)


@router.post(
    "/accounts/snapshots/backfill",
    response_model=ManagedPortfolioAccountSnapshotBackfillResponse,
    summary="포트폴리오 계정 snapshot backfill",
    description=(
        "legacy 계정의 portfolio_daily_snapshots를 현재 계산 로직으로 다시 생성하는 one-off 운영 엔드포인트입니다. "
        "기본은 dry-run이며, ADMIN_REFRESH_SECRET 환경변수와 X-Admin-Secret 헤더가 일치해야 실행됩니다."
    ),
    responses={**COMMON_ADMIN_401, **COMMON_ADMIN_422},
)
def backfill_account_snapshots(
    payload: AccountSnapshotBackfillRequest,
    x_admin_secret: str | None = Header(default=None, alias="X-Admin-Secret"),
) -> ManagedPortfolioAccountSnapshotBackfillResponse:
    _verify_admin_refresh_secret(x_admin_secret)
    try:
        result = portfolio_account_service.backfill_account_snapshots(
            data_source=payload.data_source,
            account_ids=payload.account_ids,
            user_ids=payload.user_ids,
            started_from=payload.started_from,
            started_to=payload.started_to,
            limit=payload.limit if not payload.allow_all_matching else None,
            dry_run=payload.dry_run,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return ManagedPortfolioAccountSnapshotBackfillResponse(
        status=result.status,
        dry_run=result.dry_run,
        data_source=result.data_source,
        account_count=result.account_count,
        success_count=result.success_count,
        failure_count=result.failure_count,
        selected_account_ids=result.selected_account_ids,
        updated_account_ids=result.updated_account_ids,
        failed_account_ids=result.failed_account_ids,
        failed_user_ids=result.failed_user_ids,
        message=result.message,
    )


@router.get(
    "/universe/readiness",
    response_model=ManagedUniverseReadinessResponse,
    summary="시뮬레이션 준비 상태",
    description="현재 active 유니버스로 실제 포트폴리오 계산을 시작할 수 있는지 점검합니다.",
    responses=COMMON_ADMIN_422,
)
def get_managed_universe_readiness() -> ManagedUniverseReadinessResponse:
    try:
        readiness = portfolio_simulation_service.inspect_managed_universe_readiness()
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return ManagedUniverseReadinessResponse(
        ready=readiness.ready,
        summary=readiness.summary,
        issues=readiness.issues,
        active_version_name=readiness.active_version_name,
        instrument_count=readiness.instrument_count,
        priced_ticker_count=readiness.priced_ticker_count,
        stock_return_rows=readiness.stock_return_rows,
        effective_history_rows=readiness.effective_history_rows,
        minimum_history_rows=readiness.minimum_history_rows,
        sector_checks=[
            ManagedUniverseSectorReadinessResponse(
                sector_code=item.sector_code,
                sector_name=item.sector_name,
                required_count=item.required_count,
                actual_count=item.actual_count,
                ready=item.ready,
            )
            for item in readiness.sector_checks
        ],
        short_history_instruments=[
            ManagedUniverseShortHistoryInstrumentResponse(
                ticker=item.ticker,
                sector_code=item.sector_code,
                sector_name=item.sector_name,
                aligned_return_rows=item.aligned_return_rows,
                raw_return_rows=item.raw_return_rows,
                first_price_date=item.first_price_date,
                last_price_date=item.last_price_date,
                history_years=item.history_years,
                is_youngest=item.is_youngest,
            )
            for item in readiness.short_history_instruments
        ],
        price_window=None if readiness.price_window is None else _price_window_response(readiness.price_window),
        selected_combination=None
        if readiness.selected_combination is None
        else CombinationSelectionResponse(
            combination_id=readiness.selected_combination.combination_id,
            members_by_sector=readiness.selected_combination.members_by_sector,
            total_combinations_tested=readiness.selected_combination.total_combinations_tested,
            successful_combinations=readiness.selected_combination.successful_combinations,
            discard_reasons=readiness.selected_combination.discard_reasons,
        ),
    )


@router.get(
    "/tickers/lookup",
    response_model=TickerLookupResponse,
    summary="티커 자동채움",
    description="정확한 티커를 기준으로 종목명, 시장, 통화 정보를 자동채움합니다.",
    responses=COMMON_ADMIN_422,
)
def lookup_ticker(
    ticker: str = Query(..., description="조회할 정확한 티커", examples=["QQQ"]),
) -> TickerLookupResponse:
    try:
        result = ticker_discovery_service.lookup_ticker(ticker)
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return TickerLookupResponse(
        ticker=result.ticker,
        name=result.name,
        market=result.market,
        currency=result.currency,
        exchange=result.exchange,
        quote_type=result.quote_type,
    )


@router.get(
    "/tickers/search",
    response_model=TickerSearchResponse,
    summary="종목 검색",
    description="종목명 또는 티커 키워드를 입력하면 후보 티커 목록을 반환합니다.",
    responses=COMMON_ADMIN_422,
)
def search_tickers(
    query: str = Query(..., description="종목명 또는 티커 키워드", examples=["nasdaq growth"]),
    max_results: int = Query(default=8, description="반환할 최대 후보 수", ge=1, le=20),
) -> TickerSearchResponse:
    if max_results < 1 or max_results > 20:
        raise HTTPException(status_code=422, detail="max_results는 1 이상 20 이하로 입력해주세요.")
    try:
        results = ticker_discovery_service.search_tickers(query=query, max_results=max_results)
    except RuntimeError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return TickerSearchResponse(
        query=query.strip(),
        results=[
            TickerSearchResultResponse(
                ticker=item.ticker,
                name=item.name,
                exchange=item.exchange,
                quote_type=item.quote_type,
                market=item.market,
                currency=item.currency,
            )
            for item in results
        ],
    )


def _version_response(version: ManagedUniverseVersion) -> ManagedUniverseVersionResponse:
    return ManagedUniverseVersionResponse(
        version_id=version.version_id,
        version_name=version.version_name,
        source_type=version.source_type,
        notes=version.notes,
        is_active=version.is_active,
        created_at=version.created_at,
        instrument_count=version.instrument_count,
    )


def _asset_response(asset) -> AssetClassResponse:
    return AssetClassResponse(
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


def _version_detail_response(version: ManagedUniverseVersion, instruments, assets) -> ManagedUniverseVersionDetailResponse:
    return ManagedUniverseVersionDetailResponse(
        **_version_response(version).model_dump(),
        asset_roles=[
            ManagedUniverseAssetRoleResponse(
                asset_code=asset.code,
                asset_name=asset.name,
                role_key=asset.role_key,
                role_name=asset.role_name,
                role_description=asset.role_description,
                selection_mode=asset.selection_mode,
                weighting_mode=asset.weighting_mode,
                return_mode=asset.return_mode,
            )
            for asset in assets
        ],
        instruments=[
            ManagedUniverseItemResponse(
                ticker=item.ticker,
                name=item.name,
                sector_code=item.sector_code,
                sector_name=item.sector_name,
                market=item.market,
                currency=item.currency,
                base_weight=item.base_weight,
            )
            for item in instruments
        ],
    )


def _price_stats_response(stats: ManagedPriceStats) -> ManagedPriceStatsResponse:
    return ManagedPriceStatsResponse(
        total_rows=stats.total_rows,
        ticker_count=stats.ticker_count,
        min_date=stats.min_date,
        max_date=stats.max_date,
    )


def _price_refresh_job_response(job: ManagedPriceRefreshJob) -> ManagedPriceRefreshJobResponse:
    return ManagedPriceRefreshJobResponse(
        job_id=job.job_id,
        version_id=job.version_id,
        version_name=job.version_name,
        refresh_mode=job.refresh_mode.value,
        status=job.status,
        ticker_count=job.ticker_count,
        success_count=job.success_count,
        failure_count=job.failure_count,
        message=job.message,
        created_at=job.created_at,
        started_at=job.started_at,
        finished_at=job.finished_at,
    )


def _price_refresh_response(
    result: ManagedPriceRefreshResult,
    *,
    account_snapshot_status=None,
) -> ManagedPriceRefreshResponse:
    return ManagedPriceRefreshResponse(
        job=_price_refresh_job_response(result.job),
        price_stats=_price_stats_response(result.price_stats),
        price_window=None if result.price_window is None else _price_window_response(result.price_window),
        frontier_snapshot=None
        if result.frontier_snapshot_status is None
        else ManagedFrontierSnapshotStatusResponse(
            status=result.frontier_snapshot_status.status,
            snapshot_count=result.frontier_snapshot_status.snapshot_count,
            horizons=result.frontier_snapshot_status.horizons,
            failed_horizons=result.frontier_snapshot_status.failed_horizons,
            message=result.frontier_snapshot_status.message,
        ),
        comparison_backtest_snapshot=None
        if result.comparison_backtest_snapshot_status is None
        else ManagedComparisonBacktestSnapshotStatusResponse(
            status=result.comparison_backtest_snapshot_status.status,
            snapshot_count=result.comparison_backtest_snapshot_status.snapshot_count,
            line_count=result.comparison_backtest_snapshot_status.line_count,
            message=result.comparison_backtest_snapshot_status.message,
        ),
        account_snapshot_refresh=None
        if account_snapshot_status is None
        else ManagedPortfolioAccountSnapshotStatusResponse(
            status=account_snapshot_status.status,
            account_count=account_snapshot_status.account_count,
            success_count=account_snapshot_status.success_count,
            failure_count=account_snapshot_status.failure_count,
            failed_user_ids=account_snapshot_status.failed_user_ids,
            message=account_snapshot_status.message,
        ),
    )


def _price_window_response(price_window: ManagedUniversePriceWindow) -> ManagedUniversePriceWindowResponse:
    return ManagedUniversePriceWindowResponse(
        version_id=price_window.version_id,
        aligned_start_date=price_window.aligned_start_date,
        aligned_end_date=price_window.aligned_end_date,
        youngest_ticker=price_window.youngest_ticker,
        youngest_start_date=price_window.youngest_start_date,
        ticker_count=price_window.ticker_count,
    )


def _verify_admin_refresh_secret(x_admin_secret: str | None) -> None:
    if not ADMIN_REFRESH_SECRET:
        raise HTTPException(status_code=401, detail="ADMIN_REFRESH_SECRET가 설정되지 않았습니다.")
    if x_admin_secret is None or not secrets.compare_digest(x_admin_secret, ADMIN_REFRESH_SECRET):
        raise HTTPException(status_code=401, detail="X-Admin-Secret이 올바르지 않습니다.")
