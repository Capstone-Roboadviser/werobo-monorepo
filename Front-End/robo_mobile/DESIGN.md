# WeRobo Design System

> Source of truth for visual + interaction design. Updated 2026-05-04 to align with the capstone design guidelines (Neon Carrot orange + flat monochromatic palette) and the PDF-spec UX rework (`0502_캡스톤_자산배분 RA_보고서.pdf`).

## Brand Personality
WeRobo is a robo-advisor that makes portfolio investment accessible to Korean retail investors. The design communicates **trust through clarity** and **confidence through warmth**. Every screen should feel like a calm, capable financial advisor — friendly enough to invite a beginner in, precise enough that an expert respects the data.

## Aesthetic Direction
**Style:** Flat design + monochromatic orange. Card-based layouts inspired by Korean fintech offerings (Hanwha Life Offering, Hi-Bank). Minimal chrome, no gradients on UI elements (orange-on-orange tonal contrast carries depth).
**Mood:** Warm confidence. The orange signals optimism and momentum without being aggressive; the light surface signals openness and approachability.
**Differentiator:** Interactive data visualization (efficient frontier, animated donut charts, real-time portfolio simulation graph) is the core UX. Users feel in control of their financial decisions because they physically interact with the data.

## Color System

### Primary
| Token | Hex | Use |
|-------|-----|-----|
| primary (Neon Carrot) | `#FE9337` | Brand, CTAs, active states, key emphasis |
| primaryDark | `#E07A1F` | Pressed states (8% darker) |
| primaryLight | `#FFC091` | Subtle backgrounds, hover tints (= sub tier 5) |

**Usage rule:** Primary applied to **only 1-2 elements per screen** (primary CTA, single active state, or a key figure). Do not paint backgrounds, multiple buttons, or full panels in primary.

### Sub palette — 5-tier monochromatic orange (asset class tones)
A 5-step tonal scale derived from the primary, used for asset class differentiation and tiered emphasis. Conveys portfolio character (defensive ↔ aggressive) at a glance.

| Tier | Hex | Asset class(es) | Character |
|------|-----|-----------------|-----------|
| 5 (lightest) | `#FFC091` | 현금성자산 | Most defensive |
| 4 | `#FFB57D` | 단기채권 | Defensive |
| 3 | `#FFAA69` | 인프라채권, 금 | Income / alt-defensive (tier-shared) |
| 2 | `#FF9F52` | 미국가치주 | Equity — value bias |
| 1 (darkest) | `#FE9337` | 미국성장주, 신성장주 | Most aggressive (tier-shared) |

**Tie-breaker on shared tiers:** 1px segment gap on donut charts; asset name list disambiguates exactly. No second hue, no patterns — keep monochromatic.

### Essential / neutral colors
| Hex | Name | Use |
|-----|------|-----|
| `#1A1919` | Warm black | Primary text, dark-mode background |
| `#F4F2F0` | Warm gray | Card surfaces, secondary backgrounds |
| `#FFFFFF` | White | Surface, text on orange |

### Status colors (retained from prior system)
| Token | Hex | Use |
|-------|-----|-----|
| accent (gain) | `#059669` | Positive return / success (WCAG AA on light) |
| warning | `#FBBF24` | Risk indicators |
| error | `#EF4444` | Error states only — never for negative returns |

Green still reads "up" in financial contexts and is retained alongside the orange brand. Negative returns use neutral `#1A1919` text with a `▼` glyph, not red, to avoid panic.

## Typography
5-font system designed for Korean readability — already aligned with the capstone spec.

| Font | Role | Why |
|------|------|-----|
| Jalnan (여기어때 잘난체) | Display / logo / splash | Bold, friendly Korean display face. Used sparingly. |
| Noto Sans KR | Body / headings | Best Korean web font. Excellent readability at all sizes. |
| Gothic A1 | Captions / 더보기 / supplementary | Lighter weight for secondary information. |
| Google Sans Flex | Numbers / financial figures | Tabular figures for currency and % alignment. |
| IBM Plex Sans Devanagari | English text / tags | Pairs with Noto Sans KR for mixed-language content. |

**Hierarchy:** 8 styles from logo (48px) to caption (12px). Body text 16px for comfortable mobile reading. Numbers always Google Sans Flex regardless of surrounding language context.

## Default Theme: Light
Light mode is the default surface. Dark mode is supported but secondary.

**Light surface stack:**
| Token | Hex | Use |
|-------|-----|-----|
| background | `#F4F2F0` | Scaffold background |
| surface | `#FFFFFF` | Card / sheet surface |
| card | `#F4F2F0` | Inset card on white surface |
| border | `#E5E1DD` | Hairline dividers |
| textPrimary | `#1A1919` | Primary text |
| textSecondary | `#6B6B6B` | Secondary text |
| textTertiary | `#8E8E8E` | Tertiary / captions (WCAG AA 4.6:1 on light) |

**Dark surface stack (secondary):**
| Token | Hex | Use |
|-------|-----|-----|
| background | `#1A1919` | Scaffold background |
| surface | `#232020` | Card / sheet surface (warm-tinted) |
| card | `#2A2625` | Inset card |
| border | `#3A3636` | Hairline dividers |
| textPrimary | `#F0EEEC` | Primary text |
| textSecondary | `#A39E99` | Secondary text |
| textTertiary | `#7A7470` | Tertiary text |

**Why light default** (overrides the original guideline's dark default): the PDF reference apps (Hanwha Life Offering, Hi-Bank, fintech dashboards) all lean light-bg with orange accents. Light surfaces let the orange brand carry visual weight without competing with dark depth cues. Dark mode remains available as a user preference.

## Motion Principles
1. **Purpose over decoration.** Every animation communicates state change, not aesthetic flair.
2. **Snappy, not spongy.** 75-400ms durations with custom cubics (steeper initial slopes). No spring, no bounce, no parallax.
3. **Staggered reveal.** Dashboard sections fade+slide in sequence (50-80ms offset). Creates a "reading" rhythm.
4. **Interactive feedback.** Scale-on-press (0.97x) via `Pressable` widget on all tappable elements.
5. **Data animation.** Charts draw progressively (800ms+). Rolling numbers animate between values. Donut sectors interpolate smoothly on tab switch.

**Animation constants (codified as `WeRoboMotion` in [theme.dart](lib/app/theme.dart)):**

| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| micro | 75ms | enter | Toggle states, checkbox, radio |
| short | 150ms | enter | Hover, press feedback |
| medium | 250ms | move | Expand/collapse, tab switch |
| long | 400ms | move | Page transitions, full-screen |
| pageTransition | 300ms | enter | FadeTransition between screens |
| stagger | 50ms offset | enter | Per-item delay in list reveals |
| chartDraw | 800ms | chartReveal | Progressive chart rendering |

Curves: `enter = Cubic(0.16, 1, 0.3, 1)`, `move = Cubic(0.4, 0, 0.2, 1)`, `chartReveal = Cubic(0.65, 0, 0.35, 1)`.

## Plain-Language Design Principle
Every data point has two layers: the number and the explanation. Beginners see the explanation first, experts see the number first. **Both are always present.**

**Examples:**
- Efficient frontier: "이 곡선은 같은 위험도에서 가장 높은 수익을 내는 조합을 보여줍니다"
- Risk indicator: market-relative 0-100 scale with 낮음/보통/높음 label (not raw volatility %)
- Portfolio composition: per-tier plain summaries ("채권 중심으로 변동이 적어요")
- Contribution analysis: "미국 가치주이(가) +7.8%로 가장 큰 수익 기여를 했어요"
- Alert frequency settings: "자주 받기 / 보통 / 중요할 때만" (internally maps to 1.5σ/2.0σ/3.0σ — σ never exposed)

**Rule:** If a user needs a finance degree to understand a screen, add a caption. If a number has no context, add a comparison.

## Elevation System
3-tier shadow scale for visual depth on light surfaces.

| Tier | Flutter | Use |
|------|---------|-----|
| subtle | `BoxShadow(blurRadius: 3, offset: Offset(0,1), color: Color(0x0A000000))` | Cards, stat rows, list items |
| medium | `BoxShadow(blurRadius: 12, offset: Offset(0,4), color: Color(0x0F000000))` | Tooltips, dropdowns, popovers |
| elevated | `BoxShadow(blurRadius: 32, offset: Offset(0,12), color: Color(0x14000000))` | Modals, bottom sheets, contribution tooltips |

**Dark mode:** triple opacity (0.04 → 0.12, 0.06 → 0.18, 0.08 → 0.24).

## Interactive States

| State | Token | Value | Use |
|-------|-------|-------|-----|
| Disabled | opacity | 0.4 | All disabled elements |
| Focus | ring | `0 0 0 3px rgba(254,147,55,0.3)` | Inputs, buttons on keyboard focus |
| Pressed | scale | 0.97x | All tappable (via `Pressable`) |
| Hover (web) | primaryDark | `#E07A1F` | Primary buttons on hover |

Focus ring is now orange-tinted (was sky-blue-tinted) at 30% alpha. Required for accessibility.

## Component Vocabulary
- **Cards:** 12px radius, `#FFFFFF` surface or `#F4F2F0` for inset. Subtle elevation. No border by default — content-first.
- **Primary button:** 52px height, 12px radius, full-width. `#FE9337` fill, white text. Outline variant (`#FE9337` border) for secondary actions.
- **Charts:** `CustomPaint` only (no charting libraries). Touch crosshairs for exploration. Smooth idealized Bezier curves on the efficient frontier (no scatter, no raw-data plotting). Real-time portfolio simulation line on home (deferred from MVP) will support tap-for-tooltip.
- **Donut:** full-mode (centered, used on the post-frontier portfolio review screen) and a future `compact: true` mode reserved for the deferred home dashboard. 1px gap between segments. Center label = portfolio name.
- **Asset weight bar (frontier):** stacked horizontal bar with one colored segment per asset class, ordered defensive → aggressive (cash leftmost, 신성장주 rightmost). Segments use 5-tier orange palette. Resize live as the user drags the frontier dot. No labels, no % text.
- **Asset weight list (portfolio review):** vertical layout below the donut. Each row = tonal swatch + 자산군 name + ETF tickers (Gothic A1, secondary) + % (Google Sans Flex, primary). Sortable by weight.
- **Asset bubbles on frontier:** fixed-radius circles labeled with 자산군 name. **No size-growth animation, no % labels.** Position by `AssetClass` enum order along the curve, not raw (vol, return) coords.
- **Stats card:** 3-column with hairline dividers. Optional subtitle for plain-language risk label.
- **Issue timeline (new):** vertical feed on home tab. Each item: 8px tonal dot (orange = active alert, gray = info), timestamp (Gothic A1 caption), headline (Noto Sans KR body), expandable detail. Sorted newest first.
- **Contribution tooltip (new):** elevated card on graph tap. Shows TOP-2 contributing assets (asset name + 비중 × 수익률 = ₩ figure) + optional 2σ-outlier badge. Dismiss on outside tap.
- **Alert frequency selector (new):** 3-segment control in settings. Plain labels (자주 받기 / 보통 / 중요할 때만). Internal σ never displayed.
- **Navigation:** bottom tab bar with 4 items (홈 / 포트폴리오 / 커뮤니티 / 설정). Active = primary color with `#FFC091` (tier 5) tinted background. Pill-style page indicators for onboarding.

## Layout Principles
- 24px horizontal padding on all screens
- 28px vertical spacing between major sections
- 16px spacing between related elements
- `SafeArea` on all screens (iOS notch / home indicator)
- `SingleChildScrollView` with `BouncingScrollPhysics` for scrollable content
- Donut + list parallel layout: donut consumes ~40% of width, list ~60%, 16px gap

## Spacing Scale
Base unit: 4px. All values multiples of 4.

| Token | Value | Use |
|-------|-------|-----|
| 2xs | 2px | Icon-to-label gaps |
| xs | 4px | Within-component micro |
| sm | 8px | Related elements (label↔input) |
| md | 12px | List items, card internal |
| lg | 16px | Related sections, standard padding |
| xl | 20px | Section top from header |
| 2xl | 24px | Horizontal screen, between major sections |
| 3xl | 28px | Between major dashboard sections |
| 4xl | 32px | Bottom padding before safe area |

**Border radius scale:**
| Token | Value | Use |
|-------|-------|-----|
| sm | 6px | Badges, delta indicators |
| md | 10px | Icon containers, nav backgrounds |
| lg | 12px | Cards, buttons, inputs |
| xl | 16px | Hero cards |
| full | 9999px | Circular elements, dot indicators |

## Core Flow & Information Architecture

**Simplified user flow** (per PDF Section I.1):
splash → welcome → login → **efficient frontier** → **포트폴리오 비중 확인** → home

The questionnaire-based onboarding is **eliminated**. Risk preference is captured implicitly by the dot the user drags on the efficient frontier — no profiling form, no target return picker, no tax bracket inputs. The frontier-drag interaction *is* the risk signal.

**Home shell** (4 bottom tabs): 홈 / 포트폴리오 / 커뮤니티 / 설정 — unchanged.

## Interaction Patterns

### Efficient Frontier (signature interaction)
- **Aspect ratio: 1:3 horizontal (3:1 width:height)** — was 1:1. Acceptable range 1:2 to 1:4 depending on viewport; 1:3 is the default. Wide aspect makes the curve slope legible on mobile.
- **Smooth idealized curve** — replaces the raw scatter plot. Visual approximation, not data-precise. Goal is conceptual understanding, not coordinate accuracy ("정확한 위치보다는 시각적으로 이해 가능한 수준의 배치를 목표로 함").
- **Asset positioning by enum order, not raw coords:** asset bubbles arranged left → right in `AssetClass` enum order (defensive → aggressive). 현금성자산 leftmost, 신성장주 rightmost. Fixed-radius bubbles only — **no size-growth animation, no % labels** on bubbles.
- **Stacked bar below the graph** (not a list with %): `AssetWeightBar` widget shows asset proportions as colored segments. Segments resize live as the user drags the dot. Order also matches the AssetClass enum so the visual gradient reads as risk increasing left-to-right. No labels, no % text — segments communicate proportion visually.
- **Tonal asset coloring** — each asset class gets its tier color from the 5-step orange palette, so portfolio character (defensive ↔ aggressive) is visible at a glance.
- Page swipe disabled during drag to prevent gesture conflict.
- Plain-language caption: "이 곡선은 같은 위험도에서 가장 높은 수익을 내는 조합을 보여줍니다".

### 포트폴리오 비중 확인 (post-frontier confirmation)
- **Donut on top + asset list below (vertical stack)** — decided 2026-05-05 over a side-by-side layout because horizontal arrangement breaks on iPhone Mini-class viewports (375pt wide).
- Donut is full-size (~240px diameter), centered, anchors visual hierarchy. Asset list scrolls below within the same `SingleChildScrollView`.
- **Tab order: 포트폴리오 비교 first (default)**, 변동성 second. Information priority follows the user's natural exploration flow (compare against market first, then drill into volatility).
- **변동성 tab dual-line:** portfolio σ overlaid against market σ. Was single-line; now compares against the market.
- **Default time range: 3년** (was 전체). Shorter recent window is more meaningful for most users.
- **Pinch-to-zoom + horizontal drag** on time-series for exploration.
- Bottom CTA: 투자 확정 (52px primary button).

### Home tab — investment-data-first dashboard
**Removed (PDF "데이터 다이어트"):** 현재 자산 amount header, 입금 현황 card, +입금하기 button, 정기 입금 button. These weakened the robo-advisor identity and duplicated generic-banking patterns.

**Added:**
- **Real-time portfolio simulation graph** at very top — shows live 수익률 over time. Replaces the static asset header.
- **포트폴리오 주요 이슈 알림 timeline** below the graph — vertical feed of asset news, market volatility warnings, and algorithm signals.
- **Contribution tooltip** on graph tap — clicking a volatile point shows the TOP-2 contributing assets (비중 × 수익률) and a 2σ-outlier badge if applicable.

**Kept:** 포트폴리오 구성 list (with %/₩ toggle), pie sector tap → ETF tickers in center, plain-language commentary, auto-rebalancing toggle, 로그인 없이 둘러보기 preview mode.

### Pie chart sectors
Tap a sector to see constituent ETF tickers in the center. Builds trust through transparency. Unchanged from prior system.

### Auto-rebalancing
Settings tab toggle (cosmetic for demo). Paired with explanation card in 포트폴리오 tab explaining the 10% drift rule. Unchanged.

### Preview-mode-by-default
The dedicated login screen was removed during the 2026-05 overhaul (the prior implementation was incompatible with the new flow). The app now reaches frontier directly from splash for unauthed users — preview mode (formerly "로그인 없이 둘러보기") is the default unauth experience. Real auth is a follow-up build.

## Alert / Digest System

**User-facing settings (설정 tab → 알림 빈도):**
3-segment selector with plain-language labels.

| Label | Internal threshold | Expected frequency |
|-------|-------------------|---------------------|
| 자주 받기 | 1.5σ | 월 2-3회 |
| 보통 *(default)* | 2.0σ | 월 1-2회 |
| 중요할 때만 | 3.0σ | 분기 1회 |

σ values never surface to the user.

**Backend trigger levels (spec only — backend logic outside this design):**

| Level | σ trigger | Approx threshold | Cooldown |
|-------|-----------|-----------------|----------|
| 일반 | ±1.5σ | ±0.52% | 3일 |
| 주의 | ±3.0σ | ±1.05% | 1일 |
| 긴급 | ±5.0σ | ±1.75% | none — always send |

Cooldowns prevent spam during crisis periods (2020 COVID, 2022 rate shock). Emergency alerts bypass cooldown.

**σ window:** rolling 60-day (chosen over 20d/252d after backtesting; balances reactivity and stability). Portfolio σ uses the full correlation matrix, not a naive sum of individual σs.

**Root-cause display (on home graph tap):**
- **TOP-2 contribution:** the two assets with the largest 비중 × 수익률 impact on the spike
- **2σ-outlier badge:** flag any asset whose move exceeded 2× its 60-day rolling σ — catches asset-specific structural anomalies even when the asset's portfolio weight is small (e.g., cash-equivalent flash move)

**Bottom-nav badge:** 8px orange dot on 홈 tab when an unread 긴급-level alert exists.

**신성장주 inclusion:** included in the alert system from launch. Data integrity flagged as a known risk in the PDF (53 tickers); requires data validation pass before launch. If a 신성장주 anomaly fires while data is still being validated, the alert ships with a "데이터 정합성 검토 중" caveat in the contribution tooltip.

**Post-launch tuning analytics:** record alert open rate, dismissal pattern, and acted-on rate per σ band. Settings stored in `analytics_event` table (or backend equivalent) so the σ thresholds can be re-tuned in production based on actual user behavior.

## Responsive Strategy
Mobile-only Flutter app. "Responsive" = phone size variation.

**Targets:**
- Primary: iPhone 17 Pro (390 × 844 logical points)
- Small: iPhone SE 3rd gen (375 × 667)
- Large: iPhone 17 Pro Max (430 × 932)

**Approach:**
- Fixed 24px horizontal padding across sizes
- Charts size relative to available width, not pixel-fixed
- Text does not scale with device size (Noto Sans KR readable at 12px minimum)
- Bottom nav and primary button heights fixed (52px / 44px+ touch targets)
- `SingleChildScrollView` handles overflow on small devices
- No landscape mode required for capstone demo
- Donut + list parallel layout falls back to stacked on devices narrower than 360pt

**Safe area:**
- `SafeArea` on all screens for notch and home indicator
- Bottom buttons padded `EdgeInsets.fromLTRB(24, 0, 24, 32)`

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-08 | Initial design system (sky blue + light) | Created via /design-consultation from Figma + capstone tokens |
| 2026-04-09 | Plain-language principle adopted | User testing revealed "too complex" — every data point now has number + explanation |
| 2026-04-09 | Chart simplified to 2 lines + benchmark toggle | Capstone meeting requirement |
| 2026-04-09 | Market-relative risk scale (0-100) | Replaces raw volatility for legibility |
| 2026-04-09 | Stay current course on color | Sky blue + clean fintech is category-literate; differentiator is the frontier interaction |
| **2026-05-04** | **Brand color: sky blue → Neon Carrot `#FE9337`** | Capstone design guidelines update; aligned with Hanwha Life / Hi-Bank reference aesthetic |
| **2026-05-04** | **Asset palette: 7-color rainbow → 5-tier monochromatic orange** | Conveys portfolio character (defensive ↔ aggressive) at a glance per PDF |
| **2026-05-04** | **Theme default: light (overrides original spec's dark default)** | PDF reference apps lean light; orange brand reads bolder against light surfaces |
| **2026-05-04** | **Onboarding cut: questionnaire deleted** | PDF Section I.1 — frontier dot drag *is* the risk signal; eliminates ~3 screens of friction |
| **2026-05-04** | **Home dashboard rework** | PDF Section I.2.홈 — strip generic-banking metrics, foreground real-time portfolio simulation + issue timeline |
| **2026-05-04** | **Donut + list parallel layout on portfolio detail** | PDF Section I.2.a — donut center wasted space, asset names need parallel visibility |
| **2026-05-04** | **Tab order swap: 비교 first, 변동성 second** | PDF — comparison is the natural first question, volatility is follow-up |
| **2026-05-04** | **Frontier 1:1 → 2:1 horizontal + smooth curve** | PDF — slope legibility on mobile + visual idealization vs raw scatter |
| **2026-05-04** | **Alert system: σ-based, 3 levels, plain-language settings** | PDF Section II — rolling 60d σ, plain-language UX (자주/보통/중요할 때만) |
| **2026-05-04** | **신성장주 included in alerts (J in scope)** | User decision — data integrity flagged as known risk with caveat copy |
| **2026-05-05** | **Frontier aspect ratio refined: 1:3 horizontal default (range 1:2 to 1:4)** | User notes — 1:1 wastes vertical space; wide aspect makes slope legible on small screens |
| **2026-05-05** | **Asset bubbles on frontier: fixed positions by enum order, no size-growth animation, no % labels** | User notes — "정확한 위치보다는 시각적으로 이해 가능한 수준" + bubble grow + % was visual noise. Fixes the bug where 인프라 채권 was incorrectly leftmost; cash now leftmost, 신성장주 rightmost. |
| **2026-05-05** | **Frontier asset list → stacked bar (`AssetWeightBar`)** | User notes — "그래프 아래 percentage 방식에서 막대 그래프 방식으로 전환". Bar segments resize live; communicates proportion visually without labels. |
| **2026-05-05** | **Portfolio review layout: side-by-side → vertical stack** | User notes — "왼쪽-오른쪽 배치는 아이폰 미니 같은 작은 화면에서 UI 문제 발생 가능성으로 인해 상하 배치로 결정". Donut on top, asset list below. |
| **2026-05-05** | **Home dashboard rework deferred from MVP** | User direction — "defer all notes under 홈 section in the pdf". Home tab inherits Phase 1 reskin only; full rework moves to a follow-up project. `ContributionAnalysis` model and `AlertAnalytics` service ship now for forward-compat. |

## Competitive Positioning
Researched 2026-04-09; refreshed 2026-05-04 with the orange direction.

**Closest references (per PDF):** Hanwha Life Offering app, Hi-Bank — Korean fintech with bold orange + light, card-based dashboards. Differs from earlier benchmarks (Toss/Robinhood/Wealthfront/Betterment) which lean blue+white or black+green.

**Where WeRobo fits:**
- Visual register: Hanwha Life / Hi-Bank (warm, confident, accessible)
- Functional register: Wealthfront / Betterment (robo-advisor, beginner-friendly, portfolio-first)
- NOT competing with Toss / Robinhood (active trading, real-time tickers)
- **Differentiator:** efficient frontier visualization remains the signature interaction. No competitor lets users physically explore the risk/return tradeoff.

**Design edge:** the orange brand + frontier interaction. The orange register sets us apart from blue-saturated fintech; the frontier sets us apart from list-of-funds robo-advisors.

## What This Design Is NOT
- Not a trading app (no real-time tickers, no buy/sell buttons, no red/green candles)
- Not a gamified finance app (no streaks, no achievements, no social pressure)
- Not a generic banking app (no 입금/출금 emphasis, no balance-front-and-center)
- Not a data dashboard (no dense tables, no chart grids, no export buttons)
- It IS a calm, confident advisor that shows you your portfolio and helps you understand it
