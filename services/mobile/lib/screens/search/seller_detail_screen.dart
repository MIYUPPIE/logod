import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/seller_record.dart';
import '../../models/sync_status.dart';
import '../payment/payment_flow_screen.dart';

class SellerDetailScreen extends StatelessWidget {
  final SellerRecord seller;

  const SellerDetailScreen({super.key, required this.seller});

  /// A payment always needs a canonical, server-assigned seller id
  /// (PaymentCreateRequest.seller_id is a required integer in
  /// contracts/openapi.yaml) - a seller registered on this device that has
  /// not synced yet only has a client_uuid. Rather than invent a
  /// backend-unsupported "pay against a local id" flow, payment collection
  /// is gated on the seller already being synced. See README's "Contract
  /// gaps observed" section.
  bool get _canCollectPayment => seller.status == SyncStatus.synced && seller.serverId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage:
                    seller.photoPath != null ? FileImage(File(seller.photoPath!)) : null,
                child: seller.photoPath == null ? const Icon(Icons.person, size: 48) : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(seller.fullName, style: Theme.of(context).textTheme.titleLarge),
            ),
            Center(child: Text(seller.displayId)),
            Center(
              child: Chip(
                label: Text(seller.status.label),
                backgroundColor: _statusColor(context, seller.status),
              ),
            ),
            if (seller.status == SyncStatus.flagged && seller.flagReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  seller.flagReason!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            _section('Business', [
              _row('Name', seller.businessName),
              _row('Category', seller.businessCategory),
              _row('Shop no.', seller.shopNumber ?? '-'),
              _row('Market', seller.marketName ?? seller.marketId.toString()),
            ]),
            _section('Contact', [
              _row('Phone', seller.phone),
              _row('NIN', seller.nin ?? '-'),
            ]),
            if (seller.qrPayload != null) ...[
              const SizedBox(height: 8),
              Center(
                child: QrImageView(
                  data: seller.qrPayload!,
                  size: 160,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_canCollectPayment)
              FilledButton.icon(
                key: const Key('collect_payment_button'),
                icon: const Icon(Icons.payments),
                label: const Text('Collect payment'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PaymentFlowScreen(seller: seller)),
                ),
              )
            else
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This seller is still pending sync. Payments can only be collected '
                    'once the registration has synced and received a permanent seller ID.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color? _statusColor(BuildContext context, SyncStatus status) => switch (status) {
        SyncStatus.synced => Colors.green.shade100,
        SyncStatus.pendingSync => Colors.amber.shade100,
        SyncStatus.flagged || SyncStatus.duplicateSuspected => Colors.red.shade100,
      };

  Widget _section(String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...rows,
              ],
            ),
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
