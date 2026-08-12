import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/repositories/payment_repository.dart';
import 'package:revenue_agent_app/repositories/seller_repository.dart';
import 'package:revenue_agent_app/repositories/sync_service.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_db.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _batchResponse(List<Map<String, dynamic>> results) => Response(
      requestOptions: RequestOptions(path: '/sync/batch'),
      statusCode: 200,
      data: {'results': results},
    );

void main() {
  late AppDatabase appDb;
  late MockDio dio;
  late SellerRepository sellerRepo;
  late PaymentRepository paymentRepo;
  late SyncService syncService;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() async {
    appDb = await openTestDatabase();
    dio = MockDio();
    sellerRepo = SellerRepository(dio: dio, db: appDb.db);
    paymentRepo = PaymentRepository(db: appDb.db);
    syncService = SyncService(dio: dio, sellerRepository: sellerRepo, paymentRepository: paymentRepo);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('with nothing pending, syncPending is a no-op and never calls the network', () async {
    final outcome = await syncService.syncPending();

    expect(outcome, SyncOutcome.empty);
    verifyNever(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')));
  });

  test(
      'a response that never arrives leaves the local row untouched (pending_sync), '
      'so it is safe to rebuild the exact same batch on the next attempt', () async {
    await sellerRepo.saveNewRegistration(buildSeller(clientUuid: 'seller-timeout'));

    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/sync/batch'),
      type: DioExceptionType.receiveTimeout,
      message: 'response never arrived',
    ));

    final outcome = await syncService.syncPending();

    expect(outcome.succeeded, isFalse);
    final row = await sellerRepo.byClientUuid('seller-timeout');
    expect(row!.status.name, 'pendingSync');
    expect(row.serverId, isNull);
  });

  test(
      'retrying after a timed-out batch (app killed mid-request, response never processed) '
      'converges to exactly one synced row - no duplicate is ever created', () async {
    final clientUuid = 'seller-retry';
    await sellerRepo.saveNewRegistration(buildSeller(clientUuid: clientUuid));

    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/sync/batch'),
      type: DioExceptionType.connectionError,
    ));
    final firstAttempt = await syncService.syncPending();
    expect(firstAttempt.succeeded, isFalse);

    // The same client_uuid is resent on retry because it is still pending_sync
    // and was generated once, at local-write time, never regenerated.
    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final body = invocation.namedArguments[#data] as Map<String, dynamic>;
      final records = body['records'] as List<dynamic>;
      expect(records, hasLength(1));
      expect((records.first as Map<String, dynamic>)['client_uuid'], clientUuid);
      return _batchResponse([
        {
          'client_uuid': clientUuid,
          'status': 'synced',
          'canonical_id': 123,
          'seller_uid': 'LAG-IKJ-2026-000123',
        },
      ]);
    });
    final secondAttempt = await syncService.syncPending();
    expect(secondAttempt.succeeded, isTrue);
    expect(secondAttempt.synced, 1);

    final rows = await appDb.db.query('sellers', where: 'client_uuid = ?', whereArgs: [clientUuid]);
    expect(rows, hasLength(1));
    expect(rows.first['status'], 'synced');
    expect(rows.first['server_id'], 123);

    // A third sync attempt must not resend an already-synced record.
    final thirdAttempt = await syncService.syncPending();
    expect(thirdAttempt, SyncOutcome.empty);
  });

  test('processes a mixed seller+payment batch and routes each result to the right table', () async {
    await paymentRepo.saveNewPayment(
      buildPayment(clientUuid: 'mix-payment', sellerClientUuid: 'mix-seller', sellerServerId: 500),
    );
    await sellerRepo.saveNewRegistration(buildSeller(clientUuid: 'mix-seller-2'));

    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenAnswer((_) async => _batchResponse([
              {
                'client_uuid': 'mix-seller-2',
                'status': 'synced',
                'canonical_id': 900,
                'seller_uid': 'LAG-IKJ-2026-000900',
              },
              {
                'client_uuid': 'mix-payment',
                'status': 'synced',
                'canonical_id': 800,
                'receipt_no': 'RCPT-000800',
              },
            ]));

    final outcome = await syncService.syncPending();
    expect(outcome.synced, 2);

    final seller = await sellerRepo.byClientUuid('mix-seller-2');
    expect(seller!.sellerUid, 'LAG-IKJ-2026-000900');

    final payment = await paymentRepo.byClientUuid('mix-payment');
    expect(payment!.receiptNo, 'RCPT-000800');
  });

  test('a flagged sync result (e.g. duplicate phone) surfaces as flagged with the server reason', () async {
    await sellerRepo.saveNewRegistration(buildSeller(clientUuid: 'dup-seller'));

    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenAnswer((_) async => _batchResponse([
              {
                'client_uuid': 'dup-seller',
                'status': 'flagged',
                'reason': 'duplicate_suspected: phone already registered in this LGA',
              },
            ]));

    final outcome = await syncService.syncPending();
    expect(outcome.flagged, 1);

    final seller = await sellerRepo.byClientUuid('dup-seller');
    expect(seller!.status.name, 'flagged');
    expect(seller.flagReason, contains('duplicate_suspected'));
  });

  test('splits the 200-record batch budget across sellers and payments, oldest first', () async {
    for (var i = 0; i < 150; i++) {
      await sellerRepo.saveNewRegistration(buildSeller(clientUuid: 'seller-$i'));
    }
    for (var i = 0; i < 100; i++) {
      await paymentRepo.saveNewPayment(
        buildPayment(clientUuid: 'payment-$i', sellerClientUuid: 'seller-0', sellerServerId: 1),
      );
    }

    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenAnswer((invocation) async {
      final body = invocation.namedArguments[#data] as Map<String, dynamic>;
      final records = body['records'] as List<dynamic>;
      expect(records.length, 200);
      final sellerRecords = records.where((r) => (r as Map)['type'] == 'seller').length;
      final paymentRecords = records.where((r) => (r as Map)['type'] == 'payment').length;
      expect(sellerRecords, 150);
      expect(paymentRecords, 50);
      return _batchResponse([]);
    });

    await syncService.syncPending();
  });
}
