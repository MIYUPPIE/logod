import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/seller_record.dart';
import '../../models/sync_status.dart';
import '../../providers/repository_providers.dart';
import 'qr_scan_screen.dart';
import 'seller_detail_screen.dart';

class SellerSearchScreen extends ConsumerStatefulWidget {
  const SellerSearchScreen({super.key});

  @override
  ConsumerState<SellerSearchScreen> createState() => _SellerSearchScreenState();
}

class _SellerSearchScreenState extends ConsumerState<SellerSearchScreen> {
  final _controller = TextEditingController();
  List<SellerRecord> _results = [];
  bool _searching = false;
  String? _offlineNotice;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _offlineNotice = null;
    });

    final repo = ref.read(sellerRepositoryProvider);
    try {
      final remoteResults = await repo.searchRemote(query);
      setState(() => _results = remoteResults);
    } on DioException {
      final localResults = await repo.searchLocal(query);
      setState(() {
        _results = localResults;
        _offlineNotice = 'Offline - showing sellers previously seen on this device.';
      });
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || !mounted) return;

    final repo = ref.read(sellerRepositoryProvider);
    final seller = await repo.lookupByQr(code);
    if (!mounted) return;
    if (seller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No seller found for that QR code.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SellerDetailScreen(seller: seller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find seller'),
        actions: [
          IconButton(
            key: const Key('qr_scan_button'),
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQr,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('seller_search_field'),
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Seller ID, phone, or business name',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('seller_search_submit'),
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_offlineNotice != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_offlineNotice!, style: TextStyle(color: Colors.orange.shade800)),
            ),
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final seller = _results[index];
                return ListTile(
                  leading: CircleIcon(status: seller.status),
                  title: Text(seller.businessName),
                  subtitle: Text('${seller.fullName} - ${seller.displayId}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SellerDetailScreen(seller: seller)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  final SyncStatus status;

  const CircleIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SyncStatus.synced => Colors.green,
      SyncStatus.pendingSync => Colors.amber,
      SyncStatus.flagged || SyncStatus.duplicateSuspected => Colors.red,
    };
    return CircleAvatar(backgroundColor: color, radius: 6);
  }
}
