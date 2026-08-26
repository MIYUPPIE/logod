import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/network/auth_api.dart';
import 'package:revenue_agent_app/core/storage/token_storage.dart';
import 'package:revenue_agent_app/providers/auth_providers.dart';
import 'package:revenue_agent_app/repositories/auth_repository.dart';

/// This app is for Revenue Agents (field workflow) and Admins (field
/// workflow, unrestricted across LGAs, plus management screens) only;
/// Supervisors have the web dashboard instead. The backend's /auth/login
/// has no role restriction of its own - any active account can get a
/// token, since role is enforced per-endpoint, not at login - so this app
/// is the one place that has to say "wrong tool" for a disallowed role.
class MockDio extends Mock implements Dio {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

Map<String, dynamic> _loginResponseJson(String role) => {
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'expires_in': 900,
      'user': {
        'id': 1,
        'name': 'Test User',
        'email': 'user@example.com',
        'phone': null,
        'role': role,
        'lga_id': role == 'admin' ? null : 5,
        'device_id': null,
        'active': true,
      },
    };

void main() {
  late MockDio dio;
  late MockSecureStorage secureStorage;
  late ProviderContainer container;

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
    when(() => secureStorage.read(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => null);
    when(() => dio.post<void>('/auth/logout', data: any(named: 'data')))
        .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: '/auth/logout'), statusCode: 204));

    final tokenStorage = TokenStorage(storage: secureStorage);
    final repo = AuthRepository(authApi: AuthApi(dio), tokenStorage: tokenStorage);

    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
  });

  for (final role in ['agent', 'admin']) {
    test('a $role login succeeds and is retained', () async {
      when(() => dio.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/login'),
                statusCode: 200,
                data: _loginResponseJson(role),
              ));

      final controller = container.read(authControllerProvider.notifier);
      await controller.login(identifier: 'user@example.com', password: 'secret');

      final state = container.read(authControllerProvider);
      expect(state.isLoggedIn, isTrue);
      expect(state.errorMessage, isNull);
    });
  }

  test('a supervisor login is rejected with a clear message and clears local storage', () async {
    when(() => dio.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/login'),
              statusCode: 200,
              data: _loginResponseJson('supervisor'),
            ));

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(identifier: 'user@example.com', password: 'secret');

    final state = container.read(authControllerProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.errorMessage, contains('Agents and Admins only'));

    // The token was written by AuthRepository.login before the role was
    // known, then must have been torn down again by the rejection path.
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

  test('a stale disallowed-role session from before this check existed is logged out on bootstrap', () async {
    when(() => secureStorage.read(
          key: 'access_token',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async => 'stale-access-token');
    when(() => secureStorage.read(
          key: 'user_json',
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
          lOptions: any(named: 'lOptions'),
          webOptions: any(named: 'webOptions'),
          mOptions: any(named: 'mOptions'),
          wOptions: any(named: 'wOptions'),
        )).thenAnswer((_) async =>
            '{"id":1,"name":"Old Supervisor","email":"s@example.com","phone":null,"role":"supervisor","lga_id":5,"device_id":null,"active":true}');

    // AuthController._bootstrap runs from the constructor; read the
    // provider to trigger construction, then let the async bootstrap settle.
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(authControllerProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.errorMessage, contains('Agents and Admins only'));
  });
}
