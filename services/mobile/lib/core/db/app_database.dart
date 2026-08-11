import 'package:sqflite/sqflite.dart';

class AppDatabase {
  final Database db;

  const AppDatabase._(this.db);

  static const int schemaVersion = 1;

  /// [factory] and [path] are injectable so widget/unit tests can swap in
  /// sqflite_common_ffi with an in-memory path instead of the real platform
  /// channel (which does not exist in the `flutter test` VM).
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String path = 'revenue_agent_app.db',
  }) async {
    factory ??= databaseFactory;
    final resolvedPath =
        path == inMemoryDatabasePath ? path : await _resolvePath(factory, path);
    final db = await factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<String> _resolvePath(DatabaseFactory factory, String fileName) async {
    final dir = await factory.getDatabasesPath();
    return '$dir/$fileName';
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE sellers (
        client_uuid TEXT PRIMARY KEY,
        server_id INTEGER,
        seller_uid TEXT,
        full_name TEXT NOT NULL,
        photo_path TEXT,
        phone TEXT NOT NULL,
        nin TEXT,
        dob TEXT NOT NULL,
        gender TEXT NOT NULL,
        home_address TEXT,
        business_name TEXT NOT NULL,
        business_category TEXT NOT NULL,
        shop_number TEXT,
        market_id INTEGER NOT NULL,
        market_name TEXT,
        ward_id INTEGER NOT NULL,
        ward_name TEXT,
        lga_id INTEGER NOT NULL,
        lga_name TEXT,
        state_id INTEGER NOT NULL,
        state_name TEXT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        gps_accuracy REAL,
        gps_captured_at TEXT,
        qr_payload TEXT,
        status TEXT NOT NULL,
        flag_reason TEXT,
        origin TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_sellers_status ON sellers(status)');
    await db.execute('CREATE INDEX idx_sellers_phone ON sellers(phone)');
    await db.execute('CREATE INDEX idx_sellers_seller_uid ON sellers(seller_uid)');

    await db.execute('''
      CREATE TABLE payments (
        client_uuid TEXT PRIMARY KEY,
        server_id INTEGER,
        seller_client_uuid TEXT NOT NULL,
        seller_server_id INTEGER NOT NULL,
        seller_display_name TEXT NOT NULL,
        levy_type_id INTEGER NOT NULL,
        levy_type_name TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        receipt_no TEXT,
        status TEXT NOT NULL,
        flag_reason TEXT,
        paid_at TEXT NOT NULL,
        synced_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_payments_status ON payments(status)');
    await db.execute(
        'CREATE INDEX idx_payments_seller ON payments(seller_client_uuid)');

    await db.execute('''
      CREATE TABLE geo_states (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE geo_lgas (
        id INTEGER PRIMARY KEY,
        state_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_geo_lgas_state ON geo_lgas(state_id)');
    await db.execute('''
      CREATE TABLE geo_wards (
        id INTEGER PRIMARY KEY,
        lga_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_geo_wards_lga ON geo_wards(lga_id)');
    await db.execute('''
      CREATE TABLE geo_markets (
        id INTEGER PRIMARY KEY,
        ward_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        code TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_geo_markets_ward ON geo_markets(ward_id)');

    await db.execute('''
      CREATE TABLE levy_types (
        id INTEGER PRIMARY KEY,
        lga_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_levy_types_lga ON levy_types(lga_id)');
  }

  Future<void> close() => db.close();
}
