import 'package:flutter_app/features/sales/services/receipt_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('receipt service generates real 80mm and A4 PDF documents', () async {
    final profile = {
      'shopName': 'Cửa hàng Kiến Tạo',
      'address': 'Hà Nội',
      'phone': '0900000000',
    };
    final order = {
      'id': 1,
      'orderCode': 'SO-001',
      'orderDate': '2026-09-01',
      'subtotal': 200000,
      'discountAmount': 10000,
      'taxAmount': 19000,
      'totalAmount': 209000,
      'paidAmount': 209000,
      'customer': {'name': 'Nguyễn Văn A'},
      'items': [
        {
          'quantity': 2,
          'unitPrice': 100000,
          'subtotal': 200000,
          'product': {'name': 'Xi măng PCB40', 'sku': 'XM-001'},
        },
      ],
    };

    final roll = await ReceiptPdfService.build(
      order: order,
      profile: profile,
      config: {'paperSize': '80mm'},
    );
    final a4 = await ReceiptPdfService.build(
      order: order,
      profile: profile,
      config: {'paperSize': 'A4'},
    );

    expect(String.fromCharCodes(roll.take(4)), '%PDF');
    expect(String.fromCharCodes(a4.take(4)), '%PDF');
    expect(roll, isNot(equals(a4)));
  });
}
