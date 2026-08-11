import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sync_service.dart';
import 'connectivity_providers.dart';
import 'repository_providers.dart';

class SyncState {
  final bool isSyncing;
  final int pendingSellers;
  final int pendingPayments;
  final SyncOutcome? lastOutcome;
  final DateTime? lastSyncAttemptAt;

  const SyncState({
    this.isSyncing = false,
    this.pendingSellers = 0,
    this.pendingPayments = 0,
    this.lastOutcome,
    this.lastSyncAttemptAt,
  });

  int get pendingCount => pendingSellers + pendingPayments;

  SyncState copyWith({
    bool? isSyncing,
    int? pendingSellers,
    int? pendingPayments,
    SyncOutcome? lastOutcome,
    DateTime? lastSyncAttemptAt,
  }) =>
      SyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        pendingSellers: pendingSellers ?? this.pendingSellers,
        pendingPayments: pendingPayments ?? this.pendingPayments,
        lastOutcome: lastOutcome ?? this.lastOutcome,
        lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      );
}

/// Triggers a sync on connectivity regained and exposes a manual trigger for
/// the "Sync now" button. [_isRunning] guards against overlapping syncs from
/// a connectivity flap firing while a manual sync (or a previous
/// reconnect-triggered sync) is still in flight - SyncService itself is safe
/// to call concurrently, but running two batches back-to-back serially is
/// simpler to reason about than interleaving two in-flight HTTP calls.
class SyncController extends StateNotifier<SyncState> {
  final Ref ref;
  bool _isRunning = false;
  List<ConnectivityResult>? _lastConnectivity;

  SyncController(this.ref) : super(const SyncState()) {
    refreshPendingCounts();
    ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStreamProvider, (previous, next) {
      final results = next.valueOrNull;
      if (results == null) return;
      final wasOffline =
          _lastConnectivity == null || !isOnlineResult(_lastConnectivity!);
      _lastConnectivity = results;
      if (isOnlineResult(results) && wasOffline) {
        syncNow();
      }
    });
  }

  Future<void> refreshPendingCounts() async {
    final sellers = await ref.read(sellerRepositoryProvider).pendingSyncCount();
    final payments = await ref.read(paymentRepositoryProvider).pendingSyncCount();
    state = state.copyWith(pendingSellers: sellers, pendingPayments: payments);
  }

  Future<SyncOutcome> syncNow() async {
    if (_isRunning) return SyncOutcome.empty;
    _isRunning = true;
    state = state.copyWith(isSyncing: true, lastSyncAttemptAt: DateTime.now());
    try {
      final outcome = await ref.read(syncServiceProvider).syncPending();
      await refreshPendingCounts();
      state = state.copyWith(isSyncing: false, lastOutcome: outcome);
      return outcome;
    } finally {
      _isRunning = false;
    }
  }
}

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) => SyncController(ref),
);
