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

  test('debt aging CSV keeps Vietnamese buckets and control totals', () {
    final csv = ExcelExportService.buildDebtAgingCsv({
      'asOf': '2026-08-09',
      'totalDebt': 1500000,
      'buckets': {
        'current': 500000,
        'past30': 400000,
        'past60': 300000,
        'past90': 300000,
      },
      'customers': [
        {
          'customerName': 'Cửa hàng An Phát',
          'total': 1500000,
          'current': 500000,
          'past30': 400000,
          'past60': 300000,
          'past90': 300000,
          'overdueDays': 75,
        },
      ],
    }, exportedAt: DateTime(2026, 8, 9, 10, 30));

    expect(csv, contains('Quá hạn trên 60 ngày'));
    expect(csv, contains('Cửa hàng An Phát'));
    expect(csv, contains('"Tổng dư nợ",1500000'));
  });
}
