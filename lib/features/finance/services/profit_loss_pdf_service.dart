import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ProfitLossPdfService {
  static Future<Uint8List> build({
    required String shopName,
    required String shopTaxCode,
    required String shopAddress,
    required String periodLabel,
    required double revenue,
    required double cogs,
    required double grossProfit,
    required double grossMargin,
    required double operatingExpenses,
    required double netProfit,
    required double netMargin,
    String? notes,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final italic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Italic.ttf'),
    );

    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    String money(num value) => currency.format(value);

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Tiêu đề Đơn vị & Quốc hiệu
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          shopName.isEmpty ? 'HỘ KINH DOANH' : shopName.toUpperCase(),
                          style: pw.TextStyle(font: bold, fontSize: 10),
                        ),
                        if (shopTaxCode.isNotEmpty)
                          pw.Text(
                            'Mã số thuế: $shopTaxCode',
                            style: pw.TextStyle(font: regular, fontSize: 9),
                          ),
                        if (shopAddress.isNotEmpty)
                          pw.Text(
                            'Địa chỉ: $shopAddress',
                            style: pw.TextStyle(font: regular, fontSize: 9),
                          ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                        pw.Text(
                          'Độc lập - Tự do - Hạnh phúc',
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                        pw.Container(
                          width: 80,
                          height: 0.5,
                          color: PdfColors.black,
                          margin: const pw.EdgeInsets.symmetric(vertical: 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 2. Tên Báo cáo
              pw.Center(
                child: pw.Text(
                  'BÁO CÁO KẾT QUẢ HOẠT ĐỘNG KINH DOANH',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '(Ban hành theo Thông tư số 88/2021/TT-BTC ngày 11/10/2021 của Bộ Tài chính)',
                  style: pw.TextStyle(font: italic, fontSize: 8, color: PdfColors.grey700),
                ),
              ),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4, bottom: 14),
                  child: pw.Text(
                    'Kỳ báo cáo: $periodLabel',
                    style: pw.TextStyle(font: regular, fontSize: 10),
                  ),
                ),
              ),

              // 3. Đơn vị tính
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Đơn vị tính: Đồng Việt Nam (VND)',
                  style: pw.TextStyle(font: italic, fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 6),

              // 4. Bảng chỉ tiêu Kết quả kinh doanh P&L
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(5),
                  2: const pw.FixedColumnWidth(45),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _th('STT', bold, align: pw.TextAlign.center),
                      _th('CHỈ TIÊU KINH DOANH', bold),
                      _th('MÃ SỐ', bold, align: pw.TextAlign.center),
                      _th('SỐ TIỀN', bold, align: pw.TextAlign.right),
                      _th('TỶ LỆ (%)', bold, align: pw.TextAlign.right),
                    ],
                  ),
                  _row('1', '1. Doanh thu bán hàng và cung cấp dịch vụ', '01', money(revenue), '100.0%', bold, regular),
                  _row('2', '2. Các khoản giảm trừ doanh thu', '02', '0 đ', '0.0%', regular, regular),
                  _row('3', '3. Doanh thu thuần (01 - 02)', '10', money(revenue), '100.0%', bold, regular, isHighlight: true),
                  _row('4', '4. Giá vốn hàng bán (COGS)', '11', money(cogs), '${(revenue > 0 ? (cogs / revenue * 100) : 0).toStringAsFixed(1)}%', regular, regular),
                  _row('5', '5. Lợi nhuận gộp về bán hàng (10 - 11)', '20', money(grossProfit), '${grossMargin.toStringAsFixed(1)}%', bold, regular, isHighlight: true),
                  _row('6', '6. Chi phí bán hàng và chi phí quản lý', '21', money(operatingExpenses), '${(revenue > 0 ? (operatingExpenses / revenue * 100) : 0).toStringAsFixed(1)}%', regular, regular),
                  _row(
                    '7',
                    netProfit >= 0 ? '7. Lợi nhuận thuần trong kỳ (20 - 21)' : '7. Lỗ thuần trong kỳ (20 - 21)',
                    '30',
                    money(netProfit),
                    '${netMargin.toStringAsFixed(1)}%',
                    bold,
                    regular,
                    isHighlight: true,
                    isTotal: true,
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 5. Thuyết minh / Đánh giá hiệu quả
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Thuyết minh & Đánh giá hiệu quả hoạt động:', style: pw.TextStyle(font: bold, fontSize: 9)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '- Tỷ suất sinh lời gộp (Gross Margin): ${grossMargin.toStringAsFixed(1)}% trên tổng doanh thu thuần.',
                      style: pw.TextStyle(font: regular, fontSize: 8.5),
                    ),
                    pw.Text(
                      '- Tỷ suất sinh lời ròng (Net Profit Margin): ${netMargin.toStringAsFixed(1)}%. '
                      '${netProfit >= 0 ? 'Hộ kinh doanh hoạt động có lãi an toàn.' : 'Lưu ý: Hộ kinh doanh đang chịu lỗ hoạt động trong kỳ.'}',
                      style: pw.TextStyle(font: regular, fontSize: 8.5),
                    ),
                    if (notes != null && notes.isNotEmpty)
                      pw.Text(
                        '- Ghi chú quản trị: $notes',
                        style: pw.TextStyle(font: italic, fontSize: 8.5),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 6. Chữ ký xác nhận
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('NGƯỜI LẬP BIỂU', style: pw.TextStyle(font: bold, fontSize: 9)),
                        pw.Text('(Ký, họ tên)', style: pw.TextStyle(font: italic, fontSize: 8)),
                        pw.SizedBox(height: 48),
                        pw.Text('.......................................', style: pw.TextStyle(font: regular, fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('KẾ TOÁN / THỦ QUỸ', style: pw.TextStyle(font: bold, fontSize: 9)),
                        pw.Text('(Ký, họ tên)', style: pw.TextStyle(font: italic, fontSize: 8)),
                        pw.SizedBox(height: 48),
                        pw.Text('.......................................', style: pw.TextStyle(font: regular, fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('CHỦ HỘ KINH DOANH', style: pw.TextStyle(font: bold, fontSize: 9)),
                        pw.Text('(Ký, họ tên, đóng dấu)', style: pw.TextStyle(font: italic, fontSize: 8)),
                        pw.SizedBox(height: 48),
                        pw.Text('.......................................', style: pw.TextStyle(font: regular, fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _th(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8.5),
      ),
    );
  }

  static pw.TableRow _row(
    String stt,
    String title,
    String code,
    String amount,
    String ratio,
    pw.Font mainFont,
    pw.Font subFont, {
    bool isHighlight = false,
    bool isTotal = false,
  }) {
    final bgColor = isTotal
        ? PdfColors.blueGrey50
        : (isHighlight ? PdfColors.grey100 : PdfColors.white);
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bgColor),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(stt, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: subFont, fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(title, style: pw.TextStyle(font: mainFont, fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(code, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: subFont, fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(amount, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: mainFont, fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(ratio, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: subFont, fontSize: 8.5)),
        ),
      ],
    );
  }
}
