import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/utils/parse_utils.dart';
import 'package:flutter_app/features/finance/presentation/salary_ledger_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 9 - Vietnamese Currency Parsing Tests', () {
    test('parseCurrency handles large salary and payment amounts', () {
      expect(parseCurrency('10.000.000'), 10000000.0);
      expect(parseCurrency('10.000.000 ₫'), 10000000.0);
      expect(parseCurrency('5.500.000 đ'), 5500000.0);
      expect(parseCurrency('500.000'), 500000.0);
      expect(parseCurrency('30.000 đ'), 30000.0);
      expect(parseCurrency('1,500,000'), 1500000.0);
      expect(parseCurrency('0'), 0.0);
      expect(parseCurrency(''), 0.0);
      expect(parseCurrency(null), 0.0);
    });
  });

  group('Wave 9 - Salary Ledger Widget Tests', () {
    testWidgets('Renders SalaryLedgerScreen with items and summary', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSalaryData = {
        'items': [
          {
            'id': 1,
            'counterparty': 'Nguyễn Văn A',
            'amount': 12000000,
            'notes': 'Lương tháng 9',
            'transactionDate': '2026-09-15T08:00:00Z',
          },
          {
            'id': 2,
            'counterparty': 'Trần Thị B',
            'amount': 8500000,
            'notes': 'Tạm ứng lương',
            'transactionDate': '2026-09-18T10:30:00Z',
          },
        ],
        'filteredAmountTotal': 20500000,
        'total': 2,
        'page': 1,
        'totalPages': 1,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith(
              (ref, arg) async => mockSalaryData,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const SalaryLedgerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header title
      expect(find.text('Sổ lương'), findsOneWidget);
      // Check employee names
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Trần Thị B'), findsOneWidget);
      // Check total transactions
      expect(find.text('2 giao dịch'), findsOneWidget);
      // Check FAB or Action button
      expect(find.byIcon(Icons.payments), findsWidgets);
    });

    testWidgets('Salary Ledger opens add dialog and shows realtime preview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSalaryData = {
        'items': [],
        'filteredAmountTotal': 0,
        'total': 0,
        'page': 1,
        'totalPages': 1,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsProvider.overrideWith(
              (ref, arg) async => mockSalaryData,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const SalaryLedgerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on empty state button to add salary
      final addBtn = find.widgetWithText(ElevatedButton, 'Thêm chi lương');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Dialog should be open
      expect(
        find.widgetWithText(AlertDialog, 'Thêm chi lương'),
        findsOneWidget,
      );
      expect(find.text('Tên nhân viên *'), findsOneWidget);
      expect(find.text('Số tiền *'), findsOneWidget);

      // Enter amount with dots: 15.000.000
      final amountField = find.widgetWithText(TextField, 'Số tiền *');
      await tester.enterText(amountField, '15.000.000');
      await tester.pumpAndSettle();

      // Verify helperText reflects 15.000.000 with currency suffix
      expect(find.text('15.000.000\u00A0₫'), findsOneWidget);
    });
  });
}
