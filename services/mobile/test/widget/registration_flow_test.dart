import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/core/services/location_service.dart';
import 'package:revenue_agent_app/models/geo_node.dart';
import 'package:revenue_agent_app/providers/auth_providers.dart';
import 'package:revenue_agent_app/providers/connectivity_providers.dart';
import 'package:revenue_agent_app/providers/db_providers.dart';
import 'package:revenue_agent_app/providers/geo_providers.dart';
import 'package:revenue_agent_app/providers/service_providers.dart';
import 'package:revenue_agent_app/providers/sync_providers.dart';
import 'package:revenue_agent_app/screens/registration/registration_flow_screen.dart';

import '../helpers/fake_image.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_helpers.dart';
import '../helpers/test_db.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AppDatabase appDb;
  late MockDio dio;
  late String photoPath;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() async {
    appDb = await openTestDatabase();
    dio = MockDio();
    // The screen fires an opportunistic background sync after saving; make
    // it fail fast instead of attempting a real network call in the test.
    when(() => dio.post<Map<String, dynamic>>('/sync/batch', data: any(named: 'data')))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/sync/batch'),
      type: DioExceptionType.connectionError,
    ));
    photoPath = await writeFakePhoto();
  });

  tearDown(() async {
    await appDb.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(appDb),
          dioProvider.overrideWithValue(dio),
          // Offline: keeps SyncController's connectivity listener from
          // auto-firing syncNow() the instant it is constructed (during the
          // final save), which would otherwise race the explicit
          // refreshPendingCounts()/syncNow() calls _save() already makes and
          // destabilize pumpAndSettle. This also matches what we are
          // actually testing here: registration saving locally with zero
          // connectivity.
          connectivityStreamProvider.overrideWith((ref) => Stream.value(const [ConnectivityResult.none])),
          photoServiceProvider.overrideWithValue(FakePhotoService(photoPath)),
          locationServiceProvider.overrideWithValue(FakeLocationService(
            LocationFix(lat: 6.5244, lng: 3.3792, accuracy: 8.0, capturedAt: DateTime(2026, 8, 12)),
          )),
          // The geo cascading pickers are covered in isolation by
          // geo_repository_test.dart (including its cache-then-network
          // behaviour). Here they are overridden with data that resolves via
          // a plain microtask instead of a real sqflite/FFI read, because a
          // FutureProvider's own internal async chain does not reliably wake
          // flutter_test's pump loop when it is waiting on real platform I/O
          // - only explicitly-awaited real work (like the final save below,
          // driven by our own await/pump sequencing) does.
          statesProvider.overrideWith((ref) => Future.value(const [GeoNode(id: 1, name: 'Lagos', code: 'LAG')])),
          lgasProvider(1).overrideWith((ref) => Future.value(const [GeoNode(id: 1, name: 'Ikeja', code: 'IKJ')])),
          wardsProvider(1).overrideWith((ref) => Future.value(const [GeoNode(id: 1, name: 'Ward 1', code: null)])),
          marketsProvider(1)
              .overrideWith((ref) => Future.value(const [GeoNode(id: 1, name: 'Central Market', code: null)])),
          syncControllerProvider.overrideWith((ref) => FakeSyncController(ref)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegistrationFlowScreen()),
                  ),
                  child: const Text('open registration'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open registration'));
    await tester.pumpAndSettle();
  }

  // The registration flow does real sqflite (FFI) reads/writes as the agent
  // moves through the wizard, and FFI query execution does not resolve
  // inside flutter_test's default fake-async zone (it only completes on the
  // real event loop). tester.runAsync() switches to a real async zone for
  // the whole interaction so those queries - and the temp file used for the
  // fake photo - actually complete instead of hanging pumpAndSettle forever.
  testWidgets('completes all four steps and saves a pending_sync seller locally', (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);

      // Step 1: Identity.
      expect(find.text('Identity'), findsOneWidget);
      await tapKey(tester, 'capture_photo_button');

      await tester.enterText(find.byKey(const Key('full_name_field')), 'Amaka Obi');
      await tester.enterText(find.byKey(const Key('phone_field')), '08012345678');
      await tester.pumpAndSettle();

      await tapKey(tester, 'dob_field');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tapKey(tester, 'gender_field');
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('registration_next_button')), findsOneWidget);
      final nextButton =
          tester.widget<FilledButton>(find.byKey(const Key('registration_next_button')));
      expect(nextButton.onPressed, isNotNull, reason: 'identity step should now validate as complete');

      await tapKey(tester, 'registration_next_button');

      // Step 2: Business.
      expect(find.text('Business'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('business_name_field')), 'Amaka Provisions');
      await tester.enterText(find.byKey(const Key('business_category_field')), 'Provisions');
      await tester.pumpAndSettle();

      await tapKey(tester, 'state_field');
      await tester.tap(find.text('Lagos').last);
      await tester.pumpAndSettle();

      // lga_field/ward_field/market_field are keyed on their parent id
      // (lga_field_<stateId>, etc.) so Flutter remounts each cascading
      // dropdown fresh instead of reusing stale DropdownButtonFormField
      // state after the parent selection changes - see business_step.dart.
      // The seeded test fixture (test/helpers/geo_seed.dart) gives Lagos/
      // Ikeja/Ward 1/Central Market id 1 at every level.
      await tapKey(tester, 'lga_field_1');
      await tester.tap(find.text('Ikeja').last);
      await tester.pumpAndSettle();

      await tapKey(tester, 'ward_field_1');
      await tester.tap(find.text('Ward 1').last);
      await tester.pumpAndSettle();

      await tapKey(tester, 'market_field_1');
      await tester.tap(find.text('Central Market').last);
      await tester.pumpAndSettle();

      await tapKey(tester, 'registration_next_button');

      // Step 3: GPS - auto-captured via the fake LocationService.
      expect(find.text('GPS location'), findsOneWidget);
      expect(find.textContaining('6.524400'), findsOneWidget);
      await tapKey(tester, 'registration_next_button');

      // Step 4: Review.
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Amaka Obi'), findsWidgets);
      expect(find.text('Amaka Provisions'), findsWidgets);

      await tester.tap(find.byKey(const Key('registration_next_button')));
      await pumpUntilFound(tester, find.text('Seller saved'));

      await tester.tap(find.byKey(const Key('registration_done_button')));
      await pumpUntilFound(tester, find.text('open registration'));

      final rows = await appDb.db.query('sellers');
      expect(rows, hasLength(1));
      expect(rows.first['full_name'], 'Amaka Obi');
      expect(rows.first['business_name'], 'Amaka Provisions');
      expect(rows.first['status'], 'pendingSync');
      expect(rows.first['lat'], 6.5244);
      expect(rows.first['market_id'], 1);
    });
  });

  testWidgets('Next is disabled on step 1 until the required identity fields are filled', (tester) async {
    await tester.runAsync(() async {
      await pumpApp(tester);

      final nextButton =
          tester.widget<FilledButton>(find.byKey(const Key('registration_next_button')));
      expect(nextButton.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('full_name_field')), 'Amaka Obi');
      await tester.pumpAndSettle();

      final stillDisabled =
          tester.widget<FilledButton>(find.byKey(const Key('registration_next_button')));
      expect(stillDisabled.onPressed, isNull, reason: 'photo/phone/dob/gender are still missing');
    });
  });
}
