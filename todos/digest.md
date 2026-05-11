# Digest Screen Implementation

## Scope

This worktree touches only:
- `Front-End/robo_mobile/lib/screens/home/digest_screen.dart`
- `Front-End/robo_mobile/lib/screens/home/widgets/return_bar_chart.dart` (only if a height tweak is needed)
- `Front-End/robo_mobile/lib/screens/home/widgets/driver_card.dart` (only if you delete its usage entirely; do not edit its internals)

Do NOT touch `home_tab.dart`. The home screen issue feed lives in a separate worktree.

## Style rules (Eugene's preferences)

- Do NOT add Claude as a co-author on commits. No `Co-Authored-By` trailer. No `Generated with Claude Code` footer.
- No em dashes or en dashes anywhere. Use commas, periods, parentheses, or colons.
- Plain prose. Simple vocabulary. Short sentences.
- Do not use "quiet" or "quietly" in a figurative sense.
- Follow the project's CLAUDE.md.

## Color tokens

The screen already uses `tc.accent` (green) for gains and `WeRoboColors.error` (red) for losses. Keep that for consistency with the rest of the app inside this screen. Korean-convention red/blue is only being introduced on the home hero in another worktree. Do not propagate it here in this pass.

## Meeting context

The digest screen today reads as one period summary with drivers, detractors, a return bar chart, and narrative. The team wants Toss-style period-based summaries with clean time slicing.

교수님 emphasis: keep the UI simple. One or two clear messages per section. Daily noise is meaningless. Show meaningful periods, not "what happened on each calendar day."

## Todos

### 1. Period selector at the top

**Where:** `digest_screen.dart` `_DigestContent.build` (around line 157), insert after `_DateBadge` (around line 168).

Add a horizontal chip row with these labels and `Duration` mappings:
- 1주 (7 days)
- 1개월 (30 days, default)
- 3개월 (90 days)
- 6개월 (180 days)
- 1년 (365 days)

State: hoist a `_period` int (index 0 to 4) to `_DigestScreenState`. Default `_period = 1` (1개월). Pass to `_DigestContent` as a parameter.

Backend wiring: if `MobileBackendApi.instance.fetchDigest` accepts a period parameter, pass it. If not, refetch the same digest for now and just visually highlight the active chip. Log a TODO that says the backend needs a `period` query param.

Chip row spec:
- Container: full width, 36px tall, horizontal scroll if cramped (use `SingleChildScrollView` with `Axis.horizontal`)
- Per chip:
  - Height: 28px
  - Horizontal padding: 12px
  - Border radius: 14px (pill)
  - Active: background `WeRoboColors.primary`, text `WeRoboColors.white`, font w600 12px NotoSansKR
  - Inactive: background `tc.surface`, 1px border `tc.border`, text `tc.textSecondary`, font w500 12px NotoSansKR
  - Gap between chips: 8px
  - Tap target: full chip, no separate `GestureDetector` padding
- Gap below chip row: 16px

Pattern reference: the home screen's range chips at `home_tab.dart` line 1089 (do not import code from there, just match the look).

### 2. Period summary card

**Where:** `digest_screen.dart` `_SummaryCard` (lines 260 onward).

Replace the current internals to read three lines, in this exact order, with no chart inside the card:

```
[period label]                        caption 12px tc.textSecondary
[date range subhead]                  caption 11px tc.textTertiary
[+₩1,234,567]                         number 28px (WeRoboTypography.number), returnColor
[+5.23%]                              body 16px IBMPlexSans w600, returnColor
[one-line interpretation sentence]    bodySmall 14px tc.textSecondary, max 2 lines
```

Layout:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(periodLabel, style: WeRoboTypography.caption.copyWith(color: tc.textSecondary)),
    const SizedBox(height: 2),
    Text(dateRangeSubhead, style: WeRoboTypography.caption.copyWith(color: tc.textTertiary, fontSize: 11)),
    const SizedBox(height: 12),
    Text(formattedWon, style: WeRoboTypography.number.copyWith(color: returnColor)),
    const SizedBox(height: 4),
    Text(formattedPct, style: TextStyle(fontFamily: WeRoboFonts.english, fontSize: 16, fontWeight: FontWeight.w600, color: returnColor)),
    const SizedBox(height: 12),
    Text(interpretation, style: WeRoboTypography.bodySmall.copyWith(color: tc.textSecondary, height: 1.5)),
  ],
)
```

Card wrapper:
- Padding 20px
- Background `tc.surface`
- Border radius 16 (`WeRoboColors.radiusXL`)
- 1px border `tc.border`
- No shadow

`periodLabel` examples: "최근 한 달", "지난 일주일", "최근 3개월".
`dateRangeSubhead` example: "4월 11일 ~ 5월 11일".
`interpretation` template: pick one based on the digest values:
- If `digest.totalReturnPct > 0`: "이 기간 동안 자산이 ${_formatWon(digest.totalReturnWon.abs())} 늘었어요."
- If `< 0`: "이 기간 동안 자산이 ${_formatWon(digest.totalReturnWon.abs())} 줄었어요."
- If excess return vs market is large positive: append " 시장보다 ${excess.toStringAsFixed(1)}% 더 벌었어요."

Remove the existing `_volatilityContextText` block from the card. Variance signaling moves to the timeline (todo 3).

### 3. Timeline-style signal list

**Where:** `digest_screen.dart` `_DigestContent.build` after the summary card. Replace the existing drivers block, detractors block, and `ReturnBarChart` block with a single timeline.

Section header above the timeline:
```dart
Padding(
  padding: const EdgeInsets.only(top: 24, bottom: 8),
  child: Text(
    '이 기간 동안 일어난 일',
    style: WeRoboTypography.heading3.copyWith(color: tc.textPrimary),
  ),
)
```

Timeline row spec:
- Row height: 60px
- Horizontal padding inside the row: 0 (the screen padding already handles outer gutter)
- Vertical padding: 12px top, 12px bottom
- Three columns left to right:
  - Date pill: fixed 64px width, right-aligned text, "5월 1일" format, `WeRoboTypography.caption.copyWith(color: tc.textTertiary)`
  - Icon: 20x20, 16px gap on each side, color from event type (see icon map below)
  - Description: takes remaining width, `WeRoboTypography.bodySmall.copyWith(color: tc.textPrimary, height: 1.5)`, max 2 lines, ellipsis after that
- Vertical timeline rail: 2px wide line in `tc.border`, runs through the icon column from top of the section to bottom. Place each icon centered on the rail. Skip the rail behind the icon (or use a small white circle behind the icon to "punch through" the line).
- Divider between rows: none (the rail provides the visual continuity)

Icon map:
- Driver event (contribution positive): `Icons.trending_up_rounded`, color `tc.accent`
- Detractor event (contribution negative): `Icons.trending_down_rounded`, color `WeRoboColors.error`
- Volatility signal: `Icons.show_chart_rounded`, color `WeRoboColors.warning`
- News-driven: `Icons.article_outlined`, color `WeRoboColors.assetTier3`
- Rebalance: `Icons.auto_graph_rounded`, color `WeRoboColors.primary`

Event derivation: the `MobileDigestResponse` already has `drivers`, `detractors`, `triggerSigmaMultiple`, `sourcesUsed`. There is no per-event date field today. Use the period midpoint as the placeholder date for derived events, and call out this approximation in the commit message. Add `// TODO: surface per-event dates from backend` next to the synthesis.

Order rows newest first. Cap the list at 8 visible items. If more exist, append a non-tappable "더 보기" link in `WeRoboColors.primary` 13px w600 (route to be wired later).

### 4. Simplification pass

**Where:** `digest_screen.dart` `_DigestContent`.

After the changes above, remove:
- The standalone `_SectionHeader` widgets for "상승 기여 종목" and "하락 기여 종목" sections (their content is in the timeline now).
- The `DriverCard` mapping blocks (lines around 192 and 206). The timeline replaces them.
- The `ReturnBarChart` block at lines 176 to 182. The timeline communicates the same information.

Keep:
- Date badge at top (the period selector replaces its role as a date marker, but the badge still adds context, so leave one)
- Disclaimer at the bottom: drop it unless it carries legal language we cannot remove. Search for the disclaimer source. If it is hardcoded fluff, delete. If it comes from `digest.disclaimer` and is a real legal statement, keep but move into a small caption at the very bottom, 11px tc.textTertiary, 32px top margin.

The final scroll order should read:
1. Date badge (small)
2. Period chip row
3. Summary card
4. Timeline section header + timeline
5. Optional disclaimer

Nothing else competes.

### 5. Empty and loading states

**Where:** `digest_screen.dart` `_loading` and `_error` branches (around lines 108 to 116), and the timeline section.

Loading: keep existing `DigestLoading` widget for the initial fetch.

Error: keep existing `_ErrorState`.

Empty timeline (digest loaded but no driver, detractor, volatility, or news data):
```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Center(
    child: Column(
      children: [
        Icon(Icons.timelapse_rounded, size: 32, color: tc.textTertiary),
        const SizedBox(height: 12),
        Text(
          '이 기간 동안 큰 변화는 없었어요.',
          style: WeRoboTypography.bodySmall.copyWith(color: tc.textSecondary),
        ),
      ],
    ),
  ),
)
```

Show this inside the timeline section. The summary card above still renders.

## After implementation

- Run `cd Front-End/robo_mobile && flutter analyze` and fix any new warnings.
- Run the app in the iOS simulator (UDID `E59D10D1-D076-4149-9AC9-ABFB4855F165`).
- Screenshot at default period (1개월) and after switching to 1주 and 3개월. Save for review.
- Commit each todo as a separate commit. Use messages like `digest: period selector chips`, `digest: simplify summary card`, `digest: timeline replaces drivers/detractors`, `digest: empty state for quiet periods`.
