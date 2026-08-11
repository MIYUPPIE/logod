import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/ids.dart';
import '../../models/levy_type.dart';
import '../../models/payment_method.dart';
import '../../models/payment_record.dart';
import '../../models/seller_record.dart';
import '../../models/sync_status.dart';
import '../../providers/geo_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/sync_providers.dart';
import 'receipt_screen.dart';

class PaymentFlowScreen extends ConsumerStatefulWidget {
  final SellerRecord seller;

  const PaymentFlowScreen({super.key, required this.seller});

  @override
  ConsumerState<PaymentFlowScreen> createState() => _PaymentFlowScreenState();
}

class _PaymentFlowScreenState extends ConsumerState<PaymentFlowScreen> {
  LevyType? _selectedLevyType;
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  Future<void> _confirm() async {
    final levyType = _selectedLevyType;
    if (levyType == null) return;
    setState(() => _saving = true);

    final now = nowIso();
    final record = PaymentRecord(
      clientUuid: newClientUuid(),
      sellerClientUuid: widget.seller.clientUuid,
      sellerServerId: widget.seller.serverId!,
      sellerDisplayName: widget.seller.businessName,
      levyTypeId: levyType.id,
      levyTypeName: levyType.name,
      amount: levyType.amount,
      method: _method,
      status: SyncStatus.pendingSync,
      paidAt: now,
      createdAt: now,
    );

    await ref.read(paymentRepositoryProvider).saveNewPayment(record);
    await ref.read(syncControllerProvider.notifier).refreshPendingCounts();
    unawaited(ref.read(syncControllerProvider.notifier).syncNow());

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(payment: record, seller: widget.seller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levyTypesAsync = ref.watch(levyTypesProvider(widget.seller.lgaId));

    return Scaffold(
      appBar: AppBar(title: const Text('Collect payment')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              title: Text(widget.seller.businessName),
              subtitle: Text('${widget.seller.fullName} - ${widget.seller.displayId}'),
            ),
          ),
          Expanded(
            child: levyTypesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No levy types cached for this LGA yet. Connect to the internet once '
                    'to load them, then they will work offline.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (levyTypes) {
                if (levyTypes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No levy types configured for this LGA.'),
                    ),
                  );
                }
                _selectedLevyType ??= levyTypes.first;
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text('Levy type', style: Theme.of(context).textTheme.titleMedium),
                    RadioGroup<int>(
                      groupValue: _selectedLevyType?.id,
                      onChanged: (id) => setState(
                        () => _selectedLevyType = levyTypes.firstWhere((l) => l.id == id),
                      ),
                      child: Column(
                        children: levyTypes
                            .map(
                              (levyType) => RadioListTile<int>(
                                key: Key('levy_type_${levyType.id}'),
                                title: Text(levyType.name),
                                subtitle: Text(
                                    '₦${levyType.amount.toStringAsFixed(2)} / ${levyType.frequency.label}'),
                                value: levyType.id,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const Divider(height: 32),
                    Text('Payment method', style: Theme.of(context).textTheme.titleMedium),
                    RadioGroup<PaymentMethod>(
                      groupValue: _method,
                      onChanged: (value) => setState(() => _method = value!),
                      child: Column(
                        children: PaymentMethod.values
                            .map(
                              (method) => RadioListTile<PaymentMethod>(
                                key: Key('payment_method_${method.name}'),
                                title: Text(method.label),
                                value: method,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (_selectedLevyType != null) ...[
                      const Divider(height: 32),
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Amount to collect'),
                              Text(
                                '₦${_selectedLevyType!.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: const Key('confirm_payment_button'),
                onPressed: (_selectedLevyType != null && !_saving) ? _confirm : null,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm payment'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
