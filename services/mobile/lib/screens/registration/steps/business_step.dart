import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/geo_providers.dart';
import '../../shared/geo_dropdown.dart';
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
        GeoDropdown(
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
          GeoDropdown(
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
          GeoDropdown(
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
          GeoDropdown(
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
