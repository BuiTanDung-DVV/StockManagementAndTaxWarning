import 'dart:convert';
import 'offline_store.dart';
import 'offline_sync_engine.dart';

class OfflineSubmissionResult {
  final OfflineOperation operation;
  const OfflineSubmissionResult(this.operation);
  bool get confirmed => operation.status == 'confirmed';
  int? get entityId => confirmed
      ? ((operation.value['receipt'] as Map?)?['entityId'] as int?)
      : null;
}

class OfflineFormIdentity {
  String? _fingerprint;
  String? _id;
  String forPayload(Map<String, dynamic> payload) {
    final fingerprint = jsonEncode(payload);
    if (_fingerprint != fingerprint || _id == null) {
      _fingerprint = fingerprint;
      _id = newOperationId();
    }
    return _id!;
  }
}

/// Persist BEFORE the first network request, including when the user is online.
/// No fallback replay of an ambiguous request sent through a different API.
class OfflineSubmission {
  final OfflineStore store;
  final OfflineSyncEngine engine;
  final bool Function(OfflineScope scope) isCurrentScope;
  const OfflineSubmission({
    required this.store,
    required this.engine,
    required this.isCurrentScope,
  });

  Future<OfflineSubmissionResult> save(
    OfflineScope scope,
    String kind,
    Map<String, dynamic> payload, {
    String? operationId,
    String? draftId,
    bool sendNow = true,
  }) async {
    if (!isCurrentScope(scope)) {
      throw StateError(
        'Cửa hàng hoặc tài khoản đã thay đổi. Chưa gửi chứng từ.',
      );
    }
    final saved = await store.enqueue(
      scope,
      kind,
      payload,
      operationId: operationId,
      draftId: draftId,
    );
    if (sendNow &&
        saved.status != 'confirmed' &&
        saved.status != 'sending' &&
        saved.status != 'reviewRequired') {
      await store.retry(scope, saved.id);
    }
    // A sync error must not erase or re-key an already durable operation.
    if (sendNow && isCurrentScope(scope)) {
      await engine.sync(scope, manual: true);
    }
    final current = await store.operation(scope, saved.id);
    return OfflineSubmissionResult(current ?? saved);
  }
}

Map<String, dynamic> offlineSalesPayload(
  Map<String, dynamic> payload,
  String today,
) {
  const fields = {
    'orderDate',
    'customerId',
    'shippingCarrierId',
    'shippingFee',
    'shippingTaxRate',
    'shippingFeePayer',
    'trackingCode',
    'items',
    'discountAmount',
    'paidAmount',
    'settleInFull',
    'paymentMethod',
    'notes',
    'invoiceNumber',
    'qrPaymentRef',
  };
  return {
    for (final entry in payload.entries)
      if (fields.contains(entry.key)) entry.key: entry.value,
    'orderDate': (payload['orderDate']?.toString() ?? today).substring(0, 10),
  };
}

Map<String, dynamic> offlinePurchasePayload(Map<String, dynamic> payload) => {
  ...payload,
  'orderDate': payload['orderDate'].toString().substring(0, 10),
};
