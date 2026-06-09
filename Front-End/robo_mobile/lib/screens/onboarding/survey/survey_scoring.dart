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
