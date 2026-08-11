import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/ids.dart';
import '../models/seller_record.dart';
import '../models/sync_models.dart';
import '../models/sync_status.dart';

class SellerRepository {
  final Dio dio;
  final Database db;

  SellerRepository({required this.dio, required this.db});

  Future<void> saveNewRegistration(SellerRecord record) async {
    await db.insert('sellers', record.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<SellerRecord?> byClientUuid(String clientUuid) async {
    final rows = await db.query('sellers', where: 'client_uuid = ?', whereArgs: [clientUuid]);
    if (rows.isEmpty) return null;
    return SellerRecord.fromDb(rows.first);
  }

  Future<List<SellerRecord>> searchLocal(String query) async {
    final like = '%$query%';
    final rows = await db.query(
      'sellers',
      where: 'full_name LIKE ? OR phone LIKE ? OR business_name LIKE ? OR seller_uid LIKE ?',
      whereArgs: [like, like, like, like],
      orderBy: 'updated_at DESC',
      limit: 50,
    );
    return rows.map(SellerRecord.fromDb).toList();
  }

  /// Hits GET /sellers/search when online and caches every result locally
  /// (origin=remote_cache) keyed by the server's own client_uuid, so a
  /// seller found once stays searchable - and payable - offline afterwards.
  Future<List<SellerRecord>> searchRemote(String query) async {
    final response =
        await dio.get<List<dynamic>>('/sellers/search', queryParameters: {'q': query});
    final now = nowIso();
    final records = (response.data ?? [])
        .map((e) => SellerRecord.fromApiJson(e as Map<String, dynamic>, now))
        .toList();
    for (final record in records) {
      await _upsertPreservingLocalOnlyFields(record);
    }
    return records;
  }

  Future<SellerRecord?> lookupByQr(String sellerUid) async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/sellers/qr/$sellerUid');
      final record = SellerRecord.fromApiJson(response.data!, nowIso());
      await _upsertPreservingLocalOnlyFields(record);
      return record;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final rows =
            await db.query('sellers', where: 'seller_uid = ?', whereArgs: [sellerUid]);
        return rows.isEmpty ? null : SellerRecord.fromDb(rows.first);
      }
      rethrow;
    }
  }

  /// A remote-fetched record must never clobber a photo captured on this
  /// device for a row this agent already knows about (the server response
  /// has no local file path), so merge onto the existing row when present.
  Future<void> _upsertPreservingLocalOnlyFields(SellerRecord fetched) async {
    final existing = await byClientUuid(fetched.clientUuid);
    final merged = existing == null
        ? fetched
        : SellerRecord(
            clientUuid: fetched.clientUuid,
            serverId: fetched.serverId,
            sellerUid: fetched.sellerUid,
            fullName: fetched.fullName,
            photoPath: existing.photoPath,
            phone: fetched.phone,
            nin: fetched.nin,
            dob: fetched.dob,
            gender: fetched.gender,
            homeAddress: fetched.homeAddress,
            businessName: fetched.businessName,
            businessCategory: fetched.businessCategory,
            shopNumber: fetched.shopNumber,
            marketId: fetched.marketId,
            marketName: existing.marketName,
            wardId: fetched.wardId,
            wardName: existing.wardName,
            lgaId: fetched.lgaId,
            lgaName: existing.lgaName,
            stateId: fetched.stateId,
            stateName: existing.stateName,
            lat: fetched.lat,
            lng: fetched.lng,
            gpsAccuracy: fetched.gpsAccuracy,
            gpsCapturedAt: fetched.gpsCapturedAt,
            qrPayload: fetched.qrPayload,
            status: fetched.status,
            flagReason: existing.status == SyncStatus.flagged ? existing.flagReason : null,
            origin: existing.origin,
            createdAt: existing.createdAt,
            updatedAt: fetched.updatedAt,
          );
    await db.insert('sellers', merged.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SellerRecord>> pendingSync({int limit = 200}) async {
    final rows = await db.query(
      'sellers',
      where: 'status = ?',
      whereArgs: [SyncStatus.pendingSync.toDb()],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SellerRecord.fromDb).toList();
  }

  Future<int> pendingSyncCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sellers WHERE status = ?',
      [SyncStatus.pendingSync.toDb()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<SellerRecord>> flagged() async {
    final rows = await db.query(
      'sellers',
      where: 'status IN (?, ?)',
      whereArgs: [SyncStatus.flagged.toDb(), SyncStatus.duplicateSuspected.toDb()],
      orderBy: 'updated_at DESC',
    );
    return rows.map(SellerRecord.fromDb).toList();
  }

  /// Idempotent by construction: this is an UPDATE keyed on the primary key
  /// client_uuid, so applying the same [result] twice (e.g. a sync response
  /// processed twice after an app restart mid-batch) leaves the row in the
  /// same end state rather than creating a second row.
  Future<void> applySyncResult(SyncResult result) async {
    switch (result.status) {
      case SyncResultStatus.synced:
        await db.update(
          'sellers',
          {
            'server_id': result.canonicalId,
            'seller_uid': result.sellerUid,
            'status': SyncStatus.synced.toDb(),
            'flag_reason': null,
            'updated_at': nowIso(),
          },
          where: 'client_uuid = ?',
          whereArgs: [result.clientUuid],
        );
      case SyncResultStatus.flagged:
      case SyncResultStatus.error:
        await db.update(
          'sellers',
          {
            'status': SyncStatus.flagged.toDb(),
            'flag_reason': result.reason ?? 'Sync failed with no reason provided',
            'updated_at': nowIso(),
          },
          where: 'client_uuid = ?',
          whereArgs: [result.clientUuid],
        );
    }
  }
}
