# TODOS

## Auth Provider Integration
**What:** Implement real social login for Google, Kakao, Naver, and Apple.
**Why:** Login buttons currently stub-navigate to ComparisonScreen. Real auth is required for user accounts, data persistence, and production use.
**Pros:** Enables user-specific portfolios, session persistence, and the full product experience.
**Cons:** Each provider requires separate SDK integration and platform config (iOS plist, Android manifest).
**Context:** login_screen.dart `_onSocialLogin()` currently ignores the provider string. Packages needed:
- Google: `google_sign_in`
- Kakao: `kakao_flutter_sdk_user`
- Naver: `flutter_naver_login`
- Apple: `sign_in_with_apple`
Each requires OAuth app registration and platform-specific setup (iOS entitlements, Android SHA keys).
**Depends on:** Backend API for token exchange and user creation.

## Missing GoogleSansFlex Font
**What:** Add GoogleSansFlex font files to `assets/fonts/` and declare the family in `pubspec.yaml`.
**Why:** `WeRoboFonts.number` references `GoogleSansFlex` but the font isn't bundled. All number typography (chart percentages, stats, asset values) falls back to the system default font instead of the intended design.
**Pros:** Numbers render with the correct Figma-specified typography.
**Cons:** Adds ~200KB to the app bundle.
**Context:** The font family is declared in `lib/app/theme.dart:73` as `static const String number = 'GoogleSansFlex'` and used in `WeRoboTypography.number`. Download from Google Fonts or extract from the Figma file.
**Depends on:** Nothing. Can be done independently.

## Accessibility: Semantics Widgets
**What:** Add `Semantics` widgets to all interactive elements and data displays for screen reader support.
**Why:** The app has zero screen reader support. Charts, buttons, navigation items, and data displays are invisible to VoiceOver/TalkBack.
**Pros:** Makes the app usable for visually impaired users. Shows accessibility awareness to capstone evaluators.
**Cons:** Requires touching most widget files. ~30 Semantics additions across the codebase.
**Context:** Priority areas: (1) bottom nav items need `Semantics(label: '홈 탭')`, (2) chart widgets need `Semantics(label: '포트폴리오 비중 차트, 미국 가치주 20%...')`, (3) efficient frontier dot needs `Semantics(label: '위험도 조절 슬라이더')` with `onIncrease`/`onDecrease` for accessibility. CLAUDE.md already specifies 44px min touch targets and Semantics usage.
**Depends on:** Nothing. Can be done independently.
