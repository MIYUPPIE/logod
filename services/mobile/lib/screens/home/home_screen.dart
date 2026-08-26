import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/sync_providers.dart';
import '../flagged/flagged_records_screen.dart';
import '../registration/registration_flow_screen.dart';
import '../search/seller_search_screen.dart';
import '../shared/tiles.dart';

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
            SyncStatusCard(syncState: syncState),
            const SizedBox(height: 24),
            ActionTile(
              actionKey: const Key('register_seller_action'),
              icon: Icons.person_add_alt_1,
              label: 'Register new seller',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistrationFlowScreen()),
              ),
            ),
            const SizedBox(height: 12),
            ActionTile(
              actionKey: const Key('find_seller_action'),
              icon: Icons.search,
              label: 'Find seller / collect payment',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerSearchScreen()),
              ),
            ),
            const SizedBox(height: 12),
            ActionTile(
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
