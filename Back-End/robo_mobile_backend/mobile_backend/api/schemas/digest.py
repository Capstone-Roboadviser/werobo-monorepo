from __future__ import annotations

from pydantic import BaseModel, Field


class DigestDriverResponse(BaseModel):
    ticker: str = Field(..., description="종목 티커", examples=["AGG"])
    name_ko: str = Field(..., description="종목 한국어 이름", examples=["미국 채권 종합"])
    sector_code: str = Field(..., description="섹터 코드", examples=["us_bond"])
    weight_pct: float = Field(..., description="포트폴리오 비중(%)", examples=[25.3])
    return_pct: float = Field(..., description="7일 수익률(%)", examples=[0.8])
    contribution_won: float = Field(..., description="수익 기여금(원)", examples=[5400])
    explanation_ko: str | None = Field(None, description="AI 생성 한국어 설명")


class DigestResponse(BaseModel):
    digest_date: str = Field(..., description="다이제스트 기준일", examples=["2026-04-14"])
    period_start: str = Field(..., description="분석 시작일", examples=["2026-04-07"])
    period_end: str = Field(..., description="분석 종료일", examples=["2026-04-14"])
    total_return_pct: float = Field(..., description="주간 총 수익률(%)", examples=[-1.2])
    total_return_won: float = Field(..., description="주간 총 수익(원)", examples=[-32400])
    available: bool = Field(
        default=True,
        description="이번 주 다이제스트 노출 여부 (최근 변동성 대비 유의미한 움직임일 때 true)",
    )
    narrative_ko: str | None = Field(None, description="AI 생성 한국어 요약")
    has_narrative: bool = Field(..., description="AI 요약 포함 여부")
    drivers: list[DigestDriverResponse] = Field(..., description="상승 기여 종목 (최대 2)")
    detractors: list[DigestDriverResponse] = Field(..., description="하락 기여 종목 (최대 2)")
    sources_used: list[str] = Field(..., description="데이터 소스 목록")
    disclaimer: str = Field(
        default="이 내용은 투자 조언이 아닙니다. AI가 생성한 요약이며 투자 결정의 근거로 사용하지 마세요.",
        description="법적 면책 조항",
    )
    generated_at: str = Field(..., description="생성 시각(UTC)")
    degradation_level: int = Field(
        ...,
        description="저하 수준: 0=전체, 1=뉴스 없음, 2=내러티브 없음, 3=오류",
        examples=[0],
    )
    benchmark_7asset_return_pct: float | None = Field(
        None, description="7자산 균등배분 벤치마크 주간 수익률(%)"
    )
    benchmark_bond_return_pct: float | None = Field(
        None, description="채권 벤치마크 주간 수익률(%)"
    )
    baseline_volatility_pct: float | None = Field(
        None, description="최근 60개 5영업일 포트폴리오 수익률의 표준편차(%)"
    )
    trigger_threshold_pct: float | None = Field(
        None, description="다이제스트 노출 기준 수익률 절대값(%)"
    )
    trigger_sigma_multiple: float | None = Field(
        None, description="이번 주 수익률이 평소 5영업일 변동성의 몇 배인지"
    )
