import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalan/features/career/data/career_catalog.dart';
import 'package:dalan/shared/services/workspace_controller.dart';

void main() {
  late SharedPreferences preferences;
  late WorkspaceController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    controller = WorkspaceController(preferences);
  });

  test('profile and journal data survive workspace reload', () async {
    controller.finishSetup(
      displayName: 'Kai',
      grade: 6,
      interests: {'technology'},
    );
    controller.saveJournal(null, 'I enjoyed making a small game.');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final restored = WorkspaceController(preferences);
    expect(restored.state.displayName, 'Kai');
    expect(restored.state.grade, 6);
    expect(restored.state.interests, contains('technology'));
    expect(
      restored.state.journals.single.text,
      'I enjoyed making a small game.',
    );
  });

  test('assessment completion stores reproducible scores and version', () {
    for (final id in ['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q8']) {
      controller.answerQuestion(id, 4);
    }
    controller.completeAssessment();
    expect(controller.state.assessmentVersion, '1.0');
    expect(controller.state.assessmentScores['creative'], 75);
    expect(controller.state.assessmentCompletedAt, isNotNull);
  });

  test('journal validates length and supports editing and deletion', () {
    expect(() => controller.saveJournal(null, '   '), throwsArgumentError);
    expect(() => controller.saveJournal(null, 'x' * 2001), throwsArgumentError);
    controller.saveJournal(null, 'First note');
    final id = controller.state.journals.single.id;
    controller.saveJournal(id, 'Edited note');
    expect(controller.state.journals, hasLength(1));
    expect(controller.state.journals.single.text, 'Edited note');
    controller.deleteJournal(id);
    expect(controller.state.journals, isEmpty);
  });

  test(
    'goal changes build a grade-level roadmap and task completion is retained',
    () {
      controller.finishSetup(displayName: 'Kai', grade: 3, interests: {});
      controller.setCareerGoal(careerCatalog.first);
      expect(controller.state.goalCareerId, careerCatalog.first.id);
      expect(controller.state.tasks.first.gradeMax, 5);
      final task = controller.state.tasks.first;
      controller.updateTaskStatus(task.id, 'in_progress');
      expect(controller.state.tasks.first.status, 'in_progress');
      controller.updateTaskStatus(task.id, 'completed');
      expect(controller.state.tasks.first.completedAt, isNotNull);
      expect(
        () => controller.updateTaskStatus(task.id, 'invalid'),
        throwsArgumentError,
      );
      controller.setCareerGoal(careerCatalog.last);
      expect(controller.state.pastTasks.first.status, 'completed');
      expect(controller.state.goalCareerId, careerCatalog.last.id);
      controller.updateProfile(grade: 10);
      expect(controller.state.tasks.first.gradeMin, 9);
      expect(controller.state.pastTasks, hasLength(6));
    },
  );

  test(
    'demo connection state supports opt-in, request, response, and blocking',
    () {
      controller.requestDemoConnection('sample_jo');
      expect(
        controller.state.connections,
        isEmpty,
        reason: 'networking is off by default',
      );
      controller.setNetworkingEnabled(true);
      controller.requestDemoConnection('sample_jo');
      expect(controller.state.connections.single.status, 'pending');
      controller.cancelDemoConnection('sample_jo');
      expect(controller.state.connections, isEmpty);
      controller.respondDemoRequest('sample_mika', accepted: true);
      expect(controller.state.connections.single.status, 'accepted');
      controller.blockDemoProfile('sample_mika');
      expect(controller.state.blockedProfiles, contains('sample_mika'));
      expect(controller.state.connections, isEmpty);
    },
  );
}
