import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';

/// Overridden in main() with the real, already-opened AppDatabase before
/// runApp so every dependent provider can stay a plain synchronous Provider
/// instead of an AsyncValue-wrapped FutureProvider chain.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be overridden in main()');
});
