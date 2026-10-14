import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/workspace.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/utils/iterable_extensions.dart';
import '../../../shared/widgets/common.dart';
import '../../career/data/career_catalog.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final career = careerCatalog
        .where((item) => item.id == workspace.goalCareerId)
        .toList()
        .firstOrNull;
    if (career == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Planner'),
          actions: const [ProfileAction()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const DemoNotice(),
            const SizedBox(height: 24),
            const EmptyState(
              icon: Icons.route_outlined,
              title: 'Your path starts with a goal',
              body:
                  'Choose a career idea you are curious about. You can change it whenever you like.',
            ),
            FilledButton.icon(
              onPressed: () => context.go('/career'),
              icon: const Icon(Icons.explore),
              label: const Text('Explore careers'),
            ),
          ],
        ),
      );
    }

    final completed =
        workspace.tasks.where((task) => task.status == 'completed').length;
    final progress =
        workspace.tasks.isEmpty ? 0.0 : completed / workspace.tasks.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const DemoNotice(),
          const SizedBox(height: 18),
          Text(
            'Your learning path',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppTheme.mint,
                        child: Icon(Icons.flag_outlined, color: AppTheme.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current goal',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              career.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Goal options',
                        onSelected: (value) async {
                          if (value == 'change') context.go('/career');
                          if (value == 'pause') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Pause this path?'),
                                content: const Text(
                                  'The active goal will be cleared. Completed practice history stays in Skills, and you can choose a new direction anytime.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Keep goal'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Pause'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              ref.read(workspaceProvider.notifier).pauseGoal();
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'change',
                            child: Text('Choose a different goal'),
                          ),
                          PopupMenuItem(
                            value: 'pause',
                            child: Text('Pause and clear path'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Roadmap progress',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('$completed of ${workspace.tasks.length} tasks'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Grade ${workspace.grade} · A short, curated starter path. It can change as you learn.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Roadmap tasks'),
          const SizedBox(height: 9),
          ...workspace.tasks.asMap().entries.map(
                (entry) => _TaskTile(
                  task: entry.value,
                  index: entry.key,
                  careerTitle: career.title,
                ),
              ),
          const SizedBox(height: 14),
          const Card(
            color: AppTheme.mint,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined, color: AppTheme.green),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Small steps count. This roadmap is a guide—not a deadline or a promise about any career.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go('/skills'),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('See skills you are practicing'),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    required this.index,
    required this.careerTitle,
  });
  final LearningTask task;
  final int index;
  final String careerTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complete = task.status == 'completed';
    final icon = complete
        ? Icons.check_circle
        : task.status == 'in_progress'
            ? Icons.timelapse
            : Icons.radio_button_unchecked;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    icon,
                    color: complete
                        ? AppTheme.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${index + 1} · ${task.minutes} MIN · GRADES ${task.gradeMin}–${task.gradeMax} · ${task.difficulty.replaceAll('_', ' ').toUpperCase()}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(letterSpacing: .4),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Update task status',
                  initialValue: task.status,
                  onSelected: (status) {
                    ref
                        .read(workspaceProvider.notifier)
                        .updateTaskStatus(task.id, status);
                    if (status == 'completed') {
                      showMessage(
                        context,
                        'Nice work—your practice record was updated.',
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'not_started',
                      child: Text('Not started'),
                    ),
                    PopupMenuItem(
                      value: 'in_progress',
                      child: Text('In progress'),
                    ),
                    PopupMenuItem(value: 'completed', child: Text('Completed')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.more_vert),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 31),
              child: Text(task.description),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 31, top: 7),
              child: Text(
                'Goal: ${task.learningObjective}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 31, top: 3),
              child: Text(
                'Done when: ${task.completionCriteria}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Chip(
                avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(
                  '${_skillName(task.skillId)} · connected to $careerTitle',
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (complete && task.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 31),
                child: Text(
                  'Completed ${task.completedAt!.month}/${task.completedAt!.day}/${task.completedAt!.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _skillName(String id) => skillLabels[id] ?? id.replaceAll('_', ' ');
