import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/career/data/career_catalog.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late int _grade;
  late Set<String> _interests;

  @override
  void initState() {
    super.initState();
    final workspace = ref.read(workspaceProvider);
    _name = TextEditingController(text: workspace.displayName);
    _grade = workspace.grade;
    _interests = {...workspace.interests};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    try {
      ref.read(workspaceProvider.notifier).updateProfile(
            displayName: _name.text,
            grade: _grade,
            interests: _interests,
          );
      showMessage(context, 'Profile saved on this device.');
    } on ArgumentError catch (error) {
      showMessage(context, error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceProvider);
    final hasSession = AppConfig.supabaseReady &&
        Supabase.instance.client.auth.currentSession != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile and settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const DemoNotice(),
          const SizedBox(height: 18),
          const CircleAvatar(
            radius: 31,
            backgroundColor: AppTheme.mint,
            child: Icon(Icons.person_outline, color: AppTheme.green, size: 32),
          ),
          const SizedBox(height: 9),
          Text(
            'Your profile',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _name,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _grade,
            decoration: const InputDecoration(labelText: 'Current grade'),
            items: List.generate(
              12,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('Grade ${index + 1}'),
              ),
            ),
            onChanged: (value) => setState(() => _grade = value ?? _grade),
          ),
          const SizedBox(height: 20),
          Text(
            'Your interests',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
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
          const SizedBox(height: 15),
          FilledButton(onPressed: _save, child: const Text('Save profile')),
          const SizedBox(height: 20),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Profile discovery opt-in'),
            subtitle: const Text(
              'Off by default. The current networking demo uses fictional sample profiles only.',
            ),
            value: workspace.networkingEnabled,
            onChanged:
                ref.read(workspaceProvider.notifier).setNetworkingEnabled,
          ),
          const Card(
            color: AppTheme.mint,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                'Journal entries and assessment answers stay on this device in the MVP. They are not encrypted at rest, shared with other users, or sent to an AI provider. Avoid sensitive details.',
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (hasSession)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/welcome');
                } on AuthException catch (error) {
                  if (context.mounted) showMessage(context, error.message);
                } catch (_) {
                  if (context.mounted) {
                    showMessage(context, 'Sign out failed. Please try again.');
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out of Supabase'),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _clearData(context),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear local demo data'),
          ),
          const SizedBox(height: 8),
          Text(
            'This clears the local workspace on this device. It does not delete a Supabase account or server data.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _clearData(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear this device’s DALAN data?'),
        content: const Text(
          'This permanently removes your local demo profile, reflections, assessment answers, and roadmap from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear data'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(workspaceProvider.notifier).clearAll();
      if (context.mounted) context.go('/welcome');
    }
  }
}
