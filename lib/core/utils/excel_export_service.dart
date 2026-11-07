import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/finance/models/cash_ledger_export.dart';
import '../../features/finance/models/debt_aging_export.dart';
import '../../features/inventory/models/xnt_export.dart';
import '../../features/products/models/product_import.dart';
import '../../features/products/models/inventory_export.dart';
import 'finance_display.dart';
import 'report_xlsx_builder.dart';

class ExcelExportService {
  static Future<bool> downloadProductImportTemplate() async {
    try {
      final data = await rootBundle.load(productImportTemplateAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'Mau_nhap_san_pham',
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        return true;
      }
      return launchUrl(
        Uri.dataFromBytes(
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> exportXnt(
    XntExport report, {
    required String shopName,
  }) => _downloadXlsx(
    buildXntXlsx(report, shopName: shopName),
    'Nhap_Xuat_Ton_${report.shopId}_${report.from.replaceAll('-', '')}_${report.to.replaceAll('-', '')}.xlsx',
  );

  static Uint8List buildXntXlsx(
    XntExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) =>
      ReportXlsxBuilder.xnt(report, shopName: shopName, exportedAt: exportedAt);

  static String buildXntCsv(
    XntExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    String text(dynamic value) =>
        _csvCell(_safeSpreadsheetText(value?.toString() ?? ''));
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('BÁO CÁO NHẬP–XUẤT–TỒN - SMARTSTOCK');
    buffer.writeln(
      '"Ngày xuất",${text(DateFormat('dd/MM/yyyy HH:mm').format(exportedAt ?? DateTime.now()))}',
    );
    buffer.writeln('"Cửa hàng",${text(shopName)}');
    buffer.writeln('"Mã cửa hàng",${report.shopId}');
    buffer.writeln('"Từ ngày",${text(report.from)}');
    buffer.writeln('"Đến ngày",${text(report.to)}');
    buffer.writeln(
      '"Phạm vi kho",${text(report.warehouseId == null ? 'Tất cả kho' : 'Kho ID ${report.warehouseId}')}',
    );
    buffer.writeln('"Số sản phẩm",${report.items.length}');
    buffer.writeln('"SKU có tồn đầu",${report.summary['openingSkuCount']}');
    buffer.writeln('"SKU có nhập",${report.summary['importedSkuCount']}');
    buffer.writeln('"SKU có xuất",${report.summary['exportedSkuCount']}');
    buffer.writeln('"SKU còn tồn",${report.summary['closingSkuCount']}');
    buffer.writeln(
      '"Lưu ý","Theo ngày nghiệp vụ; không cộng tổng số lượng khác đơn vị. Đặt cột SKU dạng văn bản khi mở bằng Excel."',
    );
    buffer.writeln();
    buffer.writeln(
      'ID SẢN PHẨM,SKU,TÊN SẢN PHẨM,ĐƠN VỊ,TỒN ĐẦU,NHẬP,XUẤT,TỒN CUỐI',
    );
    for (final row in report.items) {
      buffer.writeln(
        [
          row['id'],
          text(row['sku']),
          text(row['name']),
          text(row['unit']),
          row['openingStock'],
          row['totalImport'],
          row['totalExport'],
          row['closingStock'],
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static Future<bool> exportCashLedger(
    CashLedgerExport ledger, {
    required String shopName,
  }) => _downloadXlsx(
    buildCashLedgerXlsx(ledger, shopName: shopName),
    'So_Thu_Chi_${ledger.shopId}_${ledger.from.replaceAll('-', '')}_${ledger.to.replaceAll('-', '')}.xlsx',
  );

  static Uint8List buildCashLedgerXlsx(
    CashLedgerExport ledger, {
    required String shopName,
    DateTime? exportedAt,
  }) => ReportXlsxBuilder.cashLedger(
    ledger,
    shopName: shopName,
    exportedAt: exportedAt,
  );

  static Future<bool> _downloadXlsx(Uint8List bytes, String filename) async {
    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: filename.replaceFirst(RegExp(r'\.xlsx$'), ''),
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        return true;
      }
      // Keep the existing native template/export handoff. The workbook bytes
      // and MIME remain XLSX; only the platform's download mechanism differs.
      return launchUrl(
        Uri.dataFromBytes(
          bytes,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static String buildCashLedgerCsv(
    CashLedgerExport ledger, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    String text(dynamic value) =>
        _csvCell(_safeSpreadsheetText(value?.toString() ?? ''));
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('SỔ THU CHI THEO KỲ - SMARTSTOCK');
    buffer.writeln(
      '"Ngày xuất",${text(DateFormat('dd/MM/yyyy HH:mm').format(exportedAt ?? DateTime.now()))}',
    );
    buffer.writeln('"Cửa hàng",${text(shopName)}');
    buffer.writeln('"Từ ngày",${text(ledger.from)}');
    buffer.writeln('"Đến ngày",${text(ledger.to)}');
    buffer.writeln(
      '"Bộ lọc",${text('${ledger.type == null
          ? 'Tất cả thu chi'
          : ledger.type == 'INCOME'
          ? 'Thu'
          : 'Chi'} · ${ledger.category == null ? 'Tất cả nhóm' : financeCategoryLabel(ledger.category)}')}',
    );
    buffer.writeln('"Số bản ghi",${ledger.items.length}');
    buffer.writeln(
      '"Tổng thu (VNĐ)",${CashLedgerExport.decimalAmount(ledger.incomeCents)}',
    );
    buffer.writeln(
      '"Tổng chi (VNĐ)",${CashLedgerExport.decimalAmount(ledger.expenseCents)}',
    );
    buffer.writeln(
      '"Dòng tiền thuần trong bộ lọc (VNĐ)",${CashLedgerExport.decimalAmount(ledger.incomeCents - ledger.expenseCents)}',
    );
    buffer.writeln(
      '"Phạm vi","Ngày ghi sổ; không phải số dư quỹ hoặc báo cáo lợi nhuận"',
    );
    buffer.writeln();
    buffer.writeln(
      'MÃ GIAO DỊCH,NGÀY GHI SỔ,LOẠI,NHÓM,THU (VNĐ),CHI (VNĐ),PHƯƠNG THỨC,ĐỐI TÁC,LOẠI CHỨNG TỪ,ID THAM CHIẾU,GHI CHÚ,NHÃN,ẢNH CHỨNG TỪ',
    );
    for (final row in ledger.items) {
      final amount = CashLedgerExport.decimalAmount(
        CashLedgerExport.cents(row['amount']),
      );
      final tags = row['tags'];
      buffer.writeln(
        [
          text(row['transactionCode']),
          text(row['transactionDate']),
          text(row['type'] == 'INCOME' ? 'Thu' : 'Chi'),
          text(financeCategoryLabel(row['category']?.toString())),
          row['type'] == 'INCOME' ? amount : '0.00',
          row['type'] == 'EXPENSE' ? amount : '0.00',
          text(financePaymentMethodLabel(row['paymentMethod']?.toString())),
          text(row['counterparty']),
          text(row['referenceType']),
          text(row['referenceId']),
          text(row['notes']),
          text(tags is List ? tags.join(' · ') : tags),
          text(row['receiptImageUrl']),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  /// Export Sales Orders to Excel CSV with UTF-8 BOM
  static Future<bool> exportOrdersToExcel(List<dynamic> orders) async {
    try {
      return await _downloadFile(
        buildOrdersCsv(orders),
        'Bao_Cao_Don_Hang_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } on FormatException {
      return false;
    }
  }

  static String buildOrdersCsv(List<dynamic> orders, {DateTime? exportedAt}) {
    final StringBuffer buffer = StringBuffer();
    // Add UTF-8 BOM byte sequence so Excel opens Vietnamese characters correctly
    buffer.write('\uFEFF');

    // Title Header
    buffer.writeln('BÁO CÁO DANH SÁCH ĐƠN HÀNG - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(exportedAt ?? DateTime.now())}',
    );
    buffer.writeln();

    // Table Header
    buffer.writeln(
      'MÃ ĐƠN,KHÁCH HÀNG,THỜI GIAN,PHƯƠNG THỨC,TỔNG TIỀN (VNĐ),TRẠNG THÁI',
    );

    int totalCents = 0;
    for (final order in orders) {
      String text(dynamic value) =>
          _csvCell(_safeSpreadsheetText(value?.toString() ?? ''));
      final code = order['orderCode'] ?? order['code'] ?? order['id'] ?? '';
      final customer =
          order['customer']?['name'] ?? order['customerName'] ?? 'Khách lẻ';
      final rawDate =
          (order['orderDate'] ?? order['transactionDate'] ?? order['createdAt'])
              ?.toString() ??
          '';
      final parsedDate = DateTime.tryParse(rawDate);
      final localDate = parsedDate?.isUtc == true
          ? parsedDate!.add(const Duration(hours: 7))
          : parsedDate;
      final date = localDate == null
          ? rawDate
          : DateFormat(
              rawDate.length <= 10 ? 'dd/MM/yyyy' : 'dd/MM/yyyy HH:mm',
            ).format(localDate);
      final amount = CashLedgerExport.cents(
        order['totalAmount'] ?? order['amount'],
      );
      totalCents += amount;
      if (totalCents.abs() > 9007199254740991) {
        throw const FormatException(
          'Tổng giá trị đơn vượt giới hạn xuất chính xác.',
        );
      }
      buffer.writeln(
        [
          text(code),
          text(customer),
          text(date),
          text(financePaymentMethodLabel(order['paymentMethod']?.toString())),
          CashLedgerExport.decimalAmount(amount),
          text(order['status']),
        ].join(','),
      );
    }

    buffer.writeln();
    buffer.writeln(
      'TỔNG GIÁ TRỊ ĐƠN TRONG DANH SÁCH,,,,${CashLedgerExport.decimalAmount(totalCents)},',
    );
    return buffer.toString();
  }

  /// Export the complete scoped receivables result as a typed Excel workbook.
  static Future<bool> exportCustomerDebtsToExcel(
    List<dynamic> debts, {
    int? shopId,
    String? shopName,
    String? filterDescription,
  }) {
    return _downloadXlsx(
      buildCustomerDebtsXlsx(
        debts,
        shopId: shopId,
        shopName: shopName,
        filterDescription: filterDescription,
      ),
      'So_No_Khach_Hang_${shopId == null ? '' : '${shopId}_'}${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
  }

  static Uint8List buildCustomerDebtsXlsx(
    List<dynamic> debts, {
    int? shopId,
    String? shopName,
    String? filterDescription,
    DateTime? exportedAt,
  }) => ReportXlsxBuilder.customerDebts(
    debts,
    shopId: shopId,
    shopName: shopName,
    filterDescription: filterDescription,
    exportedAt: exportedAt,
  );

  static Future<bool> exportDebtAgingToExcel(
    DebtAgingExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    final exportTime = exportedAt ?? DateTime.now();
    return _downloadXlsx(
      buildDebtAgingXlsx(report, shopName: shopName, exportedAt: exportTime),
      'Bao_Cao_Tuoi_No_${report.shopId}_${report.asOf.replaceAll('-', '')}.xlsx',
    );
  }

  static Uint8List buildDebtAgingXlsx(
    DebtAgingExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) => ReportXlsxBuilder.debtAging(
    report,
    shopName: shopName,
    exportedAt: exportedAt,
  );

  static String buildDebtAgingCsv(
    Map<String, dynamic> report, {
    DateTime? exportedAt,
  }) {
    final exportTime = exportedAt ?? DateTime.now();
    final buckets = Map<String, dynamic>.from(
      report['buckets'] as Map? ?? const {},
    );
    final customers = (report['customers'] as List?) ?? const [];
    num amount(String key) => num.tryParse(buckets[key]?.toString() ?? '') ?? 0;

    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('BÁO CÁO PHÂN TÍCH TUỔI NỢ KHÁCH HÀNG - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(exportTime)}',
    );
    buffer.writeln(
      'Ngày đối chiếu: ${_csvCell(report['asOf']?.toString() ?? '')}',
    );
    if (report['balanceBasis'] == 'CURRENT') {
      buffer.writeln(
        '"Cơ sở số dư",${_csvCell('Dư nợ hiện tại tại ${report['balanceAsOf'] ?? ''}; ngày đối chiếu dùng để phân nhóm tuổi nợ.')}',
      );
    }
    buffer.writeln();
    buffer.writeln('NHÓM NỢ,SỐ TIỀN (VNĐ)');
    buffer.writeln('${_csvCell('Chưa đến hạn')},${amount('current')}');
    buffer.writeln('${_csvCell('Quá hạn 1-30 ngày')},${amount('past30')}');
    buffer.writeln('${_csvCell('Quá hạn 31-60 ngày')},${amount('past60')}');
    buffer.writeln('${_csvCell('Quá hạn trên 60 ngày')},${amount('past90')}');
    buffer.writeln('${_csvCell('Tổng dư nợ')},${report['totalDebt'] ?? 0}');
    buffer.writeln();
    buffer.writeln(
      'KHÁCH HÀNG,TỔNG DƯ NỢ (VNĐ),CHƯA ĐẾN HẠN,QUÁ HẠN 1-30,QUÁ HẠN 31-60,QUÁ HẠN TRÊN 60,SỐ NGÀY QUÁ HẠN TỐI ĐA,LẦN TRẢ GẦN NHẤT',
    );
    for (final raw in customers) {
      final item = Map<String, dynamic>.from(raw as Map);
      final name = _safeSpreadsheetText(
        item['customerName']?.toString() ?? 'Khách hàng',
      );
      buffer.writeln(
        '${_csvCell(name)},${item['total'] ?? 0},${item['current'] ?? 0},'
        '${item['past30'] ?? 0},${item['past60'] ?? 0},${item['past90'] ?? 0},'
        '${item['overdueDays'] ?? 0},${_csvCell(item['lastPaymentDate']?.toString() ?? '')}',
      );
    }

    return buffer.toString();
  }

  /// Builds a deterministic, Excel-compatible CSV for the receivables ledger.
  ///
  /// Kept separate from the browser download so field escaping and control
  /// totals can be covered by unit tests.
  static String buildCustomerDebtsCsv(
    List<dynamic> debts, {
    DateTime? exportedAt,
    String? shopName,
    String? filterDescription,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('\uFEFF');
    final exportTime = exportedAt ?? DateTime.now();

    buffer.writeln('SỔ THEO DÕI NỢ KHÁCH HÀNG MUA CHỊU - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(exportTime)}',
    );
    if (shopName != null && shopName.trim().isNotEmpty) {
      buffer.writeln('"Cửa hàng",${_csvCell(_safeSpreadsheetText(shopName))}');
    }
    if (filterDescription != null && filterDescription.trim().isNotEmpty) {
      buffer.writeln(
        '"Bộ lọc",${_csvCell(_safeSpreadsheetText(filterDescription))}',
      );
    }
    buffer.writeln('"Số bản ghi",${debts.length}');
    buffer.writeln();

    buffer.writeln(
      'TÊN KHÁCH HÀNG,SỐ ĐIỆN THOẠI,MÃ ĐƠN NỢ,NGÀY MUA,NỢ GỐC (VNĐ),ĐÃ THU (VNĐ),ĐIỀU CHỈNH ĐẦU KỲ (VNĐ),CÒN NỢ (VNĐ)',
    );

    int totalRemainingCents = 0;
    for (final item in debts) {
      final name = _safeSpreadsheetText(
        (item['customerName'] ?? 'Khách lẻ').toString(),
      );
      final phone = _safeSpreadsheetText(
        item['customerPhone']?.toString() ?? '',
      );
      final code = _safeSpreadsheetText(item['orderCode']?.toString() ?? '');
      final parsedDate = DateTime.tryParse(item['createdAt']?.toString() ?? '');
      final date = parsedDate == null
          ? ''
          : DateFormat('dd/MM/yyyy').format(parsedDate);
      final total = CashLedgerExport.cents(item['totalAmount']);
      final paid = CashLedgerExport.cents(item['paidAmount'] ?? 0);
      final adjustment = CashLedgerExport.cents(
        item['openingAdjustmentAmount'] ?? 0,
        signed: true,
      );
      final calculated = total - paid + adjustment;
      final remaining = item['remaining'] == null
          ? (calculated < 0 ? 0 : calculated)
          : CashLedgerExport.cents(item['remaining']);
      totalRemainingCents += remaining;
      if (totalRemainingCents > 9007199254740991) {
        throw const FormatException(
          'Tổng công nợ vượt giới hạn xuất chính xác',
        );
      }

      buffer.writeln(
        '${_csvCell(name)},${_csvCell(phone)},${_csvCell(code)},'
        '${_csvCell(date)},${CashLedgerExport.decimalAmount(total)},'
        '${CashLedgerExport.decimalAmount(paid)},${CashLedgerExport.decimalAmount(adjustment)},'
        '${CashLedgerExport.decimalAmount(remaining)}',
      );
    }

    buffer.writeln();
    buffer.writeln(
      'TỔNG NỢ CẦN THU CÒN LẠI,,,,,,,${CashLedgerExport.decimalAmount(totalRemainingCents)}',
    );

    return buffer.toString();
  }

  /// Build Inventory CSV content with UTF-8 BOM, normalized fields and formula safety
  static String buildInventoryCsv(
    List<dynamic> products, {
    DateTime? exportedAt,
  }) {
    final exportTime = exportedAt ?? DateTime.now();
    final StringBuffer buffer = StringBuffer('\uFEFF');

    buffer.writeln('BÁO CÁO KIỂM KÊ TỒN KHO - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(exportTime)}',
    );
    buffer.writeln();

    buffer.writeln(
      'MÃ SẢN PHẨM,TÊN SẢN PHẨM,ĐƠN VỊ,SỐ LƯỢNG TỒN,MỨC TỐI THIỂU,GIÁ BÁN (VNĐ),TRẠNG THÁI',
    );

    for (final p in products) {
      final code = _safeSpreadsheetText(
        (p['sku'] ?? p['barcode'] ?? p['id'] ?? '').toString(),
      );
      final name = _safeSpreadsheetText((p['name'] ?? '').toString());
      final unit = _safeSpreadsheetText((p['unit'] ?? 'Cái').toString());

      final rawStock = p['currentStock'] ?? p['stockQuantity'] ?? p['stock'];
      final rawMinStock =
          p['minStock'] ??
          p['minimumStock'] ??
          p['minStockThreshold'] ??
          p['min_stock'];
      final rawPrice = p['sellingPrice'] ?? p['sellPrice'] ?? p['retailPrice'];

      final num? stock = rawStock == null
          ? null
          : num.tryParse(rawStock.toString());
      final num? minStock = rawMinStock == null
          ? null
          : num.tryParse(rawMinStock.toString());
      final double? price = rawPrice == null
          ? null
          : num.tryParse(rawPrice.toString())?.toDouble();

      final String stockStr = stock != null ? stock.toString() : '';
      final String minStockStr = minStock != null ? minStock.toString() : '';
      final String priceStr = price != null ? price.toString() : '';

      final String status;
      if (stock == null) {
        status = 'Chưa có số liệu';
      } else if (stock <= 0) {
        status = 'Hết hàng';
      } else if (minStock != null && minStock > 0 && stock <= minStock) {
        status = 'Cần nhập thêm';
      } else {
        status = 'An toàn';
      }

      buffer.writeln(
        '${_csvCell(code)},${_csvCell(name)},${_csvCell(unit)},$stockStr,$minStockStr,$priceStr,${_csvCell(status)}',
      );
    }

    return buffer.toString();
  }

  /// Export a validated server snapshot, including the user's selection.
  static Future<bool> exportInventoryToExcel(
    InventoryExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) {
    final exportTime = exportedAt ?? DateTime.now();
    return _downloadXlsx(
      buildInventoryXlsx(report, shopName: shopName, exportedAt: exportTime),
      'Bao_Cao_Ton_Kho_${report.shopId}_${DateFormat('yyyyMMdd').format(exportTime)}.xlsx',
    );
  }

  static Uint8List buildInventoryXlsx(
    InventoryExport report, {
    required String shopName,
    DateTime? exportedAt,
  }) => ReportXlsxBuilder.inventory(
    report,
    shopName: shopName,
    exportedAt: exportedAt,
  );

  static String _safeSpreadsheetText(String value) {
    final trimmedLeft = value.trimLeft();
    if (trimmedLeft.startsWith('=') ||
        trimmedLeft.startsWith('+') ||
        trimmedLeft.startsWith('-') ||
        trimmedLeft.startsWith('@') ||
        trimmedLeft.startsWith('\t') ||
        trimmedLeft.startsWith('\r')) {
      return "'$value";
    }
    return value;
  }

  static String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  static Future<bool> _downloadFile(String content, String fileName) async {
    try {
      final bytes = utf8.encode(content);
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName.replaceFirst(RegExp(r'\.csv$'), ''),
          bytes: Uint8List.fromList(bytes),
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
        // The browser accepted the download request; it owns final disk saving.
        return true;
      }
      final uri = Uri.dataFromBytes(
        bytes,
        mimeType: 'text/csv',
        parameters: {'charset': 'utf-8'},
      );
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
