import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/network/auth_api.dart';
import 'package:revenue_agent_app/core/storage/token_storage.dart';
import 'package:revenue_agent_app/repositories/auth_repository.dart';

class MockDio extends Mock implements Dio {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

const _loginResponseJson = {
  'access_token': 'access-1',
  'refresh_token': 'refresh-1',
  'expires_in': 900,
  'user': {
    'id': 1,
    'name': 'Jane Agent',
    'email': 'jane@example.com',
    'phone': '08000000000',
    'role': 'agent',
    'lga_id': 5,
    'device_id': null,
    'active': true,
  },
};

void main() {
  late MockDio dio;
  late MockSecureStorage secureStorage;
  late TokenStorage tokenStorage;
  late AuthRepository repo;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    secureStorage = MockSecureStorage();
    when(() => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async {});
    when(() => secureStorage.delete(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async {});
    tokenStorage = TokenStorage(storage: secureStorage);
    repo = AuthRepository(authApi: AuthApi(dio), tokenStorage: tokenStorage);
  });

  test('login stores access token, refresh token, and user, and returns the user', () async {
    when(() => dio.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/login'),
              statusCode: 200,
              data: _loginResponseJson,
            ));

    final user = await repo.login(identifier: 'jane@example.com', password: 'secret');

    expect(user.name, 'Jane Agent');
    verify(() => secureStorage.write(
          key: 'access_token',
          value: 'access-1',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).called(1);
    verify(() => secureStorage.write(
          key: 'refresh_token',
          value: 'refresh-1',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).called(1);
  });

  test('isLoggedIn reflects whether an access token is stored', () async {
    when(() => secureStorage.read(
          key: 'access_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => null);
    expect(await repo.isLoggedIn(), isFalse);

    when(() => secureStorage.read(
          key: 'access_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => 'some-token');
    expect(await repo.isLoggedIn(), isTrue);
  });

  test('logout revokes the refresh token server-side then always clears local storage', () async {
    when(() => secureStorage.read(
          key: 'refresh_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => 'refresh-1');
    when(() => dio.post<void>('/auth/logout', data: any(named: 'data')))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/auth/logout'), statusCode: 204));

    await repo.logout();

    verify(() => secureStorage.delete(
          key: 'access_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).called(1);
  });

  test('logout still clears local storage even if the server call fails (agent offline)', () async {
    when(() => secureStorage.read(
          key: 'refresh_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => 'refresh-1');
    when(() => dio.post<void>('/auth/logout', data: any(named: 'data')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '/auth/logout'), type: DioExceptionType.connectionError));

    await repo.logout();

    verify(() => secureStorage.delete(
          key: 'access_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).called(1);
  });
}
