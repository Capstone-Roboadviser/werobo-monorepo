from __future__ import annotations

import unittest

import pandas as pd

from app.domain.models import PortfolioComponentCandidate
from app.services.fixed_five_percent_role_return_service import FixedFivePercentRoleReturnService
from app.services.portfolio_service import PortfolioSimulationService


class FixedFivePercentRoleReturnServiceTests(unittest.TestCase):
    def test_conservative_expected_return_uses_capped_positive_spread(self) -> None:
        service = FixedFivePercentRoleReturnService()

        actual = service.conservative_expected_return()

        self.assertAlmostEqual(actual, 0.06564, places=9)

    def test_build_component_expected_returns_overrides_fixed_five_percent_role(self) -> None:
        service = PortfolioSimulationService.__new__(PortfolioSimulationService)
        service.fixed_five_percent_role_return_service = FixedFivePercentRoleReturnService()
        service.historical_stock_return_model = None
        service.component_service = type(
            "ComponentService",
            (),
            {
                "component_prior_weight_series": staticmethod(
                    lambda _selected_candidates: pd.Series(
                        {"new_growth": 0.05, "us_value": 0.95},
                        dtype=float,
                    )
                )
            },
        )()
        service.black_litterman_stock_return_model = type(
            "Model",
            (),
            {
                "calculate": staticmethod(
                    lambda *_args, **_kwargs: pd.Series(
                        {"new_growth": 0.18, "us_value": 0.08},
                        dtype=float,
                    )
                )
            },
        )()
        service._build_component_dividend_return_overlay = lambda *args, **kwargs: pd.Series(
            {"new_growth": 0.03, "us_value": 0.01},
            dtype=float,
        )

        selected_candidates = {
            "new_growth": PortfolioComponentCandidate(
                asset_code="new_growth",
                asset_name="신성장주",
                role_key="fixed_five_percent_equal_weight",
                selection_mode="all_members",
                weighting_mode="equal_weight_fixed_total_5pct",
                return_mode=FixedFivePercentRoleReturnService.RETURN_MODE,
                member_tickers=("AAA", "BBB"),
            ),
            "us_value": PortfolioComponentCandidate(
                asset_code="us_value",
                asset_name="미국 가치주",
                role_key="single_representative",
                selection_mode="single_representative",
                weighting_mode="single",
                return_mode="black_litterman_plus_dividend_yield",
                member_tickers=("VTV",),
            ),
        }

        actual = service._build_component_expected_returns(
            pd.DataFrame({"new_growth": [0.01] * 300, "us_value": [0.005] * 300}),
            selected_candidates,
            stock_returns=pd.DataFrame({"AAA": [0.01] * 300}),
        )

        self.assertAlmostEqual(
            float(actual.loc["new_growth"]),
            service.fixed_five_percent_role_return_service.conservative_expected_return(),
            places=9,
        )
        self.assertAlmostEqual(float(actual.loc["us_value"]), 0.09, places=9)

    def test_build_selected_stock_expected_returns_overrides_fixed_five_percent_role(self) -> None:
        service = PortfolioSimulationService.__new__(PortfolioSimulationService)
        service.fixed_five_percent_role_return_service = FixedFivePercentRoleReturnService()
        service.historical_stock_return_model = None
        service._build_stock_expected_returns = lambda _returns: pd.Series(
            {"AAA": 0.25, "BBB": 0.24, "VTV": 0.08},
            dtype=float,
        )
        service._build_stock_dividend_return_overlay = lambda *_args, **_kwargs: pd.Series(
            {"AAA": 0.04, "BBB": 0.04, "VTV": 0.01},
            dtype=float,
        )

        selected_candidates = {
            "new_growth": PortfolioComponentCandidate(
                asset_code="new_growth",
                asset_name="신성장주",
                role_key="fixed_five_percent_equal_weight",
                selection_mode="all_members",
                weighting_mode="equal_weight_fixed_total_5pct",
                return_mode=FixedFivePercentRoleReturnService.RETURN_MODE,
                member_tickers=("AAA", "BBB"),
            ),
            "us_value": PortfolioComponentCandidate(
                asset_code="us_value",
                asset_name="미국 가치주",
                role_key="single_representative",
                selection_mode="single_representative",
                weighting_mode="single",
                return_mode="black_litterman_plus_dividend_yield",
                member_tickers=("VTV",),
            ),
        }

        actual = service._build_selected_stock_expected_returns(
            pd.DataFrame({"AAA": [0.01] * 300, "BBB": [0.01] * 300, "VTV": [0.005] * 300}),
            selected_candidates,
        )

        conservative_return = service.fixed_five_percent_role_return_service.conservative_expected_return()
        self.assertAlmostEqual(float(actual.loc["AAA"]), conservative_return, places=9)
        self.assertAlmostEqual(float(actual.loc["BBB"]), conservative_return, places=9)
        self.assertAlmostEqual(float(actual.loc["VTV"]), 0.09, places=9)


if __name__ == "__main__":
    unittest.main()
