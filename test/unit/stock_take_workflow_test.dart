import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final formSource = File(
    'lib/features/inventory/presentation/stock_take_form_screen.dart',
  ).readAsStringSync();
  final historySource = File(
    'lib/features/inventory/presentation/stock_take_history_screen.dart',
  ).readAsStringSync();

  test('stock take form sends actual counts and explains draft behavior', () {
    expect(formSource, contains("'actualQty': i.actualQty"));
    expect(formSource, isNot(contains("'systemQty': i.systemQty")));
    expect(
      formSource,
      contains('Tồn kho chỉ thay đổi sau khi phiếu được hoàn tất'),
    );
    expect(formSource, contains('stockProvider(_warehouseId)'));
    expect(formSource, contains('selectedProductIds.toSet().length'));
  });

  test('stock take history exposes complete and cancel actions for drafts', () {
    expect(historySource, contains("updateStockTakeStatus(id, 'COMPLETED')"));
    expect(historySource, contains("updateStockTakeStatus(id, 'CANCELLED')"));
    expect(historySource, contains('if (isDraft)'));
    expect(historySource, contains("st['stockTakeCode']"));
    expect(historySource, contains("st['stockTakeDate']"));
    expect(historySource, contains('differenceCount'));
  });
}
