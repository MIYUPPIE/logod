import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/auth_tokens.dart';
import '../storage/token_storage.dart';

typedef RefreshTokenFn = Future<AuthTokens> Function(String refreshToken);

/// Attaches `Authorization: Bearer <access_token>` to every request except
/// the public auth endpoints, and silently refreshes once on a 401 before
/// retrying the original request. Concurrent 401s share a single in-flight
/// refresh (via [_refreshCompleter]) so a burst of requests failing at once
/// does not fire N parallel refresh calls and rotate the refresh token N
/// times (the backend rotates refresh tokens on every use, so a second
/// concurrent refresh would invalidate the first one's new token).
class AuthInterceptor extends Interceptor {
  final Dio dio;
  final TokenStorage tokenStorage;
  final RefreshTokenFn refreshTokenFn;
  final Future<void> Function() onAuthFailure;

  AuthInterceptor({
    required this.dio,
    required this.tokenStorage,
    required this.refreshTokenFn,
    required this.onAuthFailure,
  });

  static const _publicPaths = ['/auth/login', '/auth/refresh'];

  Completer<bool>? _refreshCompleter;

  bool _isPublic(String path) => _publicPaths.any((p) => path.contains(p));

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isPublic(options.path)) {
      final token = await tokenStorage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final alreadyRetried = requestOptions.extra['auth_retried'] == true;

    if (err.response?.statusCode == 401 && !_isPublic(requestOptions.path) && !alreadyRetried) {
      final refreshed = await _refreshOnce();
      if (refreshed) {
        try {
          final newToken = await tokenStorage.readAccessToken();
          requestOptions.headers['Authorization'] = 'Bearer $newToken';
          requestOptions.extra['auth_retried'] = true;
          final response = await dio.fetch(requestOptions);
          return handler.resolve(response);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      } else {
        await onAuthFailure();
        return handler.next(err);
      }
    }
    handler.next(err);
  }

  Future<bool> _refreshOnce() {
    final existing = _refreshCompleter;
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<bool>();
    _refreshCompleter = completer;
    _doRefresh().then((result) {
      _refreshCompleter = null;
      completer.complete(result);
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      return false;
    }
    try {
      final tokens = await refreshTokenFn(refreshToken);
      await tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        userJson: jsonEncode(tokens.user.toJson()),
      );
      return true;
    } catch (_) {
      await tokenStorage.clear();
      return false;
    }
  }
}
