from __future__ import annotations

from dataclasses import dataclass

import yfinance as yf


@dataclass(frozen=True)
class TickerLookupResult:
    ticker: str
    name: str
    market: str
    currency: str
    exchange: str | None = None
    quote_type: str | None = None


@dataclass(frozen=True)
class TickerSearchResult:
    ticker: str
    name: str
    exchange: str | None = None
    quote_type: str | None = None
    market: str | None = None
    currency: str | None = None


class TickerDiscoveryService:
    def search_tickers(self, query: str, max_results: int = 8) -> list[TickerSearchResult]:
        normalized_query = query.strip()
        if not normalized_query:
            raise RuntimeError("검색어를 입력해주세요.")

        try:
            results = self._search_via_yahoo(normalized_query, max_results=max_results)
            if results:
                return results
        except Exception as exc:  # pragma: no cover - network dependent
            if self._looks_like_ticker(normalized_query):
                try:
                    exact = self.lookup_ticker(normalized_query, prefer_search=False)
                    return [
                        TickerSearchResult(
                            ticker=exact.ticker,
                            name=exact.name,
                            exchange=exact.exchange,
                            quote_type=exact.quote_type,
                            market=exact.market,
                            currency=exact.currency,
                        )
                    ]
                except RuntimeError as lookup_exc:
                    raise RuntimeError(
                        "티커 검색에 실패했습니다. Yahoo 검색이 일시적으로 불안정할 수 있습니다. "
                        f"정확한 티커를 직접 입력하고 자동채움을 시도해보세요. 원인: {lookup_exc}"
                    ) from exc
            raise RuntimeError(
                "티커 검색에 실패했습니다. 네트워크 문제 또는 Yahoo 검색 제한일 수 있습니다. "
                "정확한 티커를 직접 입력하고 자동채움을 시도해보세요."
            ) from exc

        if self._looks_like_ticker(normalized_query):
            try:
                exact = self.lookup_ticker(normalized_query, prefer_search=False)
                return [
                    TickerSearchResult(
                        ticker=exact.ticker,
                        name=exact.name,
                        exchange=exact.exchange,
                        quote_type=exact.quote_type,
                        market=exact.market,
                        currency=exact.currency,
                    )
                ]
            except RuntimeError:
                return []

        return []

    def lookup_ticker(self, ticker: str, prefer_search: bool = True) -> TickerLookupResult:
        normalized_ticker = ticker.strip().upper()
        if not normalized_ticker:
            raise RuntimeError("티커를 입력해주세요.")

        exact_match: TickerSearchResult | None = None
        if prefer_search:
            try:
                search_matches = self._search_via_yahoo(normalized_ticker, max_results=8)
                exact_match = next(
                    (item for item in search_matches if item.ticker.upper() == normalized_ticker),
                    None,
                )
            except Exception:
                exact_match = None

        name = exact_match.name if exact_match else normalized_ticker
        market = exact_match.market or exact_match.exchange or "" if exact_match else ""
        currency = exact_match.currency if exact_match else ""
        exchange = exact_match.exchange if exact_match else None
        quote_type = exact_match.quote_type if exact_match else None

        info = self._fetch_info(normalized_ticker)

        name = str(
            info.get("shortName")
            or info.get("longName")
            or info.get("displayName")
            or name
        ).strip()
        market = str(
            info.get("exchange")
            or info.get("fullExchangeName")
            or info.get("market")
            or market
        ).strip()
        currency = str(
            info.get("currency")
            or info.get("financialCurrency")
            or currency
            or ""
        ).strip()
        exchange = str(info.get("exchange") or exchange or "").strip() or exchange
        quote_type = str(info.get("quoteType") or quote_type or "").strip() or quote_type

        if not name or not currency or not market:
            self._validate_with_download(normalized_ticker)

        normalized_market = self._normalize_market(market, exchange, normalized_ticker)
        normalized_currency = currency or self._default_currency_for_market(normalized_market, normalized_ticker)

        if not normalized_currency:
            raise RuntimeError(
                f"'{normalized_ticker}' 티커의 통화 정보를 확인하지 못했습니다. "
                "정확한 티커인지 확인하거나, 수기 입력 후 통화를 직접 보완해주세요."
            )

        return TickerLookupResult(
            ticker=normalized_ticker,
            name=name or normalized_ticker,
            market=normalized_market,
            currency=normalized_currency,
            exchange=exchange,
            quote_type=quote_type,
        )

    def _search_via_yahoo(self, query: str, max_results: int) -> list[TickerSearchResult]:
        search = yf.Search(
            query=query,
            max_results=max_results,
            news_count=0,
            lists_count=0,
            include_cb=False,
            include_nav_links=False,
            include_research=False,
            enable_cultural_assets=False,
            recommended=max_results,
            raise_errors=True,
        )

        quotes = getattr(search, "quotes", None)
        if quotes is None:
            quotes = getattr(search, "_quotes", [])

        results: list[TickerSearchResult] = []
        seen: set[str] = set()
        for quote in quotes:
            ticker = str(quote.get("symbol") or "").strip().upper()
            if not ticker or ticker in seen:
                continue
            seen.add(ticker)
            results.append(
                TickerSearchResult(
                    ticker=ticker,
                    name=str(
                        quote.get("shortname")
                        or quote.get("longname")
                        or quote.get("displayName")
                        or ticker
                    ).strip(),
                    exchange=self._clean_optional(
                        quote.get("exchange")
                        or quote.get("exchDisp")
                        or quote.get("fullExchangeName")
                    ),
                    quote_type=self._clean_optional(quote.get("quoteType") or quote.get("typeDisp")),
                    market=self._clean_optional(
                        quote.get("exchange")
                        or quote.get("exchDisp")
                        or quote.get("fullExchangeName")
                    ),
                    currency=self._clean_optional(quote.get("currency")),
                )
            )
        return results

    def _fetch_info(self, ticker: str) -> dict[str, object]:
        try:
            return yf.Ticker(ticker).get_info()
        except Exception:
            return {}

    def _validate_with_download(self, ticker: str) -> None:
        try:
            frame = yf.download(
                tickers=ticker,
                period="1mo",
                progress=False,
                auto_adjust=False,
                actions=False,
                threads=False,
            )
        except Exception as exc:  # pragma: no cover - network dependent
            raise RuntimeError(f"'{ticker}' 티커 조회에 실패했습니다: {exc}") from exc
        if frame.empty:
            raise RuntimeError(f"'{ticker}' 티커를 찾을 수 없습니다.")

    @staticmethod
    def _looks_like_ticker(value: str) -> bool:
        allowed = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-^=")
        upper = value.strip().upper()
        return bool(upper) and len(upper) <= 15 and all(char in allowed for char in upper)

    @staticmethod
    def _normalize_market(market: str, exchange: str | None, ticker: str) -> str:
        candidate = (market or exchange or "").strip()
        if candidate:
            return candidate
        if ticker.endswith(".KS"):
            return "KRX"
        if ticker.endswith(".T"):
            return "TYO"
        return "USA"

    @staticmethod
    def _default_currency_for_market(market: str, ticker: str) -> str | None:
        upper_market = (market or "").upper()
        if ticker.endswith(".KS") or "KRX" in upper_market:
            return "KRW"
        if ticker.endswith(".T") or "TYO" in upper_market or "TSE" in upper_market:
            return "JPY"
        if any(token in upper_market for token in ("NYSE", "NASDAQ", "NMS", "NYQ", "ASE", "AMEX", "USA", "US")):
            return "USD"
        if "." not in ticker:
            return "USD"
        return None

    @staticmethod
    def _clean_optional(value: object) -> str | None:
        if value is None:
            return None
        text = str(value).strip()
        return text or None
