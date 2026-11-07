import '../../../core/utils/payment_amount.dart';

String openingBalanceAmount(String input) {
  final value = input.trim().replaceAll(' ', '');
  if (RegExp(r'^0+(?:[.,]0{1,2})?$').hasMatch(value)) return '0.00';
  return parsePaymentAmount(value);
}

int openingBalanceQuantity(String input) {
  if (!RegExp(r'^\d+$').hasMatch(input.trim())) {
    throw const FormatException('Số lượng phải là số nguyên không âm');
  }
  final value = int.tryParse(input.trim());
  if (value == null || value > 2147483647) {
    throw const FormatException('Số lượng vượt giới hạn');
  }
  return value;
}

Map<String, dynamic> openingMap(dynamic value) {
  if (value is! Map) {
    throw const FormatException('Dữ liệu đối chiếu không hợp lệ');
  }
  return Map<String, dynamic>.from(value);
}

class OpeningSnapshot {
  final Map<String, dynamic> data;
  OpeningSnapshot.fromResponse(dynamic raw, int shopId, String day)
    : data = openingMap(raw) {
    if (data['shopId'] != shopId ||
        data['asOf'] != day ||
        !_hash(data['revision']) ||
        data['storageReady'] is! bool ||
        data['rows'] is! List ||
        data['labels'] is! Map ||
        data['gaps'] is! List ||
        (data['gaps'] as List).any((item) => item is! String)) {
      throw const FormatException(
        'Kết quả đối chiếu không khớp cửa hàng hoặc ngày',
      );
    }
    final keys = <String>{};
    for (final row in rows) {
      final kind = row['kind'];
      if (row['key'] is! String ||
          !keys.add(row['key']) ||
          !['CASH', 'BANK', 'STOCK', 'RECEIVABLE', 'PAYABLE'].contains(kind) ||
          (kind == 'STOCK'
              ? row['quantity'] is! int
              : row['amount'] is! String)) {
        throw const FormatException('Dòng đối chiếu không hợp lệ');
      }
    }
  }
  String get revision => data['revision'];
  bool get storageReady => data['storageReady'];
  List<Map<String, dynamic>> get rows =>
      (data['rows'] as List).map(openingMap).toList();
  String label(String key) => data['labels'][key]?.toString() ?? key;
  List<Map<String, dynamic>> get sourceCandidates =>
      ((data['sourceCandidates'] ?? []) as List).map(openingMap).toList();
}

class OpeningPreview {
  final Map<String, dynamic> plan;
  OpeningPreview.fromResponse(
    dynamic raw,
    int shopId,
    String day,
    String revision,
  ) : plan = openingMap(openingMap(raw)['plan']) {
    if (plan['shopId'] != shopId ||
        plan['asOf'] != day ||
        plan['revision'] != revision ||
        !_hash(plan['planHash']) ||
        plan['canCommit'] is! bool ||
        plan['blockers'] is! List ||
        plan['rows'] is! List ||
        plan['totals'] is! Map ||
        (plan['blockers'] as List).any((item) => item is! String)) {
      throw const FormatException(
        'Kết quả xem trước không khớp lượt đối chiếu',
      );
    }
  }
  bool get canCommit => plan['canCommit'];
  String get planHash => plan['planHash'];
  List<String> get blockers => List<String>.from(plan['blockers']);
}

class OpeningReceipt {
  final Map<String, dynamic> data;
  OpeningReceipt.fromResponse(dynamic raw, int shopId, String operationId)
    : data = openingMap(raw) {
    final plan = openingMap(data['plan']);
    if (data['batchId'] is! int ||
        data['batchId'] <= 0 ||
        data['operationId'] != operationId ||
        plan['shopId'] != shopId ||
        data['actorId'] is! int ||
        data['committedAt'] is! String ||
        plan['rows'] is! List ||
        !_hash(plan['planHash'])) {
      throw const FormatException(
        'Biên nhận không khớp lượt ghi hoặc cửa hàng',
      );
    }
  }
  int get batchId => data['batchId'];
  String get operationId => data['operationId'];
  Map<String, dynamic> get plan => openingMap(data['plan']);
}

bool _hash(dynamic value) =>
    value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
