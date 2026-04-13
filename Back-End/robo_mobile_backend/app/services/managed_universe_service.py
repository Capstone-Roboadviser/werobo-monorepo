from __future__ import annotations

import pandas as pd

from app.data.managed_universe_repository import ManagedUniverseRepository
from app.data.repository import StaticDataRepository
from app.data.stock_repository import StockDataRepository
from app.domain.models import (
    AssetClass,
    AssetRoleTemplate,
    ManagedPriceStats,
    ManagedUniverseAssetRoleAssignment,
    ManagedUniversePriceWindow,
    ManagedUniverseVersion,
    StockInstrument,
)


class ManagedUniverseService:
    """Coordinates admin-managed stock universe versions and cumulative price imports."""

    def __init__(
        self,
        repository: ManagedUniverseRepository | None = None,
        stock_repository: StockDataRepository | None = None,
    ) -> None:
        self.repository = repository or ManagedUniverseRepository()
        self.stock_repository = stock_repository or StockDataRepository()
        self.static_repository = StaticDataRepository()

    def initialize_storage(self) -> None:
        self.repository.initialize()

    def is_configured(self) -> bool:
        return self.repository.is_configured()

    def list_versions(self) -> list[ManagedUniverseVersion]:
        return self.repository.list_universe_versions()

    def get_active_version(self) -> ManagedUniverseVersion | None:
        return self.repository.get_active_version()

    def list_assets(self) -> list[AssetClass]:
        return self.static_repository.load_asset_universe()

    def list_asset_role_templates(self) -> list[AssetRoleTemplate]:
        return list(self.static_repository.load_asset_role_templates().values())

    def get_assets_for_version(self, version_id: int) -> list[AssetClass]:
        return self.static_repository.load_asset_universe(
            role_overrides=self.repository.get_asset_role_assignments_for_version(version_id),
        )

    def get_active_assets(self) -> list[AssetClass]:
        active_version = self.get_active_version()
        if active_version is None:
            return self.list_assets()
        return self.get_assets_for_version(active_version.version_id)

    def get_active_instruments(self) -> list[StockInstrument]:
        return self.repository.get_active_instruments()

    def get_instruments_for_version(self, version_id: int) -> list[StockInstrument]:
        return self.repository.get_instruments_for_version(version_id)

    def load_prices_for_instruments(
        self,
        instruments: list[StockInstrument],
        *,
        version_id: int | None = None,
        end_date: str | None = None,
    ) -> pd.DataFrame:
        tickers = [instrument.ticker for instrument in instruments]
        if version_id is None:
            return self.repository.load_prices_for_tickers(tickers, end_date=end_date)

        price_window = self.get_price_window(version_id, instruments)
        effective_end_date = end_date
        if price_window is not None and price_window.aligned_end_date is not None:
            if effective_end_date is None or effective_end_date > price_window.aligned_end_date:
                effective_end_date = price_window.aligned_end_date
        return self.repository.load_prices_for_tickers(
            tickers,
            start_date=None if price_window is None else price_window.aligned_start_date,
            end_date=effective_end_date,
        )

    def load_prices_for_tickers(self, tickers: list[str]) -> pd.DataFrame:
        return self.repository.load_prices_for_tickers(tickers)

    def load_prices_for_active_version_tickers(
        self,
        tickers: list[str],
        *,
        end_date: str | None = None,
    ) -> pd.DataFrame:
        active_version = self.get_active_version()
        if active_version is None:
            return self.repository.load_prices_for_tickers(tickers, end_date=end_date)

        instruments = self.get_instruments_for_version(active_version.version_id)
        price_window = self.get_price_window(active_version.version_id, instruments)
        effective_end_date = end_date
        if price_window is not None and price_window.aligned_end_date is not None:
            if effective_end_date is None or effective_end_date > price_window.aligned_end_date:
                effective_end_date = price_window.aligned_end_date
        return self.repository.load_prices_for_tickers(
            tickers,
            start_date=None if price_window is None else price_window.aligned_start_date,
            end_date=effective_end_date,
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
        asset_roles: list[ManagedUniverseAssetRoleAssignment] | None = None,
        notes: str | None = None,
        activate: bool = False,
    ) -> ManagedUniverseVersion:
        self.initialize_storage()
        resolved_asset_roles = self._resolve_asset_roles(asset_roles)
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
            asset_role_assignments=resolved_asset_roles,
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
        asset_roles: list[ManagedUniverseAssetRoleAssignment] | None = None,
        notes: str | None = None,
        activate: bool = False,
    ) -> ManagedUniverseVersion:
        self.initialize_storage()
        resolved_asset_roles = self._resolve_asset_roles(asset_roles)
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
            asset_role_assignments=resolved_asset_roles,
            notes=notes,
            activate=activate,
        )

    def delete_version(self, version_id: int) -> None:
        self.initialize_storage()
        self.repository.delete_universe_version(version_id)

    def _resolve_asset_roles(
        self,
        asset_roles: list[ManagedUniverseAssetRoleAssignment] | None = None,
    ) -> list[ManagedUniverseAssetRoleAssignment]:
        assets = self.list_assets()
        templates = self.static_repository.load_asset_role_templates()
        asset_codes = {asset.code for asset in assets}
        default_role_map = {asset.code: asset.role_key for asset in assets}
        provided_role_map: dict[str, str] = {}

        for item in asset_roles or []:
            asset_code = item.asset_code.strip()
            role_key = item.role_key.strip()
            if asset_code in provided_role_map:
                raise RuntimeError(f"자산군 '{asset_code}'의 role이 중복으로 전달되었습니다.")
            if asset_code not in asset_codes:
                raise RuntimeError(f"지원하지 않는 자산군 코드입니다: {asset_code}")
            if role_key not in templates:
                raise RuntimeError(f"지원하지 않는 role_key 입니다: {role_key}")
            provided_role_map[asset_code] = role_key

        return [
            ManagedUniverseAssetRoleAssignment(
                asset_code=asset.code,
                role_key=provided_role_map.get(asset.code, default_role_map[asset.code]),
            )
            for asset in assets
        ]
