from __future__ import annotations

import unittest

import pandas as pd

from app.domain.models import ExpectedReturnModelInput
from app.engine.returns import BlackLittermanReturnModel


class ExpectedReturnModelTests(unittest.TestCase):
    def test_black_litterman_model_returns_total_expected_return(self) -> None:
        returns = pd.DataFrame(
            {
                "AAA": [0.010, -0.012, 0.011, -0.008] * 63,
                "BBB": [0.013, -0.009, 0.009, -0.006] * 63,
            }
        )
        prior_weights = pd.Series({"AAA": 0.6, "BBB": 0.4}, dtype=float)
        model = BlackLittermanReturnModel(
            periods_per_year=252,
            min_obs=10,
            risk_aversion=2.5,
            risk_free_rate=0.02,
        )

        actual = model.calculate(
            ExpectedReturnModelInput(
                asset_codes=["AAA", "BBB"],
                returns=returns,
                prior_weights=prior_weights,
            )
        )

        covariance = returns.cov() * 252
        expected = 0.02 + 2.5 * (covariance.values @ (prior_weights / prior_weights.sum()).values)

        self.assertAlmostEqual(float(actual.loc["AAA"]), float(expected[0]), places=9)
        self.assertAlmostEqual(float(actual.loc["BBB"]), float(expected[1]), places=9)


if __name__ == "__main__":
    unittest.main()
