import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SalesPaymentRecovery {
  final int shopId, orderId;
  final String actorId, operationId;
  final DateTime createdAt;
  const SalesPaymentRecovery({
    required this.shopId,
    required this.orderId,
    required this.actorId,
    required this.operationId,
    required this.createdAt,
  });
  String get key =>
      'sales_payment_recovery_v1_${actorId}_${shopId}_$operationId';
  void _validate() {
    if (shopId <= 0 ||
        orderId <= 0 ||
        !RegExp(r'^[1-9]\d*$').hasMatch(actorId) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(operationId)) {
      throw const FormatException('Thông tin tra cứu không hợp lệ');
    }
  }

  Future<void> save() async {
    _validate();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      key,
      jsonEncode({
        'shopId': shopId,
        'orderId': orderId,
        'actorId': actorId,
        'operationId': operationId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      }),
    )) {
      throw StateError('Chưa lưu được mã tra cứu');
    }
  }

  static Future<List<SalesPaymentRecovery>> pending({
    required int shopId,
    required int orderId,
    required String actorId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final rows = <SalesPaymentRecovery>[];
    for (final key in prefs.getKeys().where(
      (key) =>
          key.startsWith('sales_payment_recovery_v1_${actorId}_${shopId}_'),
    )) {
      final raw = jsonDecode(prefs.getString(key) ?? '');
      if (raw is! Map ||
          raw['shopId'] != shopId ||
          raw['actorId'] != actorId ||
          raw['orderId'] is! int ||
          raw['operationId'] is! String ||
          raw['createdAt'] is! String) {
        throw const FormatException('Mã tra cứu trên thiết bị chưa đọc được');
      }
      final row = SalesPaymentRecovery(
        shopId: shopId,
        orderId: raw['orderId'],
        actorId: actorId,
        operationId: raw['operationId'],
        createdAt: DateTime.parse(raw['createdAt']),
      );
      row._validate();
      if (row.key != key) throw const FormatException('Mã tra cứu không khớp');
      if (row.orderId == orderId) rows.add(row);
    }
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return rows;
  }

  static Future<void> resolve({
    required int shopId,
    required String actorId,
    required String operationId,
  }) async {
    SalesPaymentRecovery(
      shopId: shopId,
      orderId: 1,
      actorId: actorId,
      operationId: operationId,
      createdAt: DateTime.now(),
    )._validate();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(
      'sales_payment_recovery_v1_${actorId}_${shopId}_$operationId',
    )) {
      throw StateError('Chưa xóa được mã đã đối chiếu');
    }
  }
}
