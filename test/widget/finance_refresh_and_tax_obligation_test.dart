import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/finance/presentation/daily_closing_screen.dart';
import 'package:flutter_app/features/finance/presentation/invoice_list_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_calculator_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_obligation_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
import '../support/load_ui_fonts.dart';

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _state;
  _FakeShopNotifier(this._state);

  @override
  ShopState build() => _state;
}

class _FakeLoadedTaxConfigNotifier extends TaxConfigNotifier {
  @override
  TaxConfig build() {
    return const TaxConfig(
      businessType: BusinessType.distribution,
      vatReduction20: false,
      thresholds: RevenueThresholds(
        tier1: 100000000,
        tier2: 300000000,
        tier3: 500000000,
        tier4: 1000000000,
      ),
      rates: {BusinessType.distribution: TaxRates(vat: 0.01, pit: 0.005)},
      isLoading: false,
      fiscalYear: 2026,
    );
  }
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 16: Finance Screens Refresh & Tax Obligation Tests', () {
    testWidgets('InvoiceListScreen renders with RefreshIndicator and data', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          shopProvider.overrideWith(
            () => _FakeShopNotifier(
              const ShopState(
                currentShopId: 1,
                memberType: 'OWNER',
                status: 'ACTIVE',
              ),
            ),
          ),
          invoiceListProvider.overrideWith((ref, arg) async {
            return {
              'items': [
                {
                  'id': 1,
                  'invoiceNumber': 'HD-2026-001',
                  'partnerName': 'Công ty TNHH Minh Phát',
                  'invoiceDate': '2026-09-20',
                  'invoiceType': 'IN',
                  'totalAmount': 5500000,
                  'taxAmount': 500000,
                  'items': [
                    {
                      'itemName': 'Giấy in A4 Double A',
                      'unit': 'Ram',
                      'quantity': 50,
                      'unitPrice': 100000,
                      'taxRate': 10,
                    },
                  ],
                },
              ],
              'total': 1,
              'page': 1,
              'totalPages': 1,
            };
          }),
          invoiceSummaryProvider.overrideWith((ref, arg) async {
            return {
              'vatIn': 500000,
              'vatOut': 0,
              'vatOwed': 0,
              'vatCredit': 500000,
            };
          }),
          invoiceReconciliationProvider.overrideWith((ref, arg) async {
            return {
              'from': '2026-09-01',
              'to': '2026-09-30',
              'unmatchedInvoices': [],
              'duplicates': [],
              'timingGaps': [],
              'reconciliationRate': 100.0,
            };
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const InvoiceListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.text('Công ty TNHH Minh Phát'), findsOneWidget);
    });

    testWidgets(
      'DailyClosingScreen renders with RefreshIndicator in unclosed state',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final today = DateTime.now().toIso8601String().split('T').first;
        final container = ProviderContainer(
          overrides: [
            dailyClosingProvider(today).overrideWith((ref) async {
              return {
                'totalIncome': 12500000,
                'totalExpense': 3500000,
                'cashIncome': 8000000,
                'cashExpense': 2000000,
                'bankIncome': 4500000,
                'bankExpense': 1500000,
                'totalSales': 12500000,
                'totalReturns': 0,
                'orderCount': 42,
                'closed': false,
                'openingCash': 5000000,
                'expectedCash': 11000000,
                'explanationThreshold': 50000,
                'transactions': [],
              };
            }),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const DailyClosingScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.text('SỔ SÁCH TIỀN MẶT HÔM NAY'), findsOneWidget);
        expect(find.text('Chốt ca & Khóa sổ'), findsOneWidget);
      },
    );

    testWidgets(
      'TaxObligationScreen renders with RefreshIndicator and opens add dialog',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            taxObligationsProvider.overrideWith((ref) async {
              return {
                'totalOwed': 1500000,
                'items': [
                  {
                    'id': 101,
                    'period': 'Q3/2026',
                    'vatDeclared': 1000000,
                    'pitDeclared': 500000,
                    'vatPaid': 0,
                    'pitPaid': 0,
                    'status': 'pending',
                  },
                ],
              };
            }),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const TaxObligationScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.text('Theo dõi Nghĩa vụ thuế'), findsOneWidget);
        expect(find.text('TỔNG THUẾ CÒN PHẢI NỘP'), findsOneWidget);
        expect(find.text('Q3/2026'), findsOneWidget);

        // Open Add Dialog
        await tester.tap(find.text('Khai thuế mới'));
        await tester.pumpAndSettle();

        expect(find.text('Thêm kỳ nghĩa vụ thuế'), findsOneWidget);
        expect(find.text('Kỳ kê khai (VD: Q1/2026) *'), findsOneWidget);

        // Enter VAT and verify realtime helper format
        final vatField = find.widgetWithText(
          TextField,
          'Thuế VAT phải nộp (VNĐ)',
        );
        await tester.enterText(vatField, '1500000');
        await tester.pumpAndSettle();

        expect(find.textContaining('Quy đổi: 1.500.000'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        expect(find.text('Thêm kỳ nghĩa vụ thuế'), findsNothing);
      },
    );

    testWidgets(
      'TaxCalculatorScreen renders with RefreshIndicator and calculate results',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taxConfigProvider.overrideWith(
                () => _FakeLoadedTaxConfigNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const TaxCalculatorScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(
          find.textContaining('Công cụ tính thuế HKD 2026'),
          findsOneWidget,
        );
        expect(find.text('Doanh thu nhập vào'), findsOneWidget);
      },
    );
  });
}
