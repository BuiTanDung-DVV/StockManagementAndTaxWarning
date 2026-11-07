import 'package:flutter_app/core/utils/excel_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'orders CSV preserves codes and punctuation, uses business date and exact totals',
    () {
      final csv = ExcelExportService.buildOrdersCsv([
        {
          'id': 99,
          'orderCode': '0000123',
          'customerName': 'An, "Bình"\nChi nhánh 2',
          'orderDate': '2026-10-29T18:30:00Z',
          'createdAt': '2026-10-01',
          'totalAmount': '0.10',
          'paymentMethod': 'CASH',
          'status': 'COMPLETED',
        },
        {
          'orderCode': '=1+1',
          'customerName': '+SUM(1,2)',
          'orderDate': 'not-a-date',
          'amount': '0.20',
        },
      ], exportedAt: DateTime(2026, 10, 30));
      expect(
        csv,
        contains('"0000123","An, ""Bình""\nChi nhánh 2","30/10/2026 01:30"'),
      );
      expect(csv, contains('"\'=1+1","\'+SUM(1,2)","not-a-date"'));
      expect(csv, contains('0.20,""'));
      expect(csv, contains('TỔNG GIÁ TRỊ ĐƠN TRONG DANH SÁCH,,,,0.30,'));
      expect(csv, isNot(contains('TỔNG DOANH THU')));
    },
  );

  test('orders CSV rejects missing amounts and unsafe totals', () {
    expect(
      () => ExcelExportService.buildOrdersCsv([
        {'orderCode': 'A'},
      ]),
      throwsFormatException,
    );
    expect(
      () => ExcelExportService.buildOrdersCsv([
        {'amount': '90071992547409.91'},
        {'amount': '0.01'},
      ]),
      throwsFormatException,
    );
  });
  test(
    'debt CSV identifies shop, filters and count with safe quoted metadata',
    () {
      final csv = ExcelExportService.buildCustomerDebtsCsv(
        [],
        shopName: '=Cửa hàng, "A"',
        filterDescription: 'Từ khóa: An, Bình · Đã quá hạn',
        exportedAt: DateTime(2026, 10, 30),
      );
      expect(csv, contains('"Cửa hàng","\'=Cửa hàng, ""A"""'));
      expect(csv, contains('"Bộ lọc","Từ khóa: An, Bình · Đã quá hạn"'));
      expect(csv, contains('"Số bản ghi",0'));
      expect(csv.startsWith('\uFEFF'), isTrue);
    },
  );
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
    expect(csv, contains('"25/07/2026",150000.00,50000.00,0.00,100000.00'));
    expect(csv, contains('TỔNG NỢ CẦN THU CÒN LẠI,,,,,,,100000.00'));
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

    expect(csv, contains('"Khách A","","","",100.00,150.00,0.00,0.00'));
    expect(csv, contains('TỔNG NỢ CẦN THU CÒN LẠI,,,,,,,0.00'));
  });

  test(
    'debt CSV separates opening adjustments and preserves exact remaining cents',
    () {
      final csv = ExcelExportService.buildCustomerDebtsCsv([
        {
          'totalAmount': '300.10',
          'paidAmount': '50.00',
          'openingAdjustmentAmount': '-50.00',
          'remaining': '200.10',
        },
        {'totalAmount': '0.20', 'paidAmount': 0, 'remaining': '0.20'},
      ]);
      expect(csv, contains('ĐIỀU CHỈNH ĐẦU KỲ (VNĐ)'));
      expect(csv, contains('300.10,50.00,-50.00,200.10'));
      expect(csv, contains('TỔNG NỢ CẦN THU CÒN LẠI,,,,,,,200.30'));
      expect(
        () => ExcelExportService.buildCustomerDebtsCsv([
          {'totalAmount': 100, 'paidAmount': 0, 'remaining': 'NaN'},
        ]),
        throwsFormatException,
      );
    },
  );

  test('debt aging CSV keeps Vietnamese buckets and control totals', () {
    final csv = ExcelExportService.buildDebtAgingCsv({
      'asOf': '2026-08-09',
      'balanceBasis': 'CURRENT',
      'balanceAsOf': '2026-08-10',
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
    expect(csv, contains('Dư nợ hiện tại tại 2026-08-10'));
    expect(csv, contains('ngày đối chiếu dùng để phân nhóm tuổi nợ'));
  });

  test(
    'inventory CSV normalizes fields, escapes formulas and calculates status',
    () {
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
    },
  );

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

    expect(
      csv,
      contains('"SKU-NULL","Sản phẩm mới","Cái",,,,"Chưa có số liệu"'),
    );
    expect(csv, contains('"\'=FORMULA"'));
    expect(csv, contains('5,10,20000.0,"Cần nhập thêm"'));
  });
}
