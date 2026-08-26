import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:revenue_agent_app/models/user.dart';
import 'package:revenue_agent_app/repositories/admin_repository.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late AdminRepository repo;

  setUp(() {
    dio = MockDio();
    repo = AdminRepository(dio: dio);
  });

  test('dashboardSummary parses totals, active agents, and flagged items', () async {
    when(() => dio.get<Map<String, dynamic>>('/dashboard/summary')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/dashboard/summary'),
        statusCode: 200,
        data: {
          'today_total_amount': 1500.0,
          'today_payment_count': 3,
          'active_agents': [
            {'agent_id': 1, 'name': 'Jane Agent', 'last_seen_at': null, 'today_total': 500.0},
          ],
          'pending_sync_count': 2,
          'flagged': [
            {'type': 'seller', 'id': 7, 'reason': 'duplicate_suspected'},
          ],
        },
      ),
    );

    final summary = await repo.dashboardSummary();

    expect(summary.todayTotalAmount, 1500.0);
    expect(summary.todayPaymentCount, 3);
    expect(summary.activeAgents, hasLength(1));
    expect(summary.activeAgents.first.name, 'Jane Agent');
    expect(summary.pendingSyncCount, 2);
    expect(summary.flagged.first.reason, 'duplicate_suspected');
  });

  test('listUsers parses the user list and never exposes password_hash (not present in the response)', () async {
    when(() => dio.get<List<dynamic>>('/admin/users')).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/admin/users'),
        statusCode: 200,
        data: [
          {
            'id': 1,
            'name': 'Jane Agent',
            'email': 'jane@example.com',
            'phone': null,
            'role': 'agent',
            'lga_id': 5,
            'device_id': null,
            'active': true,
          },
        ],
      ),
    );

    final users = await repo.listUsers();

    expect(users, hasLength(1));
    expect(users.first.role, UserRole.agent);
  });

  test('createUser posts the role by name and omits blank email/phone', () async {
    when(() => dio.post<Map<String, dynamic>>('/admin/users', data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/admin/users'),
        statusCode: 201,
        data: {
          'id': 2,
          'name': 'New Supervisor',
          'email': 'sup@example.com',
          'phone': null,
          'role': 'supervisor',
          'lga_id': 5,
          'device_id': null,
          'active': true,
        },
      ),
    );

    final user = await repo.createUser(
      name: 'New Supervisor',
      email: 'sup@example.com',
      phone: '',
      password: 'supersecret1',
      role: UserRole.supervisor,
      lgaId: 5,
    );

    expect(user.role, UserRole.supervisor);
    final captured = verify(() => dio.post<Map<String, dynamic>>('/admin/users', data: captureAny(named: 'data')))
        .captured
        .single as Map<String, dynamic>;
    expect(captured['role'], 'supervisor');
    expect(captured.containsKey('phone'), isFalse);
    expect(captured['email'], 'sup@example.com');
  });

  test('revenueReport formats the date range as plain yyyy-mm-dd query params', () async {
    when(() => dio.get<List<dynamic>>('/reports/revenue', queryParameters: any(named: 'queryParameters')))
        .thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/reports/revenue'),
        statusCode: 200,
        data: [
          {
            'id': 1,
            'receipt_no': 'RCT-IKJ-2026-000001',
            'seller_uid': 'LAG-IKJ-2026-000001',
            'business_name': 'Amaka Store',
            'levy_type_name': 'Daily Trading Levy',
            'amount': 500.0,
            'method': 'cash',
            'agent_name': 'Jane Agent',
            'paid_at': '2026-08-01T10:00:00Z',
          },
        ],
      ),
    );

    final rows = await repo.revenueReport(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 26));

    expect(rows, hasLength(1));
    expect(rows.first.businessName, 'Amaka Store');
    verify(() => dio.get<List<dynamic>>(
          '/reports/revenue',
          queryParameters: {'from': '2026-08-01', 'to': '2026-08-26'},
        )).called(1);
  });
}
