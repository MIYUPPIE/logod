import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../models/payment_record.dart';
import '../models/sync_models.dart';
import 'payment_repository.dart';
import 'seller_repository.dart';

class SyncOutcome {
  final bool ranNetworkCall;
  final bool succeeded;
  final int attempted;
  final int synced;
  final int flagged;
  final String? errorMessage;

  const SyncOutcome({
    required this.ranNetworkCall,
    required this.succeeded,
    required this.attempted,
    required this.synced,
    required this.flagged,
    this.errorMessage,
  });

  static const empty =
      SyncOutcome(ranNetworkCall: false, succeeded: true, attempted: 0, synced: 0, flagged: 0);
}

/// Batches every locally `pending_sync` seller/payment row (cap 200 per
/// SyncBatchRequest.records.maxItems) and posts it to /sync/batch.
///
/// Idempotency (the highest-risk part of the app per the design doc): a
/// client_uuid is generated exactly once, at local-write time, and never
/// regenerated on retry - so if this method is called again after a failed
/// or never-answered POST, it rebuilds the batch from the same still-pending
/// rows with the same client_uuids. The server already treats a repeated
/// client_uuid as an idempotent no-op (contracts/openapi.yaml, SyncRecord).
/// On this side, a local row only ever leaves `pending_sync` via
/// [SellerRepository.applySyncResult] / [PaymentRepository.applySyncResult],
/// both of which are keyed UPDATEs on the client_uuid primary key - so
/// applying the same result twice (e.g. a response processed twice, or a
/// row that syncs then gets re-included in a batch built before the first
/// result was applied) converges to the same row instead of duplicating it,
/// and a row that already left `pending_sync` is never re-sent at all.
class SyncService {
  final Dio dio;
  final SellerRepository sellerRepository;
  final PaymentRepository paymentRepository;

  SyncService({
    required this.dio,
    required this.sellerRepository,
    required this.paymentRepository,
  });

  Future<SyncOutcome> syncPending() async {
    final pendingSellers =
        await sellerRepository.pendingSync(limit: AppConfig.syncBatchMaxItems);
    final remainingBudget = AppConfig.syncBatchMaxItems - pendingSellers.length;
    final List<PaymentRecord> pendingPayments = remainingBudget > 0
        ? await paymentRepository.pendingSync(limit: remainingBudget)
        : const <PaymentRecord>[];

    if (pendingSellers.isEmpty && pendingPayments.isEmpty) {
      return SyncOutcome.empty;
    }

    final recordTypeByUuid = <String, SyncRecordType>{};
    final records = <SyncRecord>[];

    for (final seller in pendingSellers) {
      final photoBase64 = await _readPhotoBase64(seller.photoPath);
      records.add(SyncRecord(
        type: SyncRecordType.seller,
        clientUuid: seller.clientUuid,
        payload: seller.toCreateRequestJson(photoBase64: photoBase64),
      ));
      recordTypeByUuid[seller.clientUuid] = SyncRecordType.seller;
    }
    for (final payment in pendingPayments) {
      records.add(SyncRecord(
        type: SyncRecordType.payment,
        clientUuid: payment.clientUuid,
        payload: payment.toCreateRequestJson(),
      ));
      recordTypeByUuid[payment.clientUuid] = SyncRecordType.payment;
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/sync/batch',
        data: {'records': records.map((r) => r.toJson()).toList()},
      );
      final results = (response.data?['results'] as List<dynamic>? ?? [])
          .map((e) => SyncResult.fromJson(e as Map<String, dynamic>))
          .toList();

      var synced = 0;
      var flagged = 0;
      for (final result in results) {
        final type = recordTypeByUuid[result.clientUuid];
        if (type == SyncRecordType.seller) {
          await sellerRepository.applySyncResult(result);
        } else if (type == SyncRecordType.payment) {
          await paymentRepository.applySyncResult(result);
        }
        if (result.status == SyncResultStatus.synced) {
          synced++;
        } else {
          flagged++;
        }
      }

      return SyncOutcome(
        ranNetworkCall: true,
        succeeded: true,
        attempted: records.length,
        synced: synced,
        flagged: flagged,
      );
    } on DioException catch (e) {
      return SyncOutcome(
        ranNetworkCall: true,
        succeeded: false,
        attempted: records.length,
        synced: 0,
        flagged: 0,
        errorMessage: e.message,
      );
    }
  }

  Future<String?> _readPhotoBase64(String? path) async {
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
