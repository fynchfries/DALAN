import 'career.dart';

const careerRecommendationAlgorithmVersion = 'career-match-v1';

class CareerRecommendation {
  const CareerRecommendation({
    required this.career,
    required this.score,
    required this.hasSignals,
    required this.matchingInterests,
    required this.relevantSkills,
    required this.skillGaps,
    required this.explanation,
  });

  final Career career;
  final int score;
  final bool hasSignals;
  final List<String> matchingInterests;
  final List<String> relevantSkills;
  final List<String> skillGaps;
  final String explanation;
}

/// Explainable product heuristic v1, not a validated measure of career fit.
/// Available signals are reweighted: interests 50%, reflection dimensions 30%,
/// demonstrated practice evidence 20%. Missing signals are excluded, not scored
/// as zero. The displayed score is similarity to supplied preferences only.
List<CareerRecommendation> recommendCareers({
  required Iterable<Career> careers,
  required Set<String> interests,
  required Map<String, double> reflectionScores,
  required Set<String> practicedSkills,
}) {
  const weights = <String, double>{
    'interest': .50,
    'reflection': .30,
    'skill': .20,
  };
  final result = careers.map((career) {
    final matched = career.interests.where(interests.contains).toList();
    final interestScore =
        interests.isEmpty ? null : matched.length / interests.length;

    final matchingDimensions =
        career.dimensions.keys.where(reflectionScores.containsKey).toList();
    final reflectionScore = matchingDimensions.isEmpty
        ? null
        : matchingDimensions
                .map(
                  (key) =>
                      1 -
                      ((reflectionScores[key]!.clamp(0, 100).toDouble() / 100) -
                              career.dimensions[key]!)
                          .abs(),
                )
                .reduce((a, b) => a + b) /
            matchingDimensions.length;

    final relevant = career.skills.where(practicedSkills.contains).toList();
    final skillScore = practicedSkills.isEmpty || career.skills.isEmpty
        ? null
        : relevant.length / career.skills.length;
    final signals = <(String, double)?>[
      interestScore == null ? null : ('interest', interestScore),
      reflectionScore == null ? null : ('reflection', reflectionScore),
      skillScore == null ? null : ('skill', skillScore),
    ].whereType<(String, double)>();
    final weightTotal = signals.fold<double>(
      0,
      (sum, entry) => sum + weights[entry.$1]!,
    );
    final score = weightTotal == 0
        ? 0
        : (signals.fold<double>(
                  0,
                  (sum, entry) => sum + entry.$2 * weights[entry.$1]!,
                ) /
                weightTotal *
                100)
            .round();
    final gaps = career.skills
        .where((skill) => !practicedSkills.contains(skill))
        .toList();
    final reasons = <String>[];
    if (matched.isNotEmpty) reasons.add('interests you selected');
    if (reflectionScore != null) reasons.add('your self-reflections');
    if (relevant.isNotEmpty) reasons.add('skills you have practiced');
    final hasSignals = weightTotal > 0;
    final explanation = !hasSignals
        ? 'Explore this option and decide what interests you. Add interests or reflections for more tailored suggestions.'
        : reasons.isEmpty
            ? 'Your current inputs show limited overlap with this option. You can still explore it—no match score predicts what you can become.'
            : 'Suggested because it connects with ${reasons.join(' and ')}. This is a starting point—not a prediction of success.';

    return CareerRecommendation(
      career: career,
      score: score,
      hasSignals: hasSignals,
      matchingInterests: matched,
      relevantSkills: relevant,
      skillGaps: gaps,
      explanation: explanation,
    );
  }).toList();

  result.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    return scoreOrder == 0 ? a.career.id.compareTo(b.career.id) : scoreOrder;
  });
  return result;
}
