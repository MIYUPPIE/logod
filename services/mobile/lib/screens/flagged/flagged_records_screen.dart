import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/payment_record.dart';
import '../../models/seller_record.dart';
import '../../providers/repository_providers.dart';
import '../search/seller_detail_screen.dart';

final _flaggedSellersProvider = FutureProvider.autoDispose<List<SellerRecord>>(
  (ref) => ref.watch(sellerRepositoryProvider).flagged(),
);

final _flaggedPaymentsProvider = FutureProvider.autoDispose<List<PaymentRecord>>(
  (ref) => ref.watch(paymentRepositoryProvider).flagged(),
);

class FlaggedRecordsScreen extends ConsumerWidget {
  const FlaggedRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellersAsync = ref.watch(_flaggedSellersProvider);
    final paymentsAsync = ref.watch(_flaggedPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Flagged records')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_flaggedSellersProvider);
          ref.invalidate(_flaggedPaymentsProvider);
        },
        child: ListView(
          children: [
            _sectionHeader(context, 'Sellers'),
            sellersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, st) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Could not load flagged sellers.'),
              ),
              data: (sellers) => sellers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No flagged seller records.'),
                    )
                  : Column(
                      children: sellers
                          .map((seller) => ListTile(
                                title: Text(seller.businessName),
                                subtitle: Text(
                                    '${seller.fullName} - ${seller.flagReason ?? 'Flagged'}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => SellerDetailScreen(seller: seller)),
                                ),
                              ))
                          .toList(),
                    ),
            ),
            const Divider(),
            _sectionHeader(context, 'Payments'),
            paymentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, st) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Could not load flagged payments.'),
              ),
              data: (payments) => payments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No flagged payment records.'),
                    )
                  : Column(
                      children: payments
                          .map((payment) => ListTile(
                                title: Text(payment.sellerDisplayName),
                                subtitle: Text(
                                    '₦${payment.amount.toStringAsFixed(2)} - ${payment.flagReason ?? 'Flagged'}'),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
