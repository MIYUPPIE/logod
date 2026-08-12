import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:revenue_agent_app/core/db/app_database.dart';

bool _ffiInitialized = false;

Future<AppDatabase> openTestDatabase() async {
  if (!_ffiInitialized) {
    sqfliteFfiInit();
    _ffiInitialized = true;
  }
  return AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
}
