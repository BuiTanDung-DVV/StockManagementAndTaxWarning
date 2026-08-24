import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/finance/presentation/invoice_editor_dialog.dart';
import 'package:flutter_app/features/finance/presentation/invoice_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('linked invoices are read-only outside their source document', () {
    expect(
      invoiceIsLinked({'referenceType': 'SALES_ORDER', 'referenceId': 123}),
      isTrue,
    );
    expect(invoiceIsLinked({'referenceType': ''}), isFalse);
    expect(invoiceIsLinked({}), isFalse);
  });

  testWidgets('invoice editor captures item lines instead of manual totals', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => InvoiceEditorDialog(
                  onSubmit: (payload) async => submitted = payload,
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();

    expect(find.text('Dòng hàng hóa, dịch vụ'), findsOneWidget);
    expect(find.text('Thêm dòng'), findsOneWidget);
    expect(find.textContaining('Tổng cộng:'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(7));
    await tester.enterText(fields.at(1), 'Nhà cung cấp Kiến Tạo');
    await tester.enterText(fields.at(2), 'Sơn nội thất 18L');
    await tester.enterText(fields.at(3), 'Thùng');
    await tester.enterText(fields.at(4), '2');
    await tester.enterText(fields.at(5), '1000000');
    await tester.enterText(fields.at(6), '10');

    await tester.tap(find.text('Lưu hóa đơn'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!['partnerName'], 'Nhà cung cấp Kiến Tạo');
    final items = submitted!['items'] as List<dynamic>;
    expect(items, hasLength(1));
    expect(items.single['itemName'], 'Sơn nội thất 18L');
    expect(items.single['quantity'], 2);
    expect(items.single['unitPrice'], 1000000);
    expect(items.single['taxRate'], 10);
  });
}
