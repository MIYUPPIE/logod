import 'package:revenue_agent_app/models/payment_method.dart';
import 'package:revenue_agent_app/models/payment_record.dart';
import 'package:revenue_agent_app/models/seller_record.dart';
import 'package:revenue_agent_app/models/sync_status.dart';

SellerRecord buildSeller({
  required String clientUuid,
  int? serverId,
  String? sellerUid,
  SyncStatus status = SyncStatus.pendingSync,
  String? flagReason,
  RecordOrigin origin = RecordOrigin.local,
  String fullName = 'Amaka Obi',
  String phone = '08012345678',
}) {
  const now = '2026-08-12T09:00:00.000Z';
  return SellerRecord(
    clientUuid: clientUuid,
    serverId: serverId,
    sellerUid: sellerUid,
    fullName: fullName,
    photoPath: null,
    phone: phone,
    nin: null,
    dob: '1990-01-01',
    gender: 'female',
    homeAddress: null,
    businessName: 'Amaka Provisions',
    businessCategory: 'Provisions',
    shopNumber: 'A12',
    marketId: 1,
    marketName: 'Central Market',
    wardId: 1,
    wardName: 'Ward 1',
    lgaId: 1,
    lgaName: 'Ikeja',
    stateId: 1,
    stateName: 'Lagos',
    lat: 6.5244,
    lng: 3.3792,
    gpsAccuracy: 12.0,
    gpsCapturedAt: now,
    qrPayload: null,
    status: status,
    flagReason: flagReason,
    origin: origin,
    createdAt: now,
    updatedAt: now,
  );
}

PaymentRecord buildPayment({
  required String clientUuid,
  required String sellerClientUuid,
  required int sellerServerId,
  int? serverId,
  String? receiptNo,
  SyncStatus status = SyncStatus.pendingSync,
  String? flagReason,
  double amount = 500.0,
}) {
  const now = '2026-08-12T09:05:00.000Z';
  return PaymentRecord(
    clientUuid: clientUuid,
    serverId: serverId,
    sellerClientUuid: sellerClientUuid,
    sellerServerId: sellerServerId,
    sellerDisplayName: 'Amaka Provisions',
    levyTypeId: 1,
    levyTypeName: 'Daily Trading Levy',
    amount: amount,
    method: PaymentMethod.cash,
    receiptNo: receiptNo,
    status: status,
    flagReason: flagReason,
    paidAt: now,
    syncedAt: null,
    createdAt: now,
  );
}
