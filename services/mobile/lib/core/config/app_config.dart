class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api/v1',
  );

  static const int syncBatchMaxItems = 200;
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const double gpsAccuracyWarningThresholdMeters = 50.0;
}
