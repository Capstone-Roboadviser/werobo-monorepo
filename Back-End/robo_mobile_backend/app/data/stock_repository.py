from __future__ import annotations

from pathlib import Path

import pandas as pd

from app.domain.models import StockInstrument


class StockDataRepository:
    """Loads stock-level universe and price history from CSV files."""

    REQUIRED_UNIVERSE_COLUMNS = {
        "ticker",
        "name",
        "sector_code",
        "sector_name",
        "market",
        "currency",
    }
    REQUIRED_PRICE_COLUMNS = {
        "date",
        "ticker",
        "adjusted_close",
    }

    def load_stock_universe(self, path: str | Path) -> list[StockInstrument]:
        csv_path = Path(path)
        frame = pd.read_csv(csv_path)
        return self.parse_stock_universe_frame(frame)

    def parse_stock_universe_frame(self, frame: pd.DataFrame) -> list[StockInstrument]:
        missing = self.REQUIRED_UNIVERSE_COLUMNS.difference(frame.columns)
        if missing:
            missing_text = ", ".join(sorted(missing))
            raise RuntimeError(f"종목 유니버스 CSV에 필요한 컬럼이 없습니다: {missing_text}")

        frame = frame.copy()
        for column in sorted(self.REQUIRED_UNIVERSE_COLUMNS):
            frame[column] = frame[column].astype(str).str.strip()
            if (frame[column] == "").any():
                raise RuntimeError(f"종목 유니버스 CSV의 '{column}' 컬럼에 빈 값이 있습니다.")
        frame["ticker"] = frame["ticker"].str.upper()

        if frame["ticker"].duplicated().any():
            duplicates = ", ".join(sorted(frame.loc[frame["ticker"].duplicated(), "ticker"].unique().tolist()))
            raise RuntimeError(f"종목 유니버스 CSV에 중복 ticker가 있습니다: {duplicates}")

        if "base_weight" in frame.columns:
            frame["base_weight"] = pd.to_numeric(frame["base_weight"], errors="coerce")
            if ((frame["base_weight"] <= 0) & frame["base_weight"].notna()).any():
                raise RuntimeError("종목 유니버스 CSV의 base_weight는 0보다 커야 합니다.")
        else:
            frame["base_weight"] = None

        instruments: list[StockInstrument] = []
        for row in frame.to_dict(orient="records"):
            instruments.append(
                StockInstrument(
                    ticker=str(row["ticker"]).strip().upper(),
                    name=str(row["name"]).strip(),
                    sector_code=str(row["sector_code"]).strip(),
                    sector_name=str(row["sector_name"]).strip(),
                    market=str(row["market"]).strip(),
                    currency=str(row["currency"]).strip(),
                    base_weight=None if pd.isna(row["base_weight"]) else float(row["base_weight"]),
                )
            )
        return instruments

    def load_stock_prices(self, path: str | Path) -> pd.DataFrame:
        csv_path = Path(path)
        frame = pd.read_csv(csv_path)
        return self.parse_stock_prices_frame(frame)

    def parse_stock_prices_frame(self, frame: pd.DataFrame) -> pd.DataFrame:
        missing = self.REQUIRED_PRICE_COLUMNS.difference(frame.columns)
        if missing:
            missing_text = ", ".join(sorted(missing))
            raise RuntimeError(f"종목 가격 CSV에 필요한 컬럼이 없습니다: {missing_text}")

        normalized = frame.copy()
        normalized["date"] = pd.to_datetime(normalized["date"], errors="coerce")
        normalized["ticker"] = normalized["ticker"].astype(str).str.strip()
        normalized["adjusted_close"] = pd.to_numeric(normalized["adjusted_close"], errors="coerce")
        if normalized[["date", "ticker", "adjusted_close"]].isna().any().any():
            raise RuntimeError("종목 가격 CSV에 잘못된 date/ticker/adjusted_close 값이 있습니다.")
        if (normalized["ticker"] == "").any():
            raise RuntimeError("종목 가격 CSV의 ticker 컬럼에 빈 값이 있습니다.")
        if (normalized["adjusted_close"] <= 0).any():
            raise RuntimeError("종목 가격 CSV의 adjusted_close는 0보다 커야 합니다.")
        if normalized.duplicated(subset=["date", "ticker"]).any():
            duplicates = normalized.loc[normalized.duplicated(subset=["date", "ticker"], keep=False), ["date", "ticker"]]
            sample = ", ".join(
                f"{row.date.date()}:{row.ticker}"
                for row in duplicates.head(5).itertuples(index=False)
            )
            raise RuntimeError(f"종목 가격 CSV에 중복된 date+ticker 행이 있습니다: {sample}")
        normalized = normalized.sort_values(["ticker", "date"])
        return normalized[["date", "ticker", "adjusted_close"]]

    def build_stock_returns(self, prices: pd.DataFrame) -> pd.DataFrame:
        normalized = prices.copy()
        normalized["date"] = pd.to_datetime(normalized["date"], errors="coerce").dt.normalize()
        normalized["ticker"] = normalized["ticker"].astype(str).str.strip().str.upper()
        normalized["adjusted_close"] = pd.to_numeric(normalized["adjusted_close"], errors="coerce")
        normalized = normalized.dropna(subset=["date", "ticker", "adjusted_close"])
        normalized = normalized.sort_values(["ticker", "date"]).drop_duplicates(
            subset=["date", "ticker"],
            keep="last",
        )
        pivoted = normalized.pivot_table(
            index="date",
            columns="ticker",
            values="adjusted_close",
            aggfunc="last",
        ).sort_index()
        returns = pivoted.pct_change().dropna(how="all")
        returns = returns.replace([float("inf"), float("-inf")], pd.NA).dropna(axis=0, how="all")
        return returns.astype(float)
