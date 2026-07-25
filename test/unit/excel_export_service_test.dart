import 'package:flutter_app/core/utils/excel_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer debt CSV escapes text and protects spreadsheet formulas', () {
    final csv = ExcelExportService.buildCustomerDebtsCsv([
      {
        'customerName': 'Nguyễn, "An"',
        'customerPhone': '=1+1',
        'orderCode': '-DH-01',
        'createdAt': '2026-07-25T10:00:00Z',
        'totalAmount': 150000,
        'paidAmount': 50000,
      },
    ], exportedAt: DateTime(2026, 7, 25, 12, 30));

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('Ngày xuất: 25/07/2026 12:30'));
    expect(csv, contains('"Nguyễn, ""An"""'));
    expect(csv, contains('"\'=1+1"'));
    expect(csv, contains('"\'-DH-01"'));
    expect(csv, contains('"25/07/2026",150000.0,50000.0,100000.0'));
    expect(csv, contains('TỔNG NỢ CẦN THU CÒN LẠI,,,,,,100000.0'));
  });

  test('customer debt CSV does not invent dates or negative balances', () {
    final csv = ExcelExportService.buildCustomerDebtsCsv([
      {
        'customerName': 'Khách A',
        'createdAt': 'not-a-date',
        'totalAmount': 100,
        'paidAmount': 150,
      },
    ], exportedAt: DateTime(2026, 7, 25));

    expect(csv, contains('"Khách A","","","",100.0,150.0,0.0'));
    expect(csv, contains('TỔNG NỢ CẦN THU CÒN LẠI,,,,,,0.0'));
  });
}
