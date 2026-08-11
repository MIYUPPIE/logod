import 'sync_status.dart';

class SellerRecord {
  final String clientUuid;
  final int? serverId;
  final String? sellerUid;
  final String fullName;
  final String? photoPath;
  final String phone;
  final String? nin;
  final String dob;
  final String gender;
  final String? homeAddress;
  final String businessName;
  final String businessCategory;
  final String? shopNumber;
  final int marketId;
  final String? marketName;
  final int wardId;
  final String? wardName;
  final int lgaId;
  final String? lgaName;
  final int stateId;
  final String? stateName;
  final double lat;
  final double lng;
  final double? gpsAccuracy;
  final String? gpsCapturedAt;
  final String? qrPayload;
  final SyncStatus status;
  final String? flagReason;
  final RecordOrigin origin;
  final String createdAt;
  final String updatedAt;

  const SellerRecord({
    required this.clientUuid,
    this.serverId,
    this.sellerUid,
    required this.fullName,
    this.photoPath,
    required this.phone,
    this.nin,
    required this.dob,
    required this.gender,
    this.homeAddress,
    required this.businessName,
    required this.businessCategory,
    this.shopNumber,
    required this.marketId,
    this.marketName,
    required this.wardId,
    this.wardName,
    required this.lgaId,
    this.lgaName,
    required this.stateId,
    this.stateName,
    required this.lat,
    required this.lng,
    this.gpsAccuracy,
    this.gpsCapturedAt,
    this.qrPayload,
    required this.status,
    this.flagReason,
    required this.origin,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSynced => status == SyncStatus.synced && serverId != null;

  String get displayId => sellerUid ?? 'LOCAL-${clientUuid.substring(0, 8).toUpperCase()}';

  SellerRecord copyWith({
    int? serverId,
    String? sellerUid,
    String? qrPayload,
    SyncStatus? status,
    String? flagReason,
    String? updatedAt,
  }) =>
      SellerRecord(
        clientUuid: clientUuid,
        serverId: serverId ?? this.serverId,
        sellerUid: sellerUid ?? this.sellerUid,
        fullName: fullName,
        photoPath: photoPath,
        phone: phone,
        nin: nin,
        dob: dob,
        gender: gender,
        homeAddress: homeAddress,
        businessName: businessName,
        businessCategory: businessCategory,
        shopNumber: shopNumber,
        marketId: marketId,
        marketName: marketName,
        wardId: wardId,
        wardName: wardName,
        lgaId: lgaId,
        lgaName: lgaName,
        stateId: stateId,
        stateName: stateName,
        lat: lat,
        lng: lng,
        gpsAccuracy: gpsAccuracy,
        gpsCapturedAt: gpsCapturedAt,
        qrPayload: qrPayload ?? this.qrPayload,
        status: status ?? this.status,
        flagReason: flagReason ?? this.flagReason,
        origin: origin,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory SellerRecord.fromDb(Map<String, dynamic> row) => SellerRecord(
        clientUuid: row['client_uuid'] as String,
        serverId: row['server_id'] as int?,
        sellerUid: row['seller_uid'] as String?,
        fullName: row['full_name'] as String,
        photoPath: row['photo_path'] as String?,
        phone: row['phone'] as String,
        nin: row['nin'] as String?,
        dob: row['dob'] as String,
        gender: row['gender'] as String,
        homeAddress: row['home_address'] as String?,
        businessName: row['business_name'] as String,
        businessCategory: row['business_category'] as String,
        shopNumber: row['shop_number'] as String?,
        marketId: row['market_id'] as int,
        marketName: row['market_name'] as String?,
        wardId: row['ward_id'] as int,
        wardName: row['ward_name'] as String?,
        lgaId: row['lga_id'] as int,
        lgaName: row['lga_name'] as String?,
        stateId: row['state_id'] as int,
        stateName: row['state_name'] as String?,
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        gpsAccuracy: (row['gps_accuracy'] as num?)?.toDouble(),
        gpsCapturedAt: row['gps_captured_at'] as String?,
        qrPayload: row['qr_payload'] as String?,
        status: SyncStatus.fromDb(row['status'] as String),
        flagReason: row['flag_reason'] as String?,
        origin: RecordOrigin.fromDb(row['origin'] as String),
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
      );

  Map<String, dynamic> toDb() => {
        'client_uuid': clientUuid,
        'server_id': serverId,
        'seller_uid': sellerUid,
        'full_name': fullName,
        'photo_path': photoPath,
        'phone': phone,
        'nin': nin,
        'dob': dob,
        'gender': gender,
        'home_address': homeAddress,
        'business_name': businessName,
        'business_category': businessCategory,
        'shop_number': shopNumber,
        'market_id': marketId,
        'market_name': marketName,
        'ward_id': wardId,
        'ward_name': wardName,
        'lga_id': lgaId,
        'lga_name': lgaName,
        'state_id': stateId,
        'state_name': stateName,
        'lat': lat,
        'lng': lng,
        'gps_accuracy': gpsAccuracy,
        'gps_captured_at': gpsCapturedAt,
        'qr_payload': qrPayload,
        'status': status.toDb(),
        'flag_reason': flagReason,
        'origin': origin.toDb(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Matches components/schemas/SellerCreateRequest in contracts/openapi.yaml.
  /// [photoBase64] is read from [photoPath] by the caller (file IO stays out
  /// of this model) since the contract accepts base64 for offline sync
  /// payloads (multipart is only mentioned in prose, not defined as a second
  /// requestBody content type, so the app always sends base64 JSON).
  Map<String, dynamic> toCreateRequestJson({String? photoBase64}) => {
        'client_uuid': clientUuid,
        'full_name': fullName,
        'photo_base64': photoBase64,
        'phone': phone,
        'nin': nin,
        'dob': dob,
        'gender': gender,
        'home_address': homeAddress,
        'business_name': businessName,
        'business_category': businessCategory,
        'shop_number': shopNumber,
        'market_id': marketId,
        'ward_id': wardId,
        'lga_id': lgaId,
        'state_id': stateId,
        'lat': lat,
        'lng': lng,
        'gps_accuracy': gpsAccuracy,
        'gps_captured_at': gpsCapturedAt,
      };

  /// Builds a cache row from a server `Seller` response (search / QR lookup),
  /// so a found seller stays usable for payments while offline afterwards.
  factory SellerRecord.fromApiJson(Map<String, dynamic> json, String nowIso) => SellerRecord(
        clientUuid: json['client_uuid'] as String,
        serverId: json['id'] as int?,
        sellerUid: json['seller_uid'] as String?,
        fullName: json['full_name'] as String,
        photoPath: null,
        phone: json['phone'] as String,
        nin: json['nin'] as String?,
        dob: json['dob'] as String,
        gender: json['gender'] as String,
        homeAddress: json['home_address'] as String?,
        businessName: json['business_name'] as String,
        businessCategory: json['business_category'] as String,
        shopNumber: json['shop_number'] as String?,
        marketId: json['market_id'] as int,
        marketName: null,
        wardId: json['ward_id'] as int,
        wardName: null,
        lgaId: json['lga_id'] as int,
        lgaName: null,
        stateId: json['state_id'] as int,
        stateName: null,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        gpsAccuracy: (json['gps_accuracy'] as num?)?.toDouble(),
        gpsCapturedAt: json['gps_captured_at'] as String?,
        qrPayload: json['qr_payload'] as String?,
        status: (json['duplicate_suspected'] as bool? ?? false)
            ? SyncStatus.duplicateSuspected
            : SyncStatus.synced,
        flagReason: null,
        origin: RecordOrigin.remoteCache,
        createdAt: json['created_at'] as String? ?? nowIso,
        updatedAt: nowIso,
      );
}
