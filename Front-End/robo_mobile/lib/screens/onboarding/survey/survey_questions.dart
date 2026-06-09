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
