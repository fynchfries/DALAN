import 'package:flutter_test/flutter_test.dart';
import 'package:dalan/features/career/data/career_catalog.dart';
import 'package:dalan/features/career/domain/recommendation.dart';
import 'package:dalan/features/discover/domain/assessment.dart';
import 'package:dalan/features/planner/domain/roadmap.dart';
import 'package:dalan/shared/models/workspace.dart';

void main() {
  group('assessment reflection scoring', () {
    test('scores each dimension reproducibly from its answers', () {
      final answers = {
        for (final question in assessmentQuestions) question.id: 1,
      };
      answers['q1'] = 5;
      answers['q2'] = 5;
      final scores = calculateAssessmentScores(answers);
      expect(scores['creative'], 100);
      expect(scores['analytical'], 0);
      expect(scores['helping'], 0);
      expect(scores['building'], 0);
    });

    test('rejects missing or out-of-range answers', () {
      expect(() => calculateAssessmentScores({'q1': 3}), throwsArgumentError);
      final answers = {
        for (final question in assessmentQuestions) question.id: 3,
      };
      answers['q1'] = 6;
      expect(() => calculateAssessmentScores(answers), throwsArgumentError);
    });
  });

  group('career matching', () {
    test('uses available signals and explains the result', () {
      final results = recommendCareers(
        careers: careerCatalog,
        interests: {'technology'},
        reflectionScores: const {'analytical': 80},
        practicedSkills: {'coding'},
      );
      expect(results, isNotEmpty);
      expect(results.first.score, inInclusiveRange(0, 100));
      expect(results.first.explanation, isNotEmpty);
      expect(results.first.hasSignals, isTrue);
      expect(results.first.matchingInterests, contains('technology'));
      expect(results.first.skillGaps, isNotEmpty);
    });

    test('missing profile data returns usable catalog recommendations', () {
      final results = recommendCareers(
        careers: careerCatalog,
        interests: {},
        reflectionScores: {},
        practicedSkills: {},
      );
      expect(results, hasLength(careerCatalog.length));
      expect(results.every((item) => item.score == 0), isTrue);
      expect(results.every((item) => !item.hasSignals), isTrue);
      expect(results.every((item) => item.explanation.isNotEmpty), isTrue);
    });
  });

  group('grade-aware roadmap', () {
    final career = careerCatalog.first;
    test('changes activity format and expected grade range', () {
      final early = buildStarterRoadmap(career, 3);
      final older = buildStarterRoadmap(career, 10);
      expect(early, hasLength(3));
      expect(early.first.description, contains('Draw'));
      expect(older.first.description, contains('questions'));
      expect(early.first.gradeMax, 5);
      expect(older.first.gradeMin, 9);
      expect(early.last.minutes, lessThan(older.last.minutes));
    });

    test('rejects grades outside supported range', () {
      expect(() => buildStarterRoadmap(career, 0), throwsArgumentError);
      expect(() => buildStarterRoadmap(career, 13), throwsArgumentError);
    });
  });

  test(
    'task status keeps completion evidence separate from assessment score',
    () {
      const task = LearningTask(
        id: 'task',
        title: 'Task',
        description: 'Try',
        skillId: 'coding',
        minutes: 10,
      );
      final done = task.withStatus('completed');
      expect(done.status, 'completed');
      expect(done.completedAt, isNotNull);
      expect(done.learningObjective, isEmpty);
    },
  );
}
