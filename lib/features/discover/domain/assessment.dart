const assessmentVersion = '1.0';

class AssessmentQuestion {
  const AssessmentQuestion(this.id, this.prompt, this.dimension);
  final String id;
  final String prompt;
  final String dimension;
}

/// An original, non-clinical reflection questionnaire. It is not a validated
/// psychometric instrument and must not be used to diagnose or limit choices.
const assessmentQuestions = <AssessmentQuestion>[
  AssessmentQuestion(
    'q1',
    'I enjoy finding different ways to make something.',
    'creative',
  ),
  AssessmentQuestion(
    'q2',
    'I like expressing ideas through stories, art, or design.',
    'creative',
  ),
  AssessmentQuestion(
    'q3',
    'I enjoy figuring out how a problem works.',
    'analytical',
  ),
  AssessmentQuestion(
    'q4',
    'I like looking for patterns and asking why.',
    'analytical',
  ),
  AssessmentQuestion(
    'q5',
    'I feel good when I help someone learn or solve a challenge.',
    'helping',
  ),
  AssessmentQuestion(
    'q6',
    'I like listening to people and understanding their point of view.',
    'helping',
  ),
  AssessmentQuestion(
    'q7',
    'I enjoy making, fixing, or trying things hands-on.',
    'building',
  ),
  AssessmentQuestion(
    'q8',
    'I like learning how tools, machines, or systems work.',
    'building',
  ),
];

/// Each dimension is the mean of two answers, scaled from 1–5 to 0–100.
Map<String, double> calculateAssessmentScores(Map<String, int> answers) {
  if (assessmentQuestions.any(
    (question) => !answers.containsKey(question.id),
  )) {
    throw ArgumentError(
      'Answer every question before viewing reflection results.',
    );
  }
  if (answers.values.any((value) => value < 1 || value > 5)) {
    throw ArgumentError('Answers must be between 1 and 5.');
  }

  final grouped = <String, List<int>>{};
  for (final question in assessmentQuestions) {
    grouped
        .putIfAbsent(question.dimension, () => [])
        .add(answers[question.id]!);
  }
  return grouped.map((dimension, values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    return MapEntry(dimension, ((mean - 1) / 4 * 100).roundToDouble());
  });
}
