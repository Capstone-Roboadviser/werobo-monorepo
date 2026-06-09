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
