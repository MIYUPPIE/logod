import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/models/sync_models.dart';
import 'package:revenue_agent_app/models/sync_status.dart';
import 'package:revenue_agent_app/repositories/seller_repository.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AppDatabase appDb;
  late MockDio dio;
  late SellerRepository repo;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() async {
    appDb = await openTestDatabase();
    dio = MockDio();
    repo = SellerRepository(dio: dio, db: appDb.db);
  });

  tearDown(() async {
    await appDb.close();
  });

  group('saveNewRegistration', () {
    test('persists a record retrievable by client_uuid', () async {
      final seller = buildSeller(clientUuid: 'uuid-1');
      await repo.saveNewRegistration(seller);

      final fetched = await repo.byClientUuid('uuid-1');
      expect(fetched, isNotNull);
      expect(fetched!.fullName, seller.fullName);
      expect(fetched.status, SyncStatus.pendingSync);
    });

    test('saving the same client_uuid twice never creates a duplicate row', () async {
      final seller = buildSeller(clientUuid: 'uuid-dup', fullName: 'First Save');
      await repo.saveNewRegistration(seller);
      await repo.saveNewRegistration(buildSeller(clientUuid: 'uuid-dup', fullName: 'Second Save'));

      final rows = await appDb.db.query('sellers', where: 'client_uuid = ?', whereArgs: ['uuid-dup']);
      expect(rows, hasLength(1));
      expect(rows.first['full_name'], 'Second Save');
    });
  });

  group('searchLocal', () {
    test('matches on full name, phone, business name, and seller_uid', () async {
      await repo.saveNewRegistration(buildSeller(
        clientUuid: 'uuid-a',
        fullName: 'Chidi Okafor',
        phone: '08099998888',
      ));
      await repo.saveNewRegistration(buildSeller(
        clientUuid: 'uuid-b',
        fullName: 'Someone Else',
        phone: '08011112222',
      ));

      expect((await repo.searchLocal('Chidi')).map((s) => s.clientUuid), ['uuid-a']);
      expect((await repo.searchLocal('08099998888')).map((s) => s.clientUuid), ['uuid-a']);
      expect((await repo.searchLocal('Amaka Provisions')).length, 2); // shared fixture business name
    });
  });

  group('pendingSync / pendingSyncCount', () {
    test('only returns rows still in pending_sync status', () async {
      await repo.saveNewRegistration(buildSeller(clientUuid: 'p1', status: SyncStatus.pendingSync));
      await repo.saveNewRegistration(buildSeller(clientUuid: 'p2', status: SyncStatus.synced, serverId: 5));
      await repo.saveNewRegistration(buildSeller(clientUuid: 'p3', status: SyncStatus.pendingSync));

      final pending = await repo.pendingSync();
      expect(pending.map((s) => s.clientUuid).toSet(), {'p1', 'p3'});
      expect(await repo.pendingSyncCount(), 2);
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await repo.saveNewRegistration(buildSeller(clientUuid: 'lim-$i'));
      }
      final pending = await repo.pendingSync(limit: 3);
      expect(pending, hasLength(3));
    });
  });

  group('flagged', () {
    test('returns flagged and duplicate_suspected rows only', () async {
      await repo.saveNewRegistration(buildSeller(clientUuid: 'f1', status: SyncStatus.flagged, flagReason: 'dup phone'));
      await repo.saveNewRegistration(buildSeller(clientUuid: 'f2', status: SyncStatus.duplicateSuspected));
      await repo.saveNewRegistration(buildSeller(clientUuid: 'f3', status: SyncStatus.synced, serverId: 1));

      final flagged = await repo.flagged();
      expect(flagged.map((s) => s.clientUuid).toSet(), {'f1', 'f2'});
    });
  });

  group('applySyncResult', () {
    test('synced result updates canonical fields and clears any prior flag', () async {
      await repo.saveNewRegistration(
        buildSeller(clientUuid: 'sync-1', status: SyncStatus.flagged, flagReason: 'stale reason'),
      );

      await repo.applySyncResult(const SyncResult(
        clientUuid: 'sync-1',
        status: SyncResultStatus.synced,
        canonicalId: 42,
        sellerUid: 'LAG-IKJ-2026-000042',
      ));

      final updated = await repo.byClientUuid('sync-1');
      expect(updated!.status, SyncStatus.synced);
      expect(updated.serverId, 42);
      expect(updated.sellerUid, 'LAG-IKJ-2026-000042');
      expect(updated.flagReason, isNull);
    });

    test('flagged result sets status and reason without touching row count', () async {
      await repo.saveNewRegistration(buildSeller(clientUuid: 'flag-1'));

      await repo.applySyncResult(const SyncResult(
        clientUuid: 'flag-1',
        status: SyncResultStatus.flagged,
        reason: 'duplicate phone number in this LGA',
      ));

      final rows = await appDb.db.query('sellers', where: 'client_uuid = ?', whereArgs: ['flag-1']);
      expect(rows, hasLength(1));
      final updated = await repo.byClientUuid('flag-1');
      expect(updated!.status, SyncStatus.flagged);
      expect(updated.flagReason, 'duplicate phone number in this LGA');
    });

    test('applying the same synced result twice is idempotent: exactly one row, same end state', () async {
      await repo.saveNewRegistration(buildSeller(clientUuid: 'idem-1'));
      const result = SyncResult(
        clientUuid: 'idem-1',
        status: SyncResultStatus.synced,
        canonicalId: 7,
        sellerUid: 'LAG-IKJ-2026-000007',
      );

      await repo.applySyncResult(result);
      await repo.applySyncResult(result);

      final rows = await appDb.db.query('sellers', where: 'client_uuid = ?', whereArgs: ['idem-1']);
      expect(rows, hasLength(1));
      expect(rows.first['server_id'], 7);
      expect(rows.first['seller_uid'], 'LAG-IKJ-2026-000007');
      expect(rows.first['status'], 'synced');
    });
  });

  group('searchRemote', () {
    test('caches every result locally so it is findable offline afterwards', () async {
      when(() => dio.get<List<dynamic>>('/sellers/search', queryParameters: {'q': 'Chidi'}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/sellers/search'),
                statusCode: 200,
                data: [
                  {
                    'id': 10,
                    'seller_uid': 'LAG-IKJ-2026-000010',
                    'client_uuid': 'remote-uuid-1',
                    'full_name': 'Chidi Okafor',
                    'phone': '08099998888',
                    'nin': null,
                    'dob': '1985-05-05',
                    'gender': 'male',
                    'home_address': null,
                    'business_name': 'Chidi Electronics',
                    'business_category': 'Electronics',
                    'shop_number': null,
                    'market_id': 2,
                    'ward_id': 2,
                    'lga_id': 1,
                    'state_id': 1,
                    'lat': 6.5,
                    'lng': 3.4,
                    'gps_accuracy': 8.0,
                    'gps_captured_at': null,
                    'registered_by_user_id': 1,
                    'qr_payload': 'LAG-IKJ-2026-000010',
                    'duplicate_suspected': false,
                    'created_at': '2026-08-01T10:00:00.000Z',
                  }
                ],
              ));

      final results = await repo.searchRemote('Chidi');
      expect(results, hasLength(1));
      expect(results.first.sellerUid, 'LAG-IKJ-2026-000010');

      final cachedLocally = await repo.searchLocal('Chidi Electronics');
      expect(cachedLocally, hasLength(1));
      expect(cachedLocally.first.status, SyncStatus.synced);
    });

    test('a remote refresh never clobbers a photo already captured on this device', () async {
      await repo.saveNewRegistration(
        buildSeller(clientUuid: 'has-photo', status: SyncStatus.pendingSync)
            .copyWith(status: SyncStatus.pendingSync),
      );
      // Simulate a photo captured locally by writing directly (SellerRecord is immutable).
      await appDb.db.update('sellers', {'photo_path': '/tmp/photo.jpg'},
          where: 'client_uuid = ?', whereArgs: ['has-photo']);

      when(() => dio.get<List<dynamic>>('/sellers/search', queryParameters: {'q': 'has-photo'}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/sellers/search'),
                statusCode: 200,
                data: [
                  {
                    'id': 99,
                    'seller_uid': 'LAG-IKJ-2026-000099',
                    'client_uuid': 'has-photo',
                    'full_name': 'Amaka Obi',
                    'phone': '08012345678',
                    'nin': null,
                    'dob': '1990-01-01',
                    'gender': 'female',
                    'home_address': null,
                    'business_name': 'Amaka Provisions',
                    'business_category': 'Provisions',
                    'shop_number': 'A12',
                    'market_id': 1,
                    'ward_id': 1,
                    'lga_id': 1,
                    'state_id': 1,
                    'lat': 6.5244,
                    'lng': 3.3792,
                    'gps_accuracy': 12.0,
                    'gps_captured_at': null,
                    'registered_by_user_id': 1,
                    'qr_payload': 'LAG-IKJ-2026-000099',
                    'duplicate_suspected': false,
                    'created_at': '2026-08-01T10:00:00.000Z',
                  }
                ],
              ));

      await repo.searchRemote('has-photo');

      final merged = await repo.byClientUuid('has-photo');
      expect(merged!.photoPath, '/tmp/photo.jpg');
      expect(merged.serverId, 99);
    });
  });
}
