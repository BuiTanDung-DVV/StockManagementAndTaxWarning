class SalesPaymentResult {
  final Map<String, dynamic> data;
  SalesPaymentResult.fromResponse(
    dynamic raw, {
    required int shopId,
    required int orderId,
    required String operationId,
  }) : data = _validate(raw, shopId, orderId, operationId);
  static Map<String, dynamic> _validate(
    dynamic raw,
    int shopId,
    int orderId,
    String operationId,
  ) {
    if (raw is! Map ||
        raw['shopId'] != shopId ||
        raw['orderId'] != orderId ||
        raw['operationId'] != operationId ||
        raw['order'] is! Map ||
        raw['order']['id'] != orderId ||
        raw['order']['shopId'] != shopId ||
        raw['replayed'] is! bool ||
        ![
          'id',
          'customerId',
          'receivableId',
          'paymentHistoryId',
          'cashTransactionId',
        ].every((key) => raw[key] is int && raw[key] > 0) ||
        ![
          'amount',
          'orderPaidAmount',
          'receivablePaidAmount',
          'remainingAmount',
        ].every(
          (key) =>
              raw[key] is num && (raw[key] as num).isFinite && raw[key] >= 0,
        ) ||
        raw['amount'] <= 0 ||
        raw['orderPaidAmount'] < raw['amount'] ||
        raw['receivablePaidAmount'] < raw['amount'] ||
        raw['openingAdjustmentAmount'] is! num ||
        !(raw['openingAdjustmentAmount'] as num).isFinite ||
        raw['method'] is! String ||
        ![
          'CASH',
          'TRANSFER',
          'BANK_TRANSFER',
          'MOMO',
          'ZALOPAY',
          'QR',
          'CARD',
          'CREDIT_CARD',
        ].contains(raw['method']) ||
        raw['paymentDate'] is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw['paymentDate'])) {
      throw const FormatException(
        'Kết quả thu tiền chưa đầy đủ; cần kiểm tra lại',
      );
    }
    if (DateTime.tryParse(
          raw['paymentDate'],
        )?.toIso8601String().substring(0, 10) !=
        raw['paymentDate']) {
      throw const FormatException('Ngày trong biên nhận không hợp lệ');
    }
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(raw));
  }
}
