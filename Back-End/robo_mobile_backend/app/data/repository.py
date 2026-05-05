from __future__ import annotations

import json

import numpy as np
import pandas as pd

from app.core.config import ASSET_ROLE_TEMPLATES_PATH, ASSET_UNIVERSE_PATH, SAMPLE_MARKET_ASSUMPTIONS_PATH
from app.domain.models import AssetClass, AssetRoleTemplate, MarketAssumptions


class StaticDataRepository:
    """Loads fixed demo data from local JSON files."""

    def __init__(self) -> None:
        self._asset_universe: list[AssetClass] | None = None
        self._asset_role_templates: dict[str, AssetRoleTemplate] | None = None
        self._market_assumptions: MarketAssumptions | None = None
        self._sample_returns: pd.DataFrame | None = None

    def load_asset_role_templates(self) -> dict[str, AssetRoleTemplate]:
        if self._asset_role_templates is None:
            payload = json.loads(ASSET_ROLE_TEMPLATES_PATH.read_text())
            templates = [AssetRoleTemplate(**item) for item in payload]
            self._asset_role_templates = {item.key: item for item in templates}
        return self._asset_role_templates

    def load_asset_universe(self, role_overrides: dict[str, str] | None = None) -> list[AssetClass]:
        if role_overrides:
            return self._build_asset_universe(role_overrides=role_overrides)

        if self._asset_universe is None:
            self._asset_universe = self._build_asset_universe()
        return self._asset_universe

    def _build_asset_universe(self, role_overrides: dict[str, str] | None = None) -> list[AssetClass]:
        role_templates = self.load_asset_role_templates()
        payload = json.loads(ASSET_UNIVERSE_PATH.read_text())
        assets: list[AssetClass] = []
        for item in payload:
            asset_code = str(item["code"])
            role_key = str(role_overrides.get(asset_code, item.get("role_key", "single_representative"))) if role_overrides else str(item.get("role_key", "single_representative"))
            role = role_templates.get(role_key)
            if role is None:
                raise RuntimeError(f"자산군 '{item.get('code', 'unknown')}'의 role_key '{role_key}'를 찾을 수 없습니다.")
            assets.append(
                AssetClass(
                    code=asset_code,
                    name=item["name"],
                    category=item["category"],
                    description=item["description"],
                    color=item["color"],
                    min_weight=float(item["min_weight"]),
                    max_weight=float(item["max_weight"]),
                    role_key=role.key,
                    role_name=role.name,
                    role_description=role.description,
                    selection_mode=role.selection_mode,
                    weighting_mode=role.weighting_mode,
                    return_mode=role.return_mode,
                )
            )
        return assets

    def load_market_assumptions(self) -> MarketAssumptions:
        if self._market_assumptions is None:
            payload = json.loads(SAMPLE_MARKET_ASSUMPTIONS_PATH.read_text())
            self._market_assumptions = MarketAssumptions(**payload)
        return self._market_assumptions

    def load_sample_returns(self) -> pd.DataFrame:
        if self._sample_returns is None:
            assumptions = self.load_market_assumptions()
            assets = self.load_asset_universe()
            asset_codes = [asset.code for asset in assets]

            annual_returns = pd.Series(assumptions.annual_returns, dtype=float).reindex(asset_codes)
            annual_volatilities = pd.Series(assumptions.annual_volatilities, dtype=float).reindex(asset_codes)
            correlations = pd.DataFrame(assumptions.correlations, dtype=float).reindex(index=asset_codes, columns=asset_codes)

            if annual_returns.isna().any() or annual_volatilities.isna().any() or correlations.isna().any().any():
                raise RuntimeError("샘플 시장 가정 데이터가 자산군 정의와 일치하지 않습니다.")

            trading_days = 252 * assumptions.years
            dates = pd.bdate_range(end=pd.Timestamp.today().normalize(), periods=trading_days)
            daily_means = annual_returns / 252
            daily_vols = annual_volatilities / np.sqrt(252)
            covariance = np.outer(daily_vols, daily_vols) * correlations.values

            rng = np.random.default_rng(assumptions.seed)
            returns = rng.multivariate_normal(mean=daily_means.values, cov=covariance, size=trading_days)
            returns_df = pd.DataFrame(returns, index=dates, columns=asset_codes).clip(lower=-0.08, upper=0.08)
            self._sample_returns = returns_df.astype(float)

        return self._sample_returns.copy()
