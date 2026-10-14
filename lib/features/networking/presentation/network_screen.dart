import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/career/data/career_catalog.dart';
import '../../../shared/models/workspace.dart';
import '../../../shared/services/workspace_controller.dart';
import '../../../shared/utils/iterable_extensions.dart';
import '../../../shared/widgets/common.dart';

class _SampleProfile {
  const _SampleProfile(
    this.id,
    this.name,
    this.gradeBand,
    this.interests,
    this.careerId,
    this.goal,
    this.incoming,
  );
  final String id;
  final String name;
  final String gradeBand;
  final List<String> interests;
  final String careerId;
  final String goal;
  final bool incoming;
}

const _profiles = [
  _SampleProfile(
    'sample_mika',
    'Mika · sample learner',
    'Grades 6–8',
    ['creating', 'nature'],
    'designer',
    'Learning about product design',
    true,
  ),
  _SampleProfile(
    'sample_jo',
    'Jo · sample learner',
    'Grades 9–12',
    ['technology', 'creating'],
    'game_designer',
    'Trying beginner coding',
    false,
  ),
  _SampleProfile(
    'sample_lee',
    'Lee · sample learner',
    'Grades 3–5',
    ['science', 'helping'],
    'nurse',
    'Exploring science careers',
    false,
  ),
];

class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network'),
        actions: const [ProfileAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Grow with others.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Discover shared learning interests, with safety and choice first.',
          ),
          const SizedBox(height: 15),
          const DemoNotice(
            message:
                'Demo networking · sample profiles only · actions stay on this device',
          ),
          const SizedBox(height: 14),
          const Card(
            color: AppTheme.mint,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No direct messages or precise location. These sample profiles are fictional. Demo requests are not sent to real students.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            value: workspace.networkingEnabled,
            title: const Text(
              'Opt in to profile discovery',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Off by default. Real profile discovery is not connected in this demo.',
            ),
            onChanged:
                ref.read(workspaceProvider.notifier).setNetworkingEnabled,
          ),
          if (!workspace.networkingEnabled) ...[
            const SizedBox(height: 18),
            const EmptyState(
              icon: Icons.visibility_off_outlined,
              title: 'Profile discovery is off',
              body:
                  'Turn it on only if you want to explore sample profiles in this on-device demo.',
            ),
          ] else ...[
            const SizedBox(height: 20),
            const SectionHeading('Connection activity'),
            const SizedBox(height: 8),
            ..._profiles.map(
              (profile) =>
                  _connectionActivity(context, ref, workspace, profile),
            ),
            const SizedBox(height: 12),
            const SectionHeading('Explore sample profiles'),
            const SizedBox(height: 7),
            ..._rankedProfiles(workspace)
                .map((profile) => _ProfileCard(profile: profile)),
            const SizedBox(height: 14),
            Text(
              'Only explicitly selected profile topics are shown. Journal entries and assessment scores are never shared.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectionActivity(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    _SampleProfile profile,
  ) {
    if (workspace.blockedProfiles.contains(profile.id)) {
      return const SizedBox.shrink();
    }
    final connection = workspace.connections
        .where((item) => item.profileId == profile.id)
        .firstOrNull;
    if (profile.incoming) {
      if (connection?.status == 'declined') return const SizedBox.shrink();
      if (connection?.status == 'accepted') {
        return _ConnectionTile(profile: profile, status: 'accepted');
      }
      if (connection == null) return _IncomingTile(profile: profile);
    }
    if (connection == null) return const SizedBox.shrink();
    return _ConnectionTile(profile: profile, status: connection.status);
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});
  final _SampleProfile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    if (workspace.blockedProfiles.contains(profile.id)) {
      return const SizedBox.shrink();
    }
    final connection = workspace.connections
        .where((item) => item.profileId == profile.id)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.mint,
              child: Icon(Icons.person_outline, color: AppTheme.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(profile.gradeBand),
                  const SizedBox(height: 5),
                  Text(profile.goal),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    children: profile.interests
                        .map(
                          (item) => Chip(
                            label: Text(interestOptions[item] ?? item),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: workspace.interests.contains(item)
                                ? AppTheme.mint
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                  if (profile.interests.any(workspace.interests.contains) ||
                      profile.careerId == workspace.goalCareerId)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        profile.careerId == workspace.goalCareerId
                            ? 'Related to your selected career goal'
                            : 'Shares an interest you selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.green,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  if (profile.interests.isNotEmpty &&
                      workspace.interests.isEmpty &&
                      workspace.goalCareerId == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Select interests or a goal to personalize sample suggestions.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (connection == null)
                    FilledButton.tonal(
                      onPressed: () {
                        ref
                            .read(workspaceProvider.notifier)
                            .requestDemoConnection(profile.id);
                        showMessage(
                          context,
                          'Demo request saved on this device only.',
                        );
                      },
                      child: const Text('Send demo request'),
                    )
                  else if (connection.status == 'pending')
                    OutlinedButton(
                      onPressed: () => ref
                          .read(workspaceProvider.notifier)
                          .cancelDemoConnection(profile.id),
                      child: const Text('Cancel request'),
                    )
                  else if (connection.status == 'accepted')
                    OutlinedButton(
                      onPressed: () =>
                          _removeConnection(context, ref, profile.id),
                      child: const Text('Remove connection'),
                    )
                  else
                    const Text('Request declined'),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Safety options',
              onSelected: (value) =>
                  _safetyAction(context, ref, profile, value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'block',
                  child: Text('Block sample profile'),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Text('Report sample profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingTile extends ConsumerWidget {
  const _IncomingTile({required this.profile});
  final _SampleProfile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(
            Icons.mark_email_unread_outlined,
            color: AppTheme.green,
          ),
          title: Text('Sample request from ${profile.name.split(' ·').first}'),
          subtitle: const Text(
            'This fictional request lets you preview accept/decline controls.',
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            tooltip: 'Respond to sample request',
            onSelected: (value) {
              if (value == 'accept') {
                ref
                    .read(workspaceProvider.notifier)
                    .respondDemoRequest(profile.id, accepted: true);
              }
              if (value == 'decline') {
                ref
                    .read(workspaceProvider.notifier)
                    .respondDemoRequest(profile.id, accepted: false);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'accept', child: Text('Accept sample request')),
              PopupMenuItem(
                value: 'decline',
                child: Text('Decline sample request'),
              ),
            ],
          ),
        ),
      );
}

class _ConnectionTile extends ConsumerWidget {
  const _ConnectionTile({required this.profile, required this.status});
  final _SampleProfile profile;
  final String status;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            status == 'accepted'
                ? Icons.people_alt_outlined
                : Icons.outgoing_mail,
          ),
          title: Text(profile.name),
          subtitle: Text(
            status == 'accepted'
                ? 'Connected in this local demo'
                : 'Demo request pending on this device',
          ),
          trailing: IconButton(
            tooltip:
                status == 'accepted' ? 'Remove connection' : 'Cancel request',
            onPressed: () => status == 'accepted'
                ? _removeConnection(context, ref, profile.id)
                : ref
                    .read(workspaceProvider.notifier)
                    .cancelDemoConnection(profile.id),
            icon: const Icon(Icons.close),
          ),
        ),
      );
}

List<_SampleProfile> _rankedProfiles(Workspace workspace) {
  final profiles = _profiles
      .where(
        (profile) =>
            !profile.incoming &&
            !workspace.blockedProfiles.contains(profile.id),
      )
      .toList();
  int score(_SampleProfile profile) =>
      profile.interests.where(workspace.interests.contains).length * 2 +
      (profile.careerId == workspace.goalCareerId ? 3 : 0);
  profiles.sort((a, b) {
    final matchOrder = score(b).compareTo(score(a));
    return matchOrder == 0 ? a.id.compareTo(b.id) : matchOrder;
  });
  return profiles;
}

Future<void> _removeConnection(
  BuildContext context,
  WidgetRef ref,
  String profileId,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove connection?'),
      content: const Text('This removes the local demo relationship.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirm == true && context.mounted) {
    ref.read(workspaceProvider.notifier).cancelDemoConnection(profileId);
  }
}

Future<void> _safetyAction(
  BuildContext context,
  WidgetRef ref,
  _SampleProfile profile,
  String action,
) async {
  final isBlock = action == 'block';
  final confirm = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        isBlock ? 'Block this sample profile?' : 'Report this sample profile?',
      ),
      content: Text(
        isBlock
            ? 'The profile will disappear and its local demo connection will be removed.'
            : 'A local report marker will be saved. No moderation team receives reports in this demo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(isBlock ? 'Block' : 'Report'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;
  if (isBlock) {
    ref.read(workspaceProvider.notifier).blockDemoProfile(profile.id);
    showMessage(context, 'Profile blocked in this local demo.');
  } else {
    ref.read(workspaceProvider.notifier).reportDemoProfile(profile.id);
    showMessage(
      context,
      'Report marked locally; it was not sent to a moderation team.',
    );
  }
}
