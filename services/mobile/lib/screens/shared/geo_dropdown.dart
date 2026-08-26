import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/geo_node.dart';

/// A single level of a State -> LGA -> Ward -> Market cascading picker.
/// Shared by the field registration wizard and the admin levy-type screen.
///
/// Callers that chain these (a later level's `provider` depends on an
/// earlier level's selected id) MUST key each instance on its parent id,
/// e.g. `Key('lga_field_$stateId')`, not a constant Key - a constant Key
/// lets Flutter reuse the same underlying DropdownButtonFormField element
/// across a parent change, and DropdownButtonFormField only applies
/// `initialValue` on first mount, so it would keep showing/submitting a
/// stale selection from the previous parent until fully remounted. Found
/// live: the LGA picker showed the right label but submitted the previous
/// state's id, and Ward never populated at all until the app was
/// force-restarted, before this key scheme was added.
class GeoDropdown extends ConsumerWidget {
  final Key fieldKey;
  final String label;
  final FutureProvider<List<GeoNode>> provider;
  final int? selectedId;
  final ValueChanged<GeoNode> onSelected;

  const GeoDropdown({
    super.key,
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
        items: nodes.map((n) => DropdownMenuItem(value: n.id, child: Text(n.name))).toList(),
        onChanged: (id) {
          if (id == null) return;
          onSelected(nodes.firstWhere((n) => n.id == id));
        },
      ),
    );
  }
}
