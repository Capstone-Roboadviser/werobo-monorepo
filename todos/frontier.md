# Efficient Frontier Implementation

## Scope

This worktree touches only:
- `Front-End/robo_mobile/lib/screens/onboarding/onboarding_screen.dart`
- `Front-End/robo_mobile/lib/screens/onboarding/widgets/efficient_frontier_chart.dart`

No other files. Stay within these two files to avoid conflicts with other worktrees.

## Style rules (Eugene's preferences)

- Do NOT add Claude as a co-author on commits. No `Co-Authored-By` trailer. No `Generated with Claude Code` footer.
- No em dashes or en dashes anywhere. Use commas, periods, parentheses, or colons.
- Plain prose. Simple vocabulary. Short sentences.
- Do not use "quiet" or "quietly" in a figurative sense.
- Follow the project's CLAUDE.md (Flutter conventions, design tokens, theme).

## Meeting context

The Efficient Frontier chart is one of the first things users see during onboarding. The team wants it to feel less cramped and more readable. Specific points raised:
- Text and shapes were overlapping. The recent chart resize helped but more work is needed.
- The hint text "오른쪽으로 갈수록 수익이 높지만 위험도 커져요" breaks across lines awkwardly on some screens.
- The web version uses about a 1:4 (height:width) aspect ratio. The current app uses 1.2. The team wanted to try a wider ratio on the app and see if it reads better.
- The chart's starting coordinate (where the curve begins on the x axis) may need adjustment so the leftmost asset bubbles have more breathing room.
- The "시장 대비 약 52% 더 위험한" text must stay (교수님 request, replaces raw risk number).

## Todos

### 1. Hint text wrap check and fix

**Where:** `onboarding_screen.dart` lines 773 to 779.

The text lives inside `Expanded(child: Text(...))`. Today it wraps naturally based on the row's remaining width. The complaint is that the wrap point lands in a place that hurts readability.

Steps:
- Run the app on the iPhone 17 Pro simulator and screenshot the hint as it appears today.
- If the wrap is clearly bad (mid-clause, leaves orphan words), fix it. Options in order of preference:
  1. Shorten the copy so it fits one or two cleaner lines.
  2. Insert an explicit newline at a natural break (after "찾아보세요." stays as is, but add `\n` after the comma in "수익이 높지만 위험도 커져요" if it helps).
  3. Adjust the surrounding container width so the text has more room.
- If the wrap already reads fine after the chart resize, mark this todo done without code changes and note that in your commit message.

### 2. Frontier graph starting coordinate

**Where:** `efficient_frontier_chart.dart` line 28 and 29.

Today:
```dart
const double _kFrontierCurveStartX = 0.06;
const double _kFrontierCurveEndX = 0.94;
```

The curve starts at 6% of the chart width from the left. 윤화우 mentioned wanting the curve to start a bit further in so the leftmost asset bubble label has more room.

Steps:
- Try `_kFrontierCurveStartX = 0.10` and screenshot. If the leftmost bubble label no longer touches the chart edge, ship that value.
- Verify the rightmost bubble does not now get cramped. If it does, also raise `_kFrontierCurveEndX` only slightly (for example to 0.92) to keep symmetry.
- Verify the drag interaction still works at both ends. The hit testing math in `_screenToT` and `_frontierTForX` already uses these constants, so no other change is needed.

### 3. Aspect ratio decision

**Where:** `onboarding_screen.dart` line 719.

Today:
```dart
aspectRatio: 1.2,
```

The team mentioned a 1:4 ratio from the web (so AspectRatio of 4.0) but never agreed on a final value. 1.2 was the previous compromise.

Steps:
- Try `aspectRatio: 1.6` first, screenshot. This is roughly 16:10 which reads as a clear landscape chart on mobile without becoming a sliver.
- If it looks good and the bubble label layout still resolves (no overlapping), keep 1.6.
- If 1.6 looks too tall, try 2.0.
- Do not push past 2.5 on mobile. The chart needs enough vertical space for the curve to read as a curve and for the bubble labels to stack without collision.

Document the final value chosen in the commit message.

## After implementation

- Run `cd Front-End/robo_mobile && flutter analyze` and fix any new warnings.
- Run the app in the iOS simulator (UDID `E59D10D1-D076-4149-9AC9-ABFB4855F165`).
- Take a fresh screenshot of the Efficient Frontier screen after each change and save it for review.
- Commit each todo as a separate commit. Use messages like `frontier: widen aspect ratio to 1.6` or `frontier: pull curve start to 10% for label breathing room`.
