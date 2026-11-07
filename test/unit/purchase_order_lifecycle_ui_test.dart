import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/inventory/presentation/purchase_order_detail_screen.dart';
import '../support/load_ui_fonts.dart';
import '../support/purchase_detail_fixture.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final status in ['PENDING', 'COMPLETED', 'CANCELLED']) {
    testWidgets('delete is offered only for a pending order: $status', (
      tester,
    ) async {
      final order = <String, dynamic>{
        'id': 101,
        'shopId': 40,
        'orderCode': 'PO-STATE',
        'status': status,
        'totalAmount': 0,
        'items': <dynamic>[],
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: purchaseDetailOverrides(order),
          child: MaterialApp(
            theme: AppTheme.lightTheme(Colors.teal),
            home: PurchaseOrderDetailScreen(purchaseOrder: order),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Xóa đơn nhập đang chờ'),
        status == 'PENDING' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
