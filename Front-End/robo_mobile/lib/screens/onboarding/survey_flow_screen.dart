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
