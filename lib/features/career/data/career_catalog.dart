import '../domain/career.dart';

/// Curated illustrative seed data, not verified labor-market or licensing advice.
const careerCatalog = <Career>[
  Career(
    id: 'software_developer',
    title: 'Software Developer',
    summary: 'Creates and improves apps, websites, and other software.',
    responsibilities: [
      'Break problems into steps',
      'Write and test code',
      'Work with a team to improve a product',
    ],
    interests: ['technology', 'creating', 'problem_solving'],
    dimensions: {'analytical': 0.8, 'creative': 0.7, 'building': 0.5},
    skills: ['problem_solving', 'coding', 'communication'],
    education:
        'Many routes are possible, including school courses, projects, certificates, or a degree. Requirements vary by role and location.',
    activity: 'Design a simple app that helps with one small everyday problem.',
    related: ['game_designer', 'data_analyst'],
  ),
  Career(
    id: 'nurse',
    title: 'Nurse',
    summary: 'Supports people’s health as part of a care team.',
    responsibilities: [
      'Listen to patients',
      'Share health information',
      'Work with a supervised care team',
    ],
    interests: ['helping', 'science', 'communication'],
    dimensions: {'helping': 0.9, 'analytical': 0.5, 'building': 0.2},
    skills: ['communication', 'teamwork', 'science'],
    education:
        'Nursing roles require approved education and licensing that depend on the country and role. Check official local guidance.',
    activity:
        'Explore how a care team communicates, then make a poster about a healthy habit using trusted sources.',
    related: ['teacher', 'environmental_scientist'],
  ),
  Career(
    id: 'teacher',
    title: 'Teacher',
    summary: 'Helps learners understand ideas and build confidence.',
    responsibilities: [
      'Explain ideas in different ways',
      'Plan learning activities',
      'Encourage and support learners',
    ],
    interests: ['helping', 'learning', 'communication', 'creating'],
    dimensions: {'helping': 0.9, 'creative': 0.6, 'analytical': 0.4},
    skills: ['communication', 'teamwork', 'creativity'],
    education:
        'Teacher preparation and certification depend on the school system and location. This guide is a starting point, not a qualification checklist.',
    activity:
        'Teach someone a favorite concept using a drawing, demonstration, or short explanation.',
    related: ['nurse', 'designer'],
  ),
  Career(
    id: 'designer',
    title: 'Product Designer',
    summary: 'Plans how products look, feel, and work for people.',
    responsibilities: [
      'Learn what people need',
      'Sketch and test ideas',
      'Improve designs using feedback',
    ],
    interests: ['creating', 'people', 'problem_solving'],
    dimensions: {'creative': 0.9, 'helping': 0.4, 'analytical': 0.5},
    skills: ['creativity', 'problem_solving', 'communication'],
    education:
        'Designers build skills through projects and different education routes. There is no single required path for every role.',
    activity:
        'Redesign a classroom object so it is easier for more people to use.',
    related: ['software_developer', 'game_designer'],
  ),
  Career(
    id: 'environmental_scientist',
    title: 'Environmental Scientist',
    summary: 'Studies the natural world and ways to care for it.',
    responsibilities: [
      'Observe the environment',
      'Collect and interpret information',
      'Explain findings and possible solutions',
    ],
    interests: ['science', 'nature', 'problem_solving'],
    dimensions: {'analytical': 0.8, 'helping': 0.5, 'building': 0.3},
    skills: ['science', 'problem_solving', 'communication'],
    education:
        'Some roles ask for science education or field experience. Requirements differ; consult current local career and education sources.',
    activity:
        'Keep a short observation log about a local plant, animal, or weather pattern.',
    related: ['nurse', 'data_analyst'],
  ),
  Career(
    id: 'game_designer',
    title: 'Game Designer',
    summary: 'Creates the rules, stories, and experiences in games.',
    responsibilities: [
      'Develop game ideas',
      'Test whether play is clear and fun',
      'Collaborate with artists and developers',
    ],
    interests: ['technology', 'creating', 'problem_solving'],
    dimensions: {'creative': 0.9, 'analytical': 0.6, 'building': 0.4},
    skills: ['creativity', 'problem_solving', 'coding'],
    education:
        'People enter game design through varied study and project paths. A portfolio can help demonstrate skills; no universal credential is implied here.',
    activity:
        'Create a paper prototype for a short game, then ask someone to try it.',
    related: ['software_developer', 'designer'],
  ),
  Career(
    id: 'data_analyst',
    title: 'Data Analyst',
    summary: 'Looks for useful patterns in information and explains them.',
    responsibilities: [
      'Ask clear questions',
      'Organize and explore data',
      'Communicate findings honestly',
    ],
    interests: ['technology', 'science', 'problem_solving'],
    dimensions: {'analytical': 0.9, 'creative': 0.3, 'building': 0.4},
    skills: ['problem_solving', 'communication', 'coding'],
    education:
        'Data roles use different tools and education routes. This illustrative overview does not describe a specific employer requirement.',
    activity:
        'Collect a small, non-private class survey and show its results in a simple chart.',
    related: ['software_developer', 'environmental_scientist'],
  ),
];

const interestOptions = <String, String>{
  'technology': 'Technology',
  'creating': 'Creating',
  'problem_solving': 'Solving problems',
  'helping': 'Helping people',
  'science': 'Science',
  'communication': 'Communication',
  'learning': 'Learning',
  'people': 'Understanding people',
  'nature': 'Nature',
};

const skillLabels = <String, String>{
  'problem_solving': 'Problem-solving',
  'coding': 'Coding',
  'communication': 'Communication',
  'teamwork': 'Teamwork',
  'science': 'Science',
  'creativity': 'Creativity',
};
