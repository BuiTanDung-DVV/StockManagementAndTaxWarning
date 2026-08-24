import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/inventory/presentation/purchase_order_detail_screen.dart',
  ).readAsStringSync();

  test('delete action is only visible for pending purchase orders', () {
    expect(source, contains("if (status == 'PENDING')"));
    expect(source, contains('Xóa đơn nhập đang chờ'));
  });
}
