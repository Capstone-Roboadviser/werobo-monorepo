from __future__ import annotations

from typing import Protocol

import numpy as np
import pandas as pd

from app.domain.models import ExpectedReturnModelInput


class ExpectedReturnModel(Protocol):
    def calculate(self, model_input: ExpectedReturnModelInput) -> pd.Series: ...


class AssumptionReturnModel:
    def calculate(self, model_input: ExpectedReturnModelInput) -> pd.Series:
        if model_input.annual_returns is None:
            raise RuntimeError("가정 기반 기대수익률 모델에는 annual_returns 입력이 필요합니다.")
        expected_returns = pd.Series(model_input.annual_returns, dtype=float).reindex(model_input.asset_codes)
        if expected_returns.isna().any():
            raise RuntimeError("샘플 시장 가정의 기대수익률이 자산군 정의와 일치하지 않습니다.")
        return expected_returns.astype(float)


class HistoricalMeanReturnModel:
    def __init__(self, shrinkage: float = 0.20) -> None:
        self.shrinkage = shrinkage

    def calculate(self, model_input: ExpectedReturnModelInput) -> pd.Series:
        if model_input.returns is None:
            raise RuntimeError("과거평균 기대수익률 모델에는 returns 입력이 필요합니다.")
        mean_returns = model_input.returns.mean() * 252
        grand_mean = float(mean_returns.mean())
        stabilized = (1 - self.shrinkage) * mean_returns + self.shrinkage * grand_mean
        return stabilized.reindex(model_input.asset_codes).astype(float)


class BlackLittermanReturnModel:
    """Market-implied prior expected return model adapted for role-based components.

    This implementation mirrors the project's practical usage:
    it annualizes covariance from realized returns and builds the Black-Litterman
    prior `Pi = delta * Sigma * w_prior`.

    In the current setup, no subjective views are applied.
    The posterior therefore equals the market-implied prior.
    """

    def __init__(
        self,
        *,
        periods_per_year: int = 252,
        min_obs: int = 252,
        risk_aversion: float = 2.5,
        risk_free_rate: float = 0.0,
        allow_equal_weight_fallback: bool = True,
    ) -> None:
        self.periods_per_year = periods_per_year
        self.min_obs = min_obs
        self.risk_aversion = risk_aversion
        self.risk_free_rate = risk_free_rate
        self.allow_equal_weight_fallback = allow_equal_weight_fallback

    def calculate(self, model_input: ExpectedReturnModelInput) -> pd.Series:
        if model_input.returns is None:
            raise RuntimeError("Black-Litterman 기대수익률 모델에는 returns 입력이 필요합니다.")

        returns = model_input.returns.copy()
        if returns.empty:
            raise RuntimeError("Black-Litterman 기대수익률 계산에 사용할 수익률 데이터가 비어 있습니다.")

        valid_counts = returns.notna().sum()
        eligible_cols = valid_counts[valid_counts >= self.min_obs].index.tolist()
        if len(eligible_cols) == 0:
            raise RuntimeError("Black-Litterman 기대수익률 계산에 필요한 최소 관측치를 만족하는 자산이 없습니다.")

        filtered_returns = returns[eligible_cols].copy().sort_index(axis=1)
        asset_codes = filtered_returns.columns.tolist()
        covariance = filtered_returns.cov() * self.periods_per_year
        covariance = covariance.reindex(index=asset_codes, columns=asset_codes).astype(float)

        prior_weights = self._resolve_prior_weights(
            model_input.prior_weights,
            asset_codes,
        )
        implied = float(self.risk_free_rate) + float(self.risk_aversion) * (
            covariance.values @ prior_weights.values
        )
        expected_returns = pd.Series(implied, index=asset_codes, name="expected_return")
        return expected_returns.reindex(model_input.asset_codes).astype(float)

    def _resolve_prior_weights(
        self,
        prior_weights: pd.Series | None,
        asset_codes: list[str],
    ) -> pd.Series:
        if prior_weights is not None:
            aligned = (
                pd.Series(prior_weights, dtype=float)
                .reindex(asset_codes)
                .fillna(0.0)
                .clip(lower=0.0)
            )
            total = float(aligned.sum())
            if total > 0:
                return (aligned / total).astype(float)

        if not self.allow_equal_weight_fallback:
            raise RuntimeError("Black-Litterman prior weights를 만들지 못했고 equal-weight fallback이 비활성화되어 있습니다.")

        return pd.Series(
            np.full(len(asset_codes), 1.0 / len(asset_codes), dtype=float),
            index=asset_codes,
            name="prior_weight",
        )
