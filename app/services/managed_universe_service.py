from __future__ import annotations

import pandas as pd

from app.data.managed_universe_repository import ManagedUniverseRepository
from app.data.stock_repository import StockDataRepository
from app.domain.models import ManagedPriceStats, ManagedUniversePriceWindow, ManagedUniverseVersion, StockInstrument


class ManagedUniverseService:
    """Coordinates admin-managed stock universe versions and cumulative price imports."""

    def __init__(
        self,
        repository: ManagedUniverseRepository | None = None,
        stock_repository: StockDataRepository | None = None,
    ) -> None:
        self.repository = repository or ManagedUniverseRepository()
        self.stock_repository = stock_repository or StockDataRepository()

    def initialize_storage(self) -> None:
        self.repository.initialize()

    def is_configured(self) -> bool:
        return self.repository.is_configured()

    def list_versions(self) -> list[ManagedUniverseVersion]:
        return self.repository.list_universe_versions()

    def get_active_version(self) -> ManagedUniverseVersion | None:
        return self.repository.get_active_version()

    def get_active_instruments(self) -> list[StockInstrument]:
        return self.repository.get_active_instruments()

    def get_instruments_for_version(self, version_id: int) -> list[StockInstrument]:
        return self.repository.get_instruments_for_version(version_id)

    def load_prices_for_instruments(
        self,
        instruments: list[StockInstrument],
        *,
        version_id: int | None = None,
    ) -> pd.DataFrame:
        tickers = [instrument.ticker for instrument in instruments]
        if version_id is None:
            return self.repository.load_prices_for_tickers(tickers)

        price_window = self.get_price_window(version_id, instruments)
        return self.repository.load_prices_for_tickers(
            tickers,
            start_date=None if price_window is None else price_window.aligned_start_date,
            end_date=None if price_window is None else price_window.aligned_end_date,
        )

    def load_prices_for_tickers(self, tickers: list[str]) -> pd.DataFrame:
        return self.repository.load_prices_for_tickers(tickers)

    def load_prices_for_active_version_tickers(self, tickers: list[str]) -> pd.DataFrame:
        active_version = self.get_active_version()
        if active_version is None:
            return self.repository.load_prices_for_tickers(tickers)

        instruments = self.get_instruments_for_version(active_version.version_id)
        price_window = self.get_price_window(active_version.version_id, instruments)
        return self.repository.load_prices_for_tickers(
            tickers,
            start_date=None if price_window is None else price_window.aligned_start_date,
            end_date=None if price_window is None else price_window.aligned_end_date,
        )

    def get_price_window(
        self,
        version_id: int,
        instruments: list[StockInstrument],
    ) -> ManagedUniversePriceWindow | None:
        return self.repository.sync_price_window(
            version_id=version_id,
            tickers=[instrument.ticker for instrument in instruments],
        )

    def get_price_stats_for_instruments(
        self,
        instruments: list[StockInstrument],
        *,
        version_id: int | None = None,
    ) -> ManagedPriceStats:
        if version_id is None:
            return self.repository.get_price_stats([instrument.ticker for instrument in instruments])

        price_window = self.get_price_window(version_id, instruments)
        return self.repository.get_price_stats(
            [instrument.ticker for instrument in instruments],
            start_date=None if price_window is None else price_window.aligned_start_date,
            end_date=None if price_window is None else price_window.aligned_end_date,
        )

    def create_version(
        self,
        *,
        version_name: str,
        instruments: list[StockInstrument],
        notes: str | None = None,
        activate: bool = False,
    ) -> ManagedUniverseVersion:
        self.initialize_storage()
        validated = self.stock_repository.parse_stock_universe_frame(
            pd.DataFrame(
                [
                    {
                        "ticker": item.ticker,
                        "name": item.name,
                        "sector_code": item.sector_code,
                        "sector_name": item.sector_name,
                        "market": item.market,
                        "currency": item.currency,
                        "base_weight": item.base_weight,
                    }
                    for item in instruments
                ]
            )
        )
        return self.repository.create_universe_version(
            version_name=version_name,
            source_type="admin_input",
            instruments=validated,
            notes=notes,
            activate=activate,
        )

    def activate_version(self, version_id: int) -> ManagedUniverseVersion:
        self.initialize_storage()
        return self.repository.activate_version(version_id)

    def get_version(self, version_id: int) -> ManagedUniverseVersion | None:
        return self.repository.get_version(version_id)

    def get_version_instruments(self, version_id: int) -> list[StockInstrument]:
        return self.repository.get_instruments_for_version(version_id)

    def update_version(
        self,
        *,
        version_id: int,
        version_name: str,
        instruments: list[StockInstrument],
        notes: str | None = None,
        activate: bool = False,
    ) -> ManagedUniverseVersion:
        self.initialize_storage()
        validated = self.stock_repository.parse_stock_universe_frame(
            pd.DataFrame(
                [
                    {
                        "ticker": item.ticker,
                        "name": item.name,
                        "sector_code": item.sector_code,
                        "sector_name": item.sector_name,
                        "market": item.market,
                        "currency": item.currency,
                        "base_weight": item.base_weight,
                    }
                    for item in instruments
                ]
            )
        )
        return self.repository.update_universe_version(
            version_id=version_id,
            version_name=version_name,
            instruments=validated,
            notes=notes,
            activate=activate,
        )

    def delete_version(self, version_id: int) -> None:
        self.initialize_storage()
        self.repository.delete_universe_version(version_id)
