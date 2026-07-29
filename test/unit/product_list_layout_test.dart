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
}
