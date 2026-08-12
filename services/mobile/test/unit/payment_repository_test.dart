import 'package:flutter_test/flutter_test.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/models/sync_models.dart';
import 'package:revenue_agent_app/models/sync_status.dart';
import 'package:revenue_agent_app/repositories/payment_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  late AppDatabase appDb;
  late PaymentRepository repo;

  setUp(() async {
    appDb = await openTestDatabase();
    repo = PaymentRepository(db: appDb.db);
  });

  tearDown(() async {
    await appDb.close();
  });

  group('saveNewPayment', () {
    test('persists a record retrievable by client_uuid', () async {
      final payment = buildPayment(clientUuid: 'pay-1', sellerClientUuid: 'seller-1', sellerServerId: 1);
      await repo.saveNewPayment(payment);

      final fetched = await repo.byClientUuid('pay-1');
      expect(fetched, isNotNull);
      expect(fetched!.amount, 500.0);
      expect(fetched.status, SyncStatus.pendingSync);
    });

    test('saving the same client_uuid twice never creates a duplicate row', () async {
      await repo.saveNewPayment(
        buildPayment(clientUuid: 'dup', sellerClientUuid: 'seller-1', sellerServerId: 1, amount: 100),
      );
      await repo.saveNewPayment(
        buildPayment(clientUuid: 'dup', sellerClientUuid: 'seller-1', sellerServerId: 1, amount: 100),
      );

      final rows = await appDb.db.query('payments', where: 'client_uuid = ?', whereArgs: ['dup']);
      expect(rows, hasLength(1));
    });
  });

  group('forSeller', () {
    test('lists only payments for the given seller, most recent first', () async {
      await repo.saveNewPayment(buildPayment(clientUuid: 'a', sellerClientUuid: 's1', sellerServerId: 1));
      await repo.saveNewPayment(buildPayment(clientUuid: 'b', sellerClientUuid: 's2', sellerServerId: 2));
      await repo.saveNewPayment(buildPayment(clientUuid: 'c', sellerClientUuid: 's1', sellerServerId: 1));

      final payments = await repo.forSeller('s1');
      expect(payments.map((p) => p.clientUuid).toSet(), {'a', 'c'});
    });
  });

  group('pendingSync / pendingSyncCount', () {
    test('only returns pending_sync rows and respects limit', () async {
      await repo.saveNewPayment(
          buildPayment(clientUuid: 'p1', sellerClientUuid: 's1', sellerServerId: 1, status: SyncStatus.pendingSync));
      await repo.saveNewPayment(buildPayment(
          clientUuid: 'p2', sellerClientUuid: 's1', sellerServerId: 1, status: SyncStatus.synced, serverId: 9));
      await repo.saveNewPayment(
          buildPayment(clientUuid: 'p3', sellerClientUuid: 's1', sellerServerId: 1, status: SyncStatus.pendingSync));

      expect(await repo.pendingSyncCount(), 2);
      final limited = await repo.pendingSync(limit: 1);
      expect(limited, hasLength(1));
    });
  });

  group('flagged', () {
    test('returns flagged and duplicate_suspected rows only', () async {
      await repo.saveNewPayment(buildPayment(
          clientUuid: 'f1', sellerClientUuid: 's1', sellerServerId: 1, status: SyncStatus.flagged, flagReason: 'x'));
      await repo.saveNewPayment(buildPayment(
          clientUuid: 'f2', sellerClientUuid: 's1', sellerServerId: 1, status: SyncStatus.synced, serverId: 3));

      final flagged = await repo.flagged();
      expect(flagged.map((p) => p.clientUuid).toSet(), {'f1'});
    });
  });

  group('applySyncResult', () {
    test('synced result stores canonical id and receipt number, clears flag', () async {
      await repo.saveNewPayment(buildPayment(
          clientUuid: 'sync-1',
          sellerClientUuid: 's1',
          sellerServerId: 1,
          status: SyncStatus.flagged,
          flagReason: 'stale'));

      await repo.applySyncResult(const SyncResult(
        clientUuid: 'sync-1',
        status: SyncResultStatus.synced,
        canonicalId: 501,
        receiptNo: 'RCPT-000501',
      ));

      final updated = await repo.byClientUuid('sync-1');
      expect(updated!.status, SyncStatus.synced);
      expect(updated.serverId, 501);
      expect(updated.receiptNo, 'RCPT-000501');
      expect(updated.flagReason, isNull);
      expect(updated.syncedAt, isNotNull);
    });

    test('applying the same synced result twice is idempotent: exactly one row per client_uuid', () async {
      await repo.saveNewPayment(buildPayment(clientUuid: 'idem-1', sellerClientUuid: 's1', sellerServerId: 1));
      const result = SyncResult(
        clientUuid: 'idem-1',
        status: SyncResultStatus.synced,
        canonicalId: 77,
        receiptNo: 'RCPT-000077',
      );

      await repo.applySyncResult(result);
      await repo.applySyncResult(result);

      final rows = await appDb.db.query('payments', where: 'client_uuid = ?', whereArgs: ['idem-1']);
      expect(rows, hasLength(1));
      expect(rows.first['receipt_no'], 'RCPT-000077');
    });
  });
}
