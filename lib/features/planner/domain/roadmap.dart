import '../../../shared/models/workspace.dart';
import '../../career/domain/career.dart';

/// Curated starter roadmap with grade-appropriate activity formats. The tasks
/// are illustrative and intentionally small; no generated content is published.
List<LearningTask> buildStarterRoadmap(Career career, int grade) {
  if (grade < 1 || grade > 12) {
    throw ArgumentError.value(grade, 'grade', 'Expected 1–12.');
  }
  final younger = grade <= 5;
  final middle = grade <= 8;
  final gradeMin = younger
      ? 1
      : middle
          ? 6
          : 9;
  final gradeMax = younger
      ? 5
      : middle
          ? 8
          : 12;
  final difficulty = younger
      ? 'beginner'
      : middle
          ? 'developing'
          : 'beginner_plus';
  return [
    LearningTask(
      id: '${career.id}_explore',
      title: 'Explore ${career.title}',
      description: younger
          ? 'Draw or describe one thing this career might do. Share your idea with a trusted adult.'
          : 'Read the overview and write down two questions you still have about this career.',
      skillId: career.skills.first,
      minutes: younger ? 10 : 15,
      learningObjective:
          'Describe one responsibility or question about this career.',
      gradeMin: gradeMin,
      gradeMax: gradeMax,
      difficulty: difficulty,
      completionCriteria: 'Share one idea or write two questions.',
    ),
    LearningTask(
      id: '${career.id}_practice',
      title: 'Practice ${_labelFor(career.skills.last)}',
      description: middle
          ? 'Try a short, beginner-friendly activity that uses ${_labelFor(career.skills.last).toLowerCase()}. Ask for help when you need it.'
          : 'Choose a small challenge related to ${_labelFor(career.skills.last).toLowerCase()} and reflect on what you learned.',
      skillId: career.skills.last,
      minutes: younger ? 15 : 25,
      learningObjective:
          'Practice ${_labelFor(career.skills.last)} in a safe, beginner activity.',
      gradeMin: gradeMin,
      gradeMax: gradeMax,
      difficulty: difficulty,
      completionCriteria: 'Try the activity and note one thing you learned.',
    ),
    LearningTask(
      id: '${career.id}_make',
      title: 'Make a mini project',
      description: younger
          ? career.activity
          : 'Plan and make a small project inspired by ${career.title.toLowerCase()}. Explain one change you would make next time.',
      skillId:
          career.skills.length > 1 ? career.skills[1] : career.skills.first,
      minutes: younger ? 20 : 35,
      learningObjective: 'Create a small project inspired by ${career.title}.',
      gradeMin: gradeMin,
      gradeMax: gradeMax,
      difficulty: difficulty,
      completionCriteria:
          'Finish a small project and identify one possible improvement.',
    ),
  ];
}

String _labelFor(String id) {
  const labels = {
    'problem_solving': 'Problem-solving',
    'coding': 'Coding',
    'communication': 'Communication',
    'teamwork': 'Teamwork',
    'science': 'Science',
    'creativity': 'Creativity',
  };
  return labels[id] ?? id.replaceAll('_', ' ');
}
