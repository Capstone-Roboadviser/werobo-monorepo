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

**Neutrals:** White (#FFFFFF) surface, #F0F0F0 cards, #D3D3D3 borders, #000000 primary text, #6B6B6B secondary text, #C0C0C0 tertiary text.

**Chart palette:** 7 fixed colors per portfolio category. Consistent across all investment types so users build visual memory of sector colors.

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

## Component Vocabulary
- **Cards:** 12px radius, #F0F0F0 background, no border. Content-first.
- **Buttons:** 52px height, 12px radius, full-width primary. Outline variant for secondary actions.
- **Charts:** CustomPaint only. No charting libraries. Touch crosshairs for exploration. Gradient area fills for trend visualization.
- **Navigation:** Bottom tab bar with 4 items. Active = primary color with tinted background. Pill-style page indicators for onboarding.

## Layout Principles
- 24px horizontal padding on all screens
- 28px vertical spacing between major sections
- 16px spacing between related elements
- SafeArea on all screens (iOS notch/home indicator)
- SingleChildScrollView with BouncingScrollPhysics for scrollable content

## Interaction Patterns
- **Efficient frontier:** The signature interaction. User drags a dot along a curve to choose risk/return balance. Risk/return stats update in real-time. Page swipe is disabled during drag to prevent conflict.
- **Portfolio comparison:** 3-chip type selector with animated donut chart and rolling number stats. Users can compare before committing.
- **Pie chart sectors:** Tap a sector to see constituent ETF tickers in the center. Builds trust through transparency.

## What This Design Is NOT
- Not a trading app (no real-time tickers, no buy/sell buttons, no red/green candles)
- Not a gamified finance app (no streaks, no achievements, no social pressure)
- Not a data dashboard (no dense tables, no multiple chart grids, no export buttons)
- It IS a calm, confident advisor that shows you your portfolio and helps you understand it
