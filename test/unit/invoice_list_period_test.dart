import 'package:flutter_app/features/finance/presentation/invoice_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('danh sách hóa đơn mặc định dùng cùng kỳ với KPI VAT', () {
    final result = invoiceListPeriodParams(
      showAll: false,
      from: '2026-08-01',
      to: '2026-08-20',
    );

    expect(result.from, '2026-08-01');
    expect(result.to, '2026-08-20');
  });

  test('toàn bộ thời gian không gửi kỳ giả xuống backend', () {
    final result = invoiceListPeriodParams(
      showAll: true,
      from: '2026-08-01',
      to: '2026-08-20',
    );

    expect(result.from, isNull);
    expect(result.to, isNull);
  });
}
