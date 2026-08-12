import 'package:sqflite/sqflite.dart';

Future<void> seedGeoCache(Database db) async {
  await db.insert('geo_states', {'id': 1, 'name': 'Lagos', 'code': 'LAG'});
  await db.insert('geo_lgas', {'id': 1, 'state_id': 1, 'name': 'Ikeja', 'code': 'IKJ'});
  await db.insert('geo_wards', {'id': 1, 'lga_id': 1, 'name': 'Ward 1', 'code': null});
  await db.insert('geo_markets', {'id': 1, 'ward_id': 1, 'name': 'Central Market', 'code': null});
  await db.insert('levy_types', {
    'id': 1,
    'lga_id': 1,
    'name': 'Daily Trading Levy',
    'amount': 500.0,
    'frequency': 'daily',
  });
  await db.insert('levy_types', {
    'id': 2,
    'lga_id': 1,
    'name': 'Weekly Sanitation Levy',
    'amount': 1000.0,
    'frequency': 'weekly',
  });
}
