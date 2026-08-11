import 'package:sqflite/sqflite.dart';

import '../core/utils/ids.dart';
import '../models/payment_record.dart';
import '../models/sync_models.dart';
import '../models/sync_status.dart';

class PaymentRepository {
  final Database db;

  PaymentRepository({required this.db});

  Future<void> saveNewPayment(PaymentRecord record) async {
    await db.insert('payments', record.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PaymentRecord?> byClientUuid(String clientUuid) async {
    final rows = await db.query('payments', where: 'client_uuid = ?', whereArgs: [clientUuid]);
    if (rows.isEmpty) return null;
    return PaymentRecord.fromDb(rows.first);
  }

  Future<List<PaymentRecord>> forSeller(String sellerClientUuid) async {
    final rows = await db.query(
      'payments',
      where: 'seller_client_uuid = ?',
      whereArgs: [sellerClientUuid],
      orderBy: 'paid_at DESC',
    );
    return rows.map(PaymentRecord.fromDb).toList();
  }

  Future<List<PaymentRecord>> pendingSync({int limit = 200}) async {
    final rows = await db.query(
      'payments',
      where: 'status = ?',
      whereArgs: [SyncStatus.pendingSync.toDb()],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(PaymentRecord.fromDb).toList();
  }

  Future<int> pendingSyncCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM payments WHERE status = ?',
      [SyncStatus.pendingSync.toDb()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<PaymentRecord>> flagged() async {
    final rows = await db.query(
      'payments',
      where: 'status IN (?, ?)',
      whereArgs: [SyncStatus.flagged.toDb(), SyncStatus.duplicateSuspected.toDb()],
      orderBy: 'created_at DESC',
    );
    return rows.map(PaymentRecord.fromDb).toList();
  }

  /// Idempotent by construction, same reasoning as
  /// SellerRepository.applySyncResult: keyed UPDATE on the primary key, so a
  /// duplicate-applied result cannot create a second local row.
  Future<void> applySyncResult(SyncResult result) async {
    switch (result.status) {
      case SyncResultStatus.synced:
        await db.update(
          'payments',
          {
            'server_id': result.canonicalId,
            'receipt_no': result.receiptNo,
            'status': SyncStatus.synced.toDb(),
            'flag_reason': null,
            'synced_at': nowIso(),
          },
          where: 'client_uuid = ?',
          whereArgs: [result.clientUuid],
        );
      case SyncResultStatus.flagged:
      case SyncResultStatus.error:
        await db.update(
          'payments',
          {
            'status': SyncStatus.flagged.toDb(),
            'flag_reason': result.reason ?? 'Sync failed with no reason provided',
          },
          where: 'client_uuid = ?',
          whereArgs: [result.clientUuid],
        );
    }
  }
}
