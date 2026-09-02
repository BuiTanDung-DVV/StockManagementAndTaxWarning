import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfService {
  static Future<Uint8List> build({
    required Map<String, dynamic> order,
    required Map<String, dynamic> profile,
    Map<String, dynamic>? config,
  }) async {
    final settings =
        config ??
        Map<String, dynamic>.from(
          profile['receiptTemplateConfig'] as Map? ?? const {},
        );
    final a4 = settings['paperSize'] == 'A4';
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final document = pw.Document();
    final items = (order['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    String money(dynamic value) =>
        currency.format(num.tryParse(value?.toString() ?? '') ?? 0);
    pw.ImageProvider? logo;
    pw.ImageProvider? qr;
    try {
      if (settings['showLogo'] != false && profile['logoUrl'] != null) {
        logo = await networkImage(profile['logoUrl'].toString());
      }
      if (settings['showQr'] != false && profile['qrPaymentUrl'] != null) {
        qr = await networkImage(profile['qrPaymentUrl'].toString());
      }
    } catch (_) {
      // PDF remains usable when a remote image is unavailable.
    }
    final receiptHeightMm =
        170 +
        (items.length * 10) +
        (logo == null ? 0 : 20) +
        (qr == null ? 0 : 45);
    final format = a4
        ? PdfPageFormat.a4
        : PdfPageFormat(
            80 * PdfPageFormat.mm,
            receiptHeightMm * PdfPageFormat.mm,
          );
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.all(a4 ? 28 : 10),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => [
          pw.Center(
            child: pw.Column(
              children: [
                if (logo != null) pw.Image(logo, width: 52, height: 52),
                pw.Text(
                  settings['title']?.toString() ?? 'PHIẾU BÁN HÀNG',
                  style: pw.TextStyle(font: bold, fontSize: a4 ? 18 : 12),
                ),
                if (settings['showShopInfo'] != false) ...[
                  pw.Text(profile['shopName']?.toString() ?? 'Cửa hàng'),
                  if (profile['address'] != null)
                    pw.Text(profile['address'].toString()),
                  if (profile['phone'] != null)
                    pw.Text('Điện thoại: ${profile['phone']}'),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Mã đơn: ${order['orderCode'] ?? order['id'] ?? ''}'),
          pw.Text('Ngày bán: ${order['orderDate'] ?? ''}'),
          if (settings['showCustomer'] != false)
            pw.Text(
              'Khách hàng: ${(order['customer'] as Map?)?['name'] ?? 'Khách lẻ'}',
            ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold),
            cellStyle: pw.TextStyle(font: regular, fontSize: a4 ? 9 : 7),
            headers: [
              'Hàng hóa',
              if (settings['showSku'] != false) 'SKU',
              'SL',
              'Đơn giá',
              'Thành tiền',
            ],
            data: items.map((item) {
              final product = item['product'] as Map?;
              return [
                product?['name'] ?? item['itemName'] ?? 'Sản phẩm',
                if (settings['showSku'] != false) product?['sku'] ?? '',
                item['quantity'] ?? 0,
                money(item['unitPrice']),
                money(item['subtotal']),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Tiền hàng: ${money(order['subtotal'])}'),
                if (settings['showDiscount'] != false)
                  pw.Text('Chiết khấu: ${money(order['discountAmount'])}'),
                pw.Text('Thuế: ${money(order['taxAmount'])}'),
                if ((num.tryParse(order['shippingFee']?.toString() ?? '') ??
                        0) >
                    0)
                  pw.Text('Phí giao hàng: ${money(order['shippingFee'])}'),
                pw.Text(
                  'Cần thanh toán: ${money(order['totalAmount'])}',
                  style: pw.TextStyle(font: bold),
                ),
                if (settings['showPayment'] != false)
                  pw.Text('Đã thanh toán: ${money(order['paidAmount'])}'),
              ],
            ),
          ),
          if (qr != null) ...[
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Image(qr, width: 100, height: 100)),
          ],
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.Text(
              settings['footer']?.toString().trim().isNotEmpty == true
                  ? settings['footer'].toString()
                  : profile['receiptFooter']?.toString() ?? 'Cảm ơn quý khách!',
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Đây là phiếu bán hàng, không thay thế hóa đơn điện tử hợp pháp.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return document.save();
  }
}
