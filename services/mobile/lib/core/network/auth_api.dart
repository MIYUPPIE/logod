import 'package:dio/dio.dart';

import '../../models/auth_tokens.dart';

/// Thin wrappers around the /auth endpoints in contracts/openapi.yaml.
/// Kept free of token-storage/state concerns so both AuthRepository and
/// AuthInterceptor (which must refresh without depending on the repository,
/// to avoid a construction cycle) can call the same request logic.
class AuthApi {
  final Dio dio;

  const AuthApi(this.dio);

  Future<AuthTokens> login({required String identifier, required String password}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'identifier': identifier, 'password': password},
    );
    return AuthTokens.fromJson(response.data!);
  }

  Future<AuthTokens> refresh({required String refreshToken}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    return AuthTokens.fromJson(response.data!);
  }

  Future<void> logout({required String refreshToken}) async {
    await dio.post<void>('/auth/logout', data: {'refresh_token': refreshToken});
  }
}
