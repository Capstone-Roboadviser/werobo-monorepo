from __future__ import annotations

from types import SimpleNamespace
import unittest

from mobile_backend.domain.enums import InvestmentHorizon, RiskProfile, SimulationDataSource
from mobile_backend.integrations.embedded_portfolio_engine import EmbeddedPortfolioEngineAdapter


class EmbeddedPortfolioEngineAdapterTests(unittest.TestCase):
    def _build_fake_adapter(self) -> tuple[EmbeddedPortfolioEngineAdapter, SimpleNamespace]:
        adapter = EmbeddedPortfolioEngineAdapter.__new__(EmbeddedPortfolioEngineAdapter)
        fake_context = SimpleNamespace(
            assets=[
                SimpleNamespace(code="us_value", name="미국 가치주"),
                SimpleNamespace(code="us_growth", name="미국 성장주"),
                SimpleNamespace(code="short_term_bond", name="단기 채권"),
            ],
            instruments=[
                SimpleNamespace(
                    ticker="VTV",
                    name="Vanguard Value ETF",
                    sector_code="us_value",
                    sector_name="미국 가치주",
                ),
                SimpleNamespace(
                    ticker="VUG",
                    name="Vanguard Growth ETF",
                    sector_code="us_growth",
                    sector_name="미국 성장주",
                ),
                SimpleNamespace(
                    ticker="BND",
                    name="Vanguard Total Bond Market ETF",
                    sector_code="short_term_bond",
                    sector_name="단기 채권",
                ),
            ],
            expected_returns=None,
            covariance=None,
            frontier_points=[
                SimpleNamespace(
                    volatility=0.08,
                    expected_return=0.055,
                    weights={"VTV": 0.25, "VUG": 0.10, "BND": 0.65},
                ),
                SimpleNamespace(
                    volatility=0.12,
                    expected_return=0.075,
                    weights={"VTV": 0.35, "VUG": 0.30, "BND": 0.35},
                ),
                SimpleNamespace(
                    volatility=0.16,
                    expected_return=0.095,
                    weights={"VTV": 0.30, "VUG": 0.55, "BND": 0.15},
                ),
            ],
            selected_combination=None,
        )

        def fake_build_context(*, investment_horizon: InvestmentHorizon, data_source: SimulationDataSource):
            self.assertEqual(investment_horizon, InvestmentHorizon.MEDIUM)
            self.assertEqual(data_source, SimulationDataSource.STOCK_COMBINATION_DEMO)
            return fake_context

        def fake_build_core_user_profile(*, risk_profile: RiskProfile, investment_horizon: InvestmentHorizon, data_source: SimulationDataSource):
            return SimpleNamespace(
                risk_profile=risk_profile,
                investment_horizon=investment_horizon,
                data_source=data_source,
            )

        def fake_select_frontier_point_index(frontier_points, target_volatility: float) -> int:
            return min(
                range(len(frontier_points)),
                key=lambda idx: abs(frontier_points[idx].volatility - target_volatility),
            )

        def fake_portfolio_metrics_from_weights(weights, expected_returns, covariance, risk_free_rate):
            return SimpleNamespace(
                expected_return=0.07 + max(weights.values()) * 0.01,
                volatility=max(weights.values()),
                sharpe_ratio=1.0,
            )

        def fake_build_sector_allocations(*, stock_weights, sector_risk_contributions, assets, instruments):
            allocations = []
            for asset in assets:
                matching_tickers = [
                    instrument.ticker
                    for instrument in instruments
                    if instrument.sector_code == asset.code
                ]
                weight = sum(stock_weights.get(ticker, 0.0) for ticker in matching_tickers)
                if weight <= 0:
                    continue
                allocations.append(
                    SimpleNamespace(
                        asset_code=asset.code,
                        asset_name=asset.name,
                        weight=weight,
                        risk_contribution=sum(
                            sector_risk_contributions.get(ticker, 0.0)
                            for ticker in matching_tickers
                        ),
                    )
                )
            return allocations

        from app.engine.frontier import build_frontier_options

        adapter._build_context = fake_build_context
        adapter._build_core_user_profile = fake_build_core_user_profile
        adapter.build_frontier_options = build_frontier_options
        adapter.select_frontier_point_index = fake_select_frontier_point_index
        adapter.portfolio_metrics_from_weights = fake_portfolio_metrics_from_weights
        adapter.risk_contributions = lambda weights, covariance: dict(weights)
        adapter.RISK_FREE_RATE = 0.02
        adapter.portfolio_service = SimpleNamespace(
            mapping_service=SimpleNamespace(
                build_portfolio_id=lambda profile, target_volatility: (
                    f"{profile.risk_profile.value}-{int(target_volatility * 100)}"
                ),
            ),
            _weights_for_optimization=lambda weights, instruments: dict(weights),
            _build_sector_allocations=fake_build_sector_allocations,
        )
        return adapter, fake_context

    def test_build_recommendation_reuses_single_context(self) -> None:
        adapter, _ = self._build_fake_adapter()
        call_count = 0

        original_build_context = adapter._build_context

        def counting_build_context(*, investment_horizon: InvestmentHorizon, data_source: SimulationDataSource):
            nonlocal call_count
            call_count += 1
            return original_build_context(
                investment_horizon=investment_horizon,
                data_source=data_source,
            )

        adapter._build_context = counting_build_context

        response = adapter.build_recommendation(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
        )

        self.assertEqual(call_count, 1)
        self.assertEqual(response["recommended_portfolio_code"], "balanced")
        self.assertEqual(len(response["portfolios"]), 3)
        self.assertEqual(
            [portfolio["code"] for portfolio in response["portfolios"]],
            ["conservative", "balanced", "growth"],
        )
        self.assertEqual(
            [portfolio["target_volatility"] for portfolio in response["portfolios"]],
            [0.08, 0.12, 0.16],
        )

    def test_build_frontier_preview_keeps_representative_points(self) -> None:
        adapter, _ = self._build_fake_adapter()

        response = adapter.build_frontier_preview(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
            sample_points=3,
        )

        self.assertEqual(response["recommended_portfolio_code"], "balanced")
        self.assertEqual(response["total_point_count"], 3)
        self.assertEqual([point["index"] for point in response["points"]], [0, 1, 2])
        self.assertEqual(
            [point["representative_code"] for point in response["points"]],
            ["conservative", "balanced", "growth"],
        )
        self.assertEqual(
            [point["is_recommended"] for point in response["points"]],
            [False, True, False],
        )

    def test_build_frontier_selection_returns_selected_portfolio(self) -> None:
        adapter, _ = self._build_fake_adapter()

        response = adapter.build_frontier_selection(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=45.0,
            target_volatility=0.119,
        )

        self.assertEqual(response["selected_point_index"], 1)
        self.assertEqual(response["selected_target_volatility"], 0.12)
        self.assertEqual(response["representative_code"], "balanced")
        self.assertEqual(response["portfolio"]["code"], "selected")
        self.assertEqual(response["portfolio"]["label"], "선택 포트폴리오")


if __name__ == "__main__":
    unittest.main()
