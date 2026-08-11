import '../../core/utils/ids.dart';
import '../../models/seller_record.dart';
import '../../models/sync_status.dart';

class RegistrationDraft {
  String fullName = '';
  String? photoPath;
  String phone = '';
  String? nin;
  DateTime? dob;
  String? gender;
  String? homeAddress;

  String businessName = '';
  String businessCategory = '';
  String? shopNumber;
  int? stateId;
  String? stateName;
  int? lgaId;
  String? lgaName;
  int? wardId;
  String? wardName;
  int? marketId;
  String? marketName;

  double? lat;
  double? lng;
  double? gpsAccuracy;
  DateTime? gpsCapturedAt;

  bool get identityComplete =>
      fullName.trim().isNotEmpty &&
      photoPath != null &&
      phone.trim().isNotEmpty &&
      dob != null &&
      gender != null &&
      (nin == null || nin!.isEmpty || RegExp(r'^\d{11}$').hasMatch(nin!));

  bool get businessComplete =>
      businessName.trim().isNotEmpty &&
      businessCategory.trim().isNotEmpty &&
      stateId != null &&
      lgaId != null &&
      wardId != null &&
      marketId != null;

  bool get gpsComplete => lat != null && lng != null;

  SellerRecord toSellerRecord() {
    final now = nowIso();
    return SellerRecord(
      clientUuid: newClientUuid(),
      fullName: fullName.trim(),
      photoPath: photoPath,
      phone: phone.trim(),
      nin: (nin == null || nin!.isEmpty) ? null : nin,
      dob: dob!.toIso8601String().split('T').first,
      gender: gender!,
      homeAddress: (homeAddress == null || homeAddress!.trim().isEmpty) ? null : homeAddress!.trim(),
      businessName: businessName.trim(),
      businessCategory: businessCategory.trim(),
      shopNumber: (shopNumber == null || shopNumber!.trim().isEmpty) ? null : shopNumber!.trim(),
      marketId: marketId!,
      marketName: marketName,
      wardId: wardId!,
      wardName: wardName,
      lgaId: lgaId!,
      lgaName: lgaName,
      stateId: stateId!,
      stateName: stateName,
      lat: lat!,
      lng: lng!,
      gpsAccuracy: gpsAccuracy,
      gpsCapturedAt: gpsCapturedAt?.toUtc().toIso8601String(),
      qrPayload: null,
      status: SyncStatus.pendingSync,
      flagReason: null,
      origin: RecordOrigin.local,
      createdAt: now,
      updatedAt: now,
    );
  }
}
