import 'package:flutter_app/features/sales/presentation/pos_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('POS stock guard', () {
    test('reads available stock from supported API field names', () {
      expect(availableStockOf({'currentStock': 3}), 3);
      expect(availableStockOf({'stockQuantity': '4'}), 4);
      expect(availableStockOf({'stock_quantity': 5.9}), 5);
      expect(availableStockOf({}), isNull);
      expect(availableStockOf({'currentStock': 'invalid'}), isNull);
    });

    test('blocks adding an out-of-stock product', () {
      expect(
        canIncreaseQuantity(currentQuantity: 0, availableStock: 0),
        isFalse,
      );
    });

    test('blocks increasing beyond available stock', () {
      expect(
        canIncreaseQuantity(currentQuantity: 2, availableStock: 2),
        isFalse,
      );
      expect(
        canIncreaseQuantity(currentQuantity: 1, availableStock: 2),
        isTrue,
      );
    });

    test('allows increment when stock data is unavailable', () {
      expect(
        canIncreaseQuantity(currentQuantity: 10, availableStock: null),
        isTrue,
      );
    });
  });
}
