import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/payment_record.dart';
import '../../models/seller_record.dart';
import '../../models/sync_status.dart';

class ReceiptScreen extends StatelessWidget {
  final PaymentRecord payment;
  final SellerRecord seller;

  const ReceiptScreen({super.key, required this.payment, required this.seller});

  @override
  Widget build(BuildContext context) {
    final isPending = payment.status == SyncStatus.pendingSync;
    final paidAt = DateTime.tryParse(payment.paidAt)?.toLocal() ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 56),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text('Payment recorded',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          const Divider(height: 32),
                          _row('Receipt no.', payment.receiptNo ?? 'Pending sync'),
                          _row('Seller', seller.fullName),
                          _row('Business', seller.businessName),
                          _row('Seller ID', seller.displayId),
                          _row('Levy type', payment.levyTypeName),
                          _row('Amount', '₦${payment.amount.toStringAsFixed(2)}'),
                          _row('Method', payment.method.label),
                          _row('Date', DateFormat('yyyy-MM-dd HH:mm').format(paidAt)),
                          _row('Status', payment.status.label),
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const Key('receipt_done_button'),
                            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isPending)
                    IgnorePointer(
                      child: Transform.rotate(
                        angle: -0.35,
                        child: Container(
                          key: const Key('pending_sync_watermark'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PENDING SYNC',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
