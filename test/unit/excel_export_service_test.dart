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

  test('inventory CSV normalizes fields, escapes formulas and calculates status', () {
    final csv = ExcelExportService.buildInventoryCsv([
      {
        'id': 1,
        'sku': '-SKU-001',
        'name': 'Trà =1+1 "Ô Long"',
        'unit': 'Hộp',
        'currentStock': 12,
        'minStock': 5,
        'sellingPrice': 85000,
      },
      {
        'id': 2,
        'sku': 'SKU-002',
        'name': 'Cà phê hòa tan',
        'unit': 'Gói',
        'stockQuantity': 0,
        'minStockThreshold': 10,
        'retailPrice': 45000,
      },
    ], exportedAt: DateTime(2026, 9, 14, 15, 0));

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('BÁO CÁO KIỂM KÊ TỒN KHO - SMARTSTOCK'));
    expect(csv, contains('Ngày xuất: 14/09/2026 15:00'));
    // Checks formula escaping
    expect(csv, contains('"\'-SKU-001"'));
    // Checks field normalization & status
    expect(csv, contains('12,5,85000.0,"An toàn"'));
    expect(csv, contains('0,10,45000.0,"Hết hàng"'));
  });

  test('inventory CSV preserves null values without fake 0s', () {
    final csv = ExcelExportService.buildInventoryCsv([
      {
        'id': 1,
        'sku': 'SKU-NULL',
        'name': 'Sản phẩm mới',
        'unit': 'Cái',
        'currentStock': null,
        'minStock': null,
        'sellingPrice': null,
      },
      {
        'id': 2,
        'sku': '=FORMULA',
        'name': 'Công thức',
        'unit': 'Cái',
        'currentStock': 5,
        'minStock': 10,
        'sellingPrice': 20000,
      },
    ], exportedAt: DateTime(2026, 9, 14, 15, 0));

    expect(csv, contains('"SKU-NULL","Sản phẩm mới","Cái",,,,"Chưa có số liệu"'));
    expect(csv, contains('"\'=FORMULA"'));
    expect(csv, contains('5,10,20000.0,"Cần nhập thêm"'));
  });
}

