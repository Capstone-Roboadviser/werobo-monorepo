from __future__ import annotations

from types import SimpleNamespace
import unittest

from app.domain.models import PortfolioHistoryPoint, PortfolioHistorySeries
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
            weights_for_optimization=lambda weights, instruments: dict(weights),
            aggregate_sector_risk_contributions=lambda contributions, instruments: {
                "us_value": contributions.get("VTV", 0.0),
                "us_growth": contributions.get("VUG", 0.0),
                "short_term_bond": contributions.get("BND", 0.0),
            },
            build_sector_allocations=fake_build_sector_allocations,
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

    def test_build_recommendation_uses_materialized_snapshot_when_available(self) -> None:
        adapter, _ = self._build_fake_adapter()
        snapshot_payload = adapter.build_materialized_frontier_snapshot(
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        )
        adapter._get_managed_universe_snapshot_payload = lambda **kwargs: snapshot_payload
        adapter._build_context = lambda **kwargs: self.fail("snapshot hit should skip context rebuild")

        response = adapter.build_recommendation(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            propensity_score=45.0,
        )

        self.assertEqual(response["recommended_portfolio_code"], "balanced")
        self.assertEqual(
            [portfolio["code"] for portfolio in response["portfolios"]],
            ["conservative", "balanced", "growth"],
        )

    def test_build_frontier_selection_uses_materialized_snapshot_when_available(self) -> None:
        adapter, _ = self._build_fake_adapter()
        snapshot_payload = adapter.build_materialized_frontier_snapshot(
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        )
        adapter._get_managed_universe_snapshot_payload = lambda **kwargs: snapshot_payload
        adapter._build_context = lambda **kwargs: self.fail("snapshot hit should skip context rebuild")

        response = adapter.build_frontier_selection(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.MANAGED_UNIVERSE,
            propensity_score=45.0,
            target_volatility=0.119,
        )

        self.assertEqual(response["selected_point_index"], 1)
        self.assertEqual(response["representative_code"], "balanced")
        self.assertEqual(response["portfolio"]["code"], "selected")

    def test_get_volatility_history_uses_analytics_service(self) -> None:
        adapter = EmbeddedPortfolioEngineAdapter.__new__(EmbeddedPortfolioEngineAdapter)
        adapter._build_context_bundle = lambda **kwargs: (SimpleNamespace(), {})
        adapter._build_portfolio_snapshot_from_context = lambda **kwargs: {
            "stock_weights": {"VTV": 0.6, "BND": 0.4},
        }
        adapter._to_core_data_source = lambda value: value
        adapter.portfolio_analytics_service = SimpleNamespace(
            build_volatility_history=lambda **kwargs: PortfolioHistorySeries(
                points=[PortfolioHistoryPoint(date="2026-04-01", value=0.123456)],
                earliest_data_date="2020-01-02",
                latest_data_date="2026-04-01",
            )
        )

        response = adapter.get_volatility_history(
            risk_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            rolling_window=20,
        )

        self.assertEqual(response["portfolio_code"], "balanced")
        self.assertEqual(response["points"], [{"date": "2026-04-01", "volatility": 0.123456}])

    def test_build_portfolio_data_aggregates_sector_risk_contributions(self) -> None:
        adapter = EmbeddedPortfolioEngineAdapter.__new__(EmbeddedPortfolioEngineAdapter)
        context = SimpleNamespace(
            instruments=[
                SimpleNamespace(ticker="VTV", name="Value ETF", sector_code="us_value", sector_name="미국 가치주"),
                SimpleNamespace(ticker="VUG", name="Growth ETF", sector_code="us_growth", sector_name="미국 성장주"),
            ],
            expected_returns=None,
            covariance=None,
            assets=[
                SimpleNamespace(code="us_value", name="미국 가치주"),
                SimpleNamespace(code="us_growth", name="미국 성장주"),
            ],
        )
        point = SimpleNamespace(
            volatility=0.12,
            weights={"VTV": 0.55, "VUG": 0.45},
        )

        captured: dict[str, object] = {}

        def fake_build_sector_allocations(**kwargs):
            captured["sector_risk_contributions"] = kwargs["sector_risk_contributions"]
            return []

        adapter.portfolio_service = SimpleNamespace(
            weights_for_optimization=lambda weights, instruments: dict(weights),
            aggregate_sector_risk_contributions=lambda contributions, instruments: {
                "us_value": 0.61,
                "us_growth": 0.39,
            },
            build_sector_allocations=fake_build_sector_allocations,
        )
        adapter.portfolio_metrics_from_weights = lambda *args, **kwargs: SimpleNamespace(
            expected_return=0.08,
            volatility=0.12,
            sharpe_ratio=0.5,
        )
        adapter.risk_contributions = lambda weights, covariance: {
            "VTV": 0.61,
            "VUG": 0.39,
        }
        adapter.RISK_FREE_RATE = 0.02

        adapter._build_portfolio_data_from_point(
            context=context,
            instrument_by_ticker={
                "VTV": context.instruments[0],
                "VUG": context.instruments[1],
            },
            point=point,
        )

        self.assertEqual(
            captured["sector_risk_contributions"],
            {"us_value": 0.61, "us_growth": 0.39},
        )

    def test_get_comparison_backtest_accepts_tuple_points(self) -> None:
        adapter = EmbeddedPortfolioEngineAdapter.__new__(EmbeddedPortfolioEngineAdapter)
        adapter._to_core_data_source = lambda value: value
        adapter.portfolio_analytics_service = SimpleNamespace(
            build_comparison_backtest=lambda **kwargs: SimpleNamespace(
                train_start_date="2024-01-01",
                train_end_date="2024-12-31",
                test_start_date="2025-01-01",
                start_date="2025-01-01",
                end_date="2025-03-31",
                split_ratio=0.9,
                rebalance_dates=["2025-02-01"],
                lines=[
                    SimpleNamespace(
                        key="balanced",
                        label="균형형",
                        color="#3b82f6",
                        style="solid",
                        points=[
                            ("2025-01-01", 0.0),
                            ("2025-01-31", 1.25),
                        ],
                    ),
                ],
            )
        )

        response = adapter.get_comparison_backtest(
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
        )

        self.assertEqual(response["lines"][0]["points"][0]["date"], "2025-01-01")
        self.assertEqual(response["lines"][0]["points"][1]["return_pct"], 1.25)


if __name__ == "__main__":
    unittest.main()
