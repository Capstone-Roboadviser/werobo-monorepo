# WeRobo Design System

## Brand Personality
WeRobo is a robo-advisor that makes portfolio investment accessible to Korean retail investors. The design communicates **trust through clarity** and **sophistication through simplicity**. Every screen should feel like a calm, competent financial advisor, not a flashy trading app.

## Aesthetic Direction
**Style:** Clean fintech. Minimal chrome. Data-forward. White space as a feature.
**Mood:** Calm confidence. The user trusts their money with this app because the interface feels careful and considered.
**Differentiator:** Interactive data visualization (efficient frontier, animated donut charts, touch-crosshair line charts) is the core UX. Users feel in control of their financial decisions because they physically interact with the data.

## Color System
Sky blue (#20A7DB) as primary communicates trust and stability, common in Korean fintech apps. Green (#059669) for positive returns/success (darkened from #34D399 to meet WCAG AA 4.5:1 contrast ratio). Yellow (#FBBF24) for warnings/risk indicators. Red (#EF4444) only for errors, never for negative returns (to avoid panic).

| Token | Value | Usage |
|-------|-------|-------|
| primary | #20A7DB | Interactive elements, active states, brand |
| primaryLight | #A0D9EF | Hover states, subtle backgrounds |
| primaryDark | #1C96C5 | Pressed states |
| accent | #059669 | Positive performance, success |
| warning | #FBBF24 | Risk indicators |
| error | #EF4444 | Error states only |

**Neutrals (cool-tinted):** White (#FFFFFF) surface, #EFF1F3 cards, #CDD1D6 borders, #000000 primary text, #6B6B6B secondary text, #8E8E8E tertiary text. Neutrals carry a subtle cool tint to harmonize with the sky blue primary. Background: #F6F7F8.

**Chart palette:** 7 fixed colors per portfolio category. Consistent across all investment types so users build visual memory of sector colors.

| Index | Hex | Category Example |
|-------|---------|------------------|
| 1 | #20A7DB | 미국 주식 |
| 2 | #059669 | 선진국 채권 |
| 3 | #FBBF24 | 한국 주식 |
| 4 | #8B5CF6 | 신흥국 주식 |
| 5 | #F97316 | 원자재 |
| 6 | #EC4899 | 부동산 |
| 7 | #14B8A6 | 대체투자 |

## Typography
5-font system designed for Korean readability:

| Font | Role | Why |
|------|------|-----|
| Jalnan (잘난체) | Display/logo | Bold, friendly Korean display face. Used sparingly. |
| NotoSansKR | Body/headings | Best Korean web font. Excellent readability at all sizes. |
| GothicA1 | Captions/labels | Lighter weight for secondary information. |
| GoogleSansFlex | Numbers | Tabular figures for financial data alignment. |
| IBMPlexSans | English text | Pairs well with NotoSansKR for mixed-language content. |

**Hierarchy:** 8 text styles from logo (48px) to caption (12px). Body text at 16px for comfortable mobile reading.

## Motion Principles
1. **Purpose over decoration.** Every animation communicates state change, not aesthetic flair.
2. **400ms standard transition.** Page transitions use FadeTransition at 400ms. Fast enough to not block, slow enough to orient.
3. **Staggered reveal.** Dashboard sections fade+slide in sequence (80ms offset). Creates a "reading" rhythm.
4. **Interactive feedback.** Scale-on-press (0.97x) via Pressable widget on all tappable elements.
5. **Data animation.** Charts draw progressively (800-1200ms). Rolling numbers animate between values. Donut sectors interpolate smoothly on type switch.
6. **No parallax, no bounce, no spring.** These feel wrong for a finance app. Use easeOut and easeInOut curves only.

**Animation constants (codified as `WeRoboMotion` in theme.dart):**

| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| micro | 75ms | easeOut | Toggle states, checkbox, radio |
| short | 200ms | easeOut | Hover effects, press feedback |
| medium | 350ms | easeInOut | Expand/collapse, tab switch |
| long | 500ms | easeInOut | Page transitions, full-screen |
| pageTransition | 400ms | easeOut | FadeTransition between screens |
| stagger | 80ms offset | easeOut | Per-item delay in list reveals |
| chartDraw | 800-1200ms | easeOut | Progressive chart rendering |

## Plain-Language Design Principle
Every data point has two layers: the number and the explanation. Beginners see the explanation first, experts see the number first. Both are always present.

**Examples implemented:**
- Efficient frontier: "이 곡선은 같은 위험도에서 가장 높은 수익을 내는 조합을 보여줍니다"
- Risk indicator: Market-relative 0-100 scale with 낮음/보통/높음 label (not raw volatility %)
- Portfolio comparison: Per-type plain summaries ("채권 중심으로 변동이 적어요")
- Contribution analysis: "미국 가치주이(가) +7.8%로 가장 큰 수익 기여를 했어요"
- Rebalancing: "자산 비중이 목표에서 10% 이상 벗어나면 자동으로 조정"

**Rule:** If a user needs a finance degree to understand a screen, add a caption. If a number has no context, add a comparison (e.g., "은행 예금 이자보다 높은 수익").

## Elevation System
3-tier shadow scale for visual depth. All shadows are neutral (no colored shadows).

| Tier | CSS-equivalent | Flutter | Usage |
|------|---------------|---------|-------|
| subtle | 0 1px 3px rgba(0,0,0,0.04) | `BoxShadow(blurRadius: 3, offset: Offset(0,1), color: Color(0x0A000000))` | Cards, stat rows, list items |
| medium | 0 4px 12px rgba(0,0,0,0.06) | `BoxShadow(blurRadius: 12, offset: Offset(0,4), color: Color(0x0F000000))` | Tooltips, dropdowns, popovers |
| elevated | 0 12px 32px rgba(0,0,0,0.08) | `BoxShadow(blurRadius: 32, offset: Offset(0,12), color: Color(0x14000000))` | Modals, bottom sheets, toasts |

**Dark mode shadows:** Increase opacity ~3x (0.04 -> 0.12, 0.06 -> 0.18, 0.08 -> 0.24) because darker backgrounds absorb more shadow.

## Interactive States

| State | Token | Value | Usage |
|-------|-------|-------|-------|
| Disabled | opacity | 0.4 | All disabled buttons, inputs, toggles |
| Focus | ring | 0 0 0 3px rgba(32,167,219,0.3) | Inputs, buttons on keyboard focus |
| Pressed | scale | 0.97x | All tappable elements (via Pressable) |
| Hover (web) | primary-dark | #1C96C5 | Primary buttons on hover |

**Focus ring:** 3px sky blue at 30% alpha. Applied via BoxShadow in Flutter. Required for accessibility, visible on keyboard navigation.

## Component Vocabulary
- **Cards:** 12px radius, #F0F0F0 background, no border. Content-first.
- **Buttons:** 52px height, 12px radius, full-width primary. Outline variant for secondary actions.
- **Charts:** CustomPaint only. No charting libraries. Touch crosshairs for exploration. Gradient area fills for trend visualization. Comparison chart simplified to 2 lines (portfolio + benchmark) with toggle.
- **Stats card:** 3-column layout with dividers. Supports optional subtitle per stat (used for risk label).
- **Contribution bars:** Per-asset horizontal progress bars with signed % and ₩ amount. Sorted by earnings descending.
- **Expandable rebalance cards:** Tap to expand with before/after allocation bars and per-sector delta badges. Uses `AnimatedCrossFade`.
- **Explanation cards:** Light primary tint background (6% alpha), icon + heading + body text. Used for auto-rebalancing explanation.
- **Navigation:** Bottom tab bar with 4 items (홈/포트폴리오/커뮤니티/설정). Active = primary color with tinted background. Pill-style page indicators for onboarding.

## Layout Principles
- 24px horizontal padding on all screens
- 28px vertical spacing between major sections
- 16px spacing between related elements
- SafeArea on all screens (iOS notch/home indicator)
- SingleChildScrollView with BouncingScrollPhysics for scrollable content

## Interaction Patterns
- **Efficient frontier:** The signature interaction. User drags a dot along a curve to choose risk/return balance. Risk/return stats update in real-time. Page swipe is disabled during drag to prevent conflict. Plain-language caption explains the curve.
- **Portfolio comparison:** 3-chip type selector with animated donut chart and rolling number stats. Each type has a plain-language summary. Users can compare before committing.
- **Pie chart sectors:** Tap a sector to see constituent ETF tickers in the center. Builds trust through transparency.
- **Comparison chart toggle:** 2-line chart (selected portfolio + 7-asset benchmark). Benchmark line toggles on/off via a "벤치마크" button. Replaces the old 8-line chart.
- **Contribution analysis:** Per-asset return bars sorted by earnings. Each bar shows signed % and ₩ amount. Top contributor gets a plain-language commentary sentence.
- **Market-relative risk:** 0-100 scale derived from `portfolio_vol / 0.20 * 100`. Color-coded: green (0-33 낮음), yellow (34-66 보통), red (67-100 높음).
- **Auto-rebalancing toggle:** Settings tab toggle (cosmetic for demo). Paired with explanation card in portfolio tab explaining the 10% drift rule.
- **Preview mode:** "로그인 없이 둘러보기" on login screen bypasses auth for demo purposes.

## Spacing Scale
Base unit: 4px. All spacing values are multiples of 4.

| Token | Value | Usage |
|-------|-------|-------|
| 2xs | 2px | Icon-to-label gaps, tight inline spacing |
| xs | 4px | Within-component micro spacing |
| sm | 8px | Between related elements (label to input, icon to text) |
| md | 12px | Between list items, card internal padding |
| lg | 16px | Between related sections, standard padding |
| xl | 20px | Section top padding from header |
| 2xl | 24px | Horizontal screen padding, between major sections |
| 3xl | 28px | Between major dashboard sections |
| 4xl | 32px | Bottom padding before safe area |

**Border radius scale:**
| Token | Value | Usage |
|-------|-------|-------|
| sm | 6px | Badges, small chips, delta indicators |
| md | 10px | Icon containers, nav item backgrounds |
| lg | 12px | Cards, buttons, containers, inputs |
| xl | 16px | Large hero cards |
| full | 9999px | Circular elements, dot indicators |

## Responsive Strategy
This is a mobile-only Flutter app. "Responsive" means handling different phone sizes.

**Design targets:**
- Primary: iPhone 17 Pro (390x844 logical points)
- Small: iPhone SE 3rd gen (375x667)
- Large: iPhone 17 Pro Max (430x932)

**Approach:**
- Fixed horizontal padding (24px) on all screen sizes
- Charts and pie charts size themselves relative to available width, not fixed pixel sizes
- Text does not scale with device size (NotoSansKR is readable at 12px minimum)
- Bottom nav and button heights are fixed (52px buttons, 44px+ touch targets)
- `SingleChildScrollView` handles overflow on small devices
- No landscape mode required for capstone demo

**Safe area handling:**
- `SafeArea` on all screens for notch and home indicator
- Bottom buttons padded with `EdgeInsets.fromLTRB(24, 0, 24, 32)` to clear home indicator

## Dark Mode Strategy
Implemented via `WeRoboThemeColors` extension with light/dark variants.

**Surface hierarchy (dark):**
| Token | Light | Dark |
|-------|-------|------|
| background | #F6F7F8 | #0F0F0F |
| surface | #FFFFFF | #1A1A1A |
| card | #EFF1F3 | #232528 |
| border | #CDD1D6 | #363840 |

**Color adjustments:**
- Primary sky blue (#20A7DB) works on dark backgrounds without change
- Accent green (#059669) lightens to #34D399 for dark mode readability
- Warning yellow (#FBBF24) stays unchanged
- Error red (#EF4444) stays unchanged
- Text primary: #000000 -> #F0F0F0
- Text secondary: #6B6B6B -> #999999
- Text tertiary: #8E8E8E -> #6B6B6B

**Chart adjustments:**
- Grid lines: lighter alpha on dark (0.15 instead of 0.3)
- Area fill gradients: reduce alpha by 30%
- Tooltip backgrounds: card color instead of white

**Implementation:** `WeRoboThemeColors` ThemeExtension with `.of(context)` accessor. All widgets use `tc.textPrimary`, `tc.card`, etc. for brightness-aware colors. Static `WeRoboColors.*` for brand constants that don't change.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-08 | Initial design system created | Created by /design-consultation based on Figma specs and CLAUDE.md tokens |
| 2026-04-08 | Accent green darkened #34D399 -> #059669 | WCAG AA contrast ratio (4.5:1 on white) |
| 2026-04-08 | Added spacing scale, responsive strategy, dark mode plan | Complete the design system for implementation consistency |
| 2026-04-09 | Competitive research: stay the course | Benchmarked against Toss, Robinhood, Wealthfront, Betterment, Kakao Pay. Current direction is category-literate. Efficient frontier is the true differentiator. |
| 2026-04-09 | Plain-language design principle adopted | User testing revealed "too complex" feedback. Every data point now has two layers: number + explanation. |
| 2026-04-09 | Chart simplified to 2 lines + toggle | Meeting requirement. Old 8-line chart replaced with portfolio + 7-asset avg benchmark. Toggle to show/hide benchmark. |
| 2026-04-09 | Market-relative risk scale (0-100) | Meeting requirement. Raw volatility replaced with intuitive 0-100 scale with Korean labels. |
| 2026-04-09 | Contribution analysis added | Meeting requirement. Per-asset return bars with plain-language commentary. |
| 2026-04-09 | Auto-rebalancing UI (toggle + explanation) | Meeting requirement. 10% drift rule explained in portfolio tab. Settings toggle for demo. |
| 2026-04-09 | Preview mode added | "로그인 없이 둘러보기" link on login screen for pre-auth browsing. |
| 2026-04-09 | Polish pass: 6 fixes | Text tertiary #C0C0C0->#8E8E8E (WCAG AA), cool-tinted neutrals, 7-color chart palette, elevation system, interactive states, animation constants |

## Competitive Positioning
Researched 2026-04-09. Key competitors: Toss Invest, Robinhood, Wealthfront, Betterment, Kakao Pay Securities.

**Category convergence:** Nearly every investment app uses white/dark + one blue accent + sans-serif. WeRobo's sky blue + Noto Sans is category-literate but not distinctive.

**Where WeRobo fits:**
- Closest to Betterment/Wealthfront (robo-advisor, beginner-friendly, portfolio-first)
- NOT competing with Toss/Robinhood (active trading, real-time tickers)
- Differentiated by efficient frontier visualization (no competitor offers this as a core UX)

**What competitors do well that we should note:**
- Toss: language simplification, beginner-first terminology, investment-as-simple-as-money-transfer
- Robinhood: color restraint (black/white/neutrals + one bold accent), elevated typography
- Wealthfront: mobile-centric, gets users to first portfolio in minimal steps
- Betterment: all-in-one net worth dashboard, trust through simplicity

**WeRobo's design edge:** The efficient frontier interaction. No competitor lets users physically explore the risk/return tradeoff. This is our signature moment, and the design should amplify it.

**Decision:** Stay the current course. Sky blue + clean fintech is the right baseline for a Korean robo-advisor capstone. The efficient frontier interaction is the differentiator, not the color palette.

## What This Design Is NOT
- Not a trading app (no real-time tickers, no buy/sell buttons, no red/green candles)
- Not a gamified finance app (no streaks, no achievements, no social pressure)
- Not a data dashboard (no dense tables, no multiple chart grids, no export buttons)
- It IS a calm, confident advisor that shows you your portfolio and helps you understand it
