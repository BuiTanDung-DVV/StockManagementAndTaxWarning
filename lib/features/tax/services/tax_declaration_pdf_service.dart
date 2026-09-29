import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TaxDeclarationPdfService {
  static Future<Uint8List> build({
    required String shopName,
    required String taxCode,
    required String businessSector,
    required String period,
    required String year,
    required double revenue,
    required double vatRate,
    required double pitRate,
    required double vatAmount,
    required double pitAmount,
    required String policySourceCode,
    required bool isExempt,
    String? address,
    String? phone,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );

    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    String money(num value) => currency.format(value);

    final periodDisplay = period.startsWith('Q')
        ? 'Quý ${period.replaceAll('Q', '')} năm $year'
        : 'Tháng $period năm $year';

    final totalTax = vatAmount + pitAmount;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Quốc hiệu & Tiêu ngữ
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
                          style: pw.TextStyle(font: bold, fontSize: 10),
                        ),
                        pw.Text(
                          'Độc lập - Tự do - Hạnh phúc',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 9,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Mẫu số: 01/CNKD',
                        style: pw.TextStyle(font: bold, fontSize: 10),
                      ),
                      pw.Text(
                        '(Ban hành kèm theo TT 40/2021/TT-BTC)',
                        style: pw.TextStyle(font: regular, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TỜ KHAI THUẾ ĐỐI VỚI HỘ KINH DOANH, CÁ NHÂN KINH DOANH',
                      style: pw.TextStyle(font: bold, fontSize: 13),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Kỳ tính thuế: $periodDisplay',
                      style: pw.TextStyle(font: bold, fontSize: 11),
                    ),
                    pw.Text(
                      '[X] Kê khai định kỳ   [ ] Kê khai từng lần phát sinh',
                      style: pw.TextStyle(font: regular, fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              // Thông tin người nộp thuế
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'I. THÔNG TIN NGƯỜI NỘP THUẾ',
                      style: pw.TextStyle(font: bold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            '[01] Tên người nộp thuế: $shopName',
                            style: pw.TextStyle(font: regular, fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '[02] Mã số thuế: $taxCode',
                            style: pw.TextStyle(font: bold, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '[03] Ngành nghề kinh doanh chính: $businessSector',
                      style: pw.TextStyle(font: regular, fontSize: 9),
                    ),
                    if (address != null && address.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '[04] Địa chỉ kinh doanh: $address',
                        style: pw.TextStyle(font: regular, fontSize: 9),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '[05] Căn cứ chính sách thuế: $policySourceCode',
                      style: pw.TextStyle(
                        font: regular,
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              // Bảng nghĩa vụ thuế
              pw.Text(
                'II. NGHĨA VỤ THUẾ PHÁT SINH TRONG KỲ',
                style: pw.TextStyle(font: bold, fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                context: context,
                cellStyle: pw.TextStyle(font: regular, fontSize: 9),
                headerStyle: pw.TextStyle(font: bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headers: <String>[
                  'STT',
                  'Chỉ tiêu nghĩa vụ thuế',
                  'Doanh thu tính thuế',
                  'Thuế suất',
                  'Số thuế phải nộp',
                ],
                data: <List<String>>[
                  [
                    '1',
                    'Thuế Giá trị gia tăng (GTGT)',
                    money(revenue),
                    '${(vatRate * 100).toStringAsFixed(1)}%',
                    isExempt ? '0 đ (Miễn thuế)' : money(vatAmount),
                  ],
                  [
                    '2',
                    'Thuế Thu nhập cá nhân (TNCN)',
                    money(revenue),
                    '${(pitRate * 100).toStringAsFixed(1)}%',
                    isExempt ? '0 đ (Miễn thuế)' : money(pitAmount),
                  ],
                  [
                    'TỔNG',
                    'Tổng số thuế phát sinh phải nộp',
                    money(revenue),
                    '-',
                    isExempt ? '0 đ (Miễn thuế)' : money(totalTax),
                  ],
                ],
              ),
              if (isExempt) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  color: PdfColors.amber50,
                  child: pw.Text(
                    '* Lưu ý: Hộ kinh doanh có tổng doanh thu năm trong ngưỡng quy định được miễn nộp thuế GTGT và TNCN.',
                    style: pw.TextStyle(
                      font: regular,
                      fontSize: 8,
                      color: PdfColors.amber900,
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 24),
              // Cam kết & Ký tên
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Tôi cam đoan số liệu khai trên là đúng sự thật',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.Text(
                        'và chịu trách nhiệm trước pháp luật về số liệu kê khai.',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Ngày ..... tháng ..... năm $year',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'NGƯỜI NỘP THUẾ hoặc ĐẠI DIỆN HỢP PHÁP',
                        style: pw.TextStyle(font: bold, fontSize: 9),
                      ),
                      pw.Text(
                        '(Ký, ghi rõ họ tên)',
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                      pw.SizedBox(height: 35),
                      pw.Text(
                        shopName,
                        style: pw.TextStyle(font: bold, fontSize: 10),
                      ),
                    ],
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
}
