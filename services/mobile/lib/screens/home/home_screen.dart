import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/sync_providers.dart';
import '../flagged/flagged_records_screen.dart';
import '../registration/registration_flow_screen.dart';
import '../search/seller_search_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? 'Revenue Agent' : 'Hi, ${user.name.split(' ').first}'),
        actions: [
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncControllerProvider.notifier).refreshPendingCounts(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SyncStatusCard(syncState: syncState),
            const SizedBox(height: 24),
            _ActionTile(
              actionKey: const Key('register_seller_action'),
              icon: Icons.person_add_alt_1,
              label: 'Register new seller',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistrationFlowScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              actionKey: const Key('find_seller_action'),
              icon: Icons.search,
              label: 'Find seller / collect payment',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerSearchScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              actionKey: const Key('flagged_records_action'),
              icon: Icons.flag,
              label: 'Flagged / duplicate-suspected records',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FlaggedRecordsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusCard extends ConsumerWidget {
  final SyncState syncState;

  const _SyncStatusCard({required this.syncState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: syncState.pendingCount > 0
          ? Colors.amber.shade50
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(syncState.pendingCount > 0 ? Icons.cloud_off : Icons.cloud_done),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncState.pendingCount > 0
                        ? '${syncState.pendingCount} record(s) pending sync'
                        : 'All records synced',
                    key: const Key('sync_pending_count_text'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (syncState.lastOutcome != null) ...[
              const SizedBox(height: 8),
              Text(
                syncState.lastOutcome!.succeeded
                    ? 'Last sync: ${syncState.lastOutcome!.synced} synced, ${syncState.lastOutcome!.flagged} flagged'
                    : 'Last sync failed: ${syncState.lastOutcome!.errorMessage ?? 'no connection'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('sync_now_button'),
              onPressed: syncState.isSyncing
                  ? null
                  : () => ref.read(syncControllerProvider.notifier).syncNow(),
              icon: syncState.isSyncing
                  ? const SizedBox(
                      height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: actionKey,
        leading: Icon(icon, size: 28),
        title: Text(label, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
