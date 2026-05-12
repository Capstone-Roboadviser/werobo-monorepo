# AI 요약 Bottom Sheet — Design

Status: Approved 2026-05-12
Author: honge6090 + Claude

## Problem

Tapping the AI 요약 card on the home tab currently navigates with a full-page
fade route to `DigestScreen`. The interaction feels heavyweight for what is
essentially a contextual detail panel, and the AppBar + back button add chrome
that competes with the digest's own header (return amount, date range).

Reference behavior we want to match (Toss Securities AI summary): a sheet that
slides up from the bottom, covers most of the screen, has a drag handle and an
X close button, and shows the AI report directly with no separate page title.

## Scope

In scope:

- Replace the full-page presentation of `DigestScreen` with a modal bottom
  sheet that slides up from below.
- Apply the new presentation to both entry points: the AI 요약 card in
  `_PortfolioIssueFeed` and the standalone `_DigestBanner`.
- Reuse the existing digest content (return summary card, narrative, drivers,
  detractors, disclaimer) verbatim. No content restructuring in this pass.
- Preserve the existing fetch logic, including the skip-loading-animation
  behavior when the current digest has already been seen.

Out of scope (deferred to follow-up):

- Restructuring the detail content (related companies, tag chips, sources row
  styled like the Toss reference).
- Adding multi-snap drag points (half-height vs full-height).
- Deep linking into the AI 요약 sheet from outside the home tab.

## User-facing behavior

1. User taps the AI 요약 card (or the standalone digest banner) on the home tab.
2. A modal bottom sheet slides up from the bottom edge in roughly 250ms using
   the standard Flutter `showModalBottomSheet` curve.
3. The sheet settles at 92% of screen height. About 8% of the home tab remains
   visible at the top under a dimmed scrim.
4. The sheet's top corners are rounded at 20px. A 36 by 4 pixel drag handle
   sits 8 pixels from the top edge, horizontally centered. A 24px X icon sits
   at the top-right with a 44 by 44 pixel tap target.
5. The body inside the sheet is scrollable and contains the existing digest
   content in the existing order: date badge, summary card, return bar chart,
   drivers, detractors, disclaimer.
6. The user dismisses the sheet by tapping the X, swiping down on the sheet,
   or tapping the dimmed scrim. Android's back gesture and back button also
   dismiss it.
7. While the digest is loading the body shows the existing `DigestLoading`
   widget. If the request fails the body shows the existing `_ErrorState`.

## Architecture

### New file

`Front-End/robo_mobile/lib/screens/home/widgets/digest_sheet.dart`

Public surface:

- `class DigestSheet extends StatefulWidget` — the body widget. Owns the
  fetch + loading/error/digest state machine. Identical logic to the current
  `_DigestScreenState`, including the `hasSeenCurrentDigest` short circuit
  and the 5500ms minimum loading duration for first-time digests.
- `static Future<void> DigestSheet.show(BuildContext context)` — convenience
  that calls `showModalBottomSheet` with the right parameters and returns
  when the sheet is dismissed.

Private widgets in the same file (moved from `digest_screen.dart`):

- `_DigestSheetShell` — provides the drag handle row, the X close button, and
  a slot for the scrollable body. Reads colors from
  `WeRoboThemeColors.of(context)`. No business logic.
- `_DigestContent`, `_ErrorState`, `_SummaryCard`, `_DateBadge`,
  `_SectionHeader`, and the file-private helpers `_formatWon`,
  `_formatSignedWon` (whichever live in `digest_screen.dart` today).

### Deleted file

`Front-End/robo_mobile/lib/screens/home/digest_screen.dart`

No other file imports it after this change.

### Changed file

`Front-End/robo_mobile/lib/screens/home/home_tab.dart`

- Remove `import 'digest_screen.dart';`.
- Add `import 'widgets/digest_sheet.dart';`.
- Replace the `onDigestTap` body on the `_PortfolioIssueFeed` instance:
  the current `Navigator.push(context, WeRoboMotion.fadeRoute<void>(const
  DigestScreen()))` becomes `DigestSheet.show(context)`.
- Replace the `_DigestBanner` `onTap` body identically.

## `showModalBottomSheet` configuration

`DigestSheet.show` wraps:

```dart
showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: true,
  enableDrag: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.4),
  builder: (_) => const DigestSheet(),
);
```

Inside `DigestSheet.build`:

```dart
return ConstrainedBox(
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.92,
  ),
  child: _DigestSheetShell(child: _renderBody()),
);
```

`_renderBody()` returns the loading widget, the error widget, or the
`_DigestContent` based on current state, identical to today's
`_DigestScreenState.build` branching.

`backgroundColor: Colors.transparent` on the modal lets `_DigestSheetShell`
draw its own rounded surface. `enableDrag: true` plus `isDismissible: true`
gives swipe-down and tap-scrim dismissal for free.

## Visual spec

```
┌────────────────────────────────────────┐   rounded top corners, radius 20
│              ▬▬▬▬                       │   drag handle 36 x 4, top 8
│                                    ✕   │   X icon 24, top-right 16, 44x44 tap
├────────────────────────────────────────┤
│                                        │
│   <DigestContent — scrollable>          │
│   - Date badge                          │
│   - Summary card                        │
│   - Return bar chart                    │
│   - Drivers                             │
│   - Detractors                          │
│   - Disclaimer                          │
│                                        │
└────────────────────────────────────────┘
```

Colors:

- Sheet surface: `WeRoboThemeColors.of(context).surface`
- Drag handle: `WeRoboThemeColors.of(context).border.withValues(alpha: 0.8)`
- X icon: `WeRoboThemeColors.of(context).textSecondary`

Padding:

- Sheet body content keeps the existing `EdgeInsets.symmetric(horizontal: 20)`
  used by `_DigestContent` today.
- The drag handle and X live in a 56-pixel-tall header band above the body.
  The body's first item (date badge) starts immediately below that band with
  no extra top padding.

## Motion

- Open: Flutter default for `showModalBottomSheet` with `isScrollControlled:
  true`. No custom transition.
- Close: same default, reversed.
- The previous `WeRoboMotion.fadeRoute` is no longer applied to the digest
  flow. Other callers of `WeRoboMotion.fadeRoute` remain untouched.

## State and data flow

The fetch state machine is unchanged from `_DigestScreenState`:

1. `didChangeDependencies` triggers the first fetch (guarded by
   `_fetchStarted`).
2. If `state.hasSeenCurrentDigest` is true the loading view is skipped.
3. Otherwise the fetch is raced against a 5500ms `Future.delayed` so the
   loading animation has time to complete.
4. On success, `state.markDigestSeen(result.digestDate)` runs and the digest
   is stored in state.
5. On `MobileBackendException`, the error string (specialized for 422) is
   stored and rendered by `_ErrorState`.

No changes to `MobileBackendApi.fetchDigest`, no changes to the digest model.

## Edge cases

- **Digest unavailable (`available == false`)**: render the existing
  `_ErrorState` with the message `표시할 다이제스트가 없습니다.`.
- **No access token**: render `_ErrorState` with `로그인이 필요합니다.`.
- **422 from backend**: render `_ErrorState` with the existing
  "다이제스트를 만들기 위한 최근 데이터가 아직 부족합니다." message.
- **User dismisses mid-fetch**: the State object's `mounted` guard already
  prevents `setState` after dispose, so no leak.
- **Theme change while open**: the sheet re-reads colors from theme, so a
  light/dark toggle while open will repaint correctly.
- **Very small screens**: 92% of screen height is still scrollable. Body
  uses a `ListView`, so any content overflow scrolls inside the sheet
  without affecting the sheet height.

## Testing

Widget test in `test/screens/home/widgets/digest_sheet_test.dart`:

- Pumps a test harness that calls `DigestSheet.show` on a button tap.
- Verifies the drag handle and X button render inside the sheet.
- Verifies tapping the X pops the route and the sheet is gone.
- Verifies the loading widget shows initially.

Manual checks on the iPhone 17 Pro simulator:

- Tap AI 요약 card -> sheet slides up, home peeks at top under scrim.
- Tap standalone `_DigestBanner` (force it by clearing seen state) ->
  same sheet.
- Swipe down on the sheet -> sheet dismisses.
- Tap scrim -> sheet dismisses.
- Toggle dark mode while sheet is open -> sheet repaints with dark surface.
- Verify the previously-seen digest skips the loading animation.

## Risks and rollback

- Risk: `showModalBottomSheet` ignores `useSafeArea` on older Flutter
  versions. The repo's pinned Flutter SDK is recent enough, but worth a
  sanity check during implementation.
- Risk: the drag handle area sits above the body; if the body's first item
  has unexpected top padding from the existing `_DigestContent`, the gap may
  look too large. Trim by adjusting the shell's bottom padding or the body's
  top padding once visible in the simulator.
- Rollback: revert the three changes (new file, deleted file, home_tab edit).
  No backend, model, or shared widget changes.
