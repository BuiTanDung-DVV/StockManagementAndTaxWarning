import '../../../core/utils/payment_amount.dart';

String supplierPaymentAmount(String input) => parsePaymentAmount(input);

class SupplierPaymentResult {
  final Map<String, dynamic> data;
  SupplierPaymentResult.fromResponse(
    dynamic raw, {
    required int shopId,
    required String operationId,
    int? payableId,
  }) : data = _validate(raw, shopId, operationId, payableId);
  static Map<String, dynamic> _validate(
    dynamic raw,
    int shopId,
    String operationId,
    int? payableId,
  ) {
    if (raw is! Map ||
        raw['shopId'] != shopId ||
        raw['operationId'] != operationId ||
        (payableId != null && raw['payableId'] != payableId) ||
        raw['replayed'] is! bool ||
        ![
          'payableId',
          'supplierId',
          'paymentHistoryId',
          'cashTransactionId',
        ].every((key) => raw[key] is int && raw[key] > 0) ||
        !['amount', 'paidAmount', 'remaining'].every(
          (key) =>
              raw[key] is num && (raw[key] as num).isFinite && raw[key] >= 0,
        ) ||
        raw['openingAdjustmentAmount'] is! num ||
        !(raw['openingAdjustmentAmount'] as num).isFinite ||
        raw['amount'] <= 0 ||
        raw['paidAmount'] < raw['amount'] ||
        raw['paymentDate'] is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw['paymentDate'])) {
      throw const FormatException(
        'Kết quả ghi nhận chưa đầy đủ; cần kiểm tra lại',
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
