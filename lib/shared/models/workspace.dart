import 'package:flutter/foundation.dart';

@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.text,
    required this.updatedAt,
  });
  final String id;
  final String text;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        'updatedAt': updatedAt.toIso8601String(),
      };
  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        text: json['text'] as String,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

@immutable
class LearningTask {
  const LearningTask({
    required this.id,
    required this.title,
    required this.description,
    required this.skillId,
    required this.minutes,
    this.learningObjective = '',
    this.gradeMin = 1,
    this.gradeMax = 12,
    this.difficulty = 'beginner',
    this.completionCriteria =
        'Complete the activity and reflect on what you learned.',
    this.status = 'not_started',
    this.completedAt,
  });
  final String id;
  final String title;
  final String description;
  final String skillId;
  final int minutes;
  final String learningObjective;
  final int gradeMin;
  final int gradeMax;
  final String difficulty;
  final String completionCriteria;
  final String status;
  final DateTime? completedAt;

  LearningTask withStatus(String value) => LearningTask(
        id: id,
        title: title,
        description: description,
        skillId: skillId,
        minutes: minutes,
        learningObjective: learningObjective,
        gradeMin: gradeMin,
        gradeMax: gradeMax,
        difficulty: difficulty,
        completionCriteria: completionCriteria,
        status: value,
        completedAt: value == 'completed' ? DateTime.now() : null,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'skillId': skillId,
        'minutes': minutes,
        'learningObjective': learningObjective,
        'gradeMin': gradeMin,
        'gradeMax': gradeMax,
        'difficulty': difficulty,
        'completionCriteria': completionCriteria,
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
      };
  factory LearningTask.fromJson(Map<String, dynamic> json) => LearningTask(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        skillId: json['skillId'] as String,
        minutes: json['minutes'] as int? ?? 15,
        learningObjective: json['learningObjective'] as String? ?? '',
        gradeMin: json['gradeMin'] as int? ?? 1,
        gradeMax: json['gradeMax'] as int? ?? 12,
        difficulty: json['difficulty'] as String? ?? 'beginner',
        completionCriteria: json['completionCriteria'] as String? ??
            'Complete the activity and reflect on what you learned.',
        status: json['status'] as String? ?? 'not_started',
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      );
}

@immutable
class DemoConnection {
  const DemoConnection({required this.profileId, required this.status});
  final String profileId;
  final String status;
  Map<String, Object?> toJson() => {'profileId': profileId, 'status': status};
  factory DemoConnection.fromJson(Map<String, dynamic> json) => DemoConnection(
        profileId: json['profileId'] as String,
        status: json['status'] as String,
      );
}

@immutable
class Workspace {
  const Workspace({
    this.setupComplete = false,
    this.displayName = 'Learner',
    this.grade = 7,
    this.interests = const {},
    this.answers = const {},
    this.assessmentScores = const {},
    this.assessmentVersion = '1.0',
    this.assessmentCompletedAt,
    this.journals = const [],
    this.savedCareers = const {},
    this.dismissedCareers = const {},
    this.goalCareerId,
    this.tasks = const [],
    this.pastTasks = const [],
    this.networkingEnabled = false,
    this.connections = const [],
    this.blockedProfiles = const {},
    this.reportedProfiles = const {},
  });

  final bool setupComplete;
  final String displayName;
  final int grade;
  final Set<String> interests;
  final Map<String, int> answers;
  final Map<String, double> assessmentScores;
  final String assessmentVersion;
  final DateTime? assessmentCompletedAt;
  final List<JournalEntry> journals;
  final Set<String> savedCareers;
  final Set<String> dismissedCareers;
  final String? goalCareerId;
  final List<LearningTask> tasks;
  final List<LearningTask> pastTasks;
  final bool networkingEnabled;
  final List<DemoConnection> connections;
  final Set<String> blockedProfiles;
  final Set<String> reportedProfiles;

  Workspace copyWith({
    bool? setupComplete,
    String? displayName,
    int? grade,
    Set<String>? interests,
    Map<String, int>? answers,
    Map<String, double>? assessmentScores,
    String? assessmentVersion,
    DateTime? assessmentCompletedAt,
    bool clearAssessmentDate = false,
    List<JournalEntry>? journals,
    Set<String>? savedCareers,
    Set<String>? dismissedCareers,
    String? goalCareerId,
    bool clearGoal = false,
    List<LearningTask>? tasks,
    List<LearningTask>? pastTasks,
    bool? networkingEnabled,
    List<DemoConnection>? connections,
    Set<String>? blockedProfiles,
    Set<String>? reportedProfiles,
  }) =>
      Workspace(
        setupComplete: setupComplete ?? this.setupComplete,
        displayName: displayName ?? this.displayName,
        grade: grade ?? this.grade,
        interests: interests ?? this.interests,
        answers: answers ?? this.answers,
        assessmentScores: assessmentScores ?? this.assessmentScores,
        assessmentVersion: assessmentVersion ?? this.assessmentVersion,
        assessmentCompletedAt: clearAssessmentDate
            ? null
            : assessmentCompletedAt ?? this.assessmentCompletedAt,
        journals: journals ?? this.journals,
        savedCareers: savedCareers ?? this.savedCareers,
        dismissedCareers: dismissedCareers ?? this.dismissedCareers,
        goalCareerId: clearGoal ? null : goalCareerId ?? this.goalCareerId,
        tasks: tasks ?? this.tasks,
        pastTasks: pastTasks ?? this.pastTasks,
        networkingEnabled: networkingEnabled ?? this.networkingEnabled,
        connections: connections ?? this.connections,
        blockedProfiles: blockedProfiles ?? this.blockedProfiles,
        reportedProfiles: reportedProfiles ?? this.reportedProfiles,
      );

  Map<String, Object?> toJson() => {
        'setupComplete': setupComplete,
        'displayName': displayName,
        'grade': grade,
        'interests': interests.toList(),
        'answers': answers,
        'assessmentScores': assessmentScores,
        'assessmentVersion': assessmentVersion,
        'assessmentCompletedAt': assessmentCompletedAt?.toIso8601String(),
        'journals': journals.map((entry) => entry.toJson()).toList(),
        'savedCareers': savedCareers.toList(),
        'dismissedCareers': dismissedCareers.toList(),
        'goalCareerId': goalCareerId,
        'tasks': tasks.map((task) => task.toJson()).toList(),
        'pastTasks': pastTasks.map((task) => task.toJson()).toList(),
        'networkingEnabled': networkingEnabled,
        'connections': connections.map((item) => item.toJson()).toList(),
        'blockedProfiles': blockedProfiles.toList(),
        'reportedProfiles': reportedProfiles.toList(),
      };

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        setupComplete: json['setupComplete'] as bool? ?? false,
        displayName: json['displayName'] as String? ?? 'Learner',
        grade: ((json['grade'] as num?)?.toInt() ?? 7).clamp(1, 12).toInt(),
        interests: Set<String>.from(json['interests'] as List? ?? const []),
        answers: (json['answers'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
        assessmentScores: (json['assessmentScores'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
        assessmentVersion: json['assessmentVersion'] as String? ?? '1.0',
        assessmentCompletedAt: DateTime.tryParse(
          json['assessmentCompletedAt'] as String? ?? '',
        ),
        journals: (json['journals'] as List? ?? const [])
            .map(
              (value) => JournalEntry.fromJson(
                  Map<String, dynamic>.from(value as Map)),
            )
            .toList(),
        savedCareers:
            Set<String>.from(json['savedCareers'] as List? ?? const []),
        dismissedCareers: Set<String>.from(
          json['dismissedCareers'] as List? ?? const [],
        ),
        goalCareerId: json['goalCareerId'] as String?,
        tasks: (json['tasks'] as List? ?? const [])
            .map(
              (value) => LearningTask.fromJson(
                  Map<String, dynamic>.from(value as Map)),
            )
            .toList(),
        pastTasks: (json['pastTasks'] as List? ?? const [])
            .map(
              (value) => LearningTask.fromJson(
                  Map<String, dynamic>.from(value as Map)),
            )
            .toList(),
        networkingEnabled: json['networkingEnabled'] as bool? ?? false,
        connections: (json['connections'] as List? ?? const [])
            .map(
              (value) => DemoConnection.fromJson(
                  Map<String, dynamic>.from(value as Map)),
            )
            .toList(),
        blockedProfiles: Set<String>.from(
          json['blockedProfiles'] as List? ?? const [],
        ),
        reportedProfiles: Set<String>.from(
          json['reportedProfiles'] as List? ?? const [],
        ),
      );
}
