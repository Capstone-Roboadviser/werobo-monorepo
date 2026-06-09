# 적합성 설문 온보딩 (Investor Suitability Survey Onboarding) — Design Spec

Date: 2026-06-09
Author: honge6090
Status: Approved (design + scoring numbers approved by user 2026-06-09)

## 1. Goal

Add a 6-question investor suitability (적합성/성향) survey that runs after login,
produces a risk profile (level 1 to 5), shows a result screen, and feeds the
resulting propensity score into the existing efficient-frontier onboarding.

Source of truth for content and layout: Figma "Robo-advisor (Copy)"
(fileKey `YuuybbOeZl3R3gLpHQ5Bl8`), frames 적합성 설문 - Step 1~6 (`53:2`, `53:183`,
`53:238`, `53:293`, `53:348`, `53:403`) and 투자 적합성 판정 결과 (`53:462`).
Reference: 캡스톤 보고서 section 4.3. Reference screenshots saved at
`/tmp/werobo_survey/step1.png` .. `step6.png`, `result.png`.

## 2. Flow

```
Login → Survey Step 1 → … → Survey Step 6 → 투자 적합성 판정 결과 → (CTA) → OnboardingScreen (frontier) → … → Home
```

- Gating: always show after login (dev mode). No completion flag gating yet.
  (Profile is still persisted so the frontier screen and a future Settings
  re-take entry can read it. A `surveyCompleted` flag can be added later to
  switch to "show once".)
- The result screen "이 결과가 마음에 들지 않아요" link restarts the survey at Step 1.
- Back chevron appears on Steps 2 to 6 only (Step 1 has no back), returning to
  the previous question with prior answers preserved.
- Selecting an option highlights it briefly (about 200ms) then auto-advances.
  Step 6 selection computes the profile and replaces the route with the result.

## 3. Screen content (verbatim Korean)

Common chrome for Steps 1 to 6:
- Top-right counter: `n / 6` (navy, e.g. `WeRoboColors.primary`).
- Thin rounded progress bar, navy fill = step / 6, light-gray track.
- Small navy label above the question: `맞춤 포트폴리오를 위해`.
- Question title: `heading2` weight.
- 4 option cards: white, hairline border (`tc.border`), ~59px tall, left-aligned
  label, `radiusL` corners, `Pressable` feedback.
- Footer (centered, tertiary text): `선택 시 자동으로 다음 질문으로 이동합니다`.

Questions and options (option order top to bottom):

1. `연령대를 선택해주세요` — `20대` / `30대` / `40대` / `50대 이상`
2. `연 소득 구간은?` — `2,400만원 미만` / `2,400 ~ 5,000만원` / `5,000만원 ~ 1억` / `1억 초과`
3. `투자 가능 금액은?` — `100만원 미만` / `100 ~ 500만원` / `500 ~ 2,000만원` / `2,000만원 초과`
4. `투자 경험은?` — `없음` / `예·적금만 있음` / `펀드·ETF 경험` / `직접 주식 경험`
5. `손실 경험은 어느 정도인가요?` — `없음` / `5% 미만` / `10% 미만` / `10% 이상 경험`
6. `투자 목적이 무엇인가요?` — `노후 준비` / `목돈 마련` / `수익 극대화` / `기타`

Result screen (투자 적합성 판정 결과):
- Small navy label: `투자자 적합성 판정 결과`.
- Title: `고객님은\n{레벨라벨} 투자자예요` (e.g. `안정 성장형` in Figma; we use the
  level label, see section 4. Figma writes it as "안정 성장형"; our enum label is
  "안정성장" so the title renders "안정성장형 투자자예요". Keep the trailing "형" by
  appending it in the title string).
- Subtitle: `분석 결과에 따라 추천 포트폴리오 범위를 정했어요.`
- Level card (light navy/lavender bg): icon tile + `레벨 {n} / 5` + level label +
  a 5-segment scale labeled `안정` / `중도안정` / `안정성장` / `적극` / `공격`, the user's
  segment highlighted navy, the rest gray.
- 추천 투자 범위 card (white): `추천 투자 범위`, `기대 연수익률` = `{min}% ~ {max}%` (navy
  number style), `최대 리스크` = `±{risk}%`, body:
  `이 범위 안에서 AI가 최적의 포트폴리오를 제안합니다.\n물론, 더 좁히거나 직접 조정할 수 있어요.`
- Re-take link (underlined, tertiary): `이 결과가 마음에 들지 않아요`.
- Primary CTA (navy, full width, 52px): `내 포트폴리오 설계 시작하기`.

## 4. Scoring (approved)

Each answer scores 1 to 4 points. Sum range 6 to 24, bucketed into 5 levels.

Per-option points (by option index 0..3 in the order listed in section 3):

| Q | 질문 | 점수 (옵션 순서대로) |
|---|------|----------------------|
| 1 | 연령대 | 4, 3, 2, 1 |
| 2 | 연 소득 구간 | 1, 2, 3, 4 |
| 3 | 투자 가능 금액 | 1, 2, 3, 4 |
| 4 | 투자 경험 | 1, 2, 3, 4 |
| 5 | 손실 경험 | 1, 2, 3, 4 |
| 6 | 투자 목적 | 1 (노후 준비), 2 (목돈 마련), 4 (수익 극대화), 2 (기타) |

Note Q6 option order on screen is 노후 준비 / 목돈 마련 / 수익 극대화 / 기타, so the
points list by index is `[1, 2, 4, 2]`.

Level buckets and mapping:

| Lv | enum | label | rawScore | 기대 연수익률 | 최대 리스크 | propensity |
|----|------|-------|----------|---------------|-------------|------------|
| 1 | stable | 안정 | 6–9 | 2% ~ 4% | ±6% | 15 |
| 2 | moderateStable | 중도안정 | 10–13 | 3% ~ 7% | ±10% | 33 |
| 3 | stableGrowth | 안정성장 | 14–17 | 4% ~ 10% | ±14% | 50 |
| 4 | active | 적극 | 18–21 | 7% ~ 14% | ±19% | 68 |
| 5 | aggressive | 공격 | 22–24 | 10% ~ 20% | ±25% | 85 |

Level 3 is anchored to the Figma example. `propensity` (0 to 100) feeds the
existing recommendation/frontier API.

Boundary rule: `rawScore <= 9 → Lv1`, `<= 13 → Lv2`, `<= 17 → Lv3`,
`<= 21 → Lv4`, else `Lv5`.

## 5. Data model

`lib/models/investor_profile.dart`:

```dart
enum RiskLevel { stable, moderateStable, stableGrowth, active, aggressive }
// label: 안정 / 중도안정 / 안정성장 / 적극 / 공격
// number: 1..5
// returnMin, returnMax (fractions, e.g. 0.04, 0.10)
// maxRisk (fraction, e.g. 0.14)
// propensityScore (double 0..100)

class InvestorProfile {
  final RiskLevel level;
  final int rawScore;             // 6..24
  final double propensityScore;   // 0..100
  final double expectedReturnMin; // fraction
  final double expectedReturnMax; // fraction
  final double maxRisk;           // fraction
  final Map<String, int> answers; // questionId -> selected option index
  // const ctor, copyWith, toJson, fromJson
}
```

`RiskLevel` carries its label, number, return range, maxRisk, and propensity via
an extension or static table so the result screen and scoring share one source.

## 6. Survey data + scoring (pure, testable)

`lib/screens/onboarding/survey/survey_questions.dart`:
- `class SurveyOption { final String label; final int points; }`
- `class SurveyQuestion { final String id; final String question; final List<SurveyOption> options; }`
- `const List<SurveyQuestion> kSurveyQuestions = [...]` (the 6 from section 3 with
  points from section 4).

`lib/screens/onboarding/survey/survey_scoring.dart`:
- `InvestorProfile scoreSurvey(Map<String,int> answers)` — sums points, buckets to
  level, fills return range / maxRisk / propensity from the `RiskLevel` table.
- Pure function, no Flutter imports beyond the model. Fully unit-tested.

## 7. Widgets

`lib/screens/onboarding/widgets/`:
- `survey_progress_bar.dart` — `SurveyProgressBar(step, total)`: thin rounded bar +
  `n / total` counter. Navy fill, animated width on step change.
- `survey_option_button.dart` — `SurveyOptionButton(label, selected, onTap)`: white
  card, hairline border, `Pressable`, brief selected highlight (navy border/fill
  tint).
- `risk_level_scale.dart` — `RiskLevelScale(activeLevel)`: 5 labeled segments with
  the active one highlighted navy.

## 8. Screens

`lib/screens/onboarding/survey_flow_screen.dart` — `SurveyFlowScreen` (Stateful):
- Holds `PageController` + `Map<String,int> _answers` + current index.
- Renders `SafeArea` > Column: back chevron (index > 0) + progress bar/counter,
  label, question, option list, footer.
- On option tap: record answer, short delay, animate to next page; on last
  question compute `scoreSurvey` and `Navigator.pushReplacement(fadeRoute(
  SurveyResultScreen(profile)))`.
- Back chevron: animate to previous page.
- Uses `logPageEnter`/`logPageExit`/`logAction` like other screens.

`lib/screens/onboarding/survey_result_screen.dart` — `SurveyResultScreen(profile)`:
- Renders the content in section 3 (result).
- CTA `내 포트폴리오 설계 시작하기`: `PortfolioStateProvider.of(context)
  .setInvestorProfile(profile)` then `Navigator.pushReplacement(fadeRoute(
  const OnboardingScreen()))`.
- Re-take link: `Navigator.pushReplacement(fadeRoute(const SurveyFlowScreen()))`.

## 9. Integration edits

1. `lib/screens/onboarding/login_screen.dart`
   - Change `_navigateToOnboarding()` (line ~58) to push `SurveyFlowScreen`
     instead of `OnboardingScreen`. Update the import. This single chokepoint
     covers direct auth, "이 계정으로 계속", and "로그인 없이 둘러보기". Method may be
     renamed `_navigateToSurvey()` for clarity.

2. `lib/app/portfolio_state.dart`
   - Add `static const String _investorProfileKey = 'werobo.investor_profile';`
   - Add `InvestorProfile? _investorProfile;` + getter `investorProfile`.
   - Add `Future<void> setInvestorProfile(InvestorProfile profile)` that sets the
     field, persists `jsonEncode(profile.toJson())` to SharedPreferences, and
     `notifyListeners()`.
   - Load it in the existing SharedPreferences bootstrap/hydrate method (match the
     pattern used for `_storySeen` / `_alertFrequency`; read the file past line 240
     to find the exact load method and follow it).

3. `lib/screens/onboarding/onboarding_screen.dart`
   - In `_fetchFrontierPreview()` (line ~103) replace the hardcoded
     `propensityScore: 45.0` with
     `PortfolioStateProvider.of(context).investorProfile?.propensityScore ?? 45.0`.
     Read state before the await (it uses `context`), guard with `mounted`.

## 10. Styling

Use existing tokens only (`lib/app/theme.dart`):
- Colors: `WeRoboColors.primary` (#0614A7), `WeRoboColors.primaryDark` for CTA,
  `WeRoboThemeColors.of(context)` for `background`/`card`/`surface`/`border`/text.
- Type: `WeRoboTypography` (heading2 question, heading3 card titles, body, caption,
  bodySmall, button, number for the % figures).
- Spacing: `WeRoboSpacing`; radius `WeRoboColors.radiusL`/`radiusXL`.
- Motion: `WeRoboMotion.fadeRoute`, `WeRoboMotion.short`/`move` for highlight and
  page slide. Use `Pressable` for taps. `WeRoboElevation.subtle` for cards.
- Light mode. Follow CLAUDE.md Dart conventions (80-col, const ctors, private
  widget classes, exhaustive switch, no print, Semantics labels, 44px touch).

Result-screen level icon: use a simple per-level emoji/icon (Figma shows a sprout
for Lv3). Not load-bearing; pick a small monotone set and keep it adjustable.

## 11. Testing

- `test/survey_scoring_test.dart`: min answers → Lv1; max answers → Lv5; the Figma
  example combination → Lv3 with 4~10% / ±14%; each boundary (9/10, 13/14, 17/18,
  21/22); propensity values per level.
- Optional widget smoke test: `SurveyFlowScreen` renders Q1 and advances on tap.

## 12. Out of scope

- The 4.4 적합 범위 over-risking guard overlay on the frontier picker.
- A Settings "성향 설문 다시하기" entry.
- A backend endpoint for survey answers (scoring is client-side).
- 포트폴리오 설계 - 1/2 frames (these map to the existing OnboardingScreen).
