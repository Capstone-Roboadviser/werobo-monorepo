from __future__ import annotations

import argparse
import json
import sys
from datetime import date
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from mobile_backend.data.auth_repository import AuthRepository
from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from mobile_backend.services.account_service import PortfolioAccountService
from mobile_backend.services.mobile_portfolio_service import MobilePortfolioService


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "원하는 날짜와 기대수익률에 가장 가까운 frontier point를 찾아 "
            "특정 사용자의 프로토타입 투자 확정 계정을 생성/교체합니다."
        ),
    )
    target_group = parser.add_mutually_exclusive_group(required=True)
    target_group.add_argument("--email", help="대상 사용자 이메일")
    target_group.add_argument("--user-id", type=int, help="대상 사용자 ID")

    profile_group = parser.add_mutually_exclusive_group()
    profile_group.add_argument(
        "--risk-profile",
        choices=[item.value for item in RiskProfile],
        help="resolved_profile 계산에 사용할 위험성향",
    )
    profile_group.add_argument(
        "--propensity-score",
        type=float,
        help="resolved_profile 계산에 사용할 성향 점수 (미지정 시 45 사용)",
    )

    parser.add_argument(
        "--as-of-date",
        required=True,
        help="historical 계산 기준일 (YYYY-MM-DD)",
    )
    parser.add_argument(
        "--expected-return-pct",
        required=True,
        type=float,
        help="원하는 연 기대수익률 퍼센트 값. 예: 6.0",
    )
    parser.add_argument(
        "--initial-cash-amount",
        type=float,
        default=10000000,
        help="초기 입금 금액. 기본값: 10000000",
    )
    parser.add_argument(
        "--investment-horizon",
        choices=[item.value for item in InvestmentHorizon],
        default=InvestmentHorizon.MEDIUM.value,
        help="투자 기간. 기본값: medium",
    )
    parser.add_argument(
        "--data-source",
        choices=[item.value for item in SimulationDataSource],
        default=SimulationDataSource.MANAGED_UNIVERSE.value,
        help="계산 데이터 소스. 기본값: managed_universe",
    )
    parser.add_argument(
        "--sample-points",
        type=int,
        default=1000,
        help="frontier preview 샘플 수. 기본값: 1000",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="DB에 쓰지 않고 선택 결과만 출력",
    )
    return parser


def _resolve_user(*, repository: AuthRepository, email: str | None, user_id: int | None):
    if email is not None:
        user = repository.get_user_by_email(email.strip())
        if user is None:
            raise RuntimeError(f"이메일에 해당하는 사용자를 찾지 못했습니다: {email}")
        return user
    assert user_id is not None
    user = repository.get_user_by_id(user_id)
    if user is None:
        raise RuntimeError(f"user_id={user_id} 사용자를 찾지 못했습니다.")
    return user


def _nearest_preview_point(preview: dict[str, object], target_expected_return_pct: float) -> dict[str, object]:
    raw_points = preview.get("points")
    if not isinstance(raw_points, list) or not raw_points:
        raise RuntimeError("frontier preview points가 비어 있습니다.")

    target_ratio = target_expected_return_pct / 100
    best_point: dict[str, object] | None = None
    best_key: tuple[float, float, int] | None = None
    for raw_point in raw_points:
        if not isinstance(raw_point, dict):
            continue
        expected_return = float(raw_point["expected_return"])
        volatility = float(raw_point["volatility"])
        point_index = int(raw_point["index"])
        key = (abs(expected_return - target_ratio), abs(volatility), point_index)
        if best_key is None or key < best_key:
            best_key = key
            best_point = raw_point

    if best_point is None:
        raise RuntimeError("유효한 frontier preview point를 찾지 못했습니다.")
    return best_point


def _selection_classification(selection: dict[str, object]) -> tuple[str, str]:
    code = selection.get("representative_code") or (
        selection.get("resolved_profile", {}) if isinstance(selection.get("resolved_profile"), dict) else {}
    ).get("code")
    label = selection.get("representative_label") or (
        selection.get("resolved_profile", {}) if isinstance(selection.get("resolved_profile"), dict) else {}
    ).get("label")
    if not isinstance(code, str) or not code:
        raise RuntimeError("selection classification code를 확인할 수 없습니다.")
    if not isinstance(label, str) or not label:
        raise RuntimeError("selection classification label을 확인할 수 없습니다.")
    return code, label


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()

    as_of_date = date.fromisoformat(args.as_of_date)
    propensity_score = 45.0 if args.risk_profile is None and args.propensity_score is None else args.propensity_score
    explicit_profile = None if args.risk_profile is None else RiskProfile(args.risk_profile)
    investment_horizon = InvestmentHorizon(args.investment_horizon)
    data_source = SimulationDataSource(args.data_source)

    auth_repository = AuthRepository()
    auth_repository.initialize()
    user = _resolve_user(
        repository=auth_repository,
        email=args.email,
        user_id=args.user_id,
    )

    mobile_portfolio_service = MobilePortfolioService()
    preview = mobile_portfolio_service.build_frontier_preview(
        propensity_score=propensity_score,
        explicit_profile=explicit_profile,
        investment_horizon=investment_horizon,
        data_source=data_source,
        sample_points=args.sample_points,
        as_of_date=as_of_date,
    )
    preview_point = _nearest_preview_point(preview, args.expected_return_pct)
    selection = mobile_portfolio_service.build_frontier_selection(
        propensity_score=propensity_score,
        explicit_profile=explicit_profile,
        investment_horizon=investment_horizon,
        data_source=data_source,
        target_volatility=None,
        point_index=int(preview_point["index"]),
        as_of_date=as_of_date,
    )
    portfolio = selection.get("portfolio")
    if not isinstance(portfolio, dict):
        raise RuntimeError("selection portfolio payload를 확인할 수 없습니다.")

    classification_code, classification_label = _selection_classification(selection)
    summary = {
        "user": {
            "id": user.id,
            "email": user.email,
            "name": user.name,
        },
        "requested": {
            "as_of_date": as_of_date.isoformat(),
            "expected_return_pct": round(float(args.expected_return_pct), 4),
            "initial_cash_amount": round(float(args.initial_cash_amount), 2),
            "investment_horizon": investment_horizon.value,
            "data_source": data_source.value,
            "risk_profile": explicit_profile.value if explicit_profile is not None else None,
            "propensity_score": propensity_score,
        },
        "matched_preview_point": {
            "index": int(preview_point["index"]),
            "volatility_pct": round(float(preview_point["volatility"]) * 100, 4),
            "expected_return_pct": round(float(preview_point["expected_return"]) * 100, 4),
        },
        "selection": {
            "selected_point_index": int(selection["selected_point_index"]),
            "classification_code": classification_code,
            "classification_label": classification_label,
            "target_volatility_pct": round(float(selection["selected_target_volatility"]) * 100, 4),
            "portfolio_id": str(portfolio["portfolio_id"]),
            "portfolio_expected_return_pct": round(float(portfolio["expected_return"]) * 100, 4),
            "portfolio_volatility_pct": round(float(portfolio["volatility"]) * 100, 4),
        },
        "dry_run": bool(args.dry_run),
    }

    if args.dry_run:
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0

    account_service = PortfolioAccountService()
    account_service.initialize_storage()
    dashboard = account_service.create_or_replace_account(
        user_id=user.id,
        data_source=data_source,
        investment_horizon=investment_horizon.value,
        portfolio_code=classification_code,
        portfolio_label=classification_label,
        portfolio_id=str(portfolio["portfolio_id"]),
        target_volatility=float(portfolio["target_volatility"]),
        expected_return=float(portfolio["expected_return"]),
        volatility=float(portfolio["volatility"]),
        sharpe_ratio=float(portfolio["sharpe_ratio"]),
        stock_allocations=list(portfolio["stock_allocations"]),
        sector_allocations=list(portfolio["sector_allocations"]),
        initial_cash_amount=float(args.initial_cash_amount),
        started_at=as_of_date.isoformat(),
    )

    print(
        json.dumps(
            {
                **summary,
                "dashboard": dashboard,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
