import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/career/data/career_catalog.dart';
import '../../features/career/domain/career.dart';
import '../../features/discover/domain/assessment.dart';
import '../../features/planner/domain/roadmap.dart';
import '../models/workspace.dart';
import '../utils/iterable_extensions.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final workspaceProvider = StateNotifierProvider<WorkspaceController, Workspace>(
  (ref) {
    return WorkspaceController(ref.watch(sharedPreferencesProvider));
  },
);

class WorkspaceController extends StateNotifier<Workspace> {
  WorkspaceController(this._preferences) : super(_read(_preferences));

  static const _storageKey = 'dalan_demo_workspace_v1';
  final SharedPreferences _preferences;
  static final _random = Random();

  static Workspace _read(SharedPreferences preferences) {
    final value = preferences.getString(_storageKey);
    if (value == null) return const Workspace();
    try {
      return Workspace.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      return const Workspace();
    }
  }

  void _save(Workspace next) {
    state = next;
    unawaited(_preferences.setString(_storageKey, jsonEncode(next.toJson())));
  }

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(100000)}';

  void finishSetup({
    required String displayName,
    required int grade,
    required Set<String> interests,
  }) {
    final name = displayName.trim();
    if (name.isEmpty || name.length > 40 || grade < 1 || grade > 12) {
      throw ArgumentError(
        'Enter a display name and choose a grade from 1 to 12.',
      );
    }
    _save(
      state.copyWith(
        setupComplete: true,
        displayName: name,
        grade: grade,
        interests: interests,
      ),
    );
  }

  void updateProfile({
    String? displayName,
    int? grade,
    Set<String>? interests,
  }) {
    if (displayName != null &&
        (displayName.trim().isEmpty || displayName.trim().length > 40)) {
      throw ArgumentError('Display name must be 1–40 characters.');
    }
    if (grade != null && (grade < 1 || grade > 12)) {
      throw ArgumentError('Grade must be 1–12.');
    }
    var tasks = state.tasks;
    var pastTasks = state.pastTasks;
    if (grade != null && grade != state.grade && state.goalCareerId != null) {
      final career = careerCatalog
          .where((item) => item.id == state.goalCareerId)
          .firstOrNull;
      if (career != null) {
        pastTasks = [...pastTasks, ...tasks];
        tasks = buildStarterRoadmap(career, grade);
      }
    }
    _save(
      state.copyWith(
        displayName: displayName?.trim(),
        grade: grade,
        interests: interests,
        tasks: tasks,
        pastTasks: pastTasks,
      ),
    );
  }

  void answerQuestion(String questionId, int answer) {
    if (answer < 1 ||
        answer > 5 ||
        !assessmentQuestions.any((item) => item.id == questionId)) {
      return;
    }
    _save(state.copyWith(answers: {...state.answers, questionId: answer}));
  }

  void completeAssessment() {
    final scores = calculateAssessmentScores(state.answers);
    _save(
      state.copyWith(
        assessmentScores: scores,
        assessmentVersion: assessmentVersion,
        assessmentCompletedAt: DateTime.now(),
      ),
    );
  }

  void saveJournal(String? id, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw ArgumentError('Journal entries must contain 1–2,000 characters.');
    }
    final entries = [...state.journals];
    final index = entries.indexWhere((entry) => entry.id == id);
    final entry = JournalEntry(
      id: id ?? _id(),
      text: trimmed,
      updatedAt: DateTime.now(),
    );
    if (index == -1) {
      entries.insert(0, entry);
    } else {
      entries[index] = entry;
    }
    _save(state.copyWith(journals: entries));
  }

  void deleteJournal(String id) => _save(
        state.copyWith(
          journals: state.journals.where((entry) => entry.id != id).toList(),
        ),
      );

  void toggleSavedCareer(String careerId) {
    final saved = {...state.savedCareers};
    saved.contains(careerId) ? saved.remove(careerId) : saved.add(careerId);
    _save(state.copyWith(savedCareers: saved));
  }

  void dismissCareer(String careerId) => _save(
        state.copyWith(dismissedCareers: {...state.dismissedCareers, careerId}),
      );

  void pauseGoal() => _save(
        state.copyWith(
          clearGoal: true,
          tasks: const [],
          pastTasks: [...state.pastTasks, ...state.tasks],
        ),
      );

  void setCareerGoal(Career career) {
    _save(
      state.copyWith(
        goalCareerId: career.id,
        tasks: buildStarterRoadmap(career, state.grade),
        pastTasks: [...state.pastTasks, ...state.tasks],
      ),
    );
  }

  void updateTaskStatus(String taskId, String status) {
    const allowed = {'not_started', 'in_progress', 'completed'};
    if (!allowed.contains(status)) throw ArgumentError('Invalid task status.');
    _save(
      state.copyWith(
        tasks: state.tasks
            .map((task) => task.id == taskId ? task.withStatus(status) : task)
            .toList(),
      ),
    );
  }

  void setNetworkingEnabled(bool value) =>
      _save(state.copyWith(networkingEnabled: value));

  void requestDemoConnection(String profileId) {
    if (!state.networkingEnabled || state.blockedProfiles.contains(profileId)) {
      return;
    }
    if (state.connections.any(
      (connection) => connection.profileId == profileId,
    )) {
      return;
    }
    _save(
      state.copyWith(
        connections: [
          ...state.connections,
          DemoConnection(profileId: profileId, status: 'pending'),
        ],
      ),
    );
  }

  void updateDemoConnection(String profileId, String status) {
    const allowed = {'pending', 'accepted'};
    if (!allowed.contains(status)) return;
    _save(
      state.copyWith(
        connections: state.connections
            .map(
              (connection) => connection.profileId == profileId
                  ? DemoConnection(profileId: profileId, status: status)
                  : connection,
            )
            .toList(),
      ),
    );
  }

  void cancelDemoConnection(String profileId) => _save(
        state.copyWith(
          connections: state.connections
              .where((item) => item.profileId != profileId)
              .toList(),
        ),
      );

  void respondDemoRequest(String profileId, {required bool accepted}) {
    if (!state.networkingEnabled || state.blockedProfiles.contains(profileId)) {
      return;
    }
    final connections =
        state.connections.where((item) => item.profileId != profileId).toList()
          ..add(
            DemoConnection(
              profileId: profileId,
              status: accepted ? 'accepted' : 'declined',
            ),
          );
    _save(state.copyWith(connections: connections));
  }

  void blockDemoProfile(String profileId) => _save(
        state.copyWith(
          blockedProfiles: {...state.blockedProfiles, profileId},
          connections: state.connections
              .where((item) => item.profileId != profileId)
              .toList(),
        ),
      );

  void reportDemoProfile(String profileId) => _save(
        state
            .copyWith(reportedProfiles: {...state.reportedProfiles, profileId}),
      );

  Future<void> clearAll() async {
    await _preferences.remove(_storageKey);
    state = const Workspace();
  }
}
