import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';
import 'package:revenue_agent_app/repositories/geo_repository.dart';

import '../helpers/test_db.dart';

class MockDio extends Mock implements Dio {}

Response<List<dynamic>> _listResponse(String path, List<Map<String, dynamic>> items) => Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: items,
    );

void main() {
  late AppDatabase appDb;
  late MockDio dio;
  late GeoRepository repo;

  setUp(() async {
    appDb = await openTestDatabase();
    dio = MockDio();
    repo = GeoRepository(dio: dio, db: appDb.db);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('states() fetches from the network on first call and caches the result', () async {
    when(() => dio.get<List<dynamic>>('/geo/states')).thenAnswer(
      (_) async => _listResponse('/geo/states', [
        {'id': 1, 'name': 'Lagos', 'code': 'LAG'},
      ]),
    );

    final first = await repo.states();
    expect(first, hasLength(1));
    expect(first.first.name, 'Lagos');
    verify(() => dio.get<List<dynamic>>('/geo/states')).called(1);

    // Second call must be served from cache, not the network.
    final second = await repo.states();
    expect(second, hasLength(1));
    verifyNoMoreInteractions(dio);
  });

  test('falls back to the cache when offline instead of throwing', () async {
    when(() => dio.get<List<dynamic>>('/geo/lgas', queryParameters: {'state_id': 1}))
        .thenAnswer((_) async => _listResponse('/geo/lgas', [
              {'id': 10, 'name': 'Ikeja', 'code': 'IKJ'},
            ]));
    final firstLoad = await repo.lgas(1);
    expect(firstLoad, hasLength(1));

    when(() => dio.get<List<dynamic>>('/geo/lgas', queryParameters: {'state_id': 1}))
        .thenThrow(DioException(
      requestOptions: RequestOptions(path: '/geo/lgas'),
      type: DioExceptionType.connectionError,
    ));

    final offlineResult = await repo.lgas(1, forceRefresh: true);
    expect(offlineResult, hasLength(1));
    expect(offlineResult.first.name, 'Ikeja');
  });

  test('wards and markets are scoped to their parent id', () async {
    when(() => dio.get<List<dynamic>>('/geo/wards', queryParameters: {'lga_id': 10}))
        .thenAnswer((_) async => _listResponse('/geo/wards', [
              {'id': 100, 'name': 'Ward A', 'code': null},
            ]));
    when(() => dio.get<List<dynamic>>('/geo/wards', queryParameters: {'lga_id': 20}))
        .thenAnswer((_) async => _listResponse('/geo/wards', [
              {'id': 200, 'name': 'Ward B', 'code': null},
            ]));

    final wardsForLga10 = await repo.wards(10);
    final wardsForLga20 = await repo.wards(20);

    expect(wardsForLga10.map((w) => w.id), [100]);
    expect(wardsForLga20.map((w) => w.id), [200]);
  });
}
