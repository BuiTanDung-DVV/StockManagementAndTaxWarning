import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void showInventoryMovementDetails(
  BuildContext context,
  Map<dynamic, dynamic> movement, {
  required String productName,
  required String unit,
  int? shopId,
}) {
  final referenceType = movement['referenceType']?.toString() ?? '';
  final referenceId = int.tryParse(movement['referenceId']?.toString() ?? '');
  final date = DateTime.tryParse(movement['createdAt']?.toString() ?? '');
  final route = referenceId == null
      ? null
      : switch (referenceType) {
          'SALES_ORDER' || 'SALES_ORDER_CANCEL' => '/sales/$referenceId',
          'PURCHASE_ORDER' =>
            '/purchase-orders/detail?id=$referenceId${shopId == null ? '' : '&shopId=$shopId'}',
          _ => null,
        };
  final fields = <String, String>{
    'Sản phẩm': productName,
    'Loại biến động': switch (movement['movementType']?.toString()) {
      'OUT' => 'Xuất kho',
      'IN' => 'Nhập kho',
      'ADJUSTMENT' => 'Điều chỉnh tồn kho',
      'RETURN' => 'Hoàn hàng về kho',
      _ => 'Biến động kho',
    },
    'Số lượng': '${movement['quantity'] ?? 0} $unit',
    if (date != null)
      'Thời gian': DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal()),
    'Kho':
        movement['warehouse']?['name']?.toString() ??
        'Kho #${movement['warehouseId'] ?? '—'}',
    if (movement['unitCost'] != null)
      'Giá vốn đơn vị': NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '₫',
        decimalDigits: 0,
      ).format(num.tryParse(movement['unitCost'].toString()) ?? 0),
    if (referenceType.isNotEmpty) 'Nguồn ghi nhận': referenceType,
    if (referenceId != null) 'Mã tham chiếu': '#$referenceId',
    if (movement['notes'] != null) 'Ghi chú': movement['notes'].toString(),
  };
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Chi tiết xuất nhập kho'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in fields.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('${field.key}: ${field.value}'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Đóng'),
        ),
        if (route != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push(route);
            },
            child: const Text('Xem chứng từ gốc'),
          ),
      ],
    ),
  );
}
