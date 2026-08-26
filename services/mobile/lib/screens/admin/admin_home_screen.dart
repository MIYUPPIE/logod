import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/dashboard_summary.dart';
import '../../providers/auth_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sync_providers.dart';
import '../flagged/flagged_records_screen.dart';
import '../registration/registration_flow_screen.dart';
import '../search/seller_search_screen.dart';
import '../shared/tiles.dart';
import 'admin_levy_types_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';

/// Full-control home for admin logins - everything an agent can do (field
/// registration/payment, unrestricted across LGAs since the backend treats
/// lga_id: nil as a state-level admin - see RevenueApi.Authz) plus the
/// management surface the web LiveView admin panel offers: live dashboard,
/// user provisioning, levy type management, revenue reports.
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  DashboardSummary? _summary;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryError = null);
    try {
      final summary = await ref.read(adminRepositoryProvider).dashboardSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } on DioException {
      if (!mounted) return;
      setState(() => _summaryError = 'Dashboard unavailable offline.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(user == null ? 'Admin' : 'Hi, ${user.name.split(' ').first}'),
        actions: [
          IconButton(
            key: const Key('logout_button'),
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncControllerProvider.notifier).refreshPendingCounts();
          await _loadSummary();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DashboardCard(summary: _summary, error: _summaryError),
            const SizedBox(height: 24),
            SyncStatusCard(syncState: syncState),
            const SizedBox(height: 24),
            Text('Field operations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ActionTile(
              actionKey: const Key('register_seller_action'),
              icon: Icons.person_add_alt_1,
              label: 'Register new seller',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const RegistrationFlowScreen())),
            ),
            const SizedBox(height: 12),
            ActionTile(
              actionKey: const Key('find_seller_action'),
              icon: Icons.search,
              label: 'Find seller / collect payment',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SellerSearchScreen())),
            ),
            const SizedBox(height: 12),
            ActionTile(
              actionKey: const Key('flagged_records_action'),
              icon: Icons.flag,
              label: 'Flagged / duplicate-suspected records',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FlaggedRecordsScreen())),
            ),
            const SizedBox(height: 24),
            Text('Administration', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ActionTile(
              actionKey: const Key('manage_users_action'),
              icon: Icons.people,
              label: 'Manage users',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
            ),
            const SizedBox(height: 12),
            ActionTile(
              actionKey: const Key('manage_levy_types_action'),
              icon: Icons.receipt_long,
              label: 'Manage levy types',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AdminLevyTypesScreen())),
            ),
            const SizedBox(height: 12),
            ActionTile(
              actionKey: const Key('reports_action'),
              icon: Icons.bar_chart,
              label: 'Revenue reports',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final DashboardSummary? summary;
  final String? error;

  const _DashboardCard({required this.summary, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!)));
    }
    if (summary == null) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Collections", style: Theme.of(context).textTheme.titleSmall),
            Text(
              'NGN ${summary!.todayTotalAmount.toStringAsFixed(2)}',
              key: const Key('dashboard_today_total_text'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${summary!.todayPaymentCount} payment(s) today'),
            if (summary!.pendingSyncCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${summary!.pendingSyncCount} record(s) flagged for review',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (summary!.activeAgents.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Active agents', style: Theme.of(context).textTheme.titleSmall),
              ...summary!.activeAgents.map(
                (agent) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(agent.name)),
                      Text('NGN ${agent.todayTotal.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
