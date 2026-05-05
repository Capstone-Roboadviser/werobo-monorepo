from __future__ import annotations

from types import SimpleNamespace
import unittest

import pandas as pd

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
        adapter.CoreSimulationDataSource = SimulationDataSource
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

    def test_build_recommendation_returns_metadata_without_representative_portfolios(self) -> None:
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
        self.assertEqual(response["resolved_profile"]["target_volatility"], 0.12)
        self.assertEqual(response["portfolios"], [])

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

    def test_build_frontier_preview_returns_full_frontier_when_sample_points_omitted(self) -> None:
        adapter, _ = self._build_fake_adapter()

        response = adapter.build_frontier_preview(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=None,
            sample_points=None,
        )

        self.assertEqual(response["total_point_count"], 3)
        self.assertEqual([point["index"] for point in response["points"]], [0, 1, 2])

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

    def test_build_frontier_selection_can_select_exact_point_index(self) -> None:
        adapter, _ = self._build_fake_adapter()

        response = adapter.build_frontier_selection(
            resolved_profile=RiskProfile.BALANCED,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            propensity_score=None,
            target_volatility=None,
            selected_point_index=2,
        )

        self.assertEqual(response["selected_point_index"], 2)
        self.assertEqual(response["selected_target_volatility"], 0.16)
        self.assertEqual(response["portfolio"]["target_volatility"], 0.16)

    def test_get_volatility_history_can_use_selected_frontier_point(self) -> None:
        adapter, _ = self._build_fake_adapter()
        captured: dict[str, object] = {}

        class FakeVolatilityHistoryRequest:
            def __init__(self, **kwargs) -> None:
                self.__dict__.update(kwargs)

        def fake_volatility_history(request):
            captured["weights"] = request.weights
            return SimpleNamespace(
                earliest_data_date="2024-01-02",
                latest_data_date="2024-01-31",
                points=[
                    SimpleNamespace(date="2024-01-31", volatility=0.16),
                ],
            )

        adapter.CoreVolatilityHistoryRequest = FakeVolatilityHistoryRequest
        adapter.core_portfolio_routes = SimpleNamespace(volatility_history=fake_volatility_history)

        response = adapter.get_volatility_history(
            risk_profile=None,
            investment_horizon=InvestmentHorizon.MEDIUM,
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            rolling_window=20,
            target_volatility=None,
            selected_point_index=2,
        )

        self.assertEqual(captured["weights"], {"VTV": 0.30, "VUG": 0.55, "BND": 0.15})
        self.assertEqual(response["portfolio_code"], "selected")
        self.assertEqual(response["portfolio_label"], "선택 포트폴리오")
        self.assertEqual(response["selected_point_index"], 2)
        self.assertEqual(response["selected_target_volatility"], 0.16)

    def test_get_comparison_backtest_uses_selected_frontier_point_only(self) -> None:
        adapter, _ = self._build_fake_adapter()
        captured: dict[str, object] = {}
        prices = pd.DataFrame(
            [
                {"date": "2024-01-02", "ticker": "VTV", "adjusted_close": 100.0},
                {"date": "2024-01-02", "ticker": "VUG", "adjusted_close": 100.0},
                {"date": "2024-01-02", "ticker": "BND", "adjusted_close": 100.0},
                {"date": "2024-01-03", "ticker": "VTV", "adjusted_close": 101.0},
                {"date": "2024-01-03", "ticker": "VUG", "adjusted_close": 103.0},
                {"date": "2024-01-03", "ticker": "BND", "adjusted_close": 100.5},
            ]
        )

        def fake_load_comparison_universe(data_source):
            captured["loaded_data_source"] = data_source
            return [], prices, "fake-universe"

        def fake_split_prices_train_test(prices_arg, *, split_ratio):
            captured["split_ratio"] = split_ratio
            train = prices_arg[prices_arg["date"] == pd.Timestamp("2024-01-02")].copy()
            test = prices_arg.copy()
            return train, test, pd.Timestamp("2024-01-02"), pd.Timestamp("2024-01-02")

        def fake_build_comparison(
            prices_arg,
            portfolios,
            expected_returns,
            benchmark_series,
            *,
            train_start_date,
            train_end_date,
            split_ratio,
        ):
            captured["portfolios"] = portfolios
            captured["expected_returns"] = expected_returns
            captured["benchmark_series"] = benchmark_series
            return SimpleNamespace(
                train_start_date=train_start_date,
                train_end_date=train_end_date,
                test_start_date="2024-01-02",
                start_date="2024-01-02",
                end_date="2024-01-03",
                split_ratio=split_ratio,
                rebalance_dates=[],
                lines=[
                    SimpleNamespace(
                        key="selected",
                        label="selected",
                        color="#64748B",
                        style="solid",
                        points=[
                            SimpleNamespace(date="2024-01-02", return_pct=0.0),
                            SimpleNamespace(date="2024-01-03", return_pct=2.1),
                        ],
                    )
                ],
            )

        adapter.core_portfolio_routes = SimpleNamespace(
            _load_comparison_universe=fake_load_comparison_universe,
            _split_prices_train_test=fake_split_prices_train_test,
            _fetch_benchmark_prices=lambda start_date: {},
        )
        adapter.build_comparison = fake_build_comparison

        response = adapter.get_comparison_backtest(
            data_source=SimulationDataSource.STOCK_COMBINATION_DEMO,
            investment_horizon=InvestmentHorizon.MEDIUM,
            target_volatility=None,
            selected_point_index=2,
        )

        self.assertEqual(list(captured["portfolios"].keys()), ["selected"])
        self.assertEqual(
            captured["portfolios"]["selected"],
            {"VTV": 0.30, "VUG": 0.55, "BND": 0.15},
        )
        self.assertEqual(list(captured["expected_returns"].keys()), ["selected"])
        self.assertEqual(response["selected_point_index"], 2)
        self.assertEqual(response["selected_target_volatility"], 0.16)
        self.assertEqual(response["lines"][0]["key"], "selected")
        self.assertEqual(response["lines"][0]["label"], "선택 포트폴리오")

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
        self.assertEqual(response["resolved_profile"]["target_volatility"], 0.12)
        self.assertEqual(response["portfolios"], [])

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


if __name__ == "__main__":
    unittest.main()
