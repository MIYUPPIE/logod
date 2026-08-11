import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../models/levy_type.dart';

class LevyTypeRepository {
  final Dio dio;
  final Database db;

  LevyTypeRepository({required this.dio, required this.db});

  Future<List<LevyType>> forLga(int lgaId, {bool forceRefresh = false}) async {
    final cached = await _readCache(lgaId);
    if (cached.isNotEmpty && !forceRefresh) return cached;
    try {
      final response =
          await dio.get<List<dynamic>>('/levy-types', queryParameters: {'lga_id': lgaId});
      final types = (response.data ?? [])
          .map((e) => LevyType.fromJson(e as Map<String, dynamic>))
          .toList();
      await db.transaction((txn) async {
        await txn.delete('levy_types', where: 'lga_id = ?', whereArgs: [lgaId]);
        for (final type in types) {
          await txn.insert('levy_types', type.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      return types;
    } on DioException {
      return cached;
    }
  }

  Future<List<LevyType>> _readCache(int lgaId) async {
    final rows = await db.query('levy_types', where: 'lga_id = ?', whereArgs: [lgaId], orderBy: 'name ASC');
    return rows.map(LevyType.fromDb).toList();
  }
}
