# TODOS

## ~~Auth Provider Integration~~ → IN PROGRESS (CEO Plan 2026-04-09)
**Status:** Being implemented via Firebase Auth as part of the Full Product MVP plan.
**Providers:** Google, Kakao, Naver, Apple via Firebase Auth.
**See:** `~/.gstack/projects/Back-End/ceo-plans/2026-04-09-werobo-full-product-mvp.md`

## ~~Missing GoogleSansFlex Font~~ → IN PROGRESS (CEO Plan 2026-04-09)
**Status:** Accepted into MVP scope. XS effort.

## Accessibility: Semantics Widgets
**What:** Add `Semantics` widgets to all interactive elements and data displays for screen reader support.
**Why:** The app has zero screen reader support. Charts, buttons, navigation items, and data displays are invisible to VoiceOver/TalkBack.
**Pros:** Makes the app usable for visually impaired users. Shows accessibility awareness to capstone evaluators.
**Cons:** Requires touching most widget files. ~30 Semantics additions across the codebase.
**Context:** Priority areas: (1) bottom nav items need `Semantics(label: '홈 탭')`, (2) chart widgets need `Semantics(label: '포트폴리오 비중 차트, 미국 가치주 20%...')`, (3) efficient frontier dot needs `Semantics(label: '위험도 조절 슬라이더')` with `onIncrease`/`onDecrease` for accessibility. CLAUDE.md already specifies 44px min touch targets and Semantics usage.
**Depends on:** Nothing. Can be done independently.

## Rebalancing History with Real Dates
**What:** Compute actual rebalancing trigger dates based on portfolio drift thresholds and show before/after allocations in the rebalance tab.
**Why:** The rebalance tab currently shows hardcoded dates and a static history list. Real rebalancing logic is a core robo-advisor feature that would impress capstone evaluators.
**Pros:** Demonstrates understanding of portfolio rebalancing mechanics. Makes the rebalance tab functional.
**Cons:** Requires drift calculation logic (compare current weights to target weights, trigger when drift exceeds threshold). Medium complexity.
**Context:** rebalance_tab.dart (120 lines) has a placeholder design ready to receive real data. The Flask API (when built) could serve rebalancing events. Drift threshold: typically 5% relative deviation from target weight.
**Effort:** M (human) -> S (CC+gstack)
**Priority:** P2
**Depends on:** Flask API backend.

## Risk Profile Re-evaluation from Settings
**What:** Let users re-do the efficient frontier interaction from Settings to change their portfolio type without re-onboarding.
**Why:** Users may want to adjust risk tolerance over time. The widget already exists in onboarding.
**Pros:** Reuses existing efficient frontier widget. Natural feature for a robo-advisor.
**Cons:** Need to handle state reset and re-fetch of all portfolio data after type change.
**Context:** Settings tab has empty onTap handlers. Add "투자 성향 재설정" option that opens the efficient frontier widget. On confirm, update user_profiles.risk_profile via API and re-fetch all data.
**Effort:** S (human) -> S (CC+gstack)
**Priority:** P2
**Depends on:** Firebase Auth (need user profile to persist change).

## Portfolio Sharing via Share Sheet
**What:** Tap a share button on the portfolio screen to generate a screenshot + summary text and share to KakaoTalk, iMessage, etc.
**Why:** Organic growth channel. Users showing their portfolio to friends is the best marketing for a robo-advisor.
**Pros:** Uses share_plus + screenshot packages. Generates "My WeRobo portfolio: +12.3% this year" with chart image.
**Cons:** Need to generate a shareable image from the chart widget. Screenshot package handles this.
**Effort:** S (human) -> S (CC+gstack)
**Priority:** P2
**Depends on:** Nothing. Can be done independently.

## Biometric Auth (Face ID / Fingerprint)
**What:** After initial Firebase login, users can unlock with biometrics on app resume.
**Why:** Finance apps need biometric auth for trust. Standard feature in Toss, Kakao Pay, etc.
**Pros:** Uses local_auth package. 1 screen (biometric prompt on app resume). Standard for any finance app.
**Cons:** Platform-specific setup (iOS Face ID usage description in Info.plist).
**Effort:** S (human) -> S (CC+gstack)
**Priority:** P2
**Depends on:** Firebase Auth.

## HTTP Client Error Handling (FormatException + SocketException)
**What:** Add `FormatException` and `SocketException` catches to `MobileBackendApi._postWithFallback` and all HTTP methods.
**Why:** Railway 502 returns HTML (triggers FormatException), and no-network triggers SocketException. Both cause app crashes. Currently only TimeoutException and MobileBackendException are caught. All interaction error states in the MVP plan depend on these being handled.
**Pros:** Prerequisite for every error state in the plan. Prevents crashes on Railway cold-start and offline usage.
**Cons:** None. Pure fix.
**Context:** Discovered via prior session analysis. File: `lib/services/mobile_backend_api.dart`. Pattern: catch FormatException → throw MobileBackendException('서버 응답 오류'), catch SocketException → throw MobileBackendException('네트워크 연결을 확인해주세요').
**Effort:** XS (human) -> XS (CC+gstack)
**Priority:** P0 (blocks all error states)
**Depends on:** Nothing.

## Crash Reporting (Sentry or Firebase Crashlytics)
**What:** Add crash reporting to capture unhandled exceptions in production.
**Why:** Zero observability currently. You'll never know when users hit bugs. Every unhandled exception should be captured.
**Pros:** Firebase Crashlytics is ~15 min setup since Firebase is already in the project. Free tier covers your scale.
**Cons:** Adds Firebase dependency (already there for auth). Minor privacy consideration (crash reports include device info).
**Effort:** S (human) -> XS (CC+gstack)
**Priority:** P1
**Depends on:** Firebase project setup (already needed for auth).

## Railway Pro Upgrade Decision
**What:** Decide whether to upgrade from Railway Hobby ($5/mo) to Pro ($20/mo) for always-on deployment.
**Why:** Hobby tier has 5-10s cold-start latency. First app launch after inactivity is painfully slow. For a "real product beyond capstone," this is the entire first impression.
**Decision gate:** If WeRobo has real users by 2026-06-15, upgrade to Pro. If capstone-only, keep Hobby.
**Pros:** Eliminates cold-start. Always-on. Better for demo reliability.
**Cons:** $20/mo ongoing cost.
**Context:** The PostAuthLoader screen + offline caching mitigate the UX impact, but they can't fix the fundamental 5-10s delay on first launch. For the capstone demo specifically, hitting the health endpoint before presenting is a manual workaround.
**Effort:** XS (just a Railway dashboard toggle)
**Priority:** P3 (decision needed by 2026-06-15)
**Depends on:** Ship target (2026-05-28).
