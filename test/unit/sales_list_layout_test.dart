import 'package:flutter_app/features/sales/presentation/sales_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sales screen keeps the primary action out of compact list content', () {
    expect(salesListUsesCompactLayout(390), isTrue);
    expect(salesListUsesCompactLayout(648), isTrue);
    expect(salesListUsesCompactLayout(799), isTrue);
    expect(salesListUsesCompactLayout(800), isFalse);
  });
}
