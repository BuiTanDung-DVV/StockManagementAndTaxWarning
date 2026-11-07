import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/order_debt_balance.dart';
import '../../sales/services/receipt_pdf_service.dart' show formatReceiptDate;

final purchaseOrderPdfExporterProvider = Provider<PurchaseOrderPdfExporter>(
  (_) => PurchaseOrderPdfExporter(),
);

class PurchaseOrderPdfExporter {
  Future<Uint8List> build({
    required Map<String, dynamic> order,
    required String shopName,
    DateTime? generatedAt,
  }) async {
    num number(dynamic value) {
      final parsed = num.tryParse('$value');
      if (parsed == null || !parsed.isFinite) {
        throw const FormatException('Số liệu phiếu nhập không hợp lệ');
      }
      return parsed;
    }

    String money(dynamic value) {
      final amount = number(value);
      return NumberFormat.currency(
        locale: 'vi_VN',
        symbol: 'đ',
        decimalDigits: amount % 1 == 0 ? 0 : 2,
      ).format(amount);
    }

    String day(dynamic value) {
      final formatted = formatReceiptDate(value);
      return RegExp(r'^\d{2}/\d{2}/\d{4}').firstMatch(formatted)?.group(0) ??
          formatted;
    }

    String text(dynamic value, [String fallback = '']) =>
        value?.toString().trim().isNotEmpty == true
        ? value.toString().trim()
        : fallback;
    final code = text(order['orderCode'], 'PO-${order['id']}');
    final status = text(order['status']).toUpperCase();
    final statusLabel = switch (status) {
      'PENDING' => 'CHỜ NHẬP KHO - BẢN DỰ KIẾN',
      'COMPLETED' => 'ĐÃ NHẬP KHO',
      'CANCELLED' => 'ĐÃ HỦY - KHÔNG GHI NHẬN NHẬP KHO',
      _ => throw const FormatException('Trạng thái phiếu nhập không hợp lệ'),
    };
    final items = (order['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (items.isEmpty || items.length > 500) {
      throw const FormatException('Phiếu nhập cần từ 1 đến 500 dòng hàng');
    }
    for (final key in ['subtotal', 'totalAmount', 'paidAmount']) {
      if (number(order[key]) < 0) {
        throw const FormatException('Số tiền phiếu nhập không được âm');
      }
    }
    BigInt cents(dynamic raw) {
      final match = RegExp(
        r'^(\d+)(?:\.(\d{1,2}))?$',
      ).firstMatch('$raw'.trim());
      if (match == null) {
        throw const FormatException(
          'Số tiền phiếu nhập cần tối đa hai chữ số thập phân',
        );
      }
      return BigInt.parse(match.group(1)!) * BigInt.from(100) +
          BigInt.parse((match.group(2) ?? '').padRight(2, '0'));
    }

    var lineTotal = BigInt.zero;
    for (final item in items) {
      final quantity = number(item['quantity']);
      if (quantity <= 0 ||
          quantity != quantity.truncateToDouble() ||
          number(item['unitPrice']) < 0 ||
          number(item['subtotal']) < 0) {
        throw const FormatException('Dòng hàng phiếu nhập không hợp lệ');
      }
      final subtotal = cents(item['subtotal']);
      if (cents(item['unitPrice']) * BigInt.from(quantity) != subtotal) {
        throw const FormatException(
          'Thành tiền dòng hàng chưa khớp số lượng và đơn giá',
        );
      }
      lineTotal += subtotal;
    }
    if (lineTotal != cents(order['subtotal']) ||
        cents(order['totalAmount']) !=
            lineTotal -
                cents(order['discountAmount'] ?? 0) +
                cents(order['taxAmount'] ?? 0)) {
      throw const FormatException(
        'Tổng tiền phiếu nhập chưa khớp các dòng hàng',
      );
    }
    final supplier = order['supplier'] is Map
        ? order['supplier'] as Map
        : const {};
    final balance = OrderDebtBalance.fromMap(order, purchase: true);
    final reconciled =
        order['debtBalanceBasis'] == 'LEDGER' &&
        balance.remaining != null &&
        balance.basis != 'ORDER';
    final generated = formatReceiptDate(
      (generatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    );
    final noteStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);
    pw.Widget amountRow(String label, String value, {bool emphasis = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 3, child: pw.Text(label)),
              pw.SizedBox(width: 16),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  value,
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontWeight: emphasis
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                    fontSize: emphasis ? 13 : 10,
                  ),
                ),
              ),
            ],
          ),
        );
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 32),
        maxPages: 100,
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
        ).copyWith(defaultTextStyle: pw.TextStyle(font: regular, fontSize: 10)),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PHIẾU NHẬP HÀNG',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(code),
                  ],
                ),
              ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$code | Tạo lúc $generated', style: noteStyle),
              pw.Text(
                'Trang ${context.pageNumber}/${context.pagesCount}',
                style: noteStyle,
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Text(
            shopName.trim().isEmpty ? 'Cửa hàng #${order['shopId']}' : shopName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'PHIẾU NHẬP HÀNG',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Chứng từ quản lý nội bộ', style: noteStyle),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey100,
            child: pw.Text(
              statusLabel,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Mã đơn: $code'),
          pw.Text('Ngày nhập: ${day(order['orderDate'])}'),
          if (text(order['paymentDueDate']).isNotEmpty)
            pw.Text('Hạn thanh toán: ${day(order['paymentDueDate'])}'),
          if (text(order['invoiceNumber']).isNotEmpty)
            pw.Text('Số hóa đơn/chứng từ gốc: ${order['invoiceNumber']}'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Nhà cung cấp: ${text(supplier['name'], text(order['supplierName'], 'Chưa có tên nhà cung cấp'))}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (text(supplier['phone']).isNotEmpty)
            pw.Text('Điện thoại: ${supplier['phone']}'),
          if (text(supplier['address']).isNotEmpty)
            pw.Text('Địa chỉ: ${supplier['address']}'),
          if (order['warehouseId'] != null)
            pw.Text('Kho nhập: #${order['warehouseId']}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'STT',
              'Sản phẩm / Mã hàng',
              'SL',
              'Đơn giá',
              'Thành tiền',
            ],
            data: [
              for (var i = 0; i < items.length; i++)
                [
                  '${i + 1}',
                  '${text((items[i]['product'] as Map?)?['name'], 'Sản phẩm #${items[i]['productId']}')}\n${text((items[i]['product'] as Map?)?['sku'])}${text((items[i]['product'] as Map?)?['unit']).isEmpty ? '' : ' | ĐVT: ${(items[i]['product'] as Map)['unit']}'}',
                  NumberFormat.decimalPattern(
                    'vi_VN',
                  ).format(number(items[i]['quantity'])),
                  money(items[i]['unitPrice']),
                  money(items[i]['subtotal']),
                ],
            ],
            columnWidths: {
              0: const pw.FlexColumnWidth(.6),
              1: const pw.FlexColumnWidth(4.1),
              2: const pw.FlexColumnWidth(.6),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1.9),
            },
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(7),
            cellAlignments: {
              0: pw.Alignment.topCenter,
              1: pw.Alignment.topLeft,
              2: pw.Alignment.topRight,
              3: pw.Alignment.topRight,
              4: pw.Alignment.topRight,
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              children: [
                amountRow('Tiền hàng', money(order['subtotal'])),
                amountRow('Giảm giá', money(order['discountAmount'] ?? 0)),
                amountRow('Thuế hàng hóa', money(order['taxAmount'] ?? 0)),
                amountRow(
                  'Tổng tiền đơn',
                  money(order['totalAmount']),
                  emphasis: true,
                ),
                pw.Divider(color: PdfColors.grey300),
                amountRow('Đã trả thực tế', money(order['paidAmount'] ?? 0)),
                if (balance.adjustment != 0)
                  amountRow(
                    'Điều chỉnh công nợ đầu kỳ',
                    '${balance.adjustment > 0 ? '+' : ''}${money(balance.adjustment)}',
                  ),
                if (status == 'PENDING')
                  pw.Text(
                    'Chưa ghi nhận công nợ. Số lượng trên phiếu chưa được nhập kho.',
                    style: noteStyle,
                  )
                else if (status == 'CANCELLED')
                  pw.Text(
                    'Đơn đã hủy; phiếu không xác nhận hàng đã nhập kho.',
                    style: noteStyle,
                  )
                else if (balance.basis == 'NOT_EFFECTIVE')
                  pw.Text(
                    'Khoản công nợ chưa đến ngày có hiệu lực.',
                    style: noteStyle,
                  )
                else
                  amountRow(
                    'Còn phải trả',
                    reconciled ? money(balance.remaining) : 'Cần đối chiếu',
                    emphasis: true,
                  ),
                if (balance.adjustment != 0)
                  pw.Text(
                    'Khoản điều chỉnh công nợ không phải tiền đã trả.',
                    style: noteStyle,
                  ),
                if (status == 'COMPLETED' && !reconciled)
                  pw.Text(
                    'Số liệu đơn và công nợ chưa đủ căn cứ hoặc chưa khớp. Cần đối chiếu trước khi trả thêm.',
                    style: noteStyle,
                  ),
                if (order['balanceAsOf'] != null)
                  pw.Text(
                    'Số liệu công nợ đến ${formatReceiptDate(order['balanceAsOf'])}.',
                    style: noteStyle,
                  ),
              ],
            ),
          ),
          if (text(order['notes']).isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Ghi chú: ${order['notes']}'),
          ],
          if (status == 'COMPLETED') ...[
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                for (final role in ['Người giao hàng', 'Người nhận hàng'])
                  pw.Column(
                    children: [
                      pw.Text(
                        role,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('(Ký, ghi rõ họ tên)', style: noteStyle),
                      pw.SizedBox(height: 45),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return document.save();
  }

  String fileName(Map<String, dynamic> order) {
    final safe = '${order['orderCode'] ?? order['id']}'.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return 'Phieu_nhap_$safe.pdf';
  }

  Future<void> save(Uint8List bytes, String filename) async {
    await FileSaver.instance.saveFile(
      name: filename.replaceFirst(RegExp(r'\.pdf$'), ''),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
