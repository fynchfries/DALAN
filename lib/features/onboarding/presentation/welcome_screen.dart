import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/career/data/career_catalog.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/widgets/common.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _interests = <String>{};
  int _grade = 7;
  bool _privacyAcknowledged = false;

  @override
  void initState() {
    super.initState();
    final workspace = ref.read(workspaceProvider);
    _name.text = workspace.setupComplete ? workspace.displayName : '';
    _grade = workspace.grade;
    _interests.addAll(workspace.interests);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _continue() {
    if (ref.read(workspaceProvider).setupComplete) {
      context.go('/discover');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_privacyAcknowledged) {
      showMessage(context, 'Please review the demo privacy note to continue.');
      return;
    }
    try {
      ref.read(workspaceProvider.notifier).finishSetup(
            displayName: _name.text,
            grade: _grade,
            interests: _interests,
          );
      context.go('/discover');
    } on ArgumentError catch (error) {
      showMessage(context, error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.explore,
                        color: AppTheme.green,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'DALAN',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  'Find your next step.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 12),
                Text(
                  'Discover what matters to you, explore possibilities, and grow skills at your own pace.',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 22),
                const DemoNotice(),
                if (workspace.setupComplete) ...[
                  const SizedBox(height: 22),
                  Text(
                    'Welcome back, ${workspace.displayName}.',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _continue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue to DALAN'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Profile and settings'),
                  ),
                  if (AppConfig.supabaseReady) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Sign in or create a Supabase account'),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 26),
                  Text(
                    'A little about you',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: const InputDecoration(
                            labelText: 'What should we call you?',
                            hintText: 'Display name',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter a display name.'
                                  : null,
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          initialValue: _grade,
                          decoration: const InputDecoration(
                            labelText: 'Current grade',
                          ),
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('Grade ${index + 1}'),
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _grade = value ?? 7),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'What are you curious about? (optional)',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: interestOptions.entries
                              .map(
                                (entry) => FilterChip(
                                  label: Text(entry.value),
                                  selected: _interests.contains(entry.key),
                                  onSelected: (selected) => setState(
                                    () => selected
                                        ? _interests.add(entry.key)
                                        : _interests.remove(entry.key),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        CheckboxListTile(
                          value: _privacyAcknowledged,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'I understand this demo saves my profile and journal on this device.',
                          ),
                          subtitle: const Text(
                            'Local data is not encrypted at rest and is not sent to AI. Avoid sensitive details, especially on shared devices.',
                          ),
                          onChanged: (value) => setState(
                            () => _privacyAcknowledged = value ?? false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _continue,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Start exploring'),
                  ),
                  if (AppConfig.supabaseReady) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.push('/auth'),
                      child: const Text('Sign in or create an account'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Authentication is available; this MVP workspace is still stored locally.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                Text(
                  'Your interests and reflections are clues—not labels or limits. You can change your mind at any time.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
