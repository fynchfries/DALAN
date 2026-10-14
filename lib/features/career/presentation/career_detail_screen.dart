import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/utils/iterable_extensions.dart';
import '../../../shared/widgets/common.dart';
import '../data/career_catalog.dart';
import '../domain/recommendation.dart';

class CareerDetailScreen extends ConsumerWidget {
  const CareerDetailScreen({super.key, required this.careerId});
  final String careerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final career =
        careerCatalog.where((item) => item.id == careerId).firstOrNull;
    final workspace = ref.watch(workspaceProvider);
    if (career == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.search_off,
          title: 'Career not found',
          body: 'This career may have been removed from the catalog.',
        ),
      );
    }
    final recommendations = recommendCareers(
      careers: [career],
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
    final recommendation = recommendations.first;
    final scoreExplanation = recommendation.hasSignals
        ? 'Preference similarity: ${recommendation.score}% (not a chance of success).'
        : 'No similarity score yet—explore this option without completing a profile.';
    final isGoal = workspace.goalCareerId == career.id;
    final saved = workspace.savedCareers.contains(career.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Career details'),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove saved career' : 'Save career',
            onPressed: () => ref
                .read(workspaceProvider.notifier)
                .toggleSavedCareer(career.id),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          ),
          const ProfileAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        children: [
          const DemoNotice(),
          const SizedBox(height: 18),
          Text(
            career.title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(career.summary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Card(
            color: AppTheme.mint,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why it appeared',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text('${recommendation.explanation}\n$scoreExplanation'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _DetailSection(
            title: 'A few things this work can involve',
            children:
                career.responsibilities.map((item) => _Bullet(item)).toList(),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Interests that may connect',
            children: [
              Wrap(
                spacing: 7,
                children: career.interests
                    .map(
                      (tag) => Chip(label: Text(interestOptions[tag] ?? tag)),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Skills to explore',
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 3,
                children: career.skills
                    .map(
                      (skill) => Chip(label: Text(skillLabels[skill] ?? skill)),
                    )
                    .toList(),
              ),
              if (recommendation.relevantSkills.isNotEmpty)
                Text(
                  'You have practiced ${recommendation.relevantSkills.map((skill) => skillLabels[skill] ?? skill).join(', ')} in your roadmap.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (recommendation.skillGaps.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  'Skills you could explore next (not weaknesses)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Wrap(
                  spacing: 7,
                  runSpacing: 2,
                  children: recommendation.skillGaps
                      .map(
                        (skill) =>
                            Chip(label: Text(skillLabels[skill] ?? skill)),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Learning pathways',
            children: [
              Text(career.education),
              const SizedBox(height: 8),
              const Text(
                'Pathways vary by place and role. Check current guidance from trusted local schools or official sources.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Try a beginner activity',
            children: [Text(career.activity)],
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Related ideas',
            children: [
              Wrap(
                spacing: 7,
                children: career.related.map((id) {
                  final related =
                      careerCatalog.where((item) => item.id == id).firstOrNull;
                  if (related == null) return const SizedBox.shrink();
                  return ActionChip(
                    label: Text(related.title),
                    onPressed: () => context.push('/career/${related.id}'),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () {
              if (!isGoal) {
                ref.read(workspaceProvider.notifier).setCareerGoal(career);
              }
              context.go('/planner');
            },
            icon: Icon(isGoal ? Icons.arrow_forward : Icons.flag_outlined),
            label: Text(isGoal ? 'Continue this roadmap' : 'Set as my goal'),
          ),
          if (isGoal) ...[
            const SizedBox(height: 8),
            Text(
              'Changing your goal later is always okay.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Illustrative seed content; not professional career or licensing advice.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 7, color: AppTheme.green),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
