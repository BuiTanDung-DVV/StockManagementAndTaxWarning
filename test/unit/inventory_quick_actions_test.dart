import 'package:flutter_app/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory quick actions avoid orphaned buttons', () {
    expect(inventoryQuickActionColumnCount(1100, 4), 4);
    expect(inventoryQuickActionColumnCount(640, 4), 2);
    expect(inventoryQuickActionColumnCount(640, 3), 3);
    expect(inventoryQuickActionColumnCount(390, 4), 1);
  });
}
