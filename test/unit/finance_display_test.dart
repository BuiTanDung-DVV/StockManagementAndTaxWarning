import 'package:flutter_app/core/utils/finance_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance category codes are displayed in Vietnamese', () {
    expect(financeCategoryLabel('PURCHASE'), 'Mua hàng');
    expect(financeCategoryLabel('SALARY'), 'Lương nhân viên');
    expect(financeCategoryLabel('RENT'), 'Tiền thuê mặt bằng');
    expect(financeCategoryLabel('SALES_RETURN'), 'Hoàn tiền hàng bán');
    expect(financeCategoryLabel('UTILITIES'), 'Điện, nước và tiện ích');
    expect(financeCategoryLabel('DELIVERY'), 'Giao nhận và bốc xếp');
    expect(financeCategoryLabel('CAPITAL'), 'Vốn góp');
    expect(financeCategoryLabel('LOAN'), 'Khoản vay');
  });

  test('currency values include Vietnamese separators and unit', () {
    expect(formatVietnameseCurrency(423831000), '423.831.000 ₫');
    expect(formatVietnameseCurrency(23398000), '23.398.000 ₫');
  });

  test(
    'transaction display prioritizes persisted notes and Vietnamese labels',
    () {
      final transaction = {
        'type': 'EXPENSE',
        'category': 'SALARY',
        'notes': 'Chi lương tháng 8',
        'paymentMethod': 'BANK_TRANSFER',
        'transactionDate': '2026-08-13',
        'createdAt': '2026-08-14T01:00:00Z',
      };

      expect(financeTransactionDescription(transaction), 'Chi lương tháng 8');
      expect(financePaymentMethodLabel('BANK_TRANSFER'), 'Chuyển khoản');
      expect(financePaymentMethodLabel('QR'), 'QR ngân hàng');
      expect(financeTransactionDateValue(transaction), '2026-08-13');
    },
  );

  test('linked transactions are read-only outside their source document', () {
    expect(
      financeTransactionIsLinked({'referenceType': 'SALES_ORDER'}),
      isTrue,
    );
    expect(
      financeTransactionIsLinked({'referenceType': 'CASH_TRANSACTION'}),
      isFalse,
    );
    expect(financeTransactionIsLinked({}), isFalse);
  });
}
