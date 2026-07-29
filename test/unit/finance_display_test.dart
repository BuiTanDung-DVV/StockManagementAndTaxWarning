import 'package:flutter_app/core/utils/finance_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finance category codes are displayed in Vietnamese', () {
    expect(financeCategoryLabel('PURCHASE'), 'Mua hàng');
    expect(financeCategoryLabel('SALARY'), 'Lương nhân viên');
    expect(financeCategoryLabel('RENT'), 'Tiền thuê mặt bằng');
    expect(financeCategoryLabel('SALES_RETURN'), 'Hoàn tiền hàng bán');
    expect(financeCategoryLabel('UTILITIES'), 'Điện, nước và tiện ích');
  });

  test('currency values include Vietnamese separators and unit', () {
    expect(formatVietnameseCurrency(423831000), '423.831.000 ₫');
    expect(formatVietnameseCurrency(23398000), '23.398.000 ₫');
  });
}
