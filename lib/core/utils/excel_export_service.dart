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

  static Future<bool> exportDebtAgingToExcel(
    Map<String, dynamic> report, {
    DateTime? exportedAt,
  }) {
    final exportTime = exportedAt ?? DateTime.now();
    return _downloadFile(
      buildDebtAgingCsv(report, exportedAt: exportTime),
      'Bao_Cao_Tuoi_No_${DateFormat('yyyyMMdd').format(exportTime)}.csv',
    );
  }

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
