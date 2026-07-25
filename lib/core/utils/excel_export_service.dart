import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ExcelExportService {
  /// Export Sales Orders to Excel CSV with UTF-8 BOM
  static void exportOrdersToExcel(List<dynamic> orders) {
    final StringBuffer buffer = StringBuffer();
    // Add UTF-8 BOM byte sequence so Excel opens Vietnamese characters correctly
    buffer.write('\uFEFF');

    // Title Header
    buffer.writeln('BÁO CÁO DANH SÁCH ĐƠN HÀNG - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    buffer.writeln();

    // Table Header
    buffer.writeln(
      'MÃ ĐƠN,KHÁCH HÀNG,THỜI GIAN,PHƯƠNG THỨC,TỔNG TIỀN (VNĐ),TRẠNG THÁI',
    );

    double totalRevenue = 0;
    for (final order in orders) {
      final code = order['code'] ?? order['id'] ?? '';
      final customer = (order['customer']?['name'] ?? 'Khách lẻ')
          .toString()
          .replaceAll(',', ' ');
      final date = order['createdAt'] != null
          ? DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(DateTime.tryParse(order['createdAt']) ?? DateTime.now())
          : '';
      final method = order['paymentMethod'] ?? 'CASH';
      final total =
          num.tryParse(order['totalAmount']?.toString() ?? '0')?.toDouble() ??
          0.0;
      final status = order['status'] ?? 'COMPLETED';

      totalRevenue += total;

      buffer.writeln('"$code","$customer","$date","$method",$total,"$status"');
    }

    buffer.writeln();
    buffer.writeln('TỔNG CỘNG DOANH THU,,,,$totalRevenue,');

    _downloadFile(
      buffer.toString(),
      'Bao_Cao_Don_Hang_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  /// Export Customer Debt Ledger to Excel CSV
  static Future<bool> exportCustomerDebtsToExcel(List<dynamic> debts) {
    return _downloadFile(
      buildCustomerDebtsCsv(debts),
      'So_No_Khach_Hang_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  /// Builds a deterministic, Excel-compatible CSV for the receivables ledger.
  ///
  /// Kept separate from the browser download so field escaping and control
  /// totals can be covered by unit tests.
  static String buildCustomerDebtsCsv(
    List<dynamic> debts, {
    DateTime? exportedAt,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('\uFEFF');
    final exportTime = exportedAt ?? DateTime.now();

    buffer.writeln('SỔ THEO DÕI NỢ KHÁCH HÀNG MUA CHỊU - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(exportTime)}',
    );
    buffer.writeln();

    buffer.writeln(
      'TÊN KHÁCH HÀNG,SỐ ĐIỆN THOẠI,MÃ ĐƠN NỢ,NGÀY MUA,TỔNG NỢ (VNĐ),ĐÃ TRẢ (VNĐ),CÒN NỢ (VNĐ)',
    );

    double totalRemainingDebt = 0;
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
      final total =
          num.tryParse(item['totalAmount']?.toString() ?? '0')?.toDouble() ??
          0.0;
      final paid =
          num.tryParse(item['paidAmount']?.toString() ?? '0')?.toDouble() ??
          0.0;
      final remaining = (total - paid).clamp(0, double.infinity).toDouble();

      totalRemainingDebt += remaining;

      buffer.writeln(
        '${_csvCell(name)},${_csvCell(phone)},${_csvCell(code)},'
        '${_csvCell(date)},$total,$paid,$remaining',
      );
    }

    buffer.writeln();
    buffer.writeln('TỔNG NỢ CẦN THU CÒN LẠI,,,,,,$totalRemainingDebt');

    return buffer.toString();
  }

  /// Export Inventory Items to Excel CSV
  static void exportInventoryToExcel(List<dynamic> products) {
    final StringBuffer buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('BÁO CÁO KIỂM KÊ TỒN KHO - SMARTSTOCK');
    buffer.writeln(
      'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
    );
    buffer.writeln();

    buffer.writeln(
      'MÃ SẢN PHẨM,TÊN SẢN PHẨM,ĐƠN VỊ,SỐ LƯỢNG TỒN,MỨC TỐI THIỂU,GIÁ BÁN (VNĐ),TRẠNG THÁI',
    );

    for (final p in products) {
      final code = p['sku'] ?? p['barcode'] ?? p['id'] ?? '';
      final name = (p['name'] ?? '').toString().replaceAll(',', ' ');
      final unit = p['unit'] ?? 'Cái';
      final stock = p['stockQuantity'] ?? 0;
      final minStock = p['minStockThreshold'] ?? 5;
      final price =
          num.tryParse(p['sellingPrice']?.toString() ?? '0')?.toDouble() ?? 0.0;
      final status = stock <= 0
          ? 'Hết hàng'
          : (stock <= minStock ? 'Cần nhập thêm' : 'An toàn');

      buffer.writeln(
        '"$code","$name","$unit",$stock,$minStock,$price,"$status"',
      );
    }

    _downloadFile(
      buffer.toString(),
      'Bao_Cao_Ton_Kho_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

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

  static Future<bool> _downloadFile(String content, String fileName) {
    final bytes = utf8.encode(content);
    final uri = Uri.dataFromBytes(bytes, mimeType: 'text/csv;charset=utf-8');
    return launchUrl(uri);
  }
}
