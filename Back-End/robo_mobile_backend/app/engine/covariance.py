from __future__ import annotations

import numpy as np
import pandas as pd


class ShrinkageCovarianceModel:
    def __init__(self, shrinkage: float = 0.20) -> None:
        self.shrinkage = shrinkage

    def calculate(self, returns: pd.DataFrame) -> pd.DataFrame:
        sample_covariance = returns.cov() * 252
        diagonal_covariance = pd.DataFrame(
            np.diag(np.diag(sample_covariance.values)),
            index=sample_covariance.index,
            columns=sample_covariance.columns,
        )
        stabilized = (1 - self.shrinkage) * sample_covariance + self.shrinkage * diagonal_covariance
        stabilized += np.eye(len(stabilized)) * 1e-6
        return stabilized.astype(float)
