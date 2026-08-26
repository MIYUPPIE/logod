import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/geo_node.dart';
import '../../../providers/geo_providers.dart';
import '../registration_draft.dart';

class BusinessStep extends ConsumerStatefulWidget {
  final RegistrationDraft draft;
  final VoidCallback onChanged;

  const BusinessStep({super.key, required this.draft, required this.onChanged});

  @override
  ConsumerState<BusinessStep> createState() => _BusinessStepState();
}

class _BusinessStepState extends ConsumerState<BusinessStep> {
  late final TextEditingController _businessNameController =
      TextEditingController(text: widget.draft.businessName);
  late final TextEditingController _categoryController =
      TextEditingController(text: widget.draft.businessCategory);
  late final TextEditingController _shopNumberController =
      TextEditingController(text: widget.draft.shopNumber ?? '');

  @override
  void dispose() {
    _businessNameController.dispose();
    _categoryController.dispose();
    _shopNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Business', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          key: const Key('business_name_field'),
          controller: _businessNameController,
          decoration: const InputDecoration(labelText: 'Business name *', border: OutlineInputBorder()),
          onChanged: (value) {
            draft.businessName = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('business_category_field'),
          controller: _categoryController,
          decoration: const InputDecoration(labelText: 'Business category *', border: OutlineInputBorder()),
          onChanged: (value) {
            draft.businessCategory = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('shop_number_field'),
          controller: _shopNumberController,
          decoration: const InputDecoration(labelText: 'Shop number (optional)', border: OutlineInputBorder()),
          onChanged: (value) {
            draft.shopNumber = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 24),
        _GeoDropdown(
          fieldKey: const Key('state_field'),
          label: 'State *',
          provider: statesProvider,
          selectedId: draft.stateId,
          onSelected: (node) {
            setState(() {
              draft.stateId = node.id;
              draft.stateName = node.name;
              draft.lgaId = null;
              draft.lgaName = null;
              draft.wardId = null;
              draft.wardName = null;
              draft.marketId = null;
              draft.marketName = null;
            });
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        if (draft.stateId != null)
          _GeoDropdown(
            // Keyed on the parent id so a state change forces a fresh
            // DropdownButtonFormField instance instead of reusing the old
            // one - DropdownButtonFormField only applies `initialValue` on
            // first mount, so without this the widget kept showing/
            // submitting a stale selection from the previous state after
            // a state change, until the whole app was restarted.
            fieldKey: Key('lga_field_${draft.stateId}'),
            label: 'LGA *',
            provider: lgasProvider(draft.stateId!),
            selectedId: draft.lgaId,
            onSelected: (node) {
              setState(() {
                draft.lgaId = node.id;
                draft.lgaName = node.name;
                draft.wardId = null;
                draft.wardName = null;
                draft.marketId = null;
                draft.marketName = null;
              });
              widget.onChanged();
            },
          ),
        const SizedBox(height: 16),
        if (draft.lgaId != null)
          _GeoDropdown(
            fieldKey: Key('ward_field_${draft.lgaId}'),
            label: 'Ward *',
            provider: wardsProvider(draft.lgaId!),
            selectedId: draft.wardId,
            onSelected: (node) {
              setState(() {
                draft.wardId = node.id;
                draft.wardName = node.name;
                draft.marketId = null;
                draft.marketName = null;
              });
              widget.onChanged();
            },
          ),
        const SizedBox(height: 16),
        if (draft.wardId != null)
          _GeoDropdown(
            fieldKey: Key('market_field_${draft.wardId}'),
            label: 'Market *',
            provider: marketsProvider(draft.wardId!),
            selectedId: draft.marketId,
            onSelected: (node) {
              setState(() {
                draft.marketId = node.id;
                draft.marketName = node.name;
              });
              widget.onChanged();
            },
          ),
      ],
    );
  }
}

class _GeoDropdown extends ConsumerWidget {
  final Key fieldKey;
  final String label;
  final FutureProvider<List<GeoNode>> provider;
  final int? selectedId;
  final ValueChanged<GeoNode> onSelected;

  const _GeoDropdown({
    required this.fieldKey,
    required this.label,
    required this.provider,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNodes = ref.watch(provider);
    return asyncNodes.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: const LinearProgressIndicator(),
      ),
      error: (err, st) => InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: const Text('Unavailable offline - visit with connectivity once to cache this list'),
      ),
      data: (nodes) => DropdownButtonFormField<int>(
        key: fieldKey,
        initialValue: nodes.any((n) => n.id == selectedId) ? selectedId : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: nodes
            .map((n) => DropdownMenuItem(value: n.id, child: Text(n.name)))
            .toList(),
        onChanged: (id) {
          if (id == null) return;
          onSelected(nodes.firstWhere((n) => n.id == id));
        },
      ),
    );
  }
}
