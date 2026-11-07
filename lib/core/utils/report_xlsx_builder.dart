import 'dart:typed_data';
import '../../features/finance/models/cash_ledger_export.dart';
import '../../features/finance/models/debt_aging_export.dart';
import '../../features/inventory/models/xnt_export.dart';
import '../../features/products/models/inventory_export.dart';
import 'finance_display.dart';
import 'report_xlsx_writer.dart';

class ReportXlsxBuilder {
  static const _heights = {
    1: 32.0,
    2: 26.0,
    3: 30.0,
    4: 28.0,
    5: 34.0,
    6: 34.0,
    7: 10.0,
    8: 32.0,
  };
  static XlsxCell _label(String value) => XlsxCell.text(value, style: 2);
  static XlsxCell _count(int value) => XlsxCell.number('$value', style: 10);
  static Uint8List inventory(
    InventoryExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    final end = report.items.isEmpty ? 9 : report.items.length + 8;
    final filters = report.filters;
    final rows = <int, List<XlsxCell?>>{
      1: [const XlsxCell.text('BÁO CÁO TỒN KHO SẢN PHẨM', style: 1)],
      2: [_label('$shopName - Mã cửa hàng: ${report.shopId}')],
      3: [
        _label('Dữ liệu tại'),
        XlsxCell.timestamp(report.generatedAt),
        null,
        null,
        _label('Ngày xuất'),
        XlsxCell.timestamp(exportedAt ?? DateTime.now()),
      ],
      4: [
        _label(
          'Từ khóa: ${filters['search'] ?? 'Tất cả'} · Nhãn: ${filters['tag'] ?? 'Tất cả'} · Danh mục: ${filters['categoryId'] == 0 ? 'Chưa phân loại' : filters['categoryId'] ?? 'Tất cả'} · ${filters['inStockOnly'] == true ? 'Có tồn tại ít nhất một kho' : 'Tất cả mức tồn'}',
        ),
      ],
      5: [
        _label(
          '${report.selection}. Tồn theo dữ liệu tại thời điểm đọc; không cộng số lượng khác đơn vị. Ô thiếu số liệu được ghi rõ, không tự thay bằng 0.',
        ),
      ],
      6: [
        _label('Dòng đang hiện'),
        XlsxCell.formula(
          'SUBTOTAL(103,A9:A$end)',
          '${report.items.length}',
          style: 10,
        ),
        _label('Khớp bộ lọc'),
        _count(report.matchingCount),
      ],
      7: [],
      8: [
        for (final name in [
          'Mã sản phẩm',
          'Sản phẩm',
          'Đơn vị',
          'Số lượng tồn',
          'Mức tối thiểu',
          'Giá bán (VNĐ)',
          'Trạng thái tồn',
          'Nhãn',
        ])
          XlsxCell.text(name, style: 3),
      ],
    };
    for (var i = 0; i < report.items.length; i++) {
      final row = report.items[i],
          text = i.isOdd ? 12 : 0,
          num = i.isOdd ? 13 : 4,
          money = i.isOdd ? 15 : 6;
      rows[i + 9] = [
        XlsxCell.text(row.sku, style: text),
        XlsxCell.text(row.name, style: text),
        XlsxCell.text(row.unit, style: text),
        row.stock == null
            ? XlsxCell.text('Chưa có số liệu', style: text)
            : XlsxCell.number('${row.stock}', style: num),
        row.minStock == null
            ? XlsxCell.text('Chưa có định mức', style: text)
            : XlsxCell.number('${row.minStock}', style: num),
        row.priceCents == null
            ? XlsxCell.text('Chưa có giá', style: text)
            : XlsxCell.number(
                CashLedgerExport.decimalAmount(row.priceCents!),
                style: money,
              ),
        XlsxCell.text(row.status, style: text),
        XlsxCell.text(
          row.tags.isEmpty ? 'Không có nhãn' : row.tags.join(' · '),
          style: text,
        ),
      ];
    }
    if (report.items.isEmpty) {
      rows[9] = [];
      rows[10] = [_label('Không có sản phẩm đã chọn trong phạm vi này.')];
    }
    return ReportXlsxWriter.build(
      sheetName: 'Tồn kho sản phẩm',
      widths: [22, 44, 14, 22, 22, 24, 30, 38],
      rows: rows,
      dataCount: report.items.length,
      merges: [
        'A1:H1',
        'A2:H2',
        'B3:D3',
        'F3:H3',
        'A4:H4',
        'A5:H5',
        if (report.items.isEmpty) 'A10:H10',
      ],
      heights: {..._heights, 4: 44, 5: 44, 8: 36},
    );
  }

  static Uint8List debtAging(
    DebtAgingExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    final end = report.customers.isEmpty ? 9 : report.customers.length + 8;
    final rows = <int, List<XlsxCell?>>{
      1: [const XlsxCell.text('BÁO CÁO TUỔI NỢ KHÁCH HÀNG', style: 1)],
      2: [_label('$shopName - Mã cửa hàng: ${report.shopId}')],
      3: [
        _label('Ngày đối chiếu'),
        XlsxCell.date(report.asOf),
        null,
        _label('Ngày xuất'),
        XlsxCell.timestamp(exportedAt ?? DateTime.now()),
      ],
      4: [_label('Số dư cập nhật'), XlsxCell.timestamp(report.balanceAsOf)],
      5: [
        _label(
          'Dư nợ hiện tại; ngày đối chiếu chỉ dùng phân nhóm tuổi nợ, không phải số dư lịch sử. Tổng hàng 6 đổi khi lọc Excel.',
        ),
      ],
      6: [
        _label('Tổng trong bộ lọc'),
        for (final pair in [
          ('B', report.totalCents),
          ('C', report.bucketCents['current']!),
          ('D', report.bucketCents['past30']!),
          ('E', report.bucketCents['past60']!),
          ('F', report.bucketCents['past90']!),
        ])
          XlsxCell.formula(
            'ROUND(SUBTOTAL(109,${pair.$1}9:${pair.$1}$end),2)',
            CashLedgerExport.decimalAmount(pair.$2),
          ),
        _label('Khách hàng'),
        XlsxCell.formula(
          'SUBTOTAL(103,A9:A$end)',
          '${report.customers.length}',
          style: 10,
        ),
      ],
      7: [],
      8: [
        for (final name in [
          'Khách hàng',
          'Tổng dư nợ (VNĐ)',
          'Chưa đến hạn',
          'Quá hạn 1–30 ngày',
          'Quá hạn 31–60 ngày',
          'Quá hạn trên 60 ngày',
          'Ngày quá hạn tối đa',
          'Lần trả gần nhất',
        ])
          XlsxCell.text(name, style: 3),
      ],
    };
    for (var i = 0; i < report.customers.length; i++) {
      final row = report.customers[i],
          text = i.isOdd ? 12 : 0,
          money = i.isOdd ? 15 : 6;
      final payment = row['lastPaymentDate'];
      rows[i + 9] = [
        XlsxCell.text(row['customerName'], style: text),
        for (final key in ['total', 'current', 'past30', 'past60', 'past90'])
          XlsxCell.number(
            CashLedgerExport.decimalAmount(CashLedgerExport.cents(row[key])),
            style: money,
          ),
        XlsxCell.number('${row['overdueDays']}', style: i.isOdd ? 13 : 4),
        payment == null
            ? XlsxCell.text('Chưa ghi nhận', style: text)
            : XlsxCell.date(
                DebtAgingExport.businessDay(payment),
                style: i.isOdd ? 14 : 5,
              ),
      ];
    }
    if (report.customers.isEmpty) {
      rows[9] = [];
      rows[10] = [_label('Không có khoản phải thu đang mở trong phạm vi này.')];
    }
    return ReportXlsxWriter.build(
      sheetName: 'Tuổi nợ khách hàng',
      widths: [34, 24, 22, 22, 22, 22, 20, 22],
      rows: rows,
      dataCount: report.customers.length,
      merges: [
        'A1:H1',
        'A2:H2',
        'B3:C3',
        'E3:F3',
        'B4:C4',
        'A5:H5',
        if (report.customers.isEmpty) 'A10:H10',
      ],
      heights: {..._heights, 5: 44, 8: 42},
    );
  }

  static Uint8List customerDebts(
    List<dynamic> debts, {
    int? shopId,
    String? shopName,
    String? filterDescription,
    DateTime? exportedAt,
  }) {
    final rows = <int, List<XlsxCell?>>{};
    var totalRemaining = 0;
    for (var i = 0; i < debts.length; i++) {
      final item = debts[i];
      if (item is! Map) {
        throw const FormatException('Dữ liệu công nợ không hợp lệ');
      }
      final total = CashLedgerExport.cents(item['totalAmount']);
      final paid = CashLedgerExport.cents(item['paidAmount'] ?? 0);
      final adjustment = CashLedgerExport.cents(
        item['openingAdjustmentAmount'] ?? 0,
        signed: true,
      );
      final calculated = total - paid + adjustment;
      if (item['remaining'] == null && calculated.abs() > 9007199254740991) {
        throw const FormatException(
          'Số dư công nợ vượt giới hạn xuất chính xác',
        );
      }
      final remaining = item['remaining'] == null
          ? (calculated < 0 ? 0 : calculated)
          : CashLedgerExport.cents(item['remaining']);
      totalRemaining += remaining;
      if (totalRemaining > 9007199254740991) {
        throw const FormatException(
          'Tổng công nợ vượt giới hạn xuất chính xác',
        );
      }
      final rawDate = item['createdAt']?.toString() ?? '';
      final date =
          rawDate.length >= 10 &&
              CashLedgerExport.validDate(rawDate.substring(0, 10))
          ? DateTime.tryParse(rawDate)
          : null;
      final businessDate = date?.isUtc == true
          ? date!.add(const Duration(hours: 7))
          : date;
      final textStyle = i.isOdd ? 12 : 0;
      final moneyStyle = i.isOdd ? 15 : 6;
      XlsxCell text(dynamic value) =>
          XlsxCell.text(value?.toString() ?? '', style: textStyle);
      XlsxCell money(int value) => XlsxCell.number(
        CashLedgerExport.decimalAmount(value),
        style: moneyStyle,
      );
      rows[i + 9] = [
        text(item['customerName'] ?? 'Khách lẻ'),
        text(item['customerPhone']),
        text(item['orderCode']),
        businessDate == null
            ? text('Chưa có ngày')
            : XlsxCell.date(
                '${businessDate.year.toString().padLeft(4, '0')}-${businessDate.month.toString().padLeft(2, '0')}-${businessDate.day.toString().padLeft(2, '0')}',
                style: i.isOdd ? 14 : 5,
              ),
        money(total),
        money(paid),
        money(adjustment),
        money(remaining),
      ];
    }
    final end = debts.isEmpty ? 9 : debts.length + 8;
    rows.addAll({
      1: [const XlsxCell.text('SỔ CÔNG NỢ KHÁCH HÀNG', style: 1)],
      2: [
        _label(
          '${shopName?.trim().isNotEmpty == true ? shopName : 'Cửa hàng'}${shopId == null ? '' : ' - Mã cửa hàng: $shopId'}',
        ),
      ],
      3: [
        _label('Ngày xuất'),
        XlsxCell.timestamp(exportedAt ?? DateTime.now()),
      ],
      4: [
        _label(
          'Bộ lọc: ${filterDescription?.trim().isNotEmpty == true ? filterDescription : 'Toàn bộ danh sách đã chọn'}',
        ),
      ],
      5: [
        _label(
          'Điều chỉnh đầu kỳ không phải tiền đã thu. Số còn nợ theo dữ liệu đã đối chiếu. Tổng hàng 6 đổi khi lọc Excel.',
        ),
      ],
      6: [
        _label('Còn phải thu'),
        XlsxCell.formula(
          'ROUND(SUBTOTAL(109,H9:H$end),2)',
          CashLedgerExport.decimalAmount(totalRemaining),
        ),
        null,
        _label('Số khoản'),
        XlsxCell.formula(
          'SUBTOTAL(103,A9:A$end)',
          '${debts.length}',
          style: 10,
        ),
      ],
      7: [],
      8: [
        for (final name in [
          'Khách hàng',
          'Điện thoại',
          'Mã đơn nợ',
          'Ngày ghi nhận',
          'Nợ gốc (VNĐ)',
          'Đã thu (VNĐ)',
          'Điều chỉnh đầu kỳ (VNĐ)',
          'Còn nợ (VNĐ)',
        ])
          XlsxCell.text(name, style: 3),
      ],
    });
    if (debts.isEmpty) {
      rows[9] = [];
      rows[10] = [_label('Không có khoản công nợ trong phạm vi đã chọn.')];
    }
    return ReportXlsxWriter.build(
      sheetName: 'Công nợ khách hàng',
      widths: [30, 18, 22, 16, 22, 22, 22, 22],
      rows: rows,
      merges: [
        'A1:H1',
        'A2:H2',
        'B3:C3',
        'B6:C6',
        'A4:H4',
        'A5:H5',
        if (debts.isEmpty) 'A10:H10',
      ],
      dataCount: debts.length,
      heights: {..._heights, 4: 42, 5: 42, 8: 38},
    );
  }

  static Uint8List xnt(
    XntExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    final rows = <int, List<XlsxCell?>>{
      1: [const XlsxCell.text('BÁO CÁO NHẬP - XUẤT - TỒN', style: 1)],
      2: [_label('$shopName - Mã cửa hàng: ${report.shopId}')],
      3: [
        _label('Từ ngày'),
        XlsxCell.date(report.from),
        null,
        _label('Đến ngày'),
        XlsxCell.date(report.to),
        null,
        _label('Kho'),
        _label(
          report.warehouseId == null ? 'Tất cả kho' : '#${report.warehouseId}',
        ),
      ],
      4: [
        _label('Ngày xuất'),
        XlsxCell.timestamp(exportedAt ?? DateTime.now()),
        null,
        null,
        _label('Số sản phẩm'),
        _count(report.items.length),
      ],
      5: [
        _label(
          'Số SKU bên dưới theo toàn bộ bộ lọc xuất. Không cộng tổng số lượng khác đơn vị.',
        ),
      ],
      6: [
        _label('Có tồn đầu'),
        _count(report.summary['openingSkuCount']!),
        _label('Có nhập'),
        _count(report.summary['importedSkuCount']!),
        _label('Có xuất'),
        _count(report.summary['exportedSkuCount']!),
        _label('Còn tồn'),
        _count(report.summary['closingSkuCount']!),
      ],
      7: [],
      8: [
        for (final name in [
          'ID sản phẩm',
          'SKU',
          'Sản phẩm',
          'Đơn vị',
          'Tồn đầu',
          'Nhập',
          'Xuất',
          'Tồn cuối',
        ])
          XlsxCell.text(name, style: 3),
      ],
    };
    for (var i = 0; i < report.items.length; i++) {
      final row = report.items[i],
          text = i.isOdd ? 12 : 0,
          number = i.isOdd ? 13 : 4;
      rows[i + 9] = [
        for (final key in ['id', 'sku', 'name', 'unit'])
          XlsxCell.text('${row[key]}', style: text),
        for (final key in [
          'openingStock',
          'totalImport',
          'totalExport',
          'closingStock',
        ])
          XlsxCell.number('${row[key]}', style: number),
      ];
    }
    if (report.items.isEmpty) {
      rows[10] = [_label('Không có sản phẩm trong phạm vi đã chọn.')];
    }
    return ReportXlsxWriter.build(
      sheetName: 'Nhập xuất tồn',
      widths: [14, 24, 54, 14, 18, 18, 18, 18],
      rows: rows,
      merges: ['A1:H1', 'A2:H2', 'A5:H5', if (report.items.isEmpty) 'A10:H10'],
      dataCount: report.items.length,
      heights: _heights,
    );
  }

  static Uint8List cashLedger(
    CashLedgerExport ledger, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    final end = 8 + (ledger.items.isEmpty ? 1 : ledger.items.length);
    final rows = <int, List<XlsxCell?>>{
      1: [const XlsxCell.text('SỔ THU CHI THEO KỲ', style: 1)],
      2: [_label('$shopName - Mã cửa hàng: ${ledger.shopId}')],
      3: [
        _label('Từ ngày'),
        XlsxCell.date(ledger.from),
        null,
        _label('Đến ngày'),
        XlsxCell.date(ledger.to),
        null,
        _label('Ngày xuất'),
        XlsxCell.timestamp(exportedAt ?? DateTime.now()),
      ],
      4: [
        _label('Bộ lọc'),
        _label(
          '${ledger.type == null
              ? 'Tất cả thu chi'
              : ledger.type == 'INCOME'
              ? 'Thu'
              : 'Chi'}; ${ledger.category == null ? 'Tất cả nhóm' : financeCategoryLabel(ledger.category)}',
        ),
      ],
      5: [
        _label(
          'Theo ngày ghi sổ, không phải số dư quỹ/lợi nhuận. Tổng hàng 6 đổi khi lọc Excel. Bản in gồm thu chi (A–H) và thông tin chứng từ (I–M), cùng mã/ngày để đối chiếu.',
        ),
      ],
      6: [
        _label('Tổng thu'),
        XlsxCell.formula(
          'ROUND(SUBTOTAL(109,E9:E$end),2)',
          CashLedgerExport.decimalAmount(ledger.incomeCents),
        ),
        null,
        _label('Tổng chi'),
        XlsxCell.formula(
          'ROUND(SUBTOTAL(109,F9:F$end),2)',
          CashLedgerExport.decimalAmount(ledger.expenseCents),
        ),
        null,
        _label('Thu - chi'),
        XlsxCell.formula(
          'ROUND(B6-E6,2)',
          CashLedgerExport.decimalAmount(
            ledger.incomeCents - ledger.expenseCents,
          ),
        ),
        null,
        _label('Số dòng'),
        XlsxCell.formula(
          'SUBTOTAL(103,A9:A$end)',
          '${ledger.items.length}',
          style: 10,
        ),
      ],
      7: [],
      8: [
        for (final name in [
          'Mã giao dịch',
          'Ngày ghi sổ',
          'Loại',
          'Nhóm',
          'Thu (VNĐ)',
          'Chi (VNĐ)',
          'Phương thức',
          'Đối tác',
          'Loại chứng từ',
          'ID tham chiếu',
          'Ghi chú',
          'Nhãn',
          'Ảnh chứng từ (URL)',
        ])
          XlsxCell.text(name, style: 3),
      ],
    };
    for (var i = 0; i < ledger.items.length; i++) {
      final row = ledger.items[i],
          text = i.isOdd ? 12 : 0,
          money = i.isOdd ? 15 : 6,
          date = i.isOdd ? 14 : 5;
      XlsxCell value(dynamic v) =>
          XlsxCell.text(v?.toString() ?? '', style: text);
      final amount = CashLedgerExport.decimalAmount(
        CashLedgerExport.cents(row['amount']),
      );
      final tags = row['tags'];
      rows[i + 9] = [
        value(row['transactionCode']),
        XlsxCell.date('${row['transactionDate']}', style: date),
        value(row['type'] == 'INCOME' ? 'Thu' : 'Chi'),
        value(financeCategoryLabel(row['category']?.toString())),
        XlsxCell.number(
          row['type'] == 'INCOME' ? amount : '0.00',
          style: money,
        ),
        XlsxCell.number(
          row['type'] == 'EXPENSE' ? amount : '0.00',
          style: money,
        ),
        value(financePaymentMethodLabel(row['paymentMethod']?.toString())),
        value(row['counterparty']),
        value(row['referenceType']),
        value(row['referenceId']),
        value(row['notes']),
        value(tags is List ? tags.join(' · ') : tags),
        value(row['receiptImageUrl']),
      ];
    }
    if (ledger.items.isEmpty) {
      rows[9] = [];
      rows[10] = [_label('Không có giao dịch trong phạm vi đã chọn.')];
    }
    return ReportXlsxWriter.build(
      sheetName: 'Sổ thu chi',
      widths: [18, 14, 8, 24, 20, 20, 18, 30, 20, 16, 48, 26, 40],
      rows: rows,
      merges: [
        'A1:H1',
        'A2:H2',
        'B4:H4',
        'B6:C6',
        'E6:F6',
        'A5:H5',
        if (ledger.items.isEmpty) 'A10:H10',
      ],
      dataCount: ledger.items.length,
      heights: {..._heights, 5: 48},
      printTitleStartRow: 8,
      printAreas: [
        'A1:H${ledger.items.isEmpty ? 10 : end}',
        if (ledger.items.isNotEmpty) 'I8:M$end',
      ],
      printHeader:
          'SỔ THU CHI · Cửa hàng #${ledger.shopId} · ${ledger.from} – ${ledger.to}',
    );
  }
}
