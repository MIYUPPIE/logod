import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/models/levy_type.dart';
import 'package:revenue_agent_app/models/sync_status.dart';
import 'package:revenue_agent_app/providers/auth_providers.dart';
import 'package:revenue_agent_app/providers/connectivity_providers.dart';
import 'package:revenue_agent_app/providers/db_providers.dart';
import 'package:revenue_agent_app/providers/geo_providers.dart';
import 'package:revenue_agent_app/providers/sync_providers.dart';
import 'package:revenue_agent_app/screens/payment/payment_flow_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump_helpers.dart';
import '../helpers/test_db.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AppDatabase appDb;
  late MockDio dio;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() async {
    appDb = await openTestDatabase();
    dio = MockDio();
    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/sync/batch'),
      type: DioExceptionType.connectionError,
    ));
  });

  tearDown(() async {
    await appDb.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final seller = buildSeller(
      clientUuid: 'seller-synced-1',
      serverId: 501,
      sellerUid: 'LAG-IKJ-2026-000501',
      status: SyncStatus.synced,
    );
    await appDb.db.insert('sellers', seller.toDb());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(appDb),
          dioProvider.overrideWithValue(dio),
          connectivityStreamProvider.overrideWith((ref) => Stream.value(const [ConnectivityResult.none])),
          // levy_type_repository_test.dart already covers the cache/network
          // behaviour; here the data resolves via a plain microtask so the
          // widget-test pump loop (which only advances simulated time, see
          // pumpUntilFound) does not need to wait on real sqflite/FFI I/O
          // just to render the levy type list.
          levyTypesProvider(seller.lgaId).overrideWith((ref) => Future.value(const [
                LevyType(id: 1, lgaId: 1, name: 'Daily Trading Levy', amount: 500.0, frequency: LevyFrequency.daily),
                LevyType(id: 2, lgaId: 1, name: 'Weekly Sanitation Levy', amount: 1000.0, frequency: LevyFrequency.weekly),
              ])),
          syncControllerProvider.overrideWith((ref) => FakeSyncController(ref)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PaymentFlowScreen(seller: seller)),
                  ),
                  child: const Text('open payment'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open payment'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'collecting a payment saves it locally with the levy type amount (not a free-typed one) '
      'and shows a pending-sync receipt', (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);

      expect(find.text('Amaka Provisions'), findsOneWidget);
      expect(find.text('Levy type'), findsOneWidget);

      await tapKey(tester, 'levy_type_2');
      await scrollToKey(tester, 'payment_amount_card');
      expect(find.text('₦1000.00'), findsOneWidget);

      await tapKey(tester, 'payment_method_pos');

      await tester.tap(find.byKey(const Key('confirm_payment_button')));
      await pumpUntilFound(tester, find.text('Payment recorded'));
      await tester.pumpAndSettle();

      expect(find.text('₦1000.00'), findsWidgets);
      expect(find.text('POS'), findsOneWidget);
      expect(find.byKey(const Key('pending_sync_watermark')), findsOneWidget);

      final rows = await appDb.db.query('payments');
      expect(rows, hasLength(1));
      expect(rows.first['levy_type_id'], 2);
      expect(rows.first['amount'], 1000.0);
      expect(rows.first['method'], 'pos');
      expect(rows.first['status'], 'pendingSync');
      expect(rows.first['seller_server_id'], 501);

      await tester.tap(find.byKey(const Key('receipt_done_button')));
      await pumpUntilFound(tester, find.text('open payment'));
    });
  });

  testWidgets('the amount shown always comes from the selected levy type, never free text',
      (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);

      // Default selection is the first levy type; its amount is shown and
      // there is no text field anywhere in this screen that could edit it.
      await scrollToKey(tester, 'payment_amount_card');
      expect(find.text('₦500.00'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);

      await tapKey(tester, 'levy_type_2');
      await scrollToKey(tester, 'payment_amount_card');
      expect(find.text('₦1000.00'), findsOneWidget);
      expect(find.text('₦500.00'), findsNothing);
    });
  });
}
