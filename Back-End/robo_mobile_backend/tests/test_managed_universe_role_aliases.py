from __future__ import annotations

import unittest

from app.data.repository import StaticDataRepository
from app.domain.models import ManagedUniverseAssetRoleAssignment
from app.services.managed_universe_service import ManagedUniverseService


class _FakeManagedUniverseRepository:
    pass


class ManagedUniverseRoleAliasTests(unittest.TestCase):
    def test_role_template_catalog_exposes_only_canonical_all_members_role(self) -> None:
        repository = StaticDataRepository()

        role_templates = repository.load_asset_role_templates()

        self.assertIn("equal_weight_dividend_basket", role_templates)
        self.assertNotIn("equal_weight_basket", role_templates)

    def test_asset_universe_normalizes_legacy_role_key(self) -> None:
        repository = StaticDataRepository()

        assets = repository.load_asset_universe(
            role_overrides={
                "gold": "equal_weight_basket",
            }
        )

        gold_asset = next(asset for asset in assets if asset.code == "gold")
        self.assertEqual(gold_asset.role_key, "equal_weight_dividend_basket")

    def test_managed_universe_service_accepts_legacy_role_key_as_alias(self) -> None:
        service = ManagedUniverseService(repository=_FakeManagedUniverseRepository())

        resolved = service._resolve_asset_roles(
            [
                ManagedUniverseAssetRoleAssignment(
                    asset_code="gold",
                    role_key="equal_weight_basket",
                )
            ]
        )

        gold_role = next(item for item in resolved if item.asset_code == "gold")
        self.assertEqual(gold_role.role_key, "equal_weight_dividend_basket")


if __name__ == "__main__":
    unittest.main()
