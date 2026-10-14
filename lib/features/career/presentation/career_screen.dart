import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/widgets/common.dart';
import '../data/career_catalog.dart';
import '../domain/recommendation.dart';

class CareerScreen extends ConsumerStatefulWidget {
  const CareerScreen({super.key});
  @override
  ConsumerState<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends ConsumerState<CareerScreen> {
  final _search = TextEditingController();
  bool _showSavedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final recommendations = recommendCareers(
      careers: careerCatalog,
      interests: workspace.interests,
      reflectionScores: workspace.assessmentScores,
      practicedSkills: {
        ...workspace.pastTasks
            .where((task) => task.status == 'completed')
            .map((task) => task.skillId),
        ...workspace.tasks
            .where((task) => task.status == 'completed')
            .map((task) => task.skillId),
      },
    );
    final query = _search.text.trim().toLowerCase();
    final visible = recommendations.where((recommendation) {
      final career = recommendation.career;
      return (!_showSavedOnly || workspace.savedCareers.contains(career.id)) &&
          (query.isEmpty ||
              career.title.toLowerCase().contains(query) ||
              career.summary.toLowerCase().contains(query));
    }).toList();
    final suggestions = recommendations
        .where((r) => !workspace.dismissedCareers.contains(r.career.id))
        .take(3)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Career ideas'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Explore what could be next.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'These ideas are starting points, not a test of what you can become. Your choices matter most.',
          ),
          const SizedBox(height: 15),
          const DemoNotice(),
          const SizedBox(height: 20),
          const SectionHeading('Suggestions for you'),
          const SizedBox(height: 4),
          Text(
            'A transparent guide based on signals you shared. Similarity is not a chance of success; you can explore every career without completing a profile.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (suggestions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You have hidden these suggestions. Browse the catalog below to explore every option.',
                ),
              ),
            )
          else
            ...suggestions.map(
              (item) => _CareerCard(
                recommendation: item,
                saved: workspace.savedCareers.contains(item.career.id),
                canDismiss: true,
              ),
            ),
          const SizedBox(height: 18),
          SectionHeading(
            'Career catalog',
            action: _showSavedOnly ? 'Show all' : 'Saved',
            onAction: () => setState(() => _showSavedOnly = !_showSavedOnly),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search careers',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            EmptyState(
              icon: Icons.bookmark_border,
              title:
                  _showSavedOnly ? 'No saved careers yet' : 'No careers found',
              body: _showSavedOnly
                  ? 'Save an idea to return to it later.'
                  : 'Try another search term.',
            )
          else
            ...visible.map(
              (item) => _CareerCard(
                recommendation: item,
                saved: workspace.savedCareers.contains(item.career.id),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Seed career information is illustrative and not verified labor-market advice.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CareerCard extends ConsumerWidget {
  const _CareerCard({
    required this.recommendation,
    required this.saved,
    this.canDismiss = false,
  });
  final CareerRecommendation recommendation;
  final bool saved;
  final bool canDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final career = recommendation.career;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/career/${career.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.work_outline, color: AppTheme.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            career.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              saved ? 'Remove saved career' : 'Save career',
                          onPressed: () => ref
                              .read(workspaceProvider.notifier)
                              .toggleSavedCareer(career.id),
                          icon: Icon(
                            saved ? Icons.bookmark : Icons.bookmark_border,
                            color: AppTheme.green,
                          ),
                        ),
                      ],
                    ),
                    Text(career.summary),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Chip(
                          label: Text(
                            recommendation.hasSignals
                                ? 'Preference match · ${recommendation.score}%'
                                : 'Explore · no profile needed',
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppTheme.mint,
                        ),
                        ...recommendation.matchingInterests.take(2).map(
                              (tag) => Chip(
                                label: Text(interestOptions[tag] ?? tag),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                      ],
                    ),
                    if (canDismiss)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => ref
                              .read(workspaceProvider.notifier)
                              .dismissCareer(career.id),
                          icon: const Icon(Icons.close, size: 17),
                          label: const Text('Hide suggestion'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
