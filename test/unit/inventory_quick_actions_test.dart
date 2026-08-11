import 'package:flutter_app/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
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

  test('inventory category totals use comparable value and SKU count', () {
    final totals = inventoryCategoryTotals([
      {'name': 'Phân bón', 'value': 12500000, 'skuCount': 18},
      {'name': 'Thiết bị phòng tắm', 'value': 8600000, 'skuCount': 12},
      {'name': 'Dòng dữ liệu cũ', 'value': null, 'skuCount': null},
    ]);

    expect(totals.totalValue, 21100000);
    expect(totals.totalSkuCount, 30);
  });

  test('all-shops scope stays read-only for inventory actions', () {
    const aggregate = ShopState(
      isAllShops: true,
      status: 'ACTIVE',
      userShops: [
        {
          'shopId': 1,
          'memberType': 'OWNER',
          'status': 'ACTIVE',
          'isActive': true,
        },
      ],
      isLoading: false,
    );

    expect(aggregate.hasPermission('inventory', 'edit'), isFalse);
    expect(aggregate.hasPermission('products', 'edit'), isFalse);
  });

  test('inventory issue rows understand the slow-moving API fields', () {
    final item = {'name': 'Xi măng PCB40', 'currentStock': '18', 'unit': 'Bao'};

    expect(inventoryIssueProductName(item), 'Xi măng PCB40');
    expect(inventoryIssueQuantity(item), 18);
  });
}
