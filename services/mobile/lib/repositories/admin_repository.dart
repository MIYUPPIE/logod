import 'package:dio/dio.dart';

import '../models/dashboard_summary.dart';
import '../models/revenue_report_row.dart';
import '../models/user.dart';

/// Admin/supervisor management endpoints - dashboard, user provisioning,
/// revenue reports. Unlike the field-agent repositories (Seller, Payment,
/// LevyType), this is online-only: management screens aren't part of the
/// offline-first design (that's specifically the field workflow's problem
/// to solve), so there's no local cache/fallback here, matching the web
/// admin panel's own assumption that admin work happens with connectivity.
class AdminRepository {
  final Dio dio;

  AdminRepository({required this.dio});

  Future<DashboardSummary> dashboardSummary() async {
    final response = await dio.get<Map<String, dynamic>>('/dashboard/summary');
    return DashboardSummary.fromJson(response.data!);
  }

  Future<List<AppUser>> listUsers() async {
    final response = await dio.get<List<dynamic>>('/admin/users');
    return (response.data ?? [])
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> createUser({
    required String name,
    String? email,
    String? phone,
    required String password,
    required UserRole role,
    int? lgaId,
  }) async {
    final response = await dio.post<Map<String, dynamic>>('/admin/users', data: {
      'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
      'role': role.name,
      'lga_id': ?lgaId,
    });
    return AppUser.fromJson(response.data!);
  }

  Future<List<RevenueReportRow>> revenueReport({required DateTime from, required DateTime to}) async {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final response = await dio.get<List<dynamic>>('/reports/revenue', queryParameters: {
      'from': iso(from),
      'to': iso(to),
    });
    return (response.data ?? [])
        .map((e) => RevenueReportRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
