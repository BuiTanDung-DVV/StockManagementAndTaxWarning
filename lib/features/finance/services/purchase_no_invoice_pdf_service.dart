import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PurchaseNoInvoicePdfService {
  static Future<Uint8List> build({
    required String shopName,
    required String shopTaxCode,
    required String shopAddress,
    required String recordCode,
    required String purchaseDate,
    required String sellerName,
    required String sellerIdentityNumber,
    required String sellerAddress,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? approvalNotes,
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
              // 1. Quốc hiệu - Tiêu ngữ
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
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '-----------------------',
                          style: pw.TextStyle(font: regular, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Mẫu số: 01/TNDN',
                        style: pw.TextStyle(font: bold, fontSize: 10),
                      ),
                      pw.Text(
                        '(Ban hành kèm theo TT số 78/2014/TT-BTC',
                        style: pw.TextStyle(font: italic, fontSize: 8),
                      ),
                      pw.Text(
                        '& TT số 88/2021/TT-BTC của Bộ Tài chính)',
                        style: pw.TextStyle(font: italic, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 2. Tiêu đề
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'BẢNG KÊ THU MUA HÀNG HÓA, DỊCH VỤ MUA VÀO KHÔNG CÓ HÓA ĐƠN',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: bold, fontSize: 13),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Số chứng từ: $recordCode • Ngày lập: $purchaseDate',
                      style: pw.TextStyle(font: italic, fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 3. Thông tin người mua và người bán
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'I. THÔNG TIN DOANH NGHIỆP / HỘ KINH DOANH MUA HÀNG:',
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('- Tên cơ sở: $shopName', style: pw.TextStyle(font: regular, fontSize: 9)),
                    pw.Text('- Mã số thuế: ${shopTaxCode.isNotEmpty ? shopTaxCode : 'Chưa cập nhật'}', style: pw.TextStyle(font: regular, fontSize: 9)),
                    pw.Text('- Địa chỉ: ${shopAddress.isNotEmpty ? shopAddress : 'Tại địa điểm kinh doanh'}', style: pw.TextStyle(font: regular, fontSize: 9)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'II. THÔNG TIN NGƯỜI BÁN HÀNG (TRỰC TIẾP SẢN XUẤT, ĐÁNH BẮT, BÁN LẺ):',
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('- Họ và tên người bán: $sellerName', style: pw.TextStyle(font: regular, fontSize: 9)),
                    pw.Text('- Số CCCD / CMND: ${sellerIdentityNumber.isNotEmpty ? sellerIdentityNumber : 'Chưa ghi nhận'}', style: pw.TextStyle(font: regular, fontSize: 9)),
                    pw.Text('- Địa chỉ cư trú: ${sellerAddress.isNotEmpty ? sellerAddress : 'Nơi cư trú người bán'}', style: pw.TextStyle(font: regular, fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // 4. Bảng chi tiết hàng hóa
              pw.Text(
                'III. CHI TIẾT HÀNG HÓA, DỊCH VỤ THU MUA:',
                style: pw.TextStyle(font: bold, fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
                headerStyle: pw.TextStyle(font: bold, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: pw.TextStyle(font: regular, fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['STT', 'Tên hàng hóa, dịch vụ', 'ĐVT', 'Số lượng', 'Đơn giá', 'Thành tiền'],
                data: [
                  for (int i = 0; i < items.length; i++)
                    [
                      '${i + 1}',
                      items[i]['productName']?.toString() ?? 'Hàng hóa ${i + 1}',
                      items[i]['unit']?.toString() ?? 'Món/Kg',
                      items[i]['quantity']?.toString() ?? '1',
                      money(num.tryParse(items[i]['unitPrice']?.toString() ?? '0') ?? 0),
                      money((num.tryParse(items[i]['quantity']?.toString() ?? '1') ?? 1) *
                          (num.tryParse(items[i]['unitPrice']?.toString() ?? '0') ?? 0)),
                    ],
                ],
              ),
              pw.SizedBox(height: 8),

              // 5. Tổng cộng
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tổng cộng tiền thanh toán:',
                    style: pw.TextStyle(font: bold, fontSize: 10),
                  ),
                  pw.Text(
                    money(totalAmount),
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Cam kết: Người mua cam đoan bảng kê này được lập đúng thực tế mua hàng của người trực tiếp sản xuất, chịu trách nhiệm trước pháp luật về tính chính xác của chứng từ.',
                style: pw.TextStyle(font: italic, fontSize: 7.5),
              ),
              pw.Spacer(),

              // 6. Chữ ký các bên
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('NGƯỜI BÁN HÀNG', style: pw.TextStyle(font: bold, fontSize: 9)),
                      pw.Text('(Ký, ghi rõ họ tên)', style: pw.TextStyle(font: italic, fontSize: 8)),
                      pw.SizedBox(height: 40),
                      pw.Text(sellerName, style: pw.TextStyle(font: regular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('NGƯỜI LẬP BẢNG KÊ', style: pw.TextStyle(font: bold, fontSize: 9)),
                      pw.Text('(Ký, ghi rõ họ tên)', style: pw.TextStyle(font: italic, fontSize: 8)),
                      pw.SizedBox(height: 40),
                      pw.Text('................................', style: pw.TextStyle(font: regular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('CHỦ CƠ SỞ KINH DOANH', style: pw.TextStyle(font: bold, fontSize: 9)),
                      pw.Text('(Ký, đóng dấu nếu có)', style: pw.TextStyle(font: italic, fontSize: 8)),
                      pw.SizedBox(height: 40),
                      pw.Text(shopName, style: pw.TextStyle(font: bold, fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
