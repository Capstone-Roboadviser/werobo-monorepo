from enum import Enum


class RiskProfile(str, Enum):
    CONSERVATIVE = "conservative"
    BALANCED = "balanced"
    GROWTH = "growth"


class InvestmentHorizon(str, Enum):
    SHORT = "short"
    MEDIUM = "medium"
    LONG = "long"


class SimulationDataSource(str, Enum):
    MANAGED_UNIVERSE = "managed_universe"
    ASSET_ASSUMPTIONS = "asset_assumptions"
    STOCK_COMBINATION_DEMO = "stock_combination_demo"


class PriceRefreshMode(str, Enum):
    INCREMENTAL = "incremental"
    FULL = "full"
