import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/core/network/auth_interceptor.dart';
import 'package:revenue_agent_app/core/storage/token_storage.dart';
import 'package:revenue_agent_app/models/auth_tokens.dart';
import 'package:revenue_agent_app/models/user.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

AuthTokens _tokens(String suffix) => AuthTokens(
      accessToken: 'access-$suffix',
      refreshToken: 'refresh-$suffix',
      expiresIn: 900,
      user: const AppUser(id: 1, name: 'Jane', role: UserRole.agent, active: true),
    );

void main() {
  late MockTokenStorage tokenStorage;
  late Dio dio;
  late int refreshCallCount;
  late bool authFailureCalled;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    tokenStorage = MockTokenStorage();
    refreshCallCount = 0;
    authFailureCalled = false;
    when(() => tokenStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userJson: any(named: 'userJson'),
        )).thenAnswer((_) async {});
    when(() => tokenStorage.clear()).thenAnswer((_) async {});

    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _StubAdapter();
  });

  Dio buildDioWithInterceptor({
    required RefreshTokenFn refreshTokenFn,
  }) {
    dio.interceptors.clear();
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      tokenStorage: tokenStorage,
      refreshTokenFn: refreshTokenFn,
      onAuthFailure: () async {
        authFailureCalled = true;
      },
    ));
    return dio;
  }

  test('attaches Authorization header from storage for a normal request', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'stored-access-token');
    buildDioWithInterceptor(refreshTokenFn: (_) async => _tokens('unused'));

    final response = await dio.get<Map<String, dynamic>>('/sellers/1');

    expect((response.requestOptions.headers['Authorization']), 'Bearer stored-access-token');
  });

  test('does not attach a header for the public /auth/login path', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'stored-access-token');
    buildDioWithInterceptor(refreshTokenFn: (_) async => _tokens('unused'));

    final response = await dio.post<Map<String, dynamic>>('/auth/login', data: {});

    expect(response.requestOptions.headers.containsKey('Authorization'), isFalse);
  });

  test('on a 401, refreshes once and retries the original request with the new token', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'expired-access-token');
    when(() => tokenStorage.readRefreshToken()).thenAnswer((_) async => 'valid-refresh-token');

    buildDioWithInterceptor(refreshTokenFn: (refreshToken) async {
      refreshCallCount++;
      return _tokens('new');
    });
    (dio.httpClientAdapter as _StubAdapter).failFirstAttemptWith401 = true;

    final response = await dio.get<Map<String, dynamic>>('/sellers/1');

    expect(response.statusCode, 200);
    expect(refreshCallCount, 1);
    expect(authFailureCalled, isFalse);
  });

  test('concurrent 401s share a single in-flight refresh (no double token rotation)', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'expired-access-token');
    when(() => tokenStorage.readRefreshToken()).thenAnswer((_) async => 'valid-refresh-token');

    buildDioWithInterceptor(refreshTokenFn: (refreshToken) async {
      refreshCallCount++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return _tokens('new');
    });
    (dio.httpClientAdapter as _StubAdapter).failFirstAttemptWith401 = true;

    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/sellers/1'),
      dio.get<Map<String, dynamic>>('/sellers/2'),
      dio.get<Map<String, dynamic>>('/sellers/3'),
    ]);

    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(refreshCallCount, 1);
  });

  test('when refresh itself fails, clears tokens, calls onAuthFailure, and surfaces the 401', () async {
    when(() => tokenStorage.readAccessToken()).thenAnswer((_) async => 'expired-access-token');
    when(() => tokenStorage.readRefreshToken()).thenAnswer((_) async => 'stale-refresh-token');

    buildDioWithInterceptor(refreshTokenFn: (refreshToken) async {
      refreshCallCount++;
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        response: Response(requestOptions: RequestOptions(path: '/auth/refresh'), statusCode: 401),
      );
    });
    (dio.httpClientAdapter as _StubAdapter).failFirstAttemptWith401 = true;
    (dio.httpClientAdapter as _StubAdapter).alwaysFail401 = true;

    await expectLater(
      dio.get<Map<String, dynamic>>('/sellers/1'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCallCount, 1);
    expect(authFailureCalled, isTrue);
    verify(() => tokenStorage.clear()).called(1);
  });
}

/// A minimal fake HttpClientAdapter: the first request to each unique path
/// returns 401 (when [failFirstAttemptWith401] is set), and any retried
/// request (marked via RequestOptions.extra['auth_retried']) returns 200 -
/// unless [alwaysFail401] is set, simulating a refresh that does not help.
class _StubAdapter implements HttpClientAdapter {
  bool failFirstAttemptWith401 = false;
  bool alwaysFail401 = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isRetried = options.extra['auth_retried'] == true;
    final shouldFail = failFirstAttemptWith401 && (alwaysFail401 || !isRetried);

    if (shouldFail) {
      return ResponseBody.fromString('{"errors":{"detail":"unauthorized"}}', 401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
    }
    return ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}
