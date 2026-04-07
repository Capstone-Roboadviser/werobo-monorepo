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
Not currently implemented. When added:

**Surface hierarchy (dark):**
| Token | Light | Dark |
|-------|-------|------|
| background | #F5F5F5 | #0F0F0F |
| surface | #FFFFFF | #1A1A1A |
| card | #F0F0F0 | #252525 |
| border | #D3D3D3 | #333333 |

**Color adjustments:**
- Primary sky blue (#20A7DB) works on dark backgrounds without change
- Accent green (#059669) lightens to #34D399 for dark mode readability
- Warning yellow (#FBBF24) stays unchanged
- Error red (#EF4444) stays unchanged
- Text primary: #000000 -> #F0F0F0
- Text secondary: #6B6B6B -> #999999
- Text tertiary: #C0C0C0 -> #555555

**Chart adjustments:**
- Grid lines: lighter alpha on dark (0.15 instead of 0.3)
- Area fill gradients: reduce alpha by 30%
- Tooltip backgrounds: card color instead of white

**Implementation:** Use `WeRoboColors` with a `Brightness` parameter or a `ThemeExtension`. All color references already go through `WeRoboColors.*`, so the migration is mechanical.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-08 | Initial design system created | Created by /design-consultation based on Figma specs and CLAUDE.md tokens |
| 2026-04-08 | Accent green darkened #34D399 -> #059669 | WCAG AA contrast ratio (4.5:1 on white) |
| 2026-04-08 | Added spacing scale, responsive strategy, dark mode plan | Complete the design system for implementation consistency |

## What This Design Is NOT
- Not a trading app (no real-time tickers, no buy/sell buttons, no red/green candles)
- Not a gamified finance app (no streaks, no achievements, no social pressure)
- Not a data dashboard (no dense tables, no multiple chart grids, no export buttons)
- It IS a calm, confident advisor that shows you your portfolio and helps you understand it
