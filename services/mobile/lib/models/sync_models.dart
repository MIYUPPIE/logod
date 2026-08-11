enum SyncRecordType { seller, payment;

  String toJson() => name;
}

class SyncRecord {
  final SyncRecordType type;
  final String clientUuid;
  final Map<String, dynamic> payload;

  const SyncRecord({required this.type, required this.clientUuid, required this.payload});

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'client_uuid': clientUuid,
        'payload': payload,
      };
}

enum SyncResultStatus { synced, flagged, error;

  static SyncResultStatus fromJson(String value) => switch (value) {
        'synced' => SyncResultStatus.synced,
        'flagged' => SyncResultStatus.flagged,
        _ => SyncResultStatus.error,
      };
}

class SyncResult {
  final String clientUuid;
  final SyncResultStatus status;
  final int? canonicalId;
  final String? sellerUid;
  final String? receiptNo;
  final String? reason;

  const SyncResult({
    required this.clientUuid,
    required this.status,
    this.canonicalId,
    this.sellerUid,
    this.receiptNo,
    this.reason,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
        clientUuid: json['client_uuid'] as String,
        status: SyncResultStatus.fromJson(json['status'] as String),
        canonicalId: json['canonical_id'] as int?,
        sellerUid: json['seller_uid'] as String?,
        receiptNo: json['receipt_no'] as String?,
        reason: json['reason'] as String?,
      );
}
