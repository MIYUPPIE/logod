import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/sync_providers.dart';

/// Shared between the agent HomeScreen and AdminHomeScreen - both let the
/// signed-in user record sellers/payments locally and sync them.
class SyncStatusCard extends ConsumerWidget {
  final SyncState syncState;

  const SyncStatusCard({super.key, required this.syncState});

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

class ActionTile extends StatelessWidget {
  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
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
