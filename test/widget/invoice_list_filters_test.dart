import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/finance/presentation/invoice_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bộ lọc hóa đơn vừa viewport mobile 390px', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: InvoiceListFilters(
              periodLabel: '01/08–20/08/2026',
              showAllPeriods: false,
              type: null,
              onPeriodChanged: (_) {},
              onTypeChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Kỳ hiện tại'), findsOneWidget);
    expect(find.text('Toàn bộ thời gian'), findsOneWidget);
    expect(find.text('Đầu vào'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
