import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/finance/domain/invoice_data_quality.dart';

void main() {
  test('đọc chỉ số chất lượng hóa đơn hoàn toàn từ phản hồi backend', () {
    final result = InvoiceDataQuality.fromResponse({
      'quality': {
        'checkedInvoices': '80',
        'missingItemInvoices': 2,
        'headerTotalMismatchInvoices': '3',
        'headerSubtotalMismatchInvoices': 6,
        'unallocatedDiscountInvoices': 8,
        'headerTaxMismatchInvoices': 7,
        'invalidLineItems': 1,
        'lineSubtotalMismatchItems': 4,
        'lineTaxMismatchItems': 5,
        'hasIssues': false,
      },
    });

    expect(result.checkedInvoices, 80);
    expect(result.unallocatedDiscountInvoices, 8);
    expect(result.issueCount, 36);
    expect(result.hasIssues, isTrue);
  });

  test('phản hồi không có quality không tạo dữ liệu cảnh báo giả', () {
    final result = InvoiceDataQuality.fromResponse({});

    expect(result.checkedInvoices, 0);
    expect(result.issueCount, 0);
    expect(result.hasIssues, isFalse);
  });
}
