import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/widgets/common.dart';
import '../../career/data/career_catalog.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final career = careerCatalog
        .where((item) => item.id == workspace.goalCareerId)
        .toList();
    final allTasks = [...workspace.pastTasks, ...workspace.tasks];
    final skills = <String>{
      ...allTasks.map((task) => task.skillId),
      ...career.expand((item) => item.skills),
    };
    final completed =
        allTasks.where((task) => task.status == 'completed').toList();
    final activeCount =
        workspace.tasks.where((task) => task.status == 'in_progress').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill tracker'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Notice your progress.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Practice is progress. These summaries show completed activities—not a score of your ability.',
          ),
          const SizedBox(height: 15),
          const DemoNotice(),
          const SizedBox(height: 19),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  value: '${completed.length}',
                  label: 'Activities complete',
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  value: '$activeCount',
                  label: 'In progress',
                  icon: Icons.timelapse,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeading('Skills in your path'),
          const SizedBox(height: 8),
          if (skills.isEmpty)
            EmptyState(
              icon: Icons.insights_outlined,
              title: 'Your practice will show up here',
              body:
                  'Choose a career goal in Planner to see related skills and activities.',
              action: 'Explore careers',
              onPressed: () => context.go('/career'),
            )
          else
            ...skills.map((skill) {
              final related =
                  allTasks.where((task) => task.skillId == skill).toList();
              final finished =
                  related.where((task) => task.status == 'completed').length;
              final fraction =
                  related.isEmpty ? 0.0 : finished / related.length;
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: AppTheme.green,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              skillLabels[skill] ?? skill.replaceAll('_', ' '),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (related.isNotEmpty)
                            Text('$finished/${related.length} practice'),
                        ],
                      ),
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          finished == 0
                              ? 'Ready when you are—try a related task to begin.'
                              : 'Supported by $finished completed ${finished == 1 ? 'activity' : 'activities'} in your roadmap.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else ...[
                        const SizedBox(height: 7),
                        const Text(
                          'Connected to your goal; no practice evidence yet.',
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          if (completed.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SectionHeading('Recent completed work'),
            const SizedBox(height: 8),
            ...completed.reversed.take(4).map(
                  (task) => Card(
                    margin: const EdgeInsets.only(bottom: 7),
                    child: ListTile(
                      leading: const Icon(
                        Icons.task_alt,
                        color: AppTheme.green,
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '${skillLabels[task.skillId] ?? task.skillId} · ${task.completedAt?.month}/${task.completedAt?.day}',
                      ),
                    ),
                  ),
                ),
          ],
          if (workspace.tasks.isEmpty && skills.isNotEmpty)
            FilledButton.icon(
              onPressed: () => context.go('/career'),
              icon: const Icon(Icons.explore),
              label: const Text('Explore careers'),
            ),
          const SizedBox(height: 12),
          const Card(
            color: AppTheme.mint,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                'Practice completion is not a proficiency score. DALAN will not label a skill as a weakness based on missing or limited evidence.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.green),
              const SizedBox(height: 9),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
