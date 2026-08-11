import 'package:flutter_app/features/finance/presentation/supplier_payables_aging_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supplier payables report switches from table to mobile cards', () {
    expect(supplierPayablesUsesMobileCards(390), isTrue);
    expect(supplierPayablesUsesMobileCards(719), isTrue);
    expect(supplierPayablesUsesMobileCards(720), isFalse);
    expect(supplierPayablesUsesMobileCards(1280), isFalse);
  });
}
