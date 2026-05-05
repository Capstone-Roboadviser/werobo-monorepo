from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException

from mobile_backend.api.routes.auth import _extract_bearer_token
from mobile_backend.api.schemas.response import (
    ErrorResponse,
    RebalanceInsightAllocationResponse,
    RebalanceInsightTradeResponse,
    RebalanceInsightResponse,
    RebalanceInsightsListResponse,
)
from mobile_backend.services.account_service import (
    PortfolioAccountNotFoundError,
    PortfolioAccountService,
)
from mobile_backend.services.auth_service import AuthService, AuthUnauthorizedError
from mobile_backend.services.insight_text_service import color_for_sector

router = APIRouter(prefix="/api/v1/insights", tags=["insights"])
account_service = PortfolioAccountService()
auth_service = AuthService()

INSIGHT_ERROR_RESPONSES = {
    401: {"model": ErrorResponse, "description": "인증 실패"},
    404: {"model": ErrorResponse, "description": "자산 계정을 찾지 못함"},
}


def _current_user_id(authorization: str | None) -> int:
    try:
        access_token = _extract_bearer_token(authorization)
        current_session = auth_service.get_current_session(access_token)
        user = current_session.get("user")
        if not isinstance(user, dict):
            raise HTTPException(status_code=401, detail="유효한 사용자 세션을 찾지 못했습니다.")
        return int(user.get("id", 0))
    except HTTPException:
        raise
    except AuthUnauthorizedError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


def _build_ticker_metadata(account: dict[str, object]) -> dict[str, dict[str, str]]:
    metadata: dict[str, dict[str, str]] = {}
    for allocation in list(account.get("stock_allocations") or []):
        ticker = str(allocation.get("ticker", "")).strip().upper()
        if not ticker:
            continue
        metadata[ticker] = {
            "ticker_name": str(allocation.get("name", "")).strip(),
            "asset_code": str(allocation.get("sector_code", "")).strip(),
            "asset_name": str(allocation.get("sector_name", "")).strip(),
        }
    return metadata


def _build_trade_details(
    insight: dict[str, object],
    *,
    ticker_metadata: dict[str, dict[str, str]],
) -> list[RebalanceInsightTradeResponse]:
    trade_rows: list[RebalanceInsightTradeResponse] = []
    for ticker, raw_amount in dict(insight.get("trades") or {}).items():
        normalized_ticker = str(ticker).strip().upper()
        amount = float(raw_amount)
        if normalized_ticker == "CASH" or abs(amount) <= 0.0:
            continue
        metadata = ticker_metadata.get(normalized_ticker, {})
        trade_rows.append(
            RebalanceInsightTradeResponse(
                ticker=normalized_ticker,
                ticker_name=metadata.get("ticker_name") or None,
                asset_code=metadata.get("asset_code") or None,
                asset_name=metadata.get("asset_name") or None,
                direction="buy" if amount > 0 else "sell",
                amount=round(abs(amount), 2),
            )
        )
    trade_rows.sort(key=lambda item: item.amount, reverse=True)
    return trade_rows


def _build_insight_response(
    insight: dict[str, object],
    *,
    ticker_metadata: dict[str, dict[str, str]],
) -> RebalanceInsightResponse:
    pre_weights = dict(insight.get("pre_weights") or {})
    post_weights = dict(insight.get("post_weights") or {})
    all_codes = list(dict.fromkeys(list(pre_weights.keys()) + list(post_weights.keys())))

    allocations = []
    for i, code in enumerate(all_codes):
        before = float(pre_weights.get(code, 0.0))
        after = float(post_weights.get(code, 0.0))
        allocations.append(
            RebalanceInsightAllocationResponse(
                asset_code=code,
                asset_name=code,
                color=color_for_sector(code, i),
                before_pct=round(before, 4),
                after_pct=round(after, 4),
            )
        )

    trade_details = _build_trade_details(
        insight,
        ticker_metadata=ticker_metadata,
    )

    return RebalanceInsightResponse(
        id=int(insight["id"]),
        rebalance_date=str(insight["rebalance_date"]),
        allocations=allocations,
        trade_details=trade_details,
        trigger=None if insight.get("trigger") is None else str(insight["trigger"]),
        trade_count=len(trade_details),
        cash_before=(
            None if insight.get("cash_before") is None else float(insight["cash_before"])
        ),
        cash_from_sales=(
            None
            if insight.get("cash_from_sales") is None
            else float(insight["cash_from_sales"])
        ),
        cash_to_buys=(
            None if insight.get("cash_to_buys") is None else float(insight["cash_to_buys"])
        ),
        cash_after=None if insight.get("cash_after") is None else float(insight["cash_after"]),
        net_cash_change=(
            None
            if insight.get("net_cash_change") is None
            else float(insight["net_cash_change"])
        ),
        explanation_text=insight.get("explanation_text"),
        is_read=bool(insight.get("is_read", False)),
        created_at=str(insight["created_at"]),
    )


def _merge_insight_rows(
    *,
    raw_insights: list[dict[str, object]],
    cash_entries: list[dict[str, object]],
) -> list[dict[str, object]]:
    insights_by_date = {
        str(row["rebalance_date"]): dict(row)
        for row in raw_insights
    }
    cash_by_date = {
        str(entry["rebalance_date"]): dict(entry)
        for entry in cash_entries
    }

    merged_rows: list[dict[str, object]] = []
    for rebalance_date in sorted(
        set(insights_by_date.keys()) | set(cash_by_date.keys()),
        reverse=True,
    ):
        base_row = insights_by_date.get(rebalance_date)
        if base_row is None:
            cash_entry = cash_by_date[rebalance_date]
            synthetic_id = -int(rebalance_date.replace("-", ""))
            base_row = {
                "id": synthetic_id,
                "rebalance_date": rebalance_date,
                "pre_weights": {},
                "post_weights": {},
                "explanation_text": None,
                # Legacy cash-ledger rows do not have a persisted insight record,
                # so expose them in history without surfacing them as unread items.
                "is_read": True,
                "created_at": str(
                    cash_entry.get("created_at")
                    or f"{rebalance_date}T00:00:00Z"
                ),
            }

        cash_entry = cash_by_date.get(rebalance_date)
        merged_rows.append(
            {
                **base_row,
                "trigger": None if cash_entry is None else cash_entry.get("trigger"),
                "cash_before": None if cash_entry is None else cash_entry.get("cash_before"),
                "cash_from_sales": (
                    None if cash_entry is None else cash_entry.get("cash_from_sales")
                ),
                "cash_to_buys": None if cash_entry is None else cash_entry.get("cash_to_buys"),
                "cash_after": None if cash_entry is None else cash_entry.get("cash_after"),
                "net_cash_change": (
                    None if cash_entry is None else cash_entry.get("net_cash_change")
                ),
                "trades": {} if cash_entry is None else dict(cash_entry.get("trades") or {}),
            }
        )

    return merged_rows


@router.get(
    "",
    response_model=RebalanceInsightsListResponse,
    summary="리밸런싱 인사이트 목록 조회",
    description="현재 로그인한 사용자의 포트폴리오 리밸런싱 인사이트를 반환합니다.",
    responses=INSIGHT_ERROR_RESPONSES,
)
def list_insights(
    authorization: str | None = Header(default=None),
) -> RebalanceInsightsListResponse:
    user_id = _current_user_id(authorization)
    try:
        account = account_service.repository.get_account_by_user_id(user_id)
        if account is None:
            return RebalanceInsightsListResponse(insights=[], unread_count=0)

        raw_insights = account_service.repository.list_rebalance_insights(int(account["id"]))
        cash_entries = account_service.repository.list_rebalance_cash_entries(int(account["id"]))
        ticker_metadata = _build_ticker_metadata(account)
        merged_rows = _merge_insight_rows(
            raw_insights=raw_insights,
            cash_entries=cash_entries,
        )
        insights = [
            _build_insight_response(
                row,
                ticker_metadata=ticker_metadata,
            )
            for row in merged_rows
        ]
        unread_count = sum(1 for i in insights if not i.is_read)
        return RebalanceInsightsListResponse(insights=insights, unread_count=unread_count)
    except PortfolioAccountNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/{insight_id}/read",
    response_model=RebalanceInsightResponse,
    summary="리밸런싱 인사이트 읽음 처리",
    description="지정된 인사이트를 읽음으로 표시합니다.",
    responses=INSIGHT_ERROR_RESPONSES,
)
def mark_insight_read(
    insight_id: int,
    authorization: str | None = Header(default=None),
) -> RebalanceInsightResponse:
    user_id = _current_user_id(authorization)
    account = account_service.repository.get_account_by_user_id(user_id)
    if account is None:
        raise HTTPException(status_code=404, detail="자산 계정을 찾지 못했습니다.")
    result = account_service.repository.mark_insight_read(insight_id)
    if result is None:
        raise HTTPException(status_code=404, detail="인사이트를 찾지 못했거나 이미 읽음 처리되었습니다.")
    cash_entries = account_service.repository.list_rebalance_cash_entries(int(account["id"]))
    cash_entry_by_date = {
        str(entry["rebalance_date"]): dict(entry)
        for entry in cash_entries
    }
    rebalance_date = str(result["rebalance_date"])
    cash_entry = cash_entry_by_date.get(rebalance_date)
    merged_result = {
        **result,
        "trigger": None if cash_entry is None else cash_entry.get("trigger"),
        "cash_before": None if cash_entry is None else cash_entry.get("cash_before"),
        "cash_from_sales": None if cash_entry is None else cash_entry.get("cash_from_sales"),
        "cash_to_buys": None if cash_entry is None else cash_entry.get("cash_to_buys"),
        "cash_after": None if cash_entry is None else cash_entry.get("cash_after"),
        "net_cash_change": None if cash_entry is None else cash_entry.get("net_cash_change"),
        "trades": {} if cash_entry is None else dict(cash_entry.get("trades") or {}),
    }
    return _build_insight_response(
        merged_result,
        ticker_metadata=_build_ticker_metadata(account),
    )
