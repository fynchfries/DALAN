class Career {
  const Career({
    required this.id,
    required this.title,
    required this.summary,
    required this.responsibilities,
    required this.interests,
    required this.dimensions,
    required this.skills,
    required this.education,
    required this.activity,
    required this.related,
  });

  final String id;
  final String title;
  final String summary;
  final List<String> responsibilities;
  final List<String> interests;
  final Map<String, double> dimensions;
  final List<String> skills;
  final String education;
  final String activity;
  final List<String> related;
}
