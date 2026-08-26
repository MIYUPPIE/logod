import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/geo_node.dart';
import '../../models/user.dart';
import '../../providers/geo_providers.dart';
import '../../providers/repository_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<AppUser>? _users;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final users = await ref.read(adminRepositoryProvider).listUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on DioException {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load users. Check your connection.');
    }
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _CreateUserScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            key: const Key('add_user_button'),
            icon: const Icon(Icons.person_add),
            onPressed: _openCreateForm,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loadError != null
            ? ListView(children: [Padding(padding: const EdgeInsets.all(16), child: Text(_loadError!))])
            : _users == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _users!.length,
                    itemBuilder: (context, index) {
                      final user = _users![index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(user.role.name[0].toUpperCase())),
                        title: Text(user.name),
                        subtitle: Text('${user.role.name} - ${user.email ?? user.phone ?? ''}'),
                        trailing: user.active ? null : const Text('inactive'),
                      );
                    },
                  ),
      ),
    );
  }
}

class _CreateUserScreen extends ConsumerStatefulWidget {
  const _CreateUserScreen();

  @override
  ConsumerState<_CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<_CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.agent;
  int? _lgaId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).createUser(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            role: _role,
            lgaId: _lgaId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.statusCode == 422 || e.response?.statusCode == 400
            ? 'Check the fields - one or more values were rejected.'
            : 'Could not create the user. Check your connection.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(statesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New user')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('new_user_name_field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('new_user_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('new_user_phone_field'),
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('new_user_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              key: const Key('new_user_role_field'),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role *', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                DropdownMenuItem(value: UserRole.supervisor, child: Text('Supervisor')),
                DropdownMenuItem(value: UserRole.agent, child: Text('Agent')),
              ],
              onChanged: (role) => setState(() => _role = role ?? UserRole.agent),
            ),
            const SizedBox(height: 16),
            statesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (err, st) => const Text('LGA list unavailable offline'),
              data: (states) => _LgaPicker(
                states: states,
                selectedLgaId: _lgaId,
                onChanged: (id) => setState(() => _lgaId = id),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('create_user_submit_button'),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create user'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flattens State -> LGA into one picker (an admin/supervisor account is
/// assigned directly to an LGA, or none for a state-level admin) rather
/// than the field registration wizard's cascading pickers.
class _LgaPicker extends ConsumerWidget {
  final List<GeoNode> states;
  final int? selectedLgaId;
  final ValueChanged<int?> onChanged;

  const _LgaPicker({required this.states, required this.selectedLgaId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = <DropdownMenuItem<int?>>[
      const DropdownMenuItem(value: null, child: Text('State-level (no LGA)')),
    ];
    for (final state in states) {
      final lgas = ref.watch(lgasProvider(state.id)).valueOrNull ?? const [];
      for (final lga in lgas) {
        entries.add(DropdownMenuItem(value: lga.id, child: Text('${state.name} / ${lga.name}')));
      }
    }

    return DropdownButtonFormField<int?>(
      key: const Key('new_user_lga_field'),
      initialValue: selectedLgaId,
      decoration: const InputDecoration(labelText: 'LGA', border: OutlineInputBorder()),
      items: entries,
      onChanged: onChanged,
    );
  }
}
