import os
from pathlib import Path

from app.domain.enums import InvestmentHorizon, RiskProfile


BASE_DIR = Path(__file__).resolve().parents[1]
PROJECT_DIR = BASE_DIR.parent
DATA_DIR = BASE_DIR / "data"
ASSET_UNIVERSE_PATH = DATA_DIR / "asset_universe.json"
ASSET_ROLE_TEMPLATES_PATH = DATA_DIR / "asset_role_templates.json"
SAMPLE_MARKET_ASSUMPTIONS_PATH = DATA_DIR / "sample_market_assumptions.json"
DEMO_STOCK_DATA_DIR = DATA_DIR / "demo"
DEMO_STOCK_UNIVERSE_PATH = DEMO_STOCK_DATA_DIR / "demo_stock_universe.csv"
DEMO_STOCK_PRICES_PATH = DEMO_STOCK_DATA_DIR / "demo_stock_prices.csv"
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()

APP_NAME = "자산배분 시뮬레이터 데모 API"
APP_DESCRIPTION = (
    "관리자 입력 기반의 종목 유니버스를 기준으로, 사용자의 위험 성향과 투자기간에 따라 "
    "효율적 투자선 상의 포트폴리오 예시를 계산하고 설명해주는 시뮬레이션 서비스"
)
APP_VERSION = "0.4.0"

RISK_FREE_RATE = 0.02
BLACK_LITTERMAN_RISK_AVERSION = 2.5
FRONTIER_POINT_COUNT = 80
RANDOM_PORTFOLIO_COUNT = 12000
TARGET_VOLATILITY_MIN = 0.04
TARGET_VOLATILITY_MAX = 0.22
TARGET_VOLATILITY_STEP = 0.02
MINIMUM_HISTORY_ROWS = 252
STOCK_MIN_WEIGHT = 0.01
STOCK_MAX_WEIGHT = 0.30
MAX_PORTFOLIO_AVERAGE_CORRELATION = 0.25
SECTOR_MINIMUM_INSTRUMENTS = 1
REPRESENTATIVE_COMBINATION_SAMPLE_COUNT = 1000
REPRESENTATIVE_MAX_EXHAUSTIVE_COMBINATIONS = 5000
REPRESENTATIVE_COMBINATION_RANDOM_SEED = 23
DEMO_COMBINATION_SAMPLE_COUNT = 40
DEMO_COMBINATION_WEIGHTING = "equal"
DEMO_COMBINATION_USE_ALL_INSTRUMENTS = True
DEMO_COMBINATION_SELECTION_SIZES = {
    "us_value": 2,
    "us_growth": 2,
    "new_growth": 2,
    "short_term_bond": 2,
    "cash_equivalents": 2,
    "gold": 2,
    "infra_bond": 2,
}

DEFAULT_TARGET_VOLATILITY = {
    RiskProfile.CONSERVATIVE: 0.08,
    RiskProfile.BALANCED: 0.12,
    RiskProfile.GROWTH: 0.16,
}

HORIZON_VOLATILITY_ADJUSTMENT = {
    InvestmentHorizon.SHORT: -0.02,
    InvestmentHorizon.MEDIUM: 0.00,
    InvestmentHorizon.LONG: 0.02,
}

FALLBACK_WEIGHTS = {
    RiskProfile.CONSERVATIVE: {
        "us_value": 0.15,
        "us_growth": 0.08,
        "new_growth": 0.10,
        "short_term_bond": 0.25,
        "cash_equivalents": 0.20,
        "gold": 0.08,
        "infra_bond": 0.14,
    },
    RiskProfile.BALANCED: {
        "us_value": 0.20,
        "us_growth": 0.15,
        "new_growth": 0.20,
        "short_term_bond": 0.15,
        "cash_equivalents": 0.10,
        "gold": 0.08,
        "infra_bond": 0.12,
    },
    RiskProfile.GROWTH: {
        "us_value": 0.18,
        "us_growth": 0.22,
        "new_growth": 0.33,
        "short_term_bond": 0.08,
        "cash_equivalents": 0.05,
        "gold": 0.06,
        "infra_bond": 0.08,
    },
}

DISCLAIMER_TEXT = (
    "본 결과는 샘플 데이터 기반의 데모용 자산배분 시뮬레이션이며, "
    "시장 예측이나 투자 자문을 제공하지 않습니다."
)
