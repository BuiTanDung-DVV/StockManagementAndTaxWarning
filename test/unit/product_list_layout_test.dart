import 'package:flutter_app/features/products/presentation/product_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product list uses compact layout for tablet and mobile widths', () {
    expect(productListUsesCompactLayout(390), isTrue);
    expect(productListUsesCompactLayout(648), isTrue);
    expect(productListUsesCompactLayout(799), isTrue);
    expect(productListUsesCompactLayout(800), isFalse);
    expect(productListUsesCompactLayout(1200), isFalse);
  });

  test('product low-stock status follows the database minimum', () {
    expect(productIsLowStock(8, 5), isFalse);
    expect(productIsLowStock(5, 5), isTrue);
    expect(productIsLowStock(3, 12), isTrue);
    expect(productIsLowStock(3, 0), isFalse);
    expect(productIsLowStock(0, 10), isFalse);
  });
}
