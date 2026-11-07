import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/order_debt_balance.dart';
import '../models/receipt_template_config.dart';

class ReceiptImageException implements Exception {
  final String message;
  const ReceiptImageException(this.message);
  @override
  String toString() => message;
}

class ReceiptPdfService {
  static final _fonts = <String, Future<pw.Font>>{};
  static Future<pw.Font> _font(String path) => _fonts.putIfAbsent(
    path,
    () async => pw.Font.ttf(await rootBundle.load(path)),
  );

  static Future<Uint8List> build({
    required Map<String, dynamic> order,
    required Map<String, dynamic> profile,
    Map<String, dynamic>? config,
    Uint8List? logoBytes,
    Future<pw.ImageProvider> Function(String)? imageLoader,
  }) async {
    final rawConfig =
        config ??
        Map<String, dynamic>.from(
          profile['receiptTemplateConfig'] as Map? ?? const {},
        );
    final settings = ReceiptTemplateConfig.normalize(rawConfig);
    final a4 = settings['paperSize'] == 'A4';
    final family = settings['fontFamily'] == 'inter' ? 'Inter' : 'NotoSans';
    final fonts = await Future.wait([
      _font('assets/fonts/$family-Regular.ttf'),
      _font('assets/fonts/$family-Bold.ttf'),
    ]);
    final regular = fonts[0], bold = fonts[1];
    final fontSize = settings['fontSize'] as double;
    final spacing = settings['lineSpacing'] as double;
    final margin = (settings['marginMm'] as double) * PdfPageFormat.mm;
    final pageWidth = a4 ? PdfPageFormat.a4.width : PdfPageFormat.roll80.width;
    final contentWidth = pageWidth - margin * 2;
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
    final loader = imageLoader ?? (String url) => networkImage(url);
    Future<pw.ImageProvider?> loadImage(String? url, String label) async {
      if (url == null || url.trim().isEmpty) return null;
      try {
        return await loader(url).timeout(const Duration(seconds: 8));
      } catch (_) {
        throw ReceiptImageException(
          'Không tải được $label. Vui lòng thử lại hoặc tắt phần ảnh này trong mẫu phiếu.',
        );
      }
    }

    final source = settings['logoSource'];
    final showLogo = settings['showLogo'] == true && source != 'none';
    final logoUrl = source == 'custom'
        ? settings['logoUrl'] as String
        : profile['logoUrl']?.toString();
    final images = await Future.wait([
      showLogo && logoBytes != null
          ? Future<pw.ImageProvider?>.value(pw.MemoryImage(logoBytes))
          : loadImage(showLogo ? logoUrl : null, 'logo phiếu'),
      loadImage(
        settings['showQr'] == true ? profile['qrPaymentUrl']?.toString() : null,
        'QR của cửa hàng',
      ),
    ]);
    final logo = images[0], qr = images[1];
    final baseTheme = pw.ThemeData.withFont(base: regular, bold: bold);
    final theme = baseTheme.copyWith(
      defaultTextStyle: baseTheme.defaultTextStyle.copyWith(
        fontSize: fontSize,
        lineSpacing: spacing,
      ),
    );
    pw.Alignment alignment(String key) => switch (settings[key]) {
      'left' => pw.Alignment.centerLeft,
      'right' => pw.Alignment.centerRight,
      _ => pw.Alignment.center,
    };
    pw.TextAlign textAlign(String key) => switch (settings[key]) {
      'left' => pw.TextAlign.left,
      'right' => pw.TextAlign.right,
      _ => pw.TextAlign.center,
    };
    pw.Widget headerText(String value, {bool title = false}) => pw.Container(
      width: double.infinity,
      alignment: alignment('headerAlignment'),
      child: pw.Text(
        value,
        textAlign: textAlign('headerAlignment'),
        style: title
            ? pw.TextStyle(
                font: bold,
                fontSize: settings['titleSize'] as double,
              )
            : null,
      ),
    );
    final debt = OrderDebtBalance.fromMap(order);
    final showNumber = settings['showItemNumber'] == true;
    final showSku = settings['showSku'] == true;
    final showUnit = settings['showUnit'] == true;
    String unit(Map item) =>
        '${(item['product'] as Map?)?['unit'] ?? item['unit'] ?? ''}';
    String name(Map item) =>
        '${(item['product'] as Map?)?['name'] ?? item['itemName'] ?? 'Sản phẩm'}';
    pw.Widget totalLine(String label, String value, {bool strong = false}) =>
        pw.Padding(
          padding: pw.EdgeInsets.only(top: 2 + spacing),
          child: !a4 && contentWidth < fontSize * 18
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      label,
                      style: strong ? pw.TextStyle(font: bold) : null,
                    ),
                    pw.Text(
                      value,
                      textAlign: pw.TextAlign.right,
                      style: strong ? pw.TextStyle(font: bold) : null,
                    ),
                  ],
                )
              : pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        label,
                        style: strong ? pw.TextStyle(font: bold) : null,
                      ),
                    ),
                    pw.SizedBox(width: 8),
              pw.Expanded(
                      child: pw.Text(
                        value,
                        textAlign: pw.TextAlign.right,
                        style: strong ? pw.TextStyle(font: bold) : null,
                      ),
                    ),
                  ],
                ),
        );
    List<pw.Widget> content(pw.Context context) => [
      if (logo != null)
        pw.Container(
          width: double.infinity,
          alignment: alignment('logoPosition'),
          padding: pw.EdgeInsets.only(bottom: 6 + spacing),
          child: pw.Image(
            logo,
            width: math.min(
              (settings['logoWidthMm'] as double) * PdfPageFormat.mm,
              contentWidth,
            ),
            height: (settings['logoHeightMm'] as double) * PdfPageFormat.mm,
            fit: pw.BoxFit.contain,
          ),
        ),
      headerText(settings['title'] as String, title: true),
      if (settings['showShopInfo'] == true) ...[
        headerText(profile['shopName']?.toString() ?? 'Cửa hàng'),
        for (final key in ['address', 'phone'])
          if (profile[key]?.toString().trim().isNotEmpty == true)
            headerText(
              key == 'phone'
                  ? 'Điện thoại: ${profile[key]}'
                  : '${profile[key]}',
            ),
      ],
      pw.SizedBox(height: 10 + spacing),
      pw.Text('Mã đơn: ${order['orderCode'] ?? order['id'] ?? ''}'),
      pw.Text('Ngày bán: ${formatReceiptDate(order['orderDate'])}'),
      if (settings['showCustomer'] == true)
        pw.Text(
          'Khách hàng: ${(order['customer'] as Map?)?['name'] ?? 'Khách lẻ'}',
        ),
      pw.SizedBox(height: 6 + spacing),
      if (a4)
        pw.TableHelper.fromTextArray(
          columnWidths: {
            if (showNumber) 0: const pw.FixedColumnWidth(36),
            (showNumber ? 1 : 0): const pw.FlexColumnWidth(4.5),
            if (showSku) (showNumber ? 2 : 1): const pw.FlexColumnWidth(1.6),
            (showNumber ? 1 : 0) + (showSku ? 2 : 1): const pw.FlexColumnWidth(
              1.4,
            ),
            (showNumber ? 1 : 0) + (showSku ? 3 : 2): const pw.FlexColumnWidth(
              1.9,
            ),
            (showNumber ? 1 : 0) + (showSku ? 4 : 3): const pw.FlexColumnWidth(
              2.1,
            ),
          },
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: pw.EdgeInsets.symmetric(
            horizontal: 5,
            vertical: 4 + spacing,
          ),
          headerStyle: pw.TextStyle(font: bold, fontSize: fontSize),
          cellStyle: pw.TextStyle(font: regular, fontSize: fontSize),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellAlignments: {
            (showNumber ? 1 : 0) + (showSku ? 2 : 1): pw.Alignment.centerRight,
            (showNumber ? 1 : 0) + (showSku ? 3 : 2): pw.Alignment.centerRight,
            (showNumber ? 1 : 0) + (showSku ? 4 : 3): pw.Alignment.centerRight,
          },
          headers: [
            if (showNumber) 'STT',
            'Hàng hóa',
            if (showSku) 'SKU',
            'SL${showUnit ? ' / ĐVT' : ''}',
            'Đơn giá',
            'Thành tiền',
          ],
          data: [
            for (var i = 0; i < items.length; i++)
              [
                if (showNumber) '${i + 1}',
                name(items[i]),
                if (showSku) '${(items[i]['product'] as Map?)?['sku'] ?? ''}',
                '${items[i]['quantity'] ?? 0}${showUnit && unit(items[i]).isNotEmpty ? ' ${unit(items[i])}' : ''}',
                money(items[i]['unitPrice']),
                money(items[i]['subtotal']),
              ],
          ],
        )
      else
        for (var i = 0; i < items.length; i++)
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 5 + spacing),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: .4),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${showNumber ? '${i + 1}. ' : ''}${name(items[i])}',
                  style: pw.TextStyle(font: bold),
                ),
                if (showSku && (items[i]['product'] as Map?)?['sku'] != null)
                  pw.Text(
                    'SKU: ${(items[i]['product'] as Map)['sku']}',
                    style: pw.TextStyle(
                      fontSize: fontSize - 1,
                      color: PdfColors.grey700,
                    ),
                  ),
                pw.SizedBox(height: 3 + spacing),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${items[i]['quantity'] ?? 0}${showUnit ? ' ${unit(items[i])}' : ''} × ${money(items[i]['unitPrice'])}',
                      ),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Expanded(
                      child: pw.Text(
                        money(items[i]['subtotal']),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      pw.SizedBox(height: 8 + spacing),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: a4 ? math.min(contentWidth, 300) : contentWidth,
          child: pw.Column(
            children: [
              totalLine('Tiền hàng', money(order['subtotal'])),
              if (settings['showDiscount'] == true)
                totalLine('Chiết khấu', money(order['discountAmount'])),
              if (settings['showTax'] == true)
                totalLine('Thuế', money(order['taxAmount'])),
              if (settings['showShipping'] == true &&
                  (num.tryParse('${order['shippingFee']}') ?? 0) > 0)
                totalLine('Phí giao hàng', money(order['shippingFee'])),
              totalLine(
                'Tổng thanh toán',
                money(order['totalAmount']),
                strong: true,
              ),
              if (settings['showPayment'] == true)
                totalLine('Đã thanh toán', money(order['paidAmount'])),
              if (settings['showBalance'] == true)
                totalLine(
                  'Còn phải thu',
                  debt.remaining == null
                      ? 'Cần đối chiếu'
                      : money(debt.remaining),
                ),
            ],
          ),
        ),
      ),
      if (settings['showNote'] == true &&
          order['notes']?.toString().trim().isNotEmpty == true) ...[
        pw.SizedBox(height: 8 + spacing),
        pw.Text('Ghi chú: ${order['notes']}'),
      ],
      if (qr != null) ...[
        pw.SizedBox(height: 10 + spacing),
        pw.Center(
          child: pw.Image(
            qr,
            width: math.min(
              (settings['qrSizeMm'] as double) * PdfPageFormat.mm,
              contentWidth,
            ),
            height: math.min(
              (settings['qrSizeMm'] as double) * PdfPageFormat.mm,
              contentWidth,
            ),
            fit: pw.BoxFit.contain,
          ),
        ),
      ],
      if (settings['showFooter'] == true) ...[
        pw.SizedBox(height: 10 + spacing),
        pw.Container(
          width: double.infinity,
          alignment: alignment('footerAlignment'),
          child: pw.Text(
            rawConfig.containsKey('footer')
                ? settings['footer'] as String
                : profile['receiptFooter']?.toString() ?? 'Cảm ơn quý khách!',
            textAlign: textAlign('footerAlignment'),
          ),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Text(
        'Đây là phiếu bán hàng nội bộ, không thay thế hóa đơn điện tử.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: math.max(7, fontSize - 1),
          color: PdfColors.grey700,
        ),
      ),
    ];
    if (a4) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(margin),
          theme: theme,
          maxPages: 200,
          build: content,
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Trang ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
        ),
      );
    } else {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: pw.EdgeInsets.all(margin),
          theme: theme,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: content(context),
          ),
        ),
      );
    }
    return document.save();
  }
}

String formatReceiptDate(dynamic value) {
  final raw = value?.toString() ?? '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw.isEmpty ? 'Chưa có ngày' : raw;
  final local = date.isUtc ? date.add(const Duration(hours: 7)) : date;
  return DateFormat(
    raw.length <= 10 ? 'dd/MM/yyyy' : 'dd/MM/yyyy HH:mm',
  ).format(local);
}
