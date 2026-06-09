# 적합성 설문 온보딩 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. (This plan will be executed via the Workflow tool, one agent per task group, with a final integration + verify stage.)

**Goal:** Add a 6-question investor suitability (적합성) survey after login that computes a risk level (1 to 5), shows a result screen, persists the profile, and seeds the existing efficient-frontier onboarding with the resulting propensity score.

**Architecture:** A single data-driven survey flow (`PageView` over a const list of question configs), a pure scoring function, an `InvestorProfile` model persisted in `PortfolioState`, and a result screen that routes into the existing `OnboardingScreen`. Reuses `WeRoboTheme` tokens. No new packages, no backend endpoint.

**Tech Stack:** Flutter (Dart 3), built-in `ChangeNotifier` + `InheritedWidget` state, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-09-survey-onboarding-design.md`
**Figma screenshots:** `/tmp/werobo_survey/step1.png` .. `step6.png`, `result.png`
**Working dir:** `Front-End/robo_mobile/` (package name expected `robo_mobile`; confirm in `pubspec.yaml`). Run Flutter via `./tool/flutterw` from that dir (fallback: `flutter`).

---

## File Structure

Create:
- `lib/models/investor_profile.dart` — `RiskLevel` enum + level table + `InvestorProfile`.
- `lib/screens/onboarding/survey/survey_questions.dart` — question/option data.
- `lib/screens/onboarding/survey/survey_scoring.dart` — pure scoring.
- `lib/screens/onboarding/widgets/survey_progress_bar.dart`
- `lib/screens/onboarding/widgets/survey_option_button.dart`
- `lib/screens/onboarding/widgets/risk_level_scale.dart`
- `lib/screens/onboarding/survey_flow_screen.dart`
- `lib/screens/onboarding/survey_result_screen.dart`
- `test/survey_scoring_test.dart`

Modify:
- `lib/screens/onboarding/login_screen.dart` — route to survey.
- `lib/app/portfolio_state.dart` — persist `investorProfile`.
- `lib/screens/onboarding/onboarding_screen.dart` — seed `propensityScore` from profile.

---

## Task 1: InvestorProfile model + RiskLevel table

**Files:**
- Create: `lib/models/investor_profile.dart`

- [ ] **Step 1: Write the model file**

```dart
import 'package:flutter/foundation.dart';

/// Investor suitability (적합성) risk level, ordered 안정 (1) to 공격 (5).
enum RiskLevel { stable, moderateStable, stableGrowth, active, aggressive }

extension RiskLevelInfo on RiskLevel {
  /// 1-based level number shown as "레벨 n / 5".
  int get number => index + 1;

  String get label => switch (this) {
        RiskLevel.stable => '안정',
        RiskLevel.moderateStable => '중도안정',
        RiskLevel.stableGrowth => '안정성장',
        RiskLevel.active => '적극',
        RiskLevel.aggressive => '공격',
      };

  /// Expected annual return range (fraction).
  double get returnMin => switch (this) {
        RiskLevel.stable => 0.02,
        RiskLevel.moderateStable => 0.03,
        RiskLevel.stableGrowth => 0.04,
        RiskLevel.active => 0.07,
        RiskLevel.aggressive => 0.10,
      };

  double get returnMax => switch (this) {
        RiskLevel.stable => 0.04,
        RiskLevel.moderateStable => 0.07,
        RiskLevel.stableGrowth => 0.10,
        RiskLevel.active => 0.14,
        RiskLevel.aggressive => 0.20,
      };

  /// Max risk (예상 변동성) as a fraction.
  double get maxRisk => switch (this) {
        RiskLevel.stable => 0.06,
        RiskLevel.moderateStable => 0.10,
        RiskLevel.stableGrowth => 0.14,
        RiskLevel.active => 0.19,
        RiskLevel.aggressive => 0.25,
      };

  /// Representative propensity score (0..100) fed to the recommendation API.
  double get propensityScore => switch (this) {
        RiskLevel.stable => 15,
        RiskLevel.moderateStable => 33,
        RiskLevel.stableGrowth => 50,
        RiskLevel.active => 68,
        RiskLevel.aggressive => 85,
      };
}

RiskLevel riskLevelFromName(String name) => RiskLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => RiskLevel.stableGrowth,
    );

/// The computed outcome of the suitability survey.
@immutable
class InvestorProfile {
  final RiskLevel level;
  final int rawScore; // 6..24
  final double propensityScore; // 0..100
  final double expectedReturnMin; // fraction
  final double expectedReturnMax; // fraction
  final double maxRisk; // fraction
  final Map<String, int> answers; // questionId -> selected option index

  const InvestorProfile({
    required this.level,
    required this.rawScore,
    required this.propensityScore,
    required this.expectedReturnMin,
    required this.expectedReturnMax,
    required this.maxRisk,
    required this.answers,
  });

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'rawScore': rawScore,
        'propensityScore': propensityScore,
        'expectedReturnMin': expectedReturnMin,
        'expectedReturnMax': expectedReturnMax,
        'maxRisk': maxRisk,
        'answers': answers,
      };

  factory InvestorProfile.fromJson(Map<String, dynamic> json) {
    final level = riskLevelFromName(json['level'] as String? ?? '');
    final answers = <String, int>{};
    final rawAnswers = json['answers'];
    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        if (value is num) {
          answers[key.toString()] = value.toInt();
        }
      });
    }
    return InvestorProfile(
      level: level,
      rawScore: (json['rawScore'] as num?)?.toInt() ?? 0,
      propensityScore:
          (json['propensityScore'] as num?)?.toDouble() ?? level.propensityScore,
      expectedReturnMin:
          (json['expectedReturnMin'] as num?)?.toDouble() ?? level.returnMin,
      expectedReturnMax:
          (json['expectedReturnMax'] as num?)?.toDouble() ?? level.returnMax,
      maxRisk: (json['maxRisk'] as num?)?.toDouble() ?? level.maxRisk,
      answers: answers,
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd Front-End/robo_mobile && ./tool/flutterw analyze lib/models/investor_profile.dart`
Expected: No issues (or only pre-existing repo-wide issues unrelated to this file).

---

## Task 2: Survey question data + scoring (TDD)

**Files:**
- Create: `lib/screens/onboarding/survey/survey_questions.dart`
- Create: `lib/screens/onboarding/survey/survey_scoring.dart`
- Test: `test/survey_scoring_test.dart`

- [ ] **Step 1: Write the question data**

`lib/screens/onboarding/survey/survey_questions.dart`:

```dart
/// One selectable answer with its suitability points (1..4).
class SurveyOption {
  final String label;
  final int points;
  const SurveyOption(this.label, this.points);
}

/// One survey question: a stable [id] and 4 [options].
class SurveyQuestion {
  final String id;
  final String question;
  final List<SurveyOption> options;
  const SurveyQuestion({
    required this.id,
    required this.question,
    required this.options,
  });
}

const String kSurveyLabel = '맞춤 포트폴리오를 위해';
const String kSurveyAutoAdvanceHint = '선택 시 자동으로 다음 질문으로 이동합니다';

const List<SurveyQuestion> kSurveyQuestions = [
  SurveyQuestion(
    id: 'age',
    question: '연령대를 선택해주세요',
    options: [
      SurveyOption('20대', 4),
      SurveyOption('30대', 3),
      SurveyOption('40대', 2),
      SurveyOption('50대 이상', 1),
    ],
  ),
  SurveyQuestion(
    id: 'income',
    question: '연 소득 구간은?',
    options: [
      SurveyOption('2,400만원 미만', 1),
      SurveyOption('2,400 ~ 5,000만원', 2),
      SurveyOption('5,000만원 ~ 1억', 3),
      SurveyOption('1억 초과', 4),
    ],
  ),
  SurveyQuestion(
    id: 'investable',
    question: '투자 가능 금액은?',
    options: [
      SurveyOption('100만원 미만', 1),
      SurveyOption('100 ~ 500만원', 2),
      SurveyOption('500 ~ 2,000만원', 3),
      SurveyOption('2,000만원 초과', 4),
    ],
  ),
  SurveyQuestion(
    id: 'experience',
    question: '투자 경험은?',
    options: [
      SurveyOption('없음', 1),
      SurveyOption('예·적금만 있음', 2),
      SurveyOption('펀드·ETF 경험', 3),
      SurveyOption('직접 주식 경험', 4),
    ],
  ),
  SurveyQuestion(
    id: 'loss',
    question: '손실 경험은 어느 정도인가요?',
    options: [
      SurveyOption('없음', 1),
      SurveyOption('5% 미만', 2),
      SurveyOption('10% 미만', 3),
      SurveyOption('10% 이상 경험', 4),
    ],
  ),
  SurveyQuestion(
    id: 'goal',
    question: '투자 목적이 무엇인가요?',
    options: [
      SurveyOption('노후 준비', 1),
      SurveyOption('목돈 마련', 2),
      SurveyOption('수익 극대화', 4),
      SurveyOption('기타', 2),
    ],
  ),
];
```

- [ ] **Step 2: Write the failing scoring test**

`test/survey_scoring_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/investor_profile.dart';
import 'package:robo_mobile/screens/onboarding/survey/survey_questions.dart';
import 'package:robo_mobile/screens/onboarding/survey/survey_scoring.dart';

void main() {
  group('riskLevelForScore boundaries', () {
    test('maps raw score to level at each boundary', () {
      expect(riskLevelForScore(6), RiskLevel.stable);
      expect(riskLevelForScore(9), RiskLevel.stable);
      expect(riskLevelForScore(10), RiskLevel.moderateStable);
      expect(riskLevelForScore(13), RiskLevel.moderateStable);
      expect(riskLevelForScore(14), RiskLevel.stableGrowth);
      expect(riskLevelForScore(17), RiskLevel.stableGrowth);
      expect(riskLevelForScore(18), RiskLevel.active);
      expect(riskLevelForScore(21), RiskLevel.active);
      expect(riskLevelForScore(22), RiskLevel.aggressive);
      expect(riskLevelForScore(24), RiskLevel.aggressive);
    });
  });

  group('scoreSurvey', () {
    test('minimum answers -> 안정 (raw 6)', () {
      final p = scoreSurvey({
        'age': 3, // 1
        'income': 0, // 1
        'investable': 0, // 1
        'experience': 0, // 1
        'loss': 0, // 1
        'goal': 0, // 1
      });
      expect(p.rawScore, 6);
      expect(p.level, RiskLevel.stable);
      expect(p.propensityScore, 15);
    });

    test('maximum answers -> 공격 (raw 24)', () {
      final p = scoreSurvey({
        'age': 0, // 4
        'income': 3, // 4
        'investable': 3, // 4
        'experience': 3, // 4
        'loss': 3, // 4
        'goal': 2, // 수익 극대화 = 4
      });
      expect(p.rawScore, 24);
      expect(p.level, RiskLevel.aggressive);
      expect(p.propensityScore, 85);
    });

    test('figma example -> 안정성장, 4~10%, ±14% (raw 15)', () {
      final p = scoreSurvey({
        'age': 1, // 30대 = 3
        'income': 2, // 5,000~1억 = 3
        'investable': 2, // 500~2,000 = 3
        'experience': 2, // 펀드·ETF = 3
        'loss': 1, // 5% 미만 = 2
        'goal': 0, // 노후 준비 = 1
      });
      expect(p.rawScore, 15);
      expect(p.level, RiskLevel.stableGrowth);
      expect(p.expectedReturnMin, 0.04);
      expect(p.expectedReturnMax, 0.10);
      expect(p.maxRisk, 0.14);
    });

    test('missing and out-of-range answers are skipped', () {
      final p = scoreSurvey({'age': 0, 'income': 99, 'goal': -1});
      expect(p.rawScore, 4); // only age counts
      expect(p.level, RiskLevel.stable);
      expect(p.answers['age'], 0);
    });
  });
}
```

- [ ] **Step 3: Run the test, verify it fails**

Run: `cd Front-End/robo_mobile && ./tool/flutterw test test/survey_scoring_test.dart`
Expected: FAIL (compile error: `scoreSurvey` / `riskLevelForScore` not defined).

- [ ] **Step 4: Write the scoring implementation**

`lib/screens/onboarding/survey/survey_scoring.dart`:

```dart
import '../../../models/investor_profile.dart';
import 'survey_questions.dart';

/// Buckets a raw suitability score (6..24) into a [RiskLevel].
RiskLevel riskLevelForScore(int rawScore) {
  if (rawScore <= 9) return RiskLevel.stable;
  if (rawScore <= 13) return RiskLevel.moderateStable;
  if (rawScore <= 17) return RiskLevel.stableGrowth;
  if (rawScore <= 21) return RiskLevel.active;
  return RiskLevel.aggressive;
}

/// Computes the [InvestorProfile] from answers (questionId -> option index).
/// Unknown ids and out-of-range indices are ignored.
InvestorProfile scoreSurvey(Map<String, int> answers) {
  var raw = 0;
  for (final q in kSurveyQuestions) {
    final idx = answers[q.id];
    if (idx == null || idx < 0 || idx >= q.options.length) continue;
    raw += q.options[idx].points;
  }
  final level = riskLevelForScore(raw);
  return InvestorProfile(
    level: level,
    rawScore: raw,
    propensityScore: level.propensityScore,
    expectedReturnMin: level.returnMin,
    expectedReturnMax: level.returnMax,
    maxRisk: level.maxRisk,
    answers: Map<String, int>.from(answers),
  );
}
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `cd Front-End/robo_mobile && ./tool/flutterw test test/survey_scoring_test.dart`
Expected: PASS (all tests green).

---

## Task 3: Reusable widgets

**Files:**
- Create: `lib/screens/onboarding/widgets/survey_progress_bar.dart`
- Create: `lib/screens/onboarding/widgets/survey_option_button.dart`
- Create: `lib/screens/onboarding/widgets/risk_level_scale.dart`

- [ ] **Step 1: Progress bar**

`survey_progress_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Top progress indicator: a thin navy bar that fills with `step / total`,
/// plus an `n / total` counter aligned right.
class SurveyProgressBar extends StatelessWidget {
  final int step; // 1-based
  final int total;
  const SurveyProgressBar({super.key, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final fraction = (step / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: WeRoboSpacing.xxl),
          child: Text(
            '$step / $total',
            textAlign: TextAlign.right,
            style: WeRoboTypography.bodySmall.copyWith(
              color: WeRoboColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: WeRoboSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WeRoboSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(WeRoboColors.radiusFull),
                child: Stack(
                  children: [
                    Container(height: 6, color: tc.border),
                    AnimatedContainer(
                      duration: WeRoboMotion.medium,
                      curve: WeRoboMotion.move,
                      height: 6,
                      width: constraints.maxWidth * fraction,
                      color: WeRoboColors.primary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Option button**

`survey_option_button.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../app/pressable.dart';
import '../../../app/theme.dart';

/// A single answer card. White with a hairline border; when [selected] it
/// shows a navy border and a faint navy tint.
class SurveyOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SurveyOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WeRoboSpacing.md),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: WeRoboMotion.short,
          curve: WeRoboMotion.move,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: WeRoboSpacing.lg,
            vertical: WeRoboSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: selected
                ? WeRoboColors.primary.withValues(alpha: 0.06)
                : tc.card,
            borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
            border: Border.all(
              color: selected ? WeRoboColors.primary : tc.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Semantics(
            button: true,
            selected: selected,
            child: Text(
              label,
              style: WeRoboTypography.body.copyWith(
                color: tc.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Risk level scale**

`risk_level_scale.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/investor_profile.dart';

/// The 5-segment risk scale on the result screen. The [active] level is
/// highlighted navy; the others are muted.
class RiskLevelScale extends StatelessWidget {
  final RiskLevel active;
  const RiskLevelScale({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Row(
      children: [
        for (final level in RiskLevel.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: level == active ? WeRoboColors.primary : tc.border,
                      borderRadius:
                          BorderRadius.circular(WeRoboColors.radiusFull),
                    ),
                  ),
                  const SizedBox(height: WeRoboSpacing.sm),
                  Text(
                    level.label,
                    textAlign: TextAlign.center,
                    style: WeRoboTypography.caption.copyWith(
                      color: level == active
                          ? WeRoboColors.primary
                          : tc.textTertiary,
                      fontWeight:
                          level == active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify**

Run: `cd Front-End/robo_mobile && ./tool/flutterw analyze lib/screens/onboarding/widgets/survey_progress_bar.dart lib/screens/onboarding/widgets/survey_option_button.dart lib/screens/onboarding/widgets/risk_level_scale.dart`
Expected: No new issues. (Confirms `Pressable` import path `../../../app/pressable.dart` resolves; if `Pressable` exposes a different prop than `onTap`/`child`, match its real API.)

---

## Task 4: Survey flow screen

**Files:**
- Create: `lib/screens/onboarding/survey_flow_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/theme.dart';
import 'survey/survey_questions.dart';
import 'survey/survey_scoring.dart';
import 'survey_result_screen.dart';
import 'widgets/survey_option_button.dart';
import 'widgets/survey_progress_bar.dart';

/// The 6-step 적합성 설문. Data-driven from [kSurveyQuestions]. Selecting an
/// option records the answer and auto-advances; the last question computes the
/// profile and routes to [SurveyResultScreen].
class SurveyFlowScreen extends StatefulWidget {
  const SurveyFlowScreen({super.key});

  @override
  State<SurveyFlowScreen> createState() => _SurveyFlowScreenState();
}

class _SurveyFlowScreenState extends State<SurveyFlowScreen> {
  final PageController _pageController = PageController();
  final Map<String, int> _answers = {};
  int _index = 0;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    logPageEnter('SurveyFlowScreen');
  }

  @override
  void dispose() {
    logPageExit('SurveyFlowScreen');
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _selectOption(SurveyQuestion question, int optionIndex) async {
    if (_advancing) return;
    setState(() {
      _answers[question.id] = optionIndex;
      _advancing = true;
    });
    logAction('survey answer', {'question': question.id, 'option': optionIndex});
    await Future<void>.delayed(WeRoboMotion.short);
    if (!mounted) return;
    if (_index >= kSurveyQuestions.length - 1) {
      final profile = scoreSurvey(_answers);
      logAction('survey complete',
          {'rawScore': profile.rawScore, 'level': profile.level.name});
      Navigator.of(context).pushReplacement(
        WeRoboMotion.fadeRoute(SurveyResultScreen(profile: profile)),
      );
      return;
    }
    await _pageController.nextPage(
      duration: WeRoboMotion.medium,
      curve: WeRoboMotion.move,
    );
    if (mounted) setState(() => _advancing = false);
  }

  Future<void> _goBack() async {
    if (_index == 0) return;
    await _pageController.previousPage(
      duration: WeRoboMotion.medium,
      curve: WeRoboMotion.move,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: _index > 0
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_left),
                        color: tc.textPrimary,
                        onPressed: _goBack,
                        tooltip: '이전',
                      ),
                    )
                  : null,
            ),
            SurveyProgressBar(step: _index + 1, total: kSurveyQuestions.length),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kSurveyQuestions.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final q = kSurveyQuestions[i];
                  return _QuestionPage(
                    question: q,
                    selectedIndex: _answers[q.id],
                    onSelect: (optionIndex) => _selectOption(q, optionIndex),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: WeRoboSpacing.xxl),
              child: Text(
                kSurveyAutoAdvanceHint,
                style: WeRoboTypography.caption.copyWith(color: tc.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  final SurveyQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  const _QuestionPage({
    required this.question,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        WeRoboSpacing.xxl,
        WeRoboSpacing.xxxl,
        WeRoboSpacing.xxl,
        WeRoboSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kSurveyLabel,
            style: WeRoboTypography.bodySmall.copyWith(
              color: WeRoboColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: WeRoboSpacing.sm),
          Text(question.question, style: WeRoboTypography.heading2.themed(context)),
          const SizedBox(height: WeRoboSpacing.xxxl),
          for (var i = 0; i < question.options.length; i++)
            SurveyOptionButton(
              label: question.options[i].label,
              selected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify** (after Task 5 exists, since it imports the result screen)

Run: `cd Front-End/robo_mobile && ./tool/flutterw analyze lib/screens/onboarding/survey_flow_screen.dart`
Expected: No new issues.

---

## Task 5: Survey result screen

**Files:**
- Create: `lib/screens/onboarding/survey_result_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import '../../app/debug_page_logger.dart';
import '../../app/portfolio_state.dart';
import '../../app/theme.dart';
import '../../models/investor_profile.dart';
import 'onboarding_screen.dart';
import 'survey_flow_screen.dart';
import 'widgets/risk_level_scale.dart';

/// 투자 적합성 판정 결과. Shows the computed [InvestorProfile], persists it on
/// confirm, and routes into the existing efficient-frontier onboarding.
class SurveyResultScreen extends StatefulWidget {
  final InvestorProfile profile;
  const SurveyResultScreen({super.key, required this.profile});

  @override
  State<SurveyResultScreen> createState() => _SurveyResultScreenState();
}

class _SurveyResultScreenState extends State<SurveyResultScreen> {
  @override
  void initState() {
    super.initState();
    logPageEnter('SurveyResultScreen');
  }

  @override
  void dispose() {
    logPageExit('SurveyResultScreen');
    super.dispose();
  }

  void _start() {
    logAction('survey result confirm', {'level': widget.profile.level.name});
    PortfolioStateProvider.of(context).setInvestorProfile(widget.profile);
    Navigator.of(context).pushReplacement(
      WeRoboMotion.fadeRoute(const OnboardingScreen()),
    );
  }

  void _retake() {
    logAction('survey retake');
    Navigator.of(context).pushReplacement(
      WeRoboMotion.fadeRoute(const SurveyFlowScreen()),
    );
  }

  static String _pct(double f) => (f * 100).round().toString();

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final p = widget.profile;
    return Scaffold(
      backgroundColor: tc.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  WeRoboSpacing.xxl,
                  WeRoboSpacing.xxxl,
                  WeRoboSpacing.xxl,
                  WeRoboSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '투자자 적합성 판정 결과',
                      style: WeRoboTypography.bodySmall.copyWith(
                        color: WeRoboColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: WeRoboSpacing.sm),
                    Text(
                      '고객님은\n${p.level.label}형 투자자예요',
                      style: WeRoboTypography.heading1.themed(context),
                    ),
                    const SizedBox(height: WeRoboSpacing.md),
                    Text(
                      '분석 결과에 따라 추천 포트폴리오 범위를 정했어요.',
                      style: WeRoboTypography.body.themed(context),
                    ),
                    const SizedBox(height: WeRoboSpacing.xxl),
                    _LevelCard(profile: p),
                    const SizedBox(height: WeRoboSpacing.lg),
                    _RangeCard(profile: p),
                    const SizedBox(height: WeRoboSpacing.sm),
                    Center(
                      child: TextButton(
                        onPressed: _retake,
                        child: Text(
                          '이 결과가 마음에 들지 않아요',
                          style: WeRoboTypography.bodySmall.copyWith(
                            color: tc.textTertiary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: WeRoboSpacing.bottomButton,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _start,
                  child: const Text('내 포트폴리오 설계 시작하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final InvestorProfile profile;
  const _LevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final level = profile.level;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WeRoboSpacing.xl),
      decoration: BoxDecoration(
        color: WeRoboColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WeRoboColors.white,
                  borderRadius: BorderRadius.circular(WeRoboColors.radiusL),
                ),
                child: const Text('🌱', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: WeRoboSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '레벨 ${level.number} / 5',
                    style: WeRoboTypography.caption
                        .copyWith(color: tc.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(level.label,
                      style: WeRoboTypography.heading3.themed(context)),
                ],
              ),
            ],
          ),
          const SizedBox(height: WeRoboSpacing.lg),
          RiskLevelScale(active: level),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  final InvestorProfile profile;
  const _RangeCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tc = WeRoboThemeColors.of(context);
    final p = profile;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WeRoboSpacing.xl),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(WeRoboColors.radiusXL),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추천 투자 범위',
            style: WeRoboTypography.bodySmall
                .copyWith(color: tc.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: WeRoboSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('기대 연수익률',
                      style: WeRoboTypography.caption
                          .copyWith(color: tc.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '${_SurveyResultScreenState._pct(p.expectedReturnMin)}% ~ ${_SurveyResultScreenState._pct(p.expectedReturnMax)}%',
                    style: WeRoboTypography.number
                        .copyWith(color: WeRoboColors.primary, fontSize: 22),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('최대 리스크',
                      style: WeRoboTypography.caption
                          .copyWith(color: tc.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '±${_SurveyResultScreenState._pct(p.maxRisk)}%',
                    style: WeRoboTypography.number
                        .copyWith(color: tc.textPrimary, fontSize: 22),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: WeRoboSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(WeRoboSpacing.md),
            decoration: BoxDecoration(
              color: tc.background,
              borderRadius: BorderRadius.circular(WeRoboColors.radiusM),
            ),
            child: Text(
              '이 범위 안에서 AI가 최적의 포트폴리오를 제안합니다.\n물론, 더 좁히거나 직접 조정할 수 있어요.',
              style: WeRoboTypography.caption.copyWith(color: tc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
```

Note: `_pct` is referenced across private widgets via `_SurveyResultScreenState._pct`. If the analyzer flags the static cross-reference style, move `_pct` to a top-level private function `String _pct(double f) => (f * 100).round().toString();` in the same file and call it directly. Either is fine; prefer the top-level function if simpler.

- [ ] **Step 2: Verify**

Run: `cd Front-End/robo_mobile && ./tool/flutterw analyze lib/screens/onboarding/survey_result_screen.dart`
Expected: No new issues. (`setInvestorProfile` and `investorProfile` come from Task 6; if analyzing before Task 6, expect an undefined-method error there only.)

---

## Task 6: Integration (login, state persistence, frontier seeding)

**Files:**
- Modify: `lib/screens/onboarding/login_screen.dart`
- Modify: `lib/app/portfolio_state.dart`
- Modify: `lib/screens/onboarding/onboarding_screen.dart`

- [ ] **Step 1: Route login to the survey**

In `login_screen.dart`:
- Replace the import `import 'onboarding_screen.dart';` with `import 'survey_flow_screen.dart';` (the file no longer references `OnboardingScreen` directly; if it still does elsewhere, keep both imports).
- Replace `_navigateToOnboarding` (around line 58) with:

```dart
  void _navigateToSurvey() {
    Navigator.of(context).pushReplacement(
      WeRoboMotion.fadeRoute(const SurveyFlowScreen()),
    );
  }
```

- Update the two call sites: in `_navigateAfterAuthenticated` (around line 69) and the "로그인 없이 둘러보기" `TextButton.onPressed` (around line 505), change `_navigateToOnboarding()` to `_navigateToSurvey()`.

- [ ] **Step 2: Persist `investorProfile` in PortfolioState**

In `portfolio_state.dart`:
- Add import near the other model imports: `import '../models/investor_profile.dart';` (`dart:convert` is already imported at line 2).
- Add the storage key alongside the others (near line 110):

```dart
  static const String _investorProfileKey = 'werobo.investor_profile';
```

- Add the field (near the other private fields, around line 139):

```dart
  InvestorProfile? _investorProfile;
```

- Add the getter (near the other getters, around line 170):

```dart
  InvestorProfile? get investorProfile => _investorProfile;
```

- Add the setter (place near other `set*`/persistence methods):

```dart
  Future<void> setInvestorProfile(InvestorProfile profile) async {
    _investorProfile = profile;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_investorProfileKey, jsonEncode(profile.toJson()));
  }
```

  IMPORTANT: match the existing SharedPreferences access pattern. Read the file past line 240 to find the startup hydrate/load method (the one that reads keys like `_storySeenKey`, `_alertFrequencyKey`, `_welcomeBannerSeenKey`). If it obtains `prefs` differently (e.g. a cached instance passed in), use that same accessor in `setInvestorProfile` instead of `SharedPreferences.getInstance()`.

- In that same hydrate/load method, add the load following the surrounding pattern:

```dart
    final investorProfileRaw = prefs.getString(_investorProfileKey);
    if (investorProfileRaw != null) {
      try {
        _investorProfile = InvestorProfile.fromJson(
          jsonDecode(investorProfileRaw) as Map<String, dynamic>,
        );
      } catch (_) {
        _investorProfile = null;
      }
    }
```

- [ ] **Step 3: Seed the frontier preview with the survey propensity**

In `onboarding_screen.dart`, the propensity is read from an `InheritedWidget`, which must not be read during `initState`. Move the fetch kickoff to `didChangeDependencies` and capture the propensity there.

Change the field (around line 88) from:

```dart
  late final Future<MobileFrontierPreviewResponse?> _frontierPreviewFuture;
```

to:

```dart
  late Future<MobileFrontierPreviewResponse?> _frontierPreviewFuture;
  double _propensityScore = 45.0;
  bool _previewStarted = false;
```

Change `initState` (around line 90) to NOT start the future:

```dart
  @override
  void initState() {
    super.initState();
    logPageEnter('OnboardingScreen');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_previewStarted) return;
    _previewStarted = true;
    _propensityScore =
        PortfolioStateProvider.of(context).investorProfile?.propensityScore ??
            45.0;
    _frontierPreviewFuture = _fetchFrontierPreview();
  }
```

In `_fetchFrontierPreview` (around line 99), change the hardcoded `propensityScore: 45.0,` to:

```dart
        propensityScore: _propensityScore,
```

- [ ] **Step 4: Verify the whole feature analyzes and tests pass**

Run: `cd Front-End/robo_mobile && ./tool/flutterw analyze`
Expected: No NEW issues introduced by these files (compare against a baseline `analyze` on the unchanged tree if needed).

Run: `cd Front-End/robo_mobile && ./tool/flutterw test test/survey_scoring_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** (only if the user has asked to commit; otherwise leave staged changes for review)

```bash
git add -A
git commit -m "feat: add investor suitability survey onboarding"
```

---

## Self-Review

**Spec coverage:** Flow (Task 6 Step 1, Task 4, Task 5) ✓. 6 questions + options verbatim (Task 2) ✓. Result screen content (Task 5) ✓. Scoring rubric + level table (Task 1, Task 2) ✓. Persistence (Task 6 Step 2) ✓. Frontier seeding (Task 6 Step 3) ✓. Re-take link (Task 5 `_retake`) ✓. Always-show gating (Task 6 Step 1 reroutes the chokepoint; no flag) ✓. Styling tokens (all UI tasks) ✓. Tests (Task 2) ✓. Out-of-scope items not implemented ✓.

**Placeholder scan:** No TBD/TODO. The one "read the file to match the prefs pattern" note in Task 6 Step 2 is a concrete instruction with fallback code, not a placeholder.

**Type consistency:** `RiskLevel` enum names, `InvestorProfile` fields, `scoreSurvey`/`riskLevelForScore` signatures, `setInvestorProfile`/`investorProfile`, and widget constructor params (`SurveyProgressBar(step,total)`, `SurveyOptionButton(label,selected,onTap)`, `RiskLevelScale(active)`, `SurveyResultScreen(profile:)`) are used consistently across tasks.
