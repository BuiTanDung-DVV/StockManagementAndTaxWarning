import 'package:flutter_app/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory quick actions avoid orphaned buttons', () {
    expect(inventoryQuickActionColumnCount(1100, 4), 4);
    expect(inventoryQuickActionColumnCount(640, 4), 2);
    expect(inventoryQuickActionColumnCount(640, 3), 3);
    expect(inventoryQuickActionColumnCount(390, 4), 1);
  });

  test('inventory KPI uses server total instead of first page length', () {
    expect(
      inventoryProductTotal({
        'items': List.generate(20, (index) => {'id': index + 1}),
        'total': 250,
      }),
      250,
    );
    expect(
      inventoryProductTotal({
        'items': List.generate(7, (index) => {'id': index + 1}),
      }),
      7,
    );
  });
}
