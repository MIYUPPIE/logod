import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/models/levy_type.dart';
import 'package:revenue_agent_app/repositories/levy_type_repository.dart';

import '../helpers/test_db.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late AppDatabase appDb;
  late MockDio dio;
  late LevyTypeRepository repo;

  setUp(() async {
    appDb = await openTestDatabase();
    dio = MockDio();
    repo = LevyTypeRepository(dio: dio, db: appDb.db);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('forLga fetches from the network then serves the cache on a later call', () async {
    when(() => dio.get<List<dynamic>>('/levy-types', queryParameters: {'lga_id': 11})).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/levy-types'),
        statusCode: 200,
        data: [
          {'id': 1, 'lga_id': 11, 'name': 'Daily Trading Levy', 'amount': 500.0, 'frequency': 'daily'},
        ],
      ),
    );

    final first = await repo.forLga(11);
    expect(first, hasLength(1));
    verify(() => dio.get<List<dynamic>>('/levy-types', queryParameters: {'lga_id': 11})).called(1);

    final second = await repo.forLga(11);
    expect(second, hasLength(1));
    verifyNoMoreInteractions(dio);
  });

  test('create posts to /admin/levy-types and caches the created row', () async {
    when(() => dio.post<Map<String, dynamic>>('/admin/levy-types', data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/admin/levy-types'),
        statusCode: 201,
        data: {'id': 5, 'lga_id': 11, 'name': 'Signage Permit', 'amount': 15000.0, 'frequency': 'one_off'},
      ),
    );

    final created = await repo.create(
      lgaId: 11,
      name: 'Signage Permit',
      amount: 15000,
      frequency: LevyFrequency.oneOff,
    );

    expect(created.id, 5);
    final captured = verify(() =>
            dio.post<Map<String, dynamic>>('/admin/levy-types', data: captureAny(named: 'data')))
        .captured
        .single as Map<String, dynamic>;
    expect(captured['frequency'], 'one_off');

    // A subsequent forLga(11) call should see the newly created row from
    // cache without a network call, since create() writes through.
    final cached = await repo.forLga(11);
    expect(cached.map((t) => t.name), contains('Signage Permit'));
  });

  test('updateAmount patches by id and refreshes the cached row', () async {
    when(() => dio.patch<Map<String, dynamic>>('/admin/levy-types/5', data: any(named: 'data')))
        .thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/admin/levy-types/5'),
        statusCode: 200,
        data: {'id': 5, 'lga_id': 11, 'name': 'Signage Permit', 'amount': 20000.0, 'frequency': 'one_off'},
      ),
    );

    final updated = await repo.updateAmount(5, 20000);

    expect(updated.amount, 20000.0);
    verify(() => dio.patch<Map<String, dynamic>>('/admin/levy-types/5', data: {'amount': 20000.0}))
        .called(1);
  });
}
