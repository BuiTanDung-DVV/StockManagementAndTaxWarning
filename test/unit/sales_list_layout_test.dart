import 'package:flutter_app/features/sales/presentation/sales_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sales order statuses never present confirmed as cancelled', () {
    expect(salesOrderStatusPresentation('CONFIRMED').label, 'Đã xác nhận');
    expect(salesOrderStatusPresentation('CANCELLED').label, 'Đã hủy');
    expect(salesOrderStatusPresentation('PENDING').label, 'Chờ xử lý');
    expect(salesOrderStatusPresentation('DELIVERED').label, 'Hoàn thành');
    expect(salesOrderStatusPresentation('unexpected').label, 'Không xác định');
  });

  test('sales screen keeps the primary action out of compact list content', () {
    expect(salesListUsesCompactLayout(390), isTrue);
    expect(salesListUsesCompactLayout(648), isTrue);
    expect(salesListUsesCompactLayout(799), isTrue);
    expect(salesListUsesCompactLayout(800), isFalse);
  });

  test('sales pagination uses server totals and safe fallbacks', () {
    expect(salesListCurrentPage({'page': 3, 'totalPages': 8, 'total': 156}), 3);
    expect(salesListTotalPages({'page': 3, 'totalPages': 8, 'total': 156}), 8);
    expect(
      salesListTotalItems({'page': 3, 'totalPages': 8, 'total': 156}),
      156,
    );
    expect(
      salesListTotalItems({
        'items': List.generate(7, (index) => {'id': index}),
      }),
      7,
    );
  });

  test('sales list period sends both DB boundaries or neither', () {
    final current = salesListPeriodParams(
      currentPeriodOnly: true,
      now: DateTime(2026, 8, 20),
    );
    expect(current.from, '2026-08-01');
    expect(current.to, '2026-08-20');

    final all = salesListPeriodParams(
      currentPeriodOnly: false,
      now: DateTime(2026, 8, 20),
    );
    expect(all.from, isNull);
    expect(all.to, isNull);
  });

  test('sales list displays the business transaction date from API data', () {
    expect(salesOrderDateLabel('2026-08-20T02:30:00.000Z'), '20/08/2026');
    expect(salesOrderDateLabel(null), 'Chưa rõ ngày');
    expect(salesOrderDateLabel('not-a-date'), 'Chưa rõ ngày');
  });

  test(
    'all-shops sales list is read-only and resolves shop names from API data',
    () {
      expect(
        salesListCanCreateTransaction(isAllShops: true, canEdit: true),
        isFalse,
      );
      expect(
        salesListCanCreateTransaction(isAllShops: false, canEdit: true),
        isTrue,
      );
      expect(
        salesListCanCreateTransaction(isAllShops: false, canEdit: false),
        isFalse,
      );
      expect(
        salesOrderShopName(
          {'shopId': 35},
          [
            {'shopId': 34, 'shopName': 'Cửa hàng A'},
            {'shopId': 35, 'shopName': 'Cửa hàng B'},
          ],
        ),
        'Cửa hàng B',
      );
      expect(salesOrderShopName({'shopId': 99}, const []), isNull);
    },
  );
}
