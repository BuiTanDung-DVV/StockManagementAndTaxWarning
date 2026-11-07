import 'package:flutter_app/features/finance/presentation/supplier_payables_aging_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supplier adjustment is presented separately from money paid', () {
    expect(
      supplierPayableAdjustmentLabel({'openingAdjustmentAmount': -50}),
      contains('Điều chỉnh đầu kỳ: -50'),
    );
    expect(
      supplierPayableAdjustmentLabel({'openingAdjustmentAmount': 0}),
      isNull,
    );
    expect(
      supplierPayableAdjustmentLabel({'openingAdjustmentAmount': 'NaN'}),
      isNull,
    );
  });
  test('supplier payables report switches from table to mobile cards', () {
    expect(supplierPayablesUsesMobileCards(390), isTrue);
    expect(supplierPayablesUsesMobileCards(719), isTrue);
    expect(supplierPayablesUsesMobileCards(720), isFalse);
    expect(supplierPayablesUsesMobileCards(1280), isFalse);
  });
}
