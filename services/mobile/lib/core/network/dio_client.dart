import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_interceptor.dart';

Dio buildDio({
  required TokenStorage tokenStorage,
  required Future<void> Function() onAuthFailure,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: 'application/json',
    ),
  );

  final authApi = AuthApi(dio);

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStorage: tokenStorage,
      refreshTokenFn: (refreshToken) => authApi.refresh(refreshToken: refreshToken),
      onAuthFailure: onAuthFailure,
    ),
  );

  return dio;
}
