import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../models/geo_node.dart';

/// Backs the State -> LGA -> Ward -> Market cascading pickers. Each level is
/// fetched once from the network and cached locally; subsequent lookups for
/// an already-cached parent id are served from SQLite so the pickers keep
/// working with zero connectivity after the first load, per the brief.
class GeoRepository {
  final Dio dio;
  final Database db;

  GeoRepository({required this.dio, required this.db});

  Future<List<GeoNode>> states({bool forceRefresh = false}) async {
    final cached = await _readCache('geo_states', where: null, whereArgs: null);
    if (cached.isNotEmpty && !forceRefresh) return cached;
    try {
      final response = await dio.get<List<dynamic>>('/geo/states');
      final nodes = _parseNodes(response.data);
      await _replaceCache('geo_states', nodes, extra: const {});
      return nodes;
    } on DioException {
      return cached;
    }
  }

  Future<List<GeoNode>> lgas(int stateId, {bool forceRefresh = false}) async {
    final cached = await _readCache('geo_lgas', where: 'state_id = ?', whereArgs: [stateId]);
    if (cached.isNotEmpty && !forceRefresh) return cached;
    try {
      final response =
          await dio.get<List<dynamic>>('/geo/lgas', queryParameters: {'state_id': stateId});
      final nodes = _parseNodes(response.data);
      await _replaceCache('geo_lgas', nodes,
          extra: {'state_id': stateId}, where: 'state_id = ?', whereArgs: [stateId]);
      return nodes;
    } on DioException {
      return cached;
    }
  }

  Future<List<GeoNode>> wards(int lgaId, {bool forceRefresh = false}) async {
    final cached = await _readCache('geo_wards', where: 'lga_id = ?', whereArgs: [lgaId]);
    if (cached.isNotEmpty && !forceRefresh) return cached;
    try {
      final response =
          await dio.get<List<dynamic>>('/geo/wards', queryParameters: {'lga_id': lgaId});
      final nodes = _parseNodes(response.data);
      await _replaceCache('geo_wards', nodes,
          extra: {'lga_id': lgaId}, where: 'lga_id = ?', whereArgs: [lgaId]);
      return nodes;
    } on DioException {
      return cached;
    }
  }

  Future<List<GeoNode>> markets(int wardId, {bool forceRefresh = false}) async {
    final cached = await _readCache('geo_markets', where: 'ward_id = ?', whereArgs: [wardId]);
    if (cached.isNotEmpty && !forceRefresh) return cached;
    try {
      final response =
          await dio.get<List<dynamic>>('/geo/markets', queryParameters: {'ward_id': wardId});
      final nodes = _parseNodes(response.data);
      await _replaceCache('geo_markets', nodes,
          extra: {'ward_id': wardId}, where: 'ward_id = ?', whereArgs: [wardId]);
      return nodes;
    } on DioException {
      return cached;
    }
  }

  List<GeoNode> _parseNodes(List<dynamic>? data) =>
      (data ?? []).map((e) => GeoNode.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<GeoNode>> _readCache(String table,
      {required String? where, required List<Object?>? whereArgs}) async {
    final rows = await db.query(table, where: where, whereArgs: whereArgs, orderBy: 'name ASC');
    return rows.map(GeoNode.fromJson).toList();
  }

  Future<void> _replaceCache(
    String table,
    List<GeoNode> nodes, {
    required Map<String, Object?> extra,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    await db.transaction((txn) async {
      await txn.delete(table, where: where, whereArgs: whereArgs);
      for (final node in nodes) {
        await txn.insert(
          table,
          {...node.toJson(), ...extra},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
