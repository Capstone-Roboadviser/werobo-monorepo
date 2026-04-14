from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    status: str = Field(..., description="서버 상태", examples=["ok"])
    app: str = Field(..., description="애플리케이션 이름", examples=["Robo Mobile Backend"])
    version: str = Field(..., description="배포된 백엔드 버전", examples=["0.1.0"])


class ErrorResponse(BaseModel):
    detail: str = Field(..., description="오류 상세 메시지", examples=["propensity_score 또는 risk_profile 중 하나는 반드시 제공해야 합니다."])


class AuthUserResponse(BaseModel):
    id: int = Field(..., description="내부 사용자 식별자", examples=[1])
    email: str = Field(..., description="사용자 이메일", examples=["investor@werobo.app"])
    name: str = Field(..., description="표시 이름", examples=["홍길동"])
    provider: str = Field(..., description="인증 제공자", examples=["password"])
    created_at: str = Field(..., description="가입 시각(UTC)", examples=["2026-04-13T08:30:00Z"])


class AuthCurrentSessionResponse(BaseModel):
    authenticated: bool = Field(..., description="현재 토큰 유효 여부", examples=[True])
    expires_at: str = Field(..., description="현재 세션 만료 시각(UTC)", examples=["2026-05-13T08:30:00Z"])
    user: AuthUserResponse = Field(..., description="현재 로그인 사용자")


class AuthSessionResponse(BaseModel):
    access_token: str = Field(..., description="Bearer 인증 토큰")
    token_type: str = Field(..., description="토큰 타입", examples=["bearer"])
    expires_at: str = Field(..., description="세션 만료 시각(UTC)", examples=["2026-05-13T08:30:00Z"])
    user: AuthUserResponse = Field(..., description="로그인/회원가입 완료 사용자")


class AuthLogoutResponse(BaseModel):
    status: str = Field(..., description="로그아웃 처리 결과", examples=["ok"])


class PortfolioAccountSummaryResponse(BaseModel):
    portfolio_code: str = Field(..., description="현재 계정의 대표 포트폴리오 코드", examples=["balanced"])
    portfolio_label: str = Field(..., description="현재 계정의 대표 포트폴리오 이름", examples=["균형형"])
    portfolio_id: str = Field(..., description="현재 계정의 포트폴리오 식별자", examples=["stocks-balanced-medium-0.12"])
    data_source: str = Field(..., description="계산에 사용한 데이터 소스", examples=["managed_universe"])
    investment_horizon: str = Field(..., description="포트폴리오 계산에 사용한 투자 기간", examples=["medium"])
    target_volatility: float = Field(..., description="확정 당시 목표 변동성", examples=[0.12])
    expected_return: float = Field(..., description="확정 당시 연 기대수익률", examples=[0.0742])
    volatility: float = Field(..., description="확정 당시 연 변동성", examples=[0.0815])
    sharpe_ratio: float = Field(..., description="확정 당시 샤프 비율", examples=[0.66])
    started_at: str = Field(..., description="자산 추적 시작일", examples=["2026-04-13"])
    last_snapshot_date: str = Field(..., description="가장 최근 평가일", examples=["2026-04-13"])
    current_value: float = Field(..., description="현재 총 자산", examples=[10325000])
    invested_amount: float = Field(..., description="누적 입금 원금", examples=[10000000])
    profit_loss: float = Field(..., description="평가 손익", examples=[325000])
    cash_balance: float = Field(..., description="현재 리밸런싱 대기 현금", examples=[12500])
    profit_loss_pct: float = Field(..., description="평가 손익률", examples=[0.0325])
    sector_allocations: list["SectorAllocationResponse"] = Field(
        default_factory=list,
        description="현재 계정 포트폴리오의 자산군 비중",
    )
    stock_allocations: list["StockAllocationResponse"] = Field(
        default_factory=list,
        description="현재 계정 포트폴리오의 종목 비중",
    )


class PortfolioAccountHistoryPointResponse(BaseModel):
    date: str = Field(..., description="스냅샷 일자", examples=["2026-04-13"])
    portfolio_value: float = Field(..., description="해당 일자의 총 자산", examples=[10325000])
    invested_amount: float = Field(..., description="해당 일자의 누적 입금 원금", examples=[10000000])
    profit_loss: float = Field(..., description="해당 일자의 평가 손익", examples=[325000])
    profit_loss_pct: float = Field(..., description="해당 일자의 평가 손익률", examples=[0.0325])


class PortfolioAccountActivityResponse(BaseModel):
    type: str = Field(..., description="활동 타입", examples=["cash_in"])
    title: str = Field(..., description="활동 표시 제목", examples=["입금"])
    date: str = Field(..., description="활동 기준일", examples=["2026-04-13"])
    amount: float | None = Field(default=None, description="활동 금액", examples=[500000])
    description: str | None = Field(default=None, description="보조 설명", examples=["균형형 포트폴리오로 자산 추적 시작"])


class PortfolioAccountDashboardResponse(BaseModel):
    has_account: bool = Field(..., description="현재 로그인 사용자의 프로토타입 자산 계정 존재 여부", examples=[True])
    summary: PortfolioAccountSummaryResponse | None = Field(default=None, description="현재 자산 요약")
    history: list[PortfolioAccountHistoryPointResponse] = Field(default_factory=list, description="일별 자산 스냅샷")
    recent_activity: list[PortfolioAccountActivityResponse] = Field(default_factory=list, description="최근 활동 내역")


class ResolvedProfileItemResponse(BaseModel):
    code: str = Field(..., description="판정된 위험 유형 코드", examples=["balanced"])
    label: str = Field(..., description="위험 유형 표시 이름", examples=["균형형"])
    propensity_score: float | None = Field(default=None, description="앱이 전달한 투자성향 점수", examples=[58.0])
    target_volatility: float = Field(..., description="투자기간을 반영해 계산한 목표 변동성", examples=[0.12])
    investment_horizon: str = Field(..., description="투자 기간", examples=["medium"])


class ProfileResolutionResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "resolved_profile": {
                    "code": "balanced",
                    "label": "균형형",
                    "propensity_score": 58.0,
                    "target_volatility": 0.12,
                    "investment_horizon": "medium",
                }
            }
        }
    )

    resolved_profile: ResolvedProfileItemResponse = Field(..., description="판정 결과")


class SectorAllocationResponse(BaseModel):
    asset_code: str = Field(..., description="자산군 코드", examples=["us_growth"])
    asset_name: str = Field(..., description="자산군 이름", examples=["미국 성장주"])
    weight: float = Field(..., description="포트폴리오 내 자산군 비중", examples=[0.24])
    risk_contribution: float = Field(..., description="전체 변동성 대비 위험기여도", examples=[0.31])


class StockAllocationResponse(BaseModel):
    ticker: str = Field(..., description="종목 티커", examples=["QQQ"])
    name: str = Field(..., description="종목명", examples=["Invesco QQQ Trust"])
    sector_code: str = Field(..., description="소속 자산군 코드", examples=["us_growth"])
    sector_name: str = Field(..., description="소속 자산군 이름", examples=["미국 성장주"])
    weight: float = Field(..., description="포트폴리오 내 개별 종목 비중", examples=[0.12])


class PortfolioRecommendationItemResponse(BaseModel):
    code: str = Field(..., description="포트폴리오 위험 유형 코드", examples=["conservative"])
    label: str = Field(..., description="포트폴리오 유형 이름", examples=["안정형"])
    portfolio_id: str = Field(..., description="내부 포트폴리오 식별자", examples=["stocks-balanced-medium-0.12"])
    target_volatility: float = Field(..., description="해당 유형의 목표 변동성", examples=[0.08])
    expected_return: float = Field(..., description="연 기대수익률", examples=[0.0742])
    volatility: float = Field(..., description="연 변동성", examples=[0.0815])
    sharpe_ratio: float = Field(..., description="샤프 비율", examples=[0.66])
    sector_allocations: list[SectorAllocationResponse] = Field(default_factory=list, description="자산군별 비중과 위험기여도")
    stock_allocations: list[StockAllocationResponse] = Field(default_factory=list, description="종목별 비중")


class RecommendationResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "resolved_profile": {
                    "code": "balanced",
                    "label": "균형형",
                    "propensity_score": 58.0,
                    "target_volatility": 0.12,
                    "investment_horizon": "medium",
                },
                "recommended_portfolio_code": "balanced",
                "data_source": "managed_universe",
                "portfolios": [
                    {
                        "code": "conservative",
                        "label": "안정형",
                        "portfolio_id": "stocks-conservative-medium-0.08",
                        "target_volatility": 0.08,
                        "expected_return": 0.0742,
                        "volatility": 0.0815,
                        "sharpe_ratio": 0.66,
                        "sector_allocations": [
                            {
                                "asset_code": "short_term_bond",
                                "asset_name": "단기 채권",
                                "weight": 0.29,
                                "risk_contribution": 0.18,
                            }
                        ],
                        "stock_allocations": [
                            {
                                "ticker": "SHY",
                                "name": "iShares 1-3 Year Treasury Bond ETF",
                                "sector_code": "short_term_bond",
                                "sector_name": "단기 채권",
                                "weight": 0.29,
                            }
                        ],
                    }
                ],
            }
        }
    )

    resolved_profile: ResolvedProfileItemResponse = Field(..., description="사용자 판정 결과")
    recommended_portfolio_code: str = Field(..., description="사용자에게 추천할 포트폴리오 유형 코드", examples=["balanced"])
    data_source: str = Field(..., description="계산에 사용한 데이터 소스", examples=["managed_universe"])
    as_of_date: str | None = Field(default=None, description="historical 계산 기준일", examples=["2026-03-01"])
    portfolios: list[PortfolioRecommendationItemResponse] = Field(default_factory=list, description="안정형/균형형/성장형 3개 대표 포트폴리오")


class FrontierPreviewPointResponse(BaseModel):
    index: int = Field(..., description="전체 frontier 목록 기준 포인트 인덱스", examples=[24])
    volatility: float = Field(..., description="연 변동성", examples=[0.1042])
    expected_return: float = Field(..., description="연 기대수익률", examples=[0.0831])
    is_recommended: bool = Field(..., description="사용자 추천 위험유형에 해당하는 포인트인지 여부", examples=[False])
    representative_code: str | None = Field(default=None, description="대표 포트폴리오 코드와 일치할 때의 코드", examples=["balanced"])
    representative_label: str | None = Field(default=None, description="대표 포트폴리오 표시 이름", examples=["균형형"])


class FrontierPreviewResponse(BaseModel):
    resolved_profile: ResolvedProfileItemResponse = Field(..., description="사용자 판정 결과")
    recommended_portfolio_code: str = Field(..., description="사용자에게 추천되는 대표 포트폴리오 코드", examples=["balanced"])
    data_source: str = Field(..., description="계산에 사용한 데이터 소스", examples=["managed_universe"])
    as_of_date: str | None = Field(default=None, description="historical 계산 기준일", examples=["2026-03-01"])
    total_point_count: int = Field(..., description="내부에서 계산된 전체 frontier 포인트 수", examples=[160])
    min_volatility: float = Field(..., description="frontier 최소 변동성", examples=[0.0415])
    max_volatility: float = Field(..., description="frontier 최대 변동성", examples=[0.1918])
    points: list[FrontierPreviewPointResponse] = Field(default_factory=list, description="모바일 차트용으로 다운샘플된 frontier 포인트")


class FrontierSelectionResponse(BaseModel):
    resolved_profile: ResolvedProfileItemResponse = Field(..., description="사용자 판정 결과")
    data_source: str = Field(..., description="계산에 사용한 데이터 소스", examples=["managed_universe"])
    as_of_date: str | None = Field(default=None, description="historical 계산 기준일", examples=["2026-03-01"])
    requested_target_volatility: float = Field(..., description="앱이 선택 요청한 목표 변동성", examples=[0.11])
    selected_target_volatility: float = Field(..., description="실제로 매칭된 frontier 포인트의 목표 변동성", examples=[0.1084])
    selected_point_index: int = Field(..., description="내부 frontier 목록에서 매칭된 포인트 인덱스", examples=[31])
    total_point_count: int = Field(..., description="내부에서 계산된 전체 frontier 포인트 수", examples=[160])
    representative_code: str | None = Field(default=None, description="가장 가까운 대표 포트폴리오 코드", examples=["balanced"])
    representative_label: str | None = Field(default=None, description="가장 가까운 대표 포트폴리오 이름", examples=["균형형"])
    portfolio: PortfolioRecommendationItemResponse = Field(..., description="사용자가 확정한 선택 포트폴리오 상세")


class VolatilityPointResponse(BaseModel):
    date: str = Field(..., description="관측일", examples=["2025-01-31"])
    volatility: float = Field(..., description="연환산 롤링 변동성", examples=[0.1123])


class VolatilityHistoryResponse(BaseModel):
    portfolio_code: str = Field(..., description="조회 대상 포트폴리오 코드", examples=["balanced"])
    portfolio_label: str = Field(..., description="조회 대상 포트폴리오 이름", examples=["균형형"])
    rolling_window: int = Field(..., description="롤링 변동성 계산 윈도우", examples=[20])
    earliest_data_date: str = Field(..., description="사용한 데이터의 시작일", examples=["2020-01-02"])
    latest_data_date: str = Field(..., description="사용한 데이터의 종료일", examples=["2026-03-31"])
    points: list[VolatilityPointResponse] = Field(default_factory=list, description="날짜별 변동성 추이")
    benchmark_points: list[VolatilityPointResponse] | None = Field(default=None, description="7자산 동일비중 포트폴리오 변동성 추이 (날짜는 points와 동일)")


class ComparisonLinePointResponse(BaseModel):
    date: str = Field(..., description="백테스트 기준일", examples=["2025-01-31"])
    return_pct: float = Field(..., description="누적 수익률", examples=[0.0834])


class ComparisonLineResponse(BaseModel):
    key: str = Field(..., description="라인 식별 키", examples=["balanced"])
    label: str = Field(..., description="라인 표시명", examples=["균형형"])
    color: str = Field(..., description="차트 색상", examples=["#2A9D8F"])
    style: str = Field(..., description="차트 렌더링 스타일", examples=["solid"])
    points: list[ComparisonLinePointResponse] = Field(default_factory=list, description="시계열 포인트")


class RebalancePolicyResponse(BaseModel):
    strategy: str = Field(..., description="리밸런싱 정책 식별자", examples=["scheduled_plus_drift_guard"])
    scheduled_rebalance_frequency: str | None = Field(
        default=None,
        description="정기 리밸런싱 주기",
        examples=["quarterly"],
    )
    force_rebalance_on_schedule: bool = Field(
        ...,
        description="정기 점검일에는 drift와 무관하게 리밸런싱을 수행하는지 여부",
        examples=[True],
    )
    drift_check_frequency: str | None = Field(
        default=None,
        description="drift guard를 검사하는 빈도",
        examples=["daily"],
    )
    drift_threshold: float | None = Field(
        default=None,
        description="drift guard 임계값",
        examples=[0.10],
    )


class RebalanceInsightAllocationResponse(BaseModel):
    asset_code: str = Field(..., description="자산군 코드", examples=["us_value"])
    asset_name: str = Field(..., description="자산군 이름", examples=["미국 가치주"])
    color: str = Field(..., description="차트 색상 (hex)", examples=["#20A7DB"])
    before_pct: float = Field(..., description="리밸런싱 전 비중", examples=[0.212])
    after_pct: float = Field(..., description="리밸런싱 후 비중", examples=[0.200])


class RebalanceInsightResponse(BaseModel):
    id: int = Field(..., description="인사이트 식별자", examples=[1])
    rebalance_date: str = Field(..., description="리밸런싱 발생일", examples=["2026-04-01"])
    allocations: list[RebalanceInsightAllocationResponse] = Field(
        default_factory=list,
        description="자산군별 리밸런싱 전후 비중",
    )
    trigger: str | None = Field(default=None, description="리밸런싱 트리거", examples=["drift_guard"])
    trade_count: int = Field(default=0, description="실제 매매가 발생한 종목 수", examples=[3])
    cash_before: float | None = Field(default=None, description="리밸런싱 전 현금 잔액", examples=[0])
    cash_from_sales: float | None = Field(default=None, description="매도로 확보한 현금", examples=[700000])
    cash_to_buys: float | None = Field(default=None, description="매수에 사용한 현금", examples=[520000])
    cash_after: float | None = Field(default=None, description="리밸런싱 후 예비현금", examples=[180000])
    net_cash_change: float | None = Field(default=None, description="리밸런싱 전후 순현금 변화", examples=[180000])
    explanation_text: str | None = Field(default=None, description="리밸런싱 설명 텍스트")
    is_read: bool = Field(..., description="읽음 여부", examples=[False])
    created_at: str = Field(..., description="생성 시각(UTC)", examples=["2026-04-01T08:30:00Z"])


class RebalanceInsightsListResponse(BaseModel):
    insights: list[RebalanceInsightResponse] = Field(default_factory=list, description="리밸런싱 인사이트 목록")
    unread_count: int = Field(..., description="읽지 않은 인사이트 수", examples=[2])


class ComparisonBacktestResponse(BaseModel):
    train_start_date: str = Field(..., description="학습 구간 시작일", examples=["2020-01-02"])
    train_end_date: str = Field(..., description="학습 구간 종료일", examples=["2023-12-29"])
    test_start_date: str = Field(..., description="테스트 구간 시작일", examples=["2024-01-02"])
    start_date: str = Field(..., description="전체 비교 시작일", examples=["2020-01-02"])
    end_date: str = Field(..., description="전체 비교 종료일", examples=["2026-03-31"])
    split_ratio: float = Field(..., description="학습/테스트 분할 비율", examples=[0.7])
    rebalance_dates: list[str] = Field(default_factory=list, description="리밸런싱 발생일 목록")
    rebalance_policy: RebalancePolicyResponse = Field(..., description="비교선 계산에 사용한 리밸런싱 정책")
    lines: list[ComparisonLineResponse] = Field(default_factory=list, description="안정형/균형형/성장형 및 벤치마크 비교 라인")
