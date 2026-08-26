import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/levy_type.dart';
import '../../providers/geo_providers.dart';
import '../../providers/repository_providers.dart';
import '../shared/geo_dropdown.dart';

class AdminLevyTypesScreen extends ConsumerStatefulWidget {
  const AdminLevyTypesScreen({super.key});

  @override
  ConsumerState<AdminLevyTypesScreen> createState() => _AdminLevyTypesScreenState();
}

class _AdminLevyTypesScreenState extends ConsumerState<AdminLevyTypesScreen> {
  int? _stateId;
  int? _lgaId;
  List<LevyType> _levyTypes = const [];
  bool _loading = false;
  String? _error;

  Future<void> _loadLevyTypes() async {
    if (_lgaId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final types = await ref.read(levyTypeRepositoryProvider).forLga(_lgaId!, forceRefresh: true);
      if (!mounted) return;
      setState(() => _levyTypes = types);
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load levy types. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateAmount(LevyType levyType, String newAmountText) async {
    final amount = double.tryParse(newAmountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }
    try {
      await ref.read(levyTypeRepositoryProvider).updateAmount(levyType.id, amount);
      await _loadLevyTypes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${levyType.name} updated.')));
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed. Check your connection.')),
      );
    }
  }

  Future<void> _openCreateForm() async {
    if (_lgaId == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _CreateLevyTypeScreen(lgaId: _lgaId!)),
    );
    if (created == true) _loadLevyTypes();
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(statesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Levy Types'),
        actions: [
          if (_lgaId != null)
            IconButton(
              key: const Key('add_levy_type_button'),
              icon: const Icon(Icons.add),
              onPressed: _openCreateForm,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          statesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, st) => const Text('States unavailable offline'),
            data: (states) => Column(
              children: [
                GeoDropdown(
                  fieldKey: const Key('levy_state_field'),
                  label: 'State',
                  provider: statesProvider,
                  selectedId: _stateId,
                  onSelected: (node) => setState(() {
                    _stateId = node.id;
                    _lgaId = null;
                    _levyTypes = const [];
                  }),
                ),
                if (_stateId != null) ...[
                  const SizedBox(height: 16),
                  GeoDropdown(
                    fieldKey: Key('levy_lga_field_$_stateId'),
                    label: 'LGA',
                    provider: lgasProvider(_stateId!),
                    selectedId: _lgaId,
                    onSelected: (node) {
                      setState(() => _lgaId = node.id);
                      _loadLevyTypes();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (!_loading && _lgaId != null && _levyTypes.isEmpty && _error == null)
            const Text('No levy types for this LGA yet. Use + to add one.'),
          ..._levyTypes.map((levyType) => _LevyTypeCard(
                levyType: levyType,
                onSave: (amount) => _updateAmount(levyType, amount),
              )),
        ],
      ),
    );
  }
}

class _LevyTypeCard extends StatefulWidget {
  final LevyType levyType;
  final ValueChanged<String> onSave;

  const _LevyTypeCard({required this.levyType, required this.onSave});

  @override
  State<_LevyTypeCard> createState() => _LevyTypeCardState();
}

class _LevyTypeCardState extends State<_LevyTypeCard> {
  late final TextEditingController _amountController =
      TextEditingController(text: widget.levyType.amount.toStringAsFixed(2));

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.levyType.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(widget.levyType.frequency.label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                key: Key('levy_amount_field_${widget.levyType.id}'),
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: 'NGN ', isDense: true),
              ),
            ),
            IconButton(
              key: Key('levy_amount_save_${widget.levyType.id}'),
              icon: const Icon(Icons.save),
              onPressed: () => widget.onSave(_amountController.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateLevyTypeScreen extends ConsumerStatefulWidget {
  final int lgaId;

  const _CreateLevyTypeScreen({required this.lgaId});

  @override
  ConsumerState<_CreateLevyTypeScreen> createState() => _CreateLevyTypeScreenState();
}

class _CreateLevyTypeScreenState extends ConsumerState<_CreateLevyTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  LevyFrequency _frequency = LevyFrequency.daily;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(levyTypeRepositoryProvider).create(
            lgaId: widget.lgaId,
            name: _nameController.text.trim(),
            amount: double.parse(_amountController.text),
            frequency: _frequency,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException {
      setState(() => _error = 'Could not create the levy type. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New levy type')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('new_levy_name_field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('new_levy_amount_field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount *', border: OutlineInputBorder()),
              validator: (v) {
                final parsed = double.tryParse(v ?? '');
                return (parsed == null || parsed <= 0) ? 'Enter a valid amount' : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LevyFrequency>(
              key: const Key('new_levy_frequency_field'),
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency *', border: OutlineInputBorder()),
              items: LevyFrequency.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                  .toList(),
              onChanged: (f) => setState(() => _frequency = f ?? LevyFrequency.daily),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('create_levy_submit_button'),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create levy type'),
            ),
          ],
        ),
      ),
    );
  }
}
