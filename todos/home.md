# Home Screen Implementation

## Scope

This worktree touches only:
- `Front-End/robo_mobile/lib/screens/home/home_tab.dart`

No other file in this list. Stay within this file to avoid conflicts with other worktrees.

## Style rules (Eugene's preferences)

- Do NOT add Claude as a co-author on commits. No `Co-Authored-By` trailer. No `Generated with Claude Code` footer.
- No em dashes or en dashes anywhere. Use commas, periods, parentheses, or colons.
- Plain prose. Simple vocabulary. Short sentences.
- Do not use "quiet" or "quietly" in a figurative sense.
- Follow the project's CLAUDE.md (Flutter conventions, design tokens, theme).

## Color tokens you will need

The theme does not have semantic gain/loss tokens. Eugene specified Korean convention (red gain, blue loss) in the meeting, which is the opposite of the Korean stock market sign convention but matches what he wrote down. Use these inline hex codes:

```dart
const Color gainColor = Color(0xFFE5455F); // warm red for positive
const Color lossColor = Color(0xFF3182F6); // bright blue for negative
```

Add them as private file-level constants at the top of `home_tab.dart` (right after imports). Do not edit `theme.dart` for this. Other worktrees own that file.

The rest of the app currently uses `tc.accent` (green) for gain and `WeRoboColors.error` (red) for loss in `_PerformanceBadge` and the drag card. That mismatch is fine for this pass. Leave those existing usages alone. Only the new hero block uses the new red/blue tokens.

## Meeting context

- Customers want to see the gap between their portfolio and the market widening over time, not daily noise.
- The home screen should lead with total return (손익 won + %), then invested and current value, then the chart.
- When users drag on the chart, they want cumulative return at that point, not day over day.
- They also want to compare two drag points and see which assets gained or lost contribution between them.
- Bear market top stocks should be the ones that defended best (least dropped), not the biggest weights.
- UI must stay simple. No information overload.

## Todos

### 1. Hero layout reorder

**Where:** `home_tab.dart` `_PortfolioHeroChartState.build` lines 866 to 907.

Replace the existing label plus value plus badge block with this exact structure:

```
[총손익 label]              caption, 13px, tc.textSecondary
[+₩1,234,567]  [+5.23%]     34px / 22px IBMPlexSans w700/w600, gainColor or lossColor
                             baseline aligned, 8px gap between them
                             ↓ 12px gap
[투자금액 ₩X · 평가금액 ₩Y]  bodySmall, 14px
                             label color: tc.textSecondary
                             amount color: tc.textPrimary, w600, IBMPlexSans
                             4px gap between label and amount within each pair
                             12px gap between pairs (with 1px tc.border divider, 12px tall, centered)
                             ↓ 20px gap
[chart]                      existing chart block
```

Exact code skeleton (adapt names, do not paste verbatim without checking nearby variables):

```dart
final isGain = displayChange >= 0;
final pnlColor = isGain ? gainColor : lossColor;
final sign = isGain ? '+' : '';
final formattedPnl = '$sign₩${_formatCurrency(displayChange.abs().toInt())}';
if (!isGain) {
  // amount itself shows the minus from _formatCurrency, do not double up
}
final formattedPct = '$sign${displayChangePct.toStringAsFixed(2)}%';

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      '총손익',
      style: WeRoboTypography.caption.copyWith(
        color: tc.textSecondary,
        fontSize: 13,
      ),
    ),
    const SizedBox(height: 6),
    Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          formattedPnl,
          style: TextStyle(
            fontFamily: WeRoboFonts.english,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: pnlColor,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formattedPct,
          style: TextStyle(
            fontFamily: WeRoboFonts.english,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: pnlColor,
            height: 1.2,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _InvestedVsCurrentRow(
      invested: accountSummary?.investedAmount ?? startValue,
      current: currentValue,
    ),
    const SizedBox(height: 20),
    // existing chart LayoutBuilder block stays as is
    ...
  ],
);
```

`_InvestedVsCurrentRow` is a new private widget you add to this file. Spec:

```dart
class _InvestedVsCurrentRow extends StatelessWidget {
  final double invested;
  final double current;
  const _InvestedVsCurrentRow({required this.invested, required this.current});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final labelStyle = WeRoboTypography.bodySmall.copyWith(
      color: tc.textSecondary,
    );
    final amountStyle = WeRoboTypography.bodySmall.copyWith(
      color: tc.textPrimary,
      fontWeight: FontWeight.w600,
      fontFamily: WeRoboFonts.english,
    );
    return Row(
      children: [
        Text('투자금액', style: labelStyle),
        const SizedBox(width: 4),
        Text('₩${_formatCurrency(invested.toInt())}', style: amountStyle),
        const SizedBox(width: 12),
        Container(width: 1, height: 12, color: tc.border),
        const SizedBox(width: 12),
        Text('평가금액', style: labelStyle),
        const SizedBox(width: 4),
        Text('₩${_formatCurrency(current.toInt())}', style: amountStyle),
      ],
    );
  }
}
```

Keep drag-aware behavior: when `crosshairValue != null`, `displayChange` and `displayChangePct` already reflect the touched point. The new layout reuses those values directly.

Remove the existing `_PerformanceBadge` from the hero. Keep the class definition in the file for now in case it is used elsewhere. Grep first. If nothing else uses it, delete the class.

### 2. Drag display: cumulative return instead of day over day

**Where:** `home_tab.dart` `_buildCardData` lines 653 to 816 and `_DragContextCard` at around line 1929.

Replace day-over-day math with cumulative-from-start math. The chart's first visible point is `valuePts.first`. Touch is `valuePts[ti]`.

Portfolio cumulative:
```dart
final base = valuePts.first.value;
if (base == 0) return null;
final portfolioPct = (valuePts[ti].value - base) / base;
```

Market cumulative: the comparison line values are already rebased to 0 at the first visible market date (see `_marketSeries` at line 562). Use that directly:
```dart
final mPts = _marketSeries(valuePts);
double? marketPct;
if (mPts.isNotEmpty) {
  // find the market point closest to the touched date
  final touchDate = valuePts[ti].date;
  final mIdx = mPts.indexWhere(
    (p) => !p.date.isBefore(touchDate),
  );
  marketPct = mIdx >= 0 ? mPts[mIdx].value : mPts.last.value;
}
```

Asset cumulative contribution: today `dayOverDayAssetReturns(date)` on `PortfolioState` returns day-over-day percentages. You need cumulative-from-start values up to the touched date.

Two options:

**Option A (preferred):** add a sibling method on `PortfolioState`:
```dart
// portfolio_state.dart
Map<String, double> cumulativeAssetReturnsUpTo(DateTime date) { ... }
```
This requires touching `portfolio_state.dart` which is outside this worktree's scope. If you go this route, ask Eugene first before editing `portfolio_state.dart`.

**Option B (fallback, no scope creep):** compute cumulative locally in `_buildCardData` using the asset history already in `state`. Walk the daily returns from start to the touched date and compound them:
```dart
final allReturns = <String, List<({DateTime date, double pct})>>{};
// gather daily returns up to ti by calling dayOverDayAssetReturns for each
// date in valuePts.sublist(1, ti + 1).
// For each asset, compute (1 + r1)(1 + r2)... - 1.
```
This is more expensive per drag frame. If perf is bad, cache the cumulative arrays keyed by `_range` in `_PortfolioHeroChartState` and invalidate when the range changes.

Pick Option B for now. Add a TODO comment that says: `// TODO: move to PortfolioState.cumulativeAssetReturnsUpTo for shared caching`.

Update the card's labels (in `_DragContextCard`) from "전날 대비" to "누적 (시작 대비)". Remove any "Day-over-day" code comments.

### 3. Two-point drag comparison for contribution

**Where:** `home_tab.dart` `_PortfolioHeroChartState` drag interaction and `_DragContextCard`.

UX spec:
- Single tap and drag: shows single-point card with cumulative numbers (todo 2).
- Long-press on the chart: sets that index as `_anchorIndex`. The chart shows a vertical line at the anchor in `tc.textSecondary` 0.5 alpha 1px dashed.
- After an anchor is set, any subsequent drag puts the card in compare mode: shows `[anchor date] → [touched date]` plus contribution deltas.
- Tap outside the chart, or tap a small "✕" inside the compare card, clears the anchor.

State additions to `_PortfolioHeroChartState`:
```dart
int? _anchorIndex;
```

Compare card spec (replace single card render when `_anchorIndex != null && _touchIndex != null && _anchorIndex != _touchIndex`):
- Width: 240px
- Height: 152px
- Padding: 12px all sides
- Background, border radius, frosted treatment: copy from existing `_DragContextCard` (search for `BackdropFilter` and frosted glass terms).
- Layout:

```
┌────────────────────────────────────────┐
│ 5월 1일 → 5월 11일               [✕]    │ ← 11px caption tc.textTertiary, right-aligned ✕ button 16x16
├────────────────────────────────────────┤
│ 포트폴리오   +3.4%  →  +5.1%   +1.7% ▲  │ ← row 1
│ 미국성장주   +2.1%  →  +4.0%   +1.9% ▲  │ ← row 2 (top contributor by |Δ|)
│ 단기채권     +0.6%  →  +0.4%   -0.2% ▼  │ ← row 3 (second by |Δ|)
└────────────────────────────────────────┘
```

Each comparison row:
- Height: 28px
- Label (asset name or "포트폴리오"): 12px caption, tc.textPrimary, fixed-width 80px
- A% and B%: 13px IBMPlexSans w500, monospace via `fontFeatures: [FontFeature.tabularFigures()]`, 56px fixed width each, right-aligned
- Arrow "→" between: 12px tc.textTertiary, 12px gap each side
- Delta: 12px IBMPlexSans w600, color `gainColor` if positive change, `lossColor` if negative
- Trailing ▲ / ▼ glyph: 10px, same color as delta

The "포트폴리오" row is always shown. The next two rows are the top 2 contributors selected by `|deltaB - deltaA|`, sorted descending.

If contribution data is unavailable for either point, render the row with `--%` placeholders rather than dropping the row.

Long-press detection: add `onLongPress: (details) { setState(() { _anchorIndex = idx; }); }` to the existing `GestureDetector` that wraps the chart. Use the same x-to-index math already in `onPanDown` and `onPanUpdate`.

Add an `IconButton` inside the compare card for the close action:
```dart
SizedBox(
  width: 16,
  height: 16,
  child: IconButton(
    padding: EdgeInsets.zero,
    iconSize: 12,
    icon: Icon(Icons.close, color: tc.textTertiary),
    onPressed: () => setState(() => _anchorIndex = null),
  ),
)
```

### 4. Permanent 한줄평 for top 2 contributors

**Where:** new section inside `_PortfolioHeroChartState.build`, after the chart's range chips (around line 1136), before the closing of the outer Column.

Render two text lines (no card, no border, just text). Spec:

```dart
Padding(
  padding: const EdgeInsets.symmetric(vertical: WeRoboSpacing.sm),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${top1.nameKo}가(이) 이번 기간 수익에 ${_formatSignedWon(top1.contributionWon)} 기여했어요.',
        style: WeRoboTypography.bodySmall.copyWith(
          color: tc.textSecondary,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '${top2.nameKo}가(이) ${_formatSignedWon(top2.contributionWon)} 영향을 줬어요.',
        style: WeRoboTypography.bodySmall.copyWith(
          color: tc.textSecondary,
          height: 1.5,
        ),
      ),
    ],
  ),
)
```

Source: reuse the data path that powers `_topContribution` (line 1308). Take the top 2 by `|contributionWon|`. If `top1.contributionWon >= 0` use "기여했어요", otherwise "영향을 줬어요". Pick the postposition (가/이) by the last character of the name. There is likely a helper in the file already (grep for `Postpos` or `가/이`); if not, write a small private helper.

If digest data is not yet loaded, render two skeleton rows: same height, light gray bar at `tc.border.withValues(alpha: 0.3)` width 60% and 50%.

### 5. Fint-style notification feed restructure

**Where:** `home_tab.dart` `_PortfolioIssueFeed` and `_PortfolioIssueItem` lines 1144 to 1476.

Current items render as: icon, eyebrow, title, body, trailing arrow. The team wants this tighter.

Target row spec:
- Row height: 56px
- Horizontal padding: 16px
- Vertical padding: 12px
- Icon: 20x20, left-aligned, color from existing item.iconColor
- Gap between icon and text: 12px
- Text: single line, title in `WeRoboTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: tc.textPrimary)`, ellipsis on overflow
- Date pill (right side): use the existing `eyebrow` value, render in `WeRoboTypography.caption.copyWith(color: tc.textTertiary)`. No background pill, just text.
- No trailing arrow chevron. Tap is implied.
- Divider between rows: 1px hairline `tc.border.withValues(alpha: 0.3)`, 16px left inset (aligned past the icon)

Drop the eyebrow above the title. Drop the body line. The title alone carries the meaning. Examples:
- "최근 한 달 다이제스트가 도착했어요" instead of eyebrow "최근 한 달" plus title "다이제스트" plus body sentence
- "미국성장주가 ₩340,000 기여했어요"
- "시장 변동성이 평소보다 2.1배 컸어요"
- "신규 알고리즘 시그널이 발생했어요"

Recompose the items in `_buildItems` (line 1201) to produce a single title string per item that captures what mattered. The existing body texts can be reused as titles after small wording tweaks.

Cap items at 3 on the home screen (was 5). If there are more, append a non-tappable last row "더 보기" in `WeRoboColors.primary` 13px w600. The route does not need to exist yet; render a `SnackBar` with "준비 중" for now.

Container wrapper:
- White surface `tc.surface`
- Border radius 12 (WeRoboColors.radiusL)
- 1px border `tc.border`
- No shadow

### 6. Bear market top stocks sort

**Where:** `home_tab.dart` lines 727 to 729.

Current:
```dart
if (portfolioPct >= 0) {
  entries.sort((a, b) => b.pct.compareTo(a.pct));
} else {
  entries.sort((a, b) => a.pct.compareTo(b.pct));
}
```

Target:
```dart
entries.sort((a, b) => b.pct.compareTo(a.pct));
```

Update the inline comment above the sort to read:
```dart
// Highest contribution first either way. In up days these are the
// top gainers. In down days these are the assets that defended best
// (least negative, sometimes positive), surfacing strength rather
// than dwelling on the biggest losses.
```

## After implementation

- Run `cd Front-End/robo_mobile && flutter analyze` and fix any new warnings.
- Run the app in the iOS simulator (UDID `E59D10D1-D076-4149-9AC9-ABFB4855F165`) and verify each change.
- Verification per todo:
  - Todo 1: drag chart, watch hero numbers update with red on gain, blue on loss.
  - Todo 2: drag and confirm the card percentages match what you'd compute from the visible first point.
  - Todo 3: long-press to set anchor, drag elsewhere, see the compare card. Tap ✕ to clear.
  - Todo 4: two text lines under the chart, even when not dragging.
  - Todo 5: home feed shows compact rows, max 3, with date on the right.
  - Todo 6: pick a 1주 view where the portfolio dropped. Verify the top 2 are the least-dropped (or positive) assets, not the worst.
- Commit each todo as a separate commit. Use plain commit messages like `home: lead with total return on hero`, `home: cumulative return on drag`, `home: two-point compare card`, `home: permanent contribution one-liners`, `home: tighten issue feed rows`, `home: bear-day top defenders`.
