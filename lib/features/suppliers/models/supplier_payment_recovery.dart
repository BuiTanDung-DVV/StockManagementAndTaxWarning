import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Recovery identifiers only. Never stores money, credentials, or queued writes.
class SupplierPaymentRecovery {
  final int shopId, supplierId, payableId;
  final String actorId, operationId;
  final DateTime createdAt;
  const SupplierPaymentRecovery({
    required this.shopId,
    required this.supplierId,
    required this.payableId,
    required this.actorId,
    required this.operationId,
    required this.createdAt,
  });
  String get key =>
      'supplier_payment_recovery_v1_${actorId}_${shopId}_$operationId';
  void _validate() {
    if (shopId <= 0 ||
        supplierId <= 0 ||
        payableId <= 0 ||
        !RegExp(r'^[1-9]\d*$').hasMatch(actorId) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(operationId)) {
      throw const FormatException('Thông tin tra cứu không hợp lệ');
    }
  }

  Future<void> save() async {
    _validate();
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      key,
      jsonEncode({
        'shopId': shopId,
        'supplierId': supplierId,
        'payableId': payableId,
        'actorId': actorId,
        'operationId': operationId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      }),
    );
    if (!saved) throw StateError('Chưa lưu được mã tra cứu');
  }

  static Future<List<SupplierPaymentRecovery>> pending({
    required int shopId,
    required String actorId,
    required int supplierId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final prefix = 'supplier_payment_recovery_v1_${actorId}_${shopId}_';
    final entries = <SupplierPaymentRecovery>[];
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final raw = jsonDecode(prefs.getString(key) ?? '');
      if (raw is! Map ||
          raw['shopId'] != shopId ||
          raw['actorId'] != actorId ||
          raw['supplierId'] is! int ||
          raw['payableId'] is! int ||
          raw['operationId'] is! String ||
          raw['createdAt'] is! String) {
        throw const FormatException('Mã tra cứu trên thiết bị chưa đọc được');
      }
      final entry = SupplierPaymentRecovery(
        shopId: shopId,
        actorId: actorId,
        supplierId: raw['supplierId'],
        payableId: raw['payableId'],
        operationId: raw['operationId'],
        createdAt: DateTime.parse(raw['createdAt']),
      );
      entry._validate();
      if (entry.key != key) {
        throw const FormatException('Mã tra cứu không khớp');
      }
      if (entry.supplierId == supplierId) entries.add(entry);
    }
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  static Future<void> resolve({
    required int shopId,
    required String actorId,
    required String operationId,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(operationId) ||
        !RegExp(r'^[1-9]\d*$').hasMatch(actorId) ||
        shopId <= 0) {
      throw const FormatException('Thông tin tra cứu không hợp lệ');
    }
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(
      'supplier_payment_recovery_v1_${actorId}_${shopId}_$operationId',
    );
    if (!removed) throw StateError('Chưa xóa được mã đã đối chiếu');
  }
}
