"""Portfolio digest service: attribution engine + LLM narrative generation."""
from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timedelta, timezone

import pandas as pd

from app.core.config import DEMO_STOCK_PRICES_PATH, RISK_FREE_RATE
from app.data.managed_universe_repository import ManagedUniverseRepository
from app.data.stock_repository import StockDataRepository
from mobile_backend.data.account_repository import PortfolioAccountRepository
from mobile_backend.data.digest_repository import DigestRepository
from mobile_backend.domain.enums import SimulationDataSource
from mobile_backend.services.news_aggregator import (
    fetch_news_for_tickers,
    get_sources_used,
)

logger = logging.getLogger(__name__)

DIGEST_PERIOD_DAYS = 7
TOP_N = 2
DIGEST_THRESHOLD_PCT = 5.0


class DigestError(Exception):
    pass


class InsufficientDataError(DigestError):
    pass


# ---------------------------------------------------------------------------
# Attribution engine (deterministic math)
# ---------------------------------------------------------------------------

def compute_attribution(
    stock_allocations: list[dict],
    prices_by_ticker: dict[str, dict[str, float]],
    portfolio_value: float,
    period_days: int = DIGEST_PERIOD_DAYS,
) -> list[dict]:
    """Compute Brinson-style return attribution for each ticker.

    Args:
        stock_allocations: list of {ticker, name, sector_code, sector_name, weight}
        prices_by_ticker: {ticker: {date_str: price}} with at least start and end dates
        portfolio_value: portfolio value at start of period (won)
        period_days: lookback period in days

    Returns:
        list of attribution dicts sorted by contribution_won descending.
    """
    attributions = []
    for alloc in stock_allocations:
        ticker = alloc.get("ticker", "")
        weight = float(alloc.get("weight", 0))
        name = alloc.get("name", ticker)
        sector_code = alloc.get("sector_code", "")
        sector_name = alloc.get("sector_name", "")

        prices = prices_by_ticker.get(ticker)
        if not prices:
            continue

        sorted_dates = sorted(prices.keys())
        if len(sorted_dates) < 2:
            continue

        price_end = prices[sorted_dates[-1]]
        price_start = prices[sorted_dates[0]]
        if price_start <= 0:
            continue

        ticker_return = (price_end / price_start) - 1
        contribution_won = weight * ticker_return * portfolio_value

        attributions.append({
            "ticker": ticker,
            "name_ko": sector_name or name,
            "sector_code": sector_code,
            "weight_pct": round(weight * 100, 1),
            "return_pct": round(ticker_return * 100, 2),
            "contribution_won": round(contribution_won),
        })

    attributions.sort(key=lambda x: x["contribution_won"], reverse=True)
    return attributions


def top_drivers_detractors(
    attributions: list[dict],
    n: int = TOP_N,
) -> tuple[list[dict], list[dict]]:
    drivers = [a for a in attributions if a["contribution_won"] > 0][:n]
    detractors = [a for a in attributions if a["contribution_won"] < 0]
    detractors.sort(key=lambda x: x["contribution_won"])
    return drivers, detractors[:n]


# ---------------------------------------------------------------------------
# Benchmark returns
# ---------------------------------------------------------------------------

def _compute_benchmark_returns(
    universe_repo: ManagedUniverseRepository,
    start_date: str,
    end_date: str,
) -> tuple[float | None, float | None]:
    """Compute 7-asset equal-weight benchmark and bond returns for period."""
    try:
        days = (datetime.fromisoformat(end_date) - datetime.fromisoformat(start_date)).days
        bond_return_pct = round(RISK_FREE_RATE * (days / 365.25) * 100, 4)

        instruments = universe_repo.get_active_instruments()
        if not instruments:
            return None, bond_return_pct

        sectors: dict[str, list[str]] = {}
        all_tickers: list[str] = []
        for inst in instruments:
            code = getattr(inst, "sector_code", "")
            ticker = getattr(inst, "ticker", "")
            if code and ticker:
                sectors.setdefault(code, []).append(ticker)
                all_tickers.append(ticker)

        if not sectors or not all_tickers:
            return None, bond_return_pct

        prices_df = universe_repo.load_prices_for_tickers(
            tickers=all_tickers,
            start_date=start_date,
            end_date=end_date,
        )
        if prices_df is None or prices_df.empty:
            return None, bond_return_pct

        prices_by_ticker: dict[str, dict[str, float]] = {}
        for _, row in prices_df.iterrows():
            ticker = str(row.get("ticker", ""))
            date_str = str(row.get("date", ""))
            price = float(row.get("adjusted_close", 0))
            if ticker not in prices_by_ticker:
                prices_by_ticker[ticker] = {}
            prices_by_ticker[ticker][date_str] = price

        sector_returns: list[float] = []
        for _sector_code, tickers in sectors.items():
            ticker_returns: list[float] = []
            for ticker in tickers:
                prices = prices_by_ticker.get(ticker)
                if not prices:
                    continue
                sorted_dates = sorted(prices.keys())
                if len(sorted_dates) < 2:
                    continue
                p_start = prices[sorted_dates[0]]
                p_end = prices[sorted_dates[-1]]
                if p_start > 0:
                    ticker_returns.append((p_end / p_start) - 1)

            if ticker_returns:
                sector_returns.append(
                    sum(ticker_returns) / len(ticker_returns)
                )

        if not sector_returns:
            return None, bond_return_pct

        seven_asset_pct = round(
            sum(sector_returns) / len(sector_returns) * 100, 2
        )
        return seven_asset_pct, bond_return_pct

    except Exception:
        logger.warning("Benchmark computation failed", exc_info=True)
        return None, None


# ---------------------------------------------------------------------------
# LLM synthesis (Gemini Flash)
# ---------------------------------------------------------------------------

GEMINI_MODEL = "gemini-2.5-flash"
LLM_TIMEOUT_SECONDS = 30

SYSTEM_PROMPT = """\
You are a Korean financial summary writer for a robo-advisor app called WeRobo.
Your job is to explain portfolio performance to young Korean investors in plain language.

Rules:
- Write in Korean (한국어)
- Never recommend buying, selling, or holding any investment
- Only state facts supported by the data provided
- Frame normal market fluctuations as "정상적인 변동 범위"
- If a rebalance was triggered, mention it
- Keep the tone calm and reassuring, like a patient financial advisor
- Use the investor's actual won amounts to make it personal
"""


def _build_user_prompt(
    total_return_pct: float,
    total_return_won: float,
    portfolio_type: str,
    drivers: list[dict],
    detractors: list[dict],
    news: dict[str, list[str]],
    rebalance_triggered: bool = False,
) -> str:
    lines = [
        f"총 수익률: {total_return_pct:.1f}% ({total_return_won:+,.0f}원)",
        f"포트폴리오 유형: {portfolio_type}",
        "",
        "상승 기여 종목:",
    ]
    for d in drivers:
        lines.append(
            f"  - {d['ticker']} ({d['name_ko']}): 비중 {d['weight_pct']}%, "
            f"수익률 {d['return_pct']:+.1f}%, 기여 {d['contribution_won']:+,}원"
        )
    lines.append("")
    lines.append("하락 기여 종목:")
    for d in detractors:
        lines.append(
            f"  - {d['ticker']} ({d['name_ko']}): 비중 {d['weight_pct']}%, "
            f"수익률 {d['return_pct']:+.1f}%, 기여 {d['contribution_won']:+,}원"
        )

    if news:
        lines.append("")
        lines.append("관련 뉴스:")
        for ticker, headlines in news.items():
            for h in headlines[:2]:
                lines.append(f"  - [{ticker}] {h}")

    if rebalance_triggered:
        lines.append("")
        lines.append("이번 주에 리밸런싱이 실행되었습니다.")

    lines.append("")
    lines.append(
        "위 데이터를 바탕으로:\n"
        "1. 요약 문단 (3~5문장): 주간 성과를 설명하고, 상위 상승/하락 종목을 원화 금액과 "
        "함께 언급하며, 관련 뉴스 맥락을 포함하고, 정상 변동인지 평가해주세요.\n"
        "2. 각 상승/하락 기여 종목에 대해 2~3문장의 한국어 설명을 작성해주세요."
    )
    lines.append("")
    lines.append(
        'JSON으로 응답해주세요: {"narrative_ko": "...", "explanations": {"TICKER": "...", ...}}'
    )
    return "\n".join(lines)


def generate_narrative(
    total_return_pct: float,
    total_return_won: float,
    portfolio_type: str,
    drivers: list[dict],
    detractors: list[dict],
    news: dict[str, list[str]],
    rebalance_triggered: bool = False,
) -> dict[str, str] | None:
    """Call Gemini Flash to generate Korean narrative + per-ticker explanations.

    Returns {"narrative_ko": "...", "explanations": {"TICKER": "..."}} or None on failure.
    """
    api_key = os.environ.get("GOOGLE_API_KEY", "")
    if not api_key:
        logger.warning("GOOGLE_API_KEY not set, skipping LLM narrative")
        return None

    try:
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            GEMINI_MODEL,
            system_instruction=SYSTEM_PROMPT,
        )

        user_prompt = _build_user_prompt(
            total_return_pct=total_return_pct,
            total_return_won=total_return_won,
            portfolio_type=portfolio_type,
            drivers=drivers,
            detractors=detractors,
            news=news,
            rebalance_triggered=rebalance_triggered,
        )

        response = model.generate_content(
            user_prompt,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                temperature=0.3,
            ),
            request_options={"timeout": LLM_TIMEOUT_SECONDS},
        )

        if not response.candidates:
            logger.error(
                "Gemini returned no candidates (safety block or empty response)"
            )
            return None

        text = response.text.strip()
        logger.info("Gemini raw response: %s", text[:500])
        return json.loads(text)
    except json.JSONDecodeError:
        logger.error(
            "Gemini returned non-JSON response", exc_info=True
        )
        return None
    except ValueError:
        logger.error(
            "Gemini response.text access failed (no valid parts)",
            exc_info=True,
        )
        return None
    except Exception:
        logger.error("Gemini narrative generation failed", exc_info=True)
        return None


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

class DigestService:
    def __init__(self) -> None:
        self.account_repo = PortfolioAccountRepository()
        self.universe_repo = ManagedUniverseRepository()
        self.digest_repo = DigestRepository()

    def initialize_storage(self) -> None:
        self.digest_repo.initialize()

    def _load_digest_prices(
        self,
        *,
        account: dict,
        tickers: list[str],
        start_date: str,
        end_date: str,
    ) -> pd.DataFrame:
        data_source_value = str(
            account.get("data_source") or SimulationDataSource.MANAGED_UNIVERSE.value
        )
        try:
            data_source = SimulationDataSource(data_source_value)
        except ValueError:
            data_source = SimulationDataSource.MANAGED_UNIVERSE

        if data_source == SimulationDataSource.STOCK_COMBINATION_DEMO:
            prices_df = StockDataRepository().load_stock_prices(str(DEMO_STOCK_PRICES_PATH)).copy()
            prices_df["ticker"] = prices_df["ticker"].astype(str).str.strip().str.upper()
            prices_df["date"] = pd.to_datetime(prices_df["date"], errors="coerce").dt.normalize()
            prices_df["adjusted_close"] = pd.to_numeric(
                prices_df["adjusted_close"],
                errors="coerce",
            )
            start_ts = pd.Timestamp(start_date).normalize()
            end_ts = pd.Timestamp(end_date).normalize()
            prices_df = prices_df[
                prices_df["ticker"].isin(sorted({str(ticker).strip().upper() for ticker in tickers if ticker}))
            ]
            prices_df = prices_df[
                (prices_df["date"] >= start_ts)
                & (prices_df["date"] <= end_ts)
            ]
            return prices_df.dropna(subset=["date", "ticker", "adjusted_close"])[
                ["date", "ticker", "adjusted_close"]
            ]

        return self.universe_repo.load_prices_for_tickers(
            tickers=tickers,
            start_date=start_date,
            end_date=end_date,
        )

    def generate(self, account: dict) -> dict:
        """Generate or return cached digest for an account.

        Returns a dict matching DigestResponse schema.
        Raises InsufficientDataError if not enough data.
        """
        account_id = int(account["id"])

        # Check cache (with read-time rebalance bust)
        cached = self.digest_repo.get_cached(account_id)
        if cached is not None:
            if cached.get("has_narrative"):
                logger.info("digest.cache.hit account_id=%s", account_id)
                return cached
            logger.info(
                "digest.cache.degraded account_id=%s, regenerating",
                account_id,
            )

        logger.info("digest.cache.miss account_id=%s", account_id)

        # Get allocations
        stock_allocations = account.get("stock_allocations") or []
        if not stock_allocations:
            raise InsufficientDataError("포트폴리오에 종목이 없습니다.")

        # Get portfolio value from latest snapshot
        snapshots = self.account_repo.list_snapshots(account_id)
        if not snapshots:
            raise InsufficientDataError("아직 충분한 데이터가 없습니다.")

        latest_snapshot = snapshots[-1]
        portfolio_value = float(latest_snapshot.get("portfolio_value", 0))

        # Compute date range
        end_date = datetime.now(timezone.utc).date()
        start_date = end_date - timedelta(days=DIGEST_PERIOD_DAYS)

        # Load prices
        tickers = [a["ticker"] for a in stock_allocations]
        prices_df = self._load_digest_prices(
            account=account,
            tickers=tickers,
            start_date=start_date.isoformat(),
            end_date=end_date.isoformat(),
        )

        if prices_df is None or prices_df.empty:
            raise InsufficientDataError("아직 충분한 데이터가 없습니다.")

        # Build prices_by_ticker: {ticker: {date_str: price}}
        prices_by_ticker: dict[str, dict[str, float]] = {}
        for _, row in prices_df.iterrows():
            ticker = str(row.get("ticker", ""))
            date_str = str(row.get("date", ""))
            price = float(row.get("adjusted_close", 0))
            if ticker not in prices_by_ticker:
                prices_by_ticker[ticker] = {}
            prices_by_ticker[ticker][date_str] = price

        # Attribution
        attributions = compute_attribution(
            stock_allocations=stock_allocations,
            prices_by_ticker=prices_by_ticker,
            portfolio_value=portfolio_value,
        )

        if not attributions:
            raise InsufficientDataError("수익률 데이터가 부족합니다.")

        total_return_won = sum(a["contribution_won"] for a in attributions)
        total_weight = sum(float(a.get("weight", 0)) for a in stock_allocations)
        total_return_pct = round(
            (total_return_won / portfolio_value * 100) if portfolio_value > 0 else 0,
            2,
        )

        drivers, detractors = top_drivers_detractors(attributions)

        # Threshold gate: only surface a digest for ±5% moves.
        if abs(total_return_pct) < DIGEST_THRESHOLD_PCT:
            now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            unavailable = {
                "digest_date": end_date.isoformat(),
                "period_start": start_date.isoformat(),
                "period_end": end_date.isoformat(),
                "total_return_pct": total_return_pct,
                "total_return_won": total_return_won,
                "available": False,
                "narrative_ko": None,
                "has_narrative": False,
                "drivers": [],
                "detractors": [],
                "sources_used": [],
                "disclaimer": "이 내용은 투자 조언이 아닙니다. AI가 생성한 요약이며 투자 결정의 근거로 사용하지 마세요.",
                "generated_at": now_utc,
                "degradation_level": 0,
                "benchmark_7asset_return_pct": None,
                "benchmark_bond_return_pct": None,
            }
            self.digest_repo.cache(account_id, unavailable)
            logger.info(
                "digest.generate.below_threshold account_id=%s total_return_pct=%s",
                account_id,
                total_return_pct,
            )
            return unavailable

        # Benchmark returns
        benchmark_7asset, benchmark_bond = _compute_benchmark_returns(
            universe_repo=self.universe_repo,
            start_date=start_date.isoformat(),
            end_date=end_date.isoformat(),
        )

        # Fetch news (parallel, 3s timeout per source)
        driver_tickers = [d["ticker"] for d in drivers]
        detractor_tickers = [d["ticker"] for d in detractors]
        all_tickers = driver_tickers + detractor_tickers
        news = fetch_news_for_tickers(all_tickers)
        sources_used = get_sources_used(news)

        # LLM narrative
        portfolio_type = account.get("portfolio_label", "균형형")
        llm_result = generate_narrative(
            total_return_pct=total_return_pct,
            total_return_won=total_return_won,
            portfolio_type=portfolio_type,
            drivers=drivers,
            detractors=detractors,
            news=news,
        )

        narrative_ko = None
        explanations = {}
        degradation_level = 0

        if llm_result is None:
            degradation_level = 2  # LLM failed
        else:
            narrative_ko = llm_result.get("narrative_ko")
            explanations = llm_result.get("explanations", {})
            if not news:
                degradation_level = 1  # News failed

        # Attach explanations to drivers/detractors
        for item in drivers + detractors:
            item["explanation_ko"] = explanations.get(item["ticker"])

        now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        digest = {
            "digest_date": end_date.isoformat(),
            "available": True,
            "period_start": start_date.isoformat(),
            "period_end": end_date.isoformat(),
            "total_return_pct": total_return_pct,
            "total_return_won": total_return_won,
            "narrative_ko": narrative_ko,
            "has_narrative": narrative_ko is not None,
            "drivers": drivers,
            "detractors": detractors,
            "sources_used": sources_used,
            "disclaimer": "이 내용은 투자 조언이 아닙니다. AI가 생성한 요약이며 투자 결정의 근거로 사용하지 마세요.",
            "generated_at": now_utc,
            "degradation_level": degradation_level,
            "benchmark_7asset_return_pct": benchmark_7asset,
            "benchmark_bond_return_pct": benchmark_bond,
        }

        # Cache the result
        self.digest_repo.cache(account_id, digest)
        logger.info(
            "digest.generate.end account_id=%s degradation_level=%s",
            account_id,
            degradation_level,
        )
        return digest
