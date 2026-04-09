from __future__ import annotations

from types import SimpleNamespace
import unittest

from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from mobile_backend.integrations.legacy_fastapi_demo import LegacyFastapiDemoAdapter


def _make_adapter_with_fakes() -> tuple[LegacyFastapiDemoAdapter, dict]:
    """Create an adapter with all internal methods faked out."""
    adapter = LegacyFastapiDemoAdapter.__new__(LegacyFastapiDemoAdapter)
    state: dict = {"build_context_calls": 0}

    target_volatility_by_profile = {
        RiskProfile.CONSERVATIVE: 0.08,
        RiskProfile.BALANCED: 0.12,
        RiskProfile.GROWTH: 0.16,
    }

    frontier_points = [
        SimpleNamespace(
            volatility=0.06,
            expected_return=0.045,
            weights={"VTV": 0.15, "VUG": 0.05, "BND": 0.80},
        ),
        SimpleNamespace(
            volatility=0.08,
            expected_return=0.055,
            weights={"VTV": 0.25, "VUG": 0.10, "BND": 0.65},
        ),
        SimpleNamespace(
            volatility=0.10,
            expected_return=0.065,
            weights={"VTV": 0.30, "VUG": 0.20, "BND": 0.50},
        ),
        SimpleNamespace(
            volatility=0.12,
            expected_return=0.075,
            weights={"VTV": 0.35, "VUG": 0.30, "BND": 0.35},
        ),
        SimpleNamespace(
            volatility=0.14,
            expected_return=0.085,
            weights={"VTV": 0.30, "VUG": 0.45, "BND": 0.25},
        ),
        SimpleNamespace(
            volatility=0.16,
            expected_return=0.095,
            weights={"VTV": 0.30, "VUG": 0.55, "BND": 0.15},
        ),
    ]

    fake_context = SimpleNamespace(
        assets=[
            SimpleNamespace(code="us_value", name="미국 가치주"),
            SimpleNamespace(code="us_growth", name="미국 성장주"),
            SimpleNamespace(code="short_term_bond", name="단기 채권"),
        ],
        instruments=[
            SimpleNamespace(ticker="VTV", name="Vanguard Value ETF", sector_code="us_value", sector_name="미국 가치주"),
            SimpleNamespace(ticker="VUG", name="Vanguard Growth ETF", sector_code="us_growth", sector_name="미국 성장주"),
            SimpleNamespace(ticker="BND", name="Vanguard Total Bond Market ETF", sector_code="short_term_bond", sector_name="단기 채권"),
        ],
        expected_returns=None,
        covariance=None,
        frontier_points=frontier_points,
        selected_combination=None,
    )

    def fake_build_context(*, investment_horizon, data_source):
        state["build_context_calls"] += 1
        return fake_context

    def fake_build_legacy_user_profile(*, risk_profile, investment_horizon, data_source):
        return SimpleNamespace(risk_profile=risk_profile, investment_horizon=investment_horizon, data_source=data_source)

    def fake_portfolio_metrics_from_weights(weights, expected_returns, covariance, risk_free_rate):
        return SimpleNamespace(
            expected_return=0.07 + max(weights.values()) * 0.01,
            volatility=max(weights.values()),
            sharpe_ratio=1.0,
        )

    def fake_build_sector_allocations(*, stock_weights, sector_risk_contributions, assets, instruments):
        allocations = []
        for asset in assets:
            matching_tickers = [inst.ticker for inst in instruments if inst.sector_code == asset.code]
            weight = sum(stock_weights.get(ticker, 0.0) for ticker in matching_tickers)
            if weight <= 0:
                continue
            allocations.append(
                SimpleNamespace(
                    asset_code=asset.code,
                    asset_name=asset.name,
                    weight=weight,
                    risk_contribution=sum(sector_risk_contributions.get(ticker, 0.0) for ticker in matching_tickers),
                )
            )
        return allocations

    from app.engine.frontier import build_frontier_options, select_frontier_point_by_return

    adapter._build_context = fake_build_context
    adapter._build_legacy_user_profile = fake_build_legacy_user_profile
    adapter.portfolio_metrics_from_weights = fake_portfolio_metrics_from_weights
    adapter.risk_contributions = lambda weights, covariance: dict(weights)
    adapter.RISK_FREE_RATE = 0.02
    adapter.build_frontier_options = build_frontier_options
    adapter.select_frontier_point_by_return = select_frontier_point_by_return
    adapter.portfolio_service = SimpleNamespace(
        mapping_service=SimpleNamespace(
            resolve_target_volatility=lambda profile: target_volatility_by_profile.get(profile.risk_profile, 0.12),
            build_portfolio_id=lambda profile, target_volatility: f"{profile.risk_profile.value}-{int(target_volatility * 100)}",
        ),
        _weights_for_optimization=lambda weights, instruments: dict(weights),
        _build_sector_allocations=fake_build_sector_allocations,
    )

    return adapter, state


class LegacyFastapiDemoAdapterTests(unittest.TestCase):
    def test_build_recommendation_reuses_single_context(self) -> None:
        adapter, state = _make_adapter_with_fakes()

        response = adapter.build_recommendation(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
        )

        self.assertEqual(state["build_context_calls"], 1)
        self.assertEqual(response["recommended_portfolio_code"], "balanced")
        self.assertEqual(len(response["portfolios"]), 3)

    def test_build_recommendation_returns_variant_codes(self) -> None:
        adapter, _ = _make_adapter_with_fakes()

        response = adapter.build_recommendation(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
        )

        codes = [p["code"] for p in response["portfolios"]]
        self.assertEqual(codes, ["lower_return", "balanced", "higher_return"])

    def test_build_recommendation_includes_stock_weights(self) -> None:
        adapter, _ = _make_adapter_with_fakes()

        response = adapter.build_recommendation(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
        )

        for portfolio in response["portfolios"]:
            self.assertIn("stock_weights", portfolio)
            self.assertIsInstance(portfolio["stock_weights"], dict)

    def test_build_recommendation_variant_labels(self) -> None:
        adapter, _ = _make_adapter_with_fakes()

        response = adapter.build_recommendation(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
        )

        labels = [p["label"] for p in response["portfolios"]]
        self.assertEqual(labels[0], "낮은 수익률")
        self.assertEqual(labels[2], "높은 수익률")


if __name__ == "__main__":
    unittest.main()
