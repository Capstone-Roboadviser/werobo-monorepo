# Copilot Instructions

## Design Context

Applies to the two FastAPI-rendered admin pages in `Back-End/robo_mobile_backend/`:

- `mobile_backend/admin_web.py` — universe management (versions, instruments, asset-role config, price refresh)
- `mobile_backend/admin_comparison_web.py` — snapshot-based universe comparison board with charts

Internal-facing only. The Flutter app in `Front-End/robo_mobile/` is out of scope for this design context.

### Users

Internal quant/research team at WeRobo (Korean robo-advisor for retail investors). They sit at a desk, often all day, doing work that feels operationally heavy: adding/removing tickers, wiring asset-role rules, running price refreshes, comparing universe snapshots against each other on a chart board. Language is Korean. They read numerical tables fluently — information density is a feature, not a bug. Job to be done: operate the instrument, not browse a dashboard.

### Brand Personality

Three words: **precise, professional, unsentimental.**

Voice is that of a senior quant tool — confident in the density of what it's presenting, uninterested in hand-holding, quiet about itself. The emotional goal is that the user feels they're operating an instrument, not navigating a website.

### Aesthetic Direction

**Modern professional trading tool**, in the lineage of **TradingView** and **Koyfin**. Chart-first, tight type, hover-driven detail, subtle semantic color. Both light and dark themes are first-class, with a user-controlled toggle. Each theme is tuned from scratch — the dark theme is not the light theme with colors inverted.

**References:** TradingView, Koyfin.

**Anti-references (strict — do not drift toward these):**

- Generic shadcn / bootstrap admin — pastel-tinted cards with diffuse drop shadows and Inter (the current state)
- Retro CRT cosplay — scanlines, phosphor glow, green-on-black decoration
- Crypto / neon / web3 — cyan-on-dark, purple-to-blue gradients, glow borders
- Korean banking legacy — heavy flat blue, stacked dropdowns, density without craft

**Theme:** Both light and dark with an explicit toggle. Light for daytime office, dark for long chart-heavy sessions. Each palette designed deliberately.

### Design Principles

1. **Density earns its keep.** No uniform padding. Tight leading on tables, generous space above section headings, varied rhythm.
2. **Type does the work.** Refined sans for UI chrome paired with a distinctive numeric/mono face for values. Tabular numerals on every column of numbers. Do not reach for Inter, IBM Plex, Space Grotesk, or anything on the reflex-fonts list.
3. **Color is meaning, not decoration.** Semantic only: greens for positive/active, reds for negative/danger, ambers for pending, one brand accent for selection and primary action. No gradient text.
4. **One canonical accent, used sparingly.** Diluting it is worse than not using it.
5. **Both themes designed, neither default.** Dark is its own intentional palette, not a color-inverted light theme.

### Constraints

- Korean-first copy — font choices must have hangul coverage
- FastAPI-rendered HTML strings, no build step, inline CSS
- Server-rendered + vanilla JS — do not introduce a framework
- Scope: polish + opinionated redesign, no new features, no new endpoints
