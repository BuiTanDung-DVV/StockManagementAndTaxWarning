import 'package:flutter_app/features/sales/presentation/sales_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
