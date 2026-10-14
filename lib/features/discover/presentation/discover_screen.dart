import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/workspace.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/widgets/common.dart';
import '../domain/assessment.dart';

const _prompts = [
  'What is something you enjoyed learning recently?',
  'When did you feel proud of how you handled a challenge?',
  'What would you like to try if you had a little more time?',
];

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final name = workspace.displayName.split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Hi, $name 👋',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'A little reflection can help you notice what matters to you.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          const DemoNotice(),
          const SizedBox(height: 22),
          _AssessmentCard(workspace: workspace),
          const SizedBox(height: 20),
          const SectionHeading('A moment to reflect'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note, color: AppTheme.green, size: 27),
                  const SizedBox(height: 8),
                  Text(
                    _prompts[DateTime.now().day % _prompts.length],
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _editJournal(context, ref),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Write a journal entry'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saved on this device (not encrypted at rest). No AI analysis is enabled.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeading(
            'Recent reflections',
            action: 'New entry',
            onAction: () => _editJournal(context, ref),
          ),
          const SizedBox(height: 10),
          if (workspace.journals.isEmpty)
            const _InlineEmpty(
              icon: Icons.lock_outline,
              text:
                  'Your journal is yours. Add a note whenever you want to remember an experience.',
            ),
          ...workspace.journals
              .take(3)
              .map((entry) => _JournalCard(entry: entry)),
          const SizedBox(height: 20),
          Card(
            color: AppTheme.mint,
            child: ListTile(
              leading: const Icon(Icons.travel_explore, color: AppTheme.green),
              title: const Text('Curious about a career?'),
              subtitle: const Text(
                'Explore ideas that connect with your interests.',
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.go('/career'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.workspace});
  final Workspace workspace;
  @override
  Widget build(BuildContext context) {
    final done = workspace.assessmentScores.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done
                            ? 'Your reflection snapshot'
                            : 'Get to know yourself',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        done
                            ? 'A starting point, not a label.'
                            : 'A short, optional reflection exercise.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (done) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: workspace.assessmentScores.entries
                    .map(
                      (entry) => Chip(
                        label: Text(
                          '${_dimensionName(entry.key)} · ${entry.value.round()}',
                        ),
                        backgroundColor: AppTheme.mint,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 2),
              Text(
                'Your answers describe how you see yourself today; they do not predict ability or career fit.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const _AssessmentDialog(),
              ),
              icon: Icon(done ? Icons.refresh : Icons.play_arrow),
              label: Text(done ? 'Retake reflection' : 'Begin reflection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentDialog extends ConsumerStatefulWidget {
  const _AssessmentDialog();
  @override
  ConsumerState<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends ConsumerState<_AssessmentDialog> {
  int _index = 0;
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final question = assessmentQuestions[_index];
    final selected = workspace.answers[question.id];
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _finished
              ? _result(workspace)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Reflection · ${_index + 1} of ${assessmentQuestions.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: (_index + 1) / assessmentQuestions.length,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      question.prompt,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    const Text('Choose how true this feels for you right now.'),
                    const SizedBox(height: 22),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1')),
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                        ButtonSegment(value: 5, label: Text('5')),
                      ],
                      selected: selected == null ? <int>{} : <int>{selected},
                      onSelectionChanged: (values) => ref
                          .read(workspaceProvider.notifier)
                          .answerQuestion(question.id, values.first),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Not like me'), Text('Very like me')],
                    ),
                    const Spacer(),
                    Text(
                      'Original reflection prompts; not a validated personality or clinical assessment.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _index == 0
                              ? null
                              : () => setState(() => _index--),
                          child: const Text('Back'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: selected == null ? null : _next,
                          child: Text(
                            _index == assessmentQuestions.length - 1
                                ? 'See snapshot'
                                : 'Next',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _next() {
    if (_index < assessmentQuestions.length - 1) {
      setState(() => _index++);
      return;
    }
    try {
      ref.read(workspaceProvider.notifier).completeAssessment();
      setState(() => _finished = true);
    } on ArgumentError catch (error) {
      showMessage(context, error.message.toString());
    }
  }

  Widget _result(Workspace workspace) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.green, size: 38),
          const SizedBox(height: 10),
          Text(
            'A snapshot of you',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'These are self-reflection scores, not a personality type, diagnosis, or measure of what you can become.',
          ),
          const SizedBox(height: 18),
          ...workspace.assessmentScores.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dimensionName(entry.key)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value / 100,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      );
}

class _JournalCard extends ConsumerWidget {
  const _JournalCard({required this.entry});
  final JournalEntry entry;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(entry.text, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(_dateLabel(entry.updatedAt)),
          trailing: PopupMenuButton<String>(
            tooltip: 'Journal actions',
            onSelected: (value) async {
              if (value == 'edit') {
                await _editJournal(context, ref, entry: entry);
              }
              if (value == 'delete' && context.mounted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete this entry?'),
                    content: const Text(
                      'This removes the journal text from this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  ref.read(workspaceProvider.notifier).deleteJournal(entry.id);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      );
}

Future<void> _editJournal(
  BuildContext context,
  WidgetRef ref, {
  JournalEntry? entry,
}) async {
  final controller = TextEditingController(text: entry?.text ?? '');
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(entry == null ? 'New reflection' : 'Edit reflection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 4,
        maxLines: 8,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Write what you noticed, learned, or enjoyed…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    try {
      ref
          .read(workspaceProvider.notifier)
          .saveJournal(entry?.id, controller.text);
      showMessage(context, 'Reflection saved on this device only.');
    } on ArgumentError catch (error) {
      showMessage(context, error.message.toString());
    }
  }
  controller.dispose();
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.green),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

String _dimensionName(String id) => switch (id) {
      'creative' => 'Creative ideas',
      'analytical' => 'Exploring problems',
      'helping' => 'Supporting people',
      'building' => 'Hands-on making',
      _ => id,
    };

String _dateLabel(DateTime date) =>
    'Updated ${date.month}/${date.day}/${date.year}';
