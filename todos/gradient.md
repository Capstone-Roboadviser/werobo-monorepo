# Gradient Bar and Asset Color Implementation

## Scope

This worktree touches only:
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/asset_weight.dart`
- `Front-End/robo_mobile/lib/app/theme.dart`

No other files. Stay within these two files to avoid conflicts with other worktrees.

## Style rules (Eugene's preferences)

- Do NOT add Claude as a co-author on commits. No `Co-Authored-By` trailer. No `Generated with Claude Code` footer.
- No em dashes or en dashes anywhere. Use commas, periods, parentheses, or colons.
- Plain prose. Simple vocabulary. Short sentences.
- Do not use "quiet" or "quietly" in a figurative sense.
- Follow the project's CLAUDE.md (Flutter conventions, design tokens, theme).

## Meeting context

The "gradient bar" lives below the Efficient Frontier and shows the user's selected portfolio's asset breakdown. The team agreed on these changes:
- Make the bar thinner and feel less heavy.
- Add "저위험" text on the left end and "고위험" text on the right end so users understand the bar maps to risk.
- Fix the colors per asset class so users learn each color over time. Current colors are all shades of orange (`assetTier1` through `assetTier5`), which makes it hard to tell segments apart. The team wants distinct, recognizable colors.
- Keep the default (현금성자산, the leftmost segment) black or near-black so it reads as a baseline, and use distinct hues (red, blue, etc.) for the others.

## Todos

### 1. Verify horizontal orientation and thin the bar

**Where:** `asset_weight.dart` `AssetWeightBar` widget.

The bar is already horizontal (segments laid out in a `Row`). The change here is purely visual: make it thinner.

- Change the default `height` parameter from 28 to 14. Half height. This will read as a thin band rather than a chunky bar.
- Update the comment block at the top of the class to mention the new thinned look.

If any caller in onboarding_screen.dart passes a custom `height` value, leave that override alone. Only the default changes.

### 2. Add 저위험 and 고위험 end labels

**Where:** `asset_weight.dart` `AssetWeightBar.build`.

Currently the bar renders as `tooltipRow` plus the segmented bar in a `Column`. Add a thin row above the bar (or wrap the bar in a `Row`) that places "저위험" on the far left and "고위험" on the far right.

Style:
- Use `WeRoboTypography.caption`.
- Color: `tc.textSecondary`.
- Vertical alignment: tightly above the bar with a 4 pixel gap.

Layout option:
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('저위험', style: ...),
    Text('고위험', style: ...),
  ],
)
```

Place this row above the bar but below the tooltip row. Order: tooltip, end labels, bar.

### 3. Distinct asset class colors

**Where:** `theme.dart` lines 35 to 53.

Today the asset palette is five shades of orange:
```dart
static const Color assetTier5 = Color(0xFFFFC091); // 현금성자산
static const Color assetTier4 = Color(0xFFFFB57D); // 단기채권
static const Color assetTier3 = Color(0xFFFFAA69); // 인프라채권, 금
static const Color assetTier2 = Color(0xFFFF9F52); // 미국가치주
static const Color assetTier1 = Color(0xFFFE9337); // 미국성장주, 신성장주
```

Replace with distinct colors per asset class. Guidance from the team:
- 현금성자산 (cash): near-black or very dark gray, reads as baseline. Try `Color(0xFF2A2A2A)`.
- 단기채권: a calm blue. Try `Color(0xFF4A7FB8)`.
- 인프라채권: a darker blue or teal. Try `Color(0xFF2C5F8D)`.
- 금: gold or warm yellow. Try `Color(0xFFD4A24A)`.
- 미국가치주: muted green. Try `Color(0xFF6FA66A)`.
- 미국성장주: brand orange (keep the existing `primary` `0xFFFE9337`).
- 신성장주: a deeper red. Try `Color(0xFFC85A4A)`.

These are starting points. If the result looks chaotic, dial saturation down. Aim for a palette that reads as harmonious when all 7 segments appear together. Test on the gradient bar with a realistic weight mix.

Update the `_assetPalette` list to match the new mapping:
```dart
static const List<Color> _assetPalette = [
  assetCash,        // index 0
  assetShortBond,   // index 1
  assetInfraBond,   // index 2
  assetGold,        // index 3
  assetUSValue,     // index 4
  assetUSGrowth,    // index 5
  assetNewGrowth,   // index 6
];
```

Rename the constants from `assetTier1` through `assetTier5` to semantic names (`assetCash`, `assetShortBond`, `assetInfraBond`, `assetGold`, `assetUSValue`, `assetUSGrowth`, `assetNewGrowth`). Update any callers in asset_weight.dart and theme.dart accordingly. If callers exist outside these two files, search for them with grep and fix them, but only touch those callers if it is a name swap. Do not change behavior elsewhere.

Also update the `primaryLight` reference at line 10 if it pointed at `assetTier5`. Pick a new appropriate `primaryLight` (a lighter shade of `primary` orange).

### 4. Pie chart and donut chart impact check

If `_assetPalette` is used by other charts (likely `vestor_pie_chart.dart` or `portfolio_charts.dart`), verify the new palette looks reasonable in those charts too. Take a screenshot and review. Do not edit those files (they belong to another worktree's scope) unless an import-only fix is needed.

## After implementation

- Run `cd Front-End/robo_mobile && flutter analyze` and fix any new warnings.
- Run the app in the iOS simulator (UDID `E59D10D1-D076-4149-9AC9-ABFB4855F165`).
- Screenshot the onboarding frontier screen to verify the new gradient bar with end labels and the distinct colors.
- Commit each todo as a separate commit. Use messages like `gradient bar: add 저위험 고위험 end labels` or `theme: distinct asset class colors`.
