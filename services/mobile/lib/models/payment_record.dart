import 'payment_method.dart';
import 'sync_status.dart';

class PaymentRecord {
  final String clientUuid;
  final int? serverId;
  final String sellerClientUuid;
  final int sellerServerId;
  final String sellerDisplayName;
  final int levyTypeId;
  final String levyTypeName;
  final double amount;
  final PaymentMethod method;
  final String? receiptNo;
  final SyncStatus status;
  final String? flagReason;
  final String paidAt;
  final String? syncedAt;
  final String createdAt;

  const PaymentRecord({
    required this.clientUuid,
    this.serverId,
    required this.sellerClientUuid,
    required this.sellerServerId,
    required this.sellerDisplayName,
    required this.levyTypeId,
    required this.levyTypeName,
    required this.amount,
    required this.method,
    this.receiptNo,
    required this.status,
    this.flagReason,
    required this.paidAt,
    this.syncedAt,
    required this.createdAt,
  });

  PaymentRecord copyWith({
    int? serverId,
    String? receiptNo,
    SyncStatus? status,
    String? flagReason,
    String? syncedAt,
  }) =>
      PaymentRecord(
        clientUuid: clientUuid,
        serverId: serverId ?? this.serverId,
        sellerClientUuid: sellerClientUuid,
        sellerServerId: sellerServerId,
        sellerDisplayName: sellerDisplayName,
        levyTypeId: levyTypeId,
        levyTypeName: levyTypeName,
        amount: amount,
        method: method,
        receiptNo: receiptNo ?? this.receiptNo,
        status: status ?? this.status,
        flagReason: flagReason ?? this.flagReason,
        paidAt: paidAt,
        syncedAt: syncedAt ?? this.syncedAt,
        createdAt: createdAt,
      );

  factory PaymentRecord.fromDb(Map<String, dynamic> row) => PaymentRecord(
        clientUuid: row['client_uuid'] as String,
        serverId: row['server_id'] as int?,
        sellerClientUuid: row['seller_client_uuid'] as String,
        sellerServerId: row['seller_server_id'] as int,
        sellerDisplayName: row['seller_display_name'] as String,
        levyTypeId: row['levy_type_id'] as int,
        levyTypeName: row['levy_type_name'] as String,
        amount: (row['amount'] as num).toDouble(),
        method: PaymentMethod.fromDb(row['method'] as String),
        receiptNo: row['receipt_no'] as String?,
        status: SyncStatus.fromDb(row['status'] as String),
        flagReason: row['flag_reason'] as String?,
        paidAt: row['paid_at'] as String,
        syncedAt: row['synced_at'] as String?,
        createdAt: row['created_at'] as String,
      );

  Map<String, dynamic> toDb() => {
        'client_uuid': clientUuid,
        'server_id': serverId,
        'seller_client_uuid': sellerClientUuid,
        'seller_server_id': sellerServerId,
        'seller_display_name': sellerDisplayName,
        'levy_type_id': levyTypeId,
        'levy_type_name': levyTypeName,
        'amount': amount,
        'method': method.toDb(),
        'receipt_no': receiptNo,
        'status': status.toDb(),
        'flag_reason': flagReason,
        'paid_at': paidAt,
        'synced_at': syncedAt,
        'created_at': createdAt,
      };

  /// Matches components/schemas/PaymentCreateRequest. Amount is deliberately
  /// omitted: the contract has no amount field on this request because the
  /// server derives it from levy_type_id (matches the design doc's
  /// server-side amount enforcement) - the locally cached `amount` here is
  /// for on-device receipt display only, never sent to the server.
  Map<String, dynamic> toCreateRequestJson() => {
        'client_uuid': clientUuid,
        'seller_id': sellerServerId,
        'levy_type_id': levyTypeId,
        'method': method.toDb(),
        'paid_at': paidAt,
      };
}
