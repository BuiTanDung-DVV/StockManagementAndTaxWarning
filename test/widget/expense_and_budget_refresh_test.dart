import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/finance/presentation/budget_plan_screen.dart';
import 'package:flutter_app/features/finance/presentation/expense_ledger_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/presentation/xnt_report_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 13 - Expense Ledger & Add Expense Dialog Tests', () {
    testWidgets(
      'ExpenseLedgerScreen renders with RefreshIndicator and opens Add Dialog with realtime helperText',
      (tester) async {
        final mockExpensesData = {
          'categories': [
            {'category': 'RENT', 'amount': 15000000},
            {'category': 'UTILITIES', 'amount': 3500000},
          ],
          'total': 18500000,
          'recentItems': [
            {
              'id': 1,
              'category': 'RENT',
              'amount': 15000000,
              'counterparty': 'Chủ nhà',
              'transactionDate': '2026-09-01T08:00:00Z',
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              expensesByCategoryProvider.overrideWith(
                (ref) async => mockExpensesData,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ExpenseLedgerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Screen Title and RefreshIndicator
        expect(find.text('Sổ chi phí'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.textContaining('Tiền thuê'), findsWidgets);

        // Tap "Thêm" button to open Add Expense Dialog
        final addBtn = find.text('Thêm');
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        // Verify Dialog
        expect(find.text('Thêm chi phí'), findsOneWidget);
        expect(find.text('Số tiền *'), findsOneWidget);

        // Enter amount and verify realtime helperText
        final amountField = find.widgetWithText(TextField, 'Số tiền *');
        expect(amountField, findsOneWidget);

        await tester.enterText(amountField, '7500000');
        await tester.pumpAndSettle();

        // Check that helperText formatted currency appears in dialog
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('7.500.000'),
          ),
          findsOneWidget,
        );

        // Unfocus before closing dialog
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        // Cancel dialog
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
      },
    );
  });

  group(
    'Wave 13 - XntReportScreen & BudgetPlanScreen RefreshIndicator Tests',
    () {
      testWidgets('XntReportScreen renders with RefreshIndicator', (
        tester,
      ) async {
        final mockXntData = {
          'summary': {
            'openingSkuCount': 10,
            'importedSkuCount': 5,
            'exportedSkuCount': 3,
            'closingSkuCount': 12,
          },
          'items': [
            {
              'sku': 'SP001',
              'productName': 'Cà phê Arabica',
              'unit': 'Gói',
              'openingStock': 20,
              'imported': 10,
              'exported': 5,
              'closingStock': 25,
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              xntReportProvider.overrideWith((ref, args) async => mockXntData),
              slowMovingProvider.overrideWith((ref) async => []),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const XntReportScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Báo cáo XNT Kho'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });

      testWidgets(
        'BudgetPlanScreen renders with RefreshIndicator on empty state',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [budgetPlansProvider.overrideWith((ref) async => [])],
              child: MaterialApp(
                theme: AppTheme.lightTheme(AppColors.primary),
                home: const BudgetPlanScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Kế Hoạch Ngân Sách'), findsOneWidget);
          expect(find.byType(RefreshIndicator), findsOneWidget);
          expect(find.text('Chưa có kế hoạch ngân sách nào'), findsOneWidget);
        },
      );
    },
  );
}
