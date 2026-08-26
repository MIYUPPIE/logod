import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/revenue_report_row.dart';
import '../../providers/repository_providers.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  late DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  late DateTime _to = DateTime.now();
  List<RevenueReportRow>? _rows;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(adminRepositoryProvider).revenueReport(from: _from, to: _to);
      if (!mounted) return;
      setState(() => _rows = rows);
    } on DioException {
      if (!mounted) return;
      setState(() => _error = 'Could not load the report. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => isFrom ? _from = picked : _to = picked);
    _load();
  }

  double get _total => (_rows ?? const []).fold(0, (sum, row) => sum + row.amount);

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revenue Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('report_from_button'),
                    onPressed: () => _pickDate(isFrom: true),
                    child: Text('From: ${_formatDate(_from)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('report_to_button'),
                    onPressed: () => _pickDate(isFrom: false),
                    child: Text('To: ${_formatDate(_to)}'),
                  ),
                ),
              ],
            ),
          ),
          if (!_loading && _rows != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total: NGN ${_total.toStringAsFixed(2)} (${_rows!.length} payments)',
                  key: const Key('report_total_text'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _rows?.length ?? 0,
              itemBuilder: (context, index) {
                final row = _rows![index];
                return ListTile(
                  title: Text(row.businessName),
                  subtitle: Text('${row.levyTypeName} - ${row.method.label} - ${row.agentName}'),
                  trailing: Text('NGN ${row.amount.toStringAsFixed(2)}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
