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
