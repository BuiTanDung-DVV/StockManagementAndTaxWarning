import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/products/presentation/product_form_screen.dart',
  ).readAsStringSync();

  test('editing a product does not overwrite inventory stock', () {
    expect(source, contains("if (!_isEdit)"));
    expect(source, contains("data['openingStock']"));
    expect(source, contains('enabled: !_isEdit'));
    expect(source, isNot(contains("'currentStock': int.tryParse")));
  });
}
