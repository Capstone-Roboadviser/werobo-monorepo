## Expected Return Pipeline

### Goal

Keep role semantics explicit while removing market-data fetches from request-time
portfolio calculations.

### Current pain points

- Asset-class `role` decides whether dividend yield should be reflected, but the
  actual dividend number may still depend on live `yfinance` access at request time.
- Request-path live fetches make mobile APIs slower and less predictable.
- The all-members dividend-aware role needed one canonical key so admin config,
  stored versions, and runtime behavior do not drift semantically.

### Target model

1. Admin price refresh fetches daily prices for the active universe.
2. The same refresh flow fetches and stores per-ticker dividend yield estimates.
3. Runtime portfolio calculations read stored dividend estimates first.
4. Live market fetch becomes an explicit fallback/debug path, not the primary
   production dependency.

### Role semantics

- `selection_mode`
  - Decides which members of an asset class enter the optimizer.
- `weighting_mode`
  - Decides how a selected asset-class basket is exploded into ticker weights.
- `return_mode`
  - Decides which expected-return model to use and whether a dividend overlay is
    added.

For dividend-aware roles, the production path should be:

`expected return = base model output + stored dividend overlay`

not:

`expected return = base model output + request-time live fetch`

Canonical role note:

- `equal_weight_dividend_basket` is the canonical all-members dividend-aware role.
- Legacy stored/admin input using `equal_weight_basket` is normalized to
  `equal_weight_dividend_basket` for backward compatibility.

### Stored dividend estimate

Each ticker-level estimate should capture:

- `ticker`
- `annualized_dividend`
- `annual_yield`
- `payments_per_year`
- `frequency_label`
- `last_payment_date`
- `source`
- `updated_at`

### Runtime rules

- Managed-universe calculations should prefer the stored dividend estimate.
- Demo tickers should never require live market access.
- If stored data is missing, the runtime should degrade predictably:
  - use live fallback only when explicitly enabled
  - otherwise use a zero overlay

### Refactor scope

- Introduce a stored dividend-yield record in the managed-universe repository.
- Move live dividend fetch logic behind a dedicated provider abstraction.
- Let `PriceRefreshService` populate dividend estimates during refresh.
- Let `DividendYieldService` read stored estimates before any live fallback.
- Update admin and architecture docs so operators understand that dividend-aware
  roles depend on refresh freshness, not request-time internet access.
