import 'package:flutter_test/flutter_test.dart';
import 'package:robo_mobile/models/investor_profile.dart';
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
