import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/finance/presentation/daily_closing_screen.dart';
import 'package:flutter_app/features/finance/presentation/expense_ledger_screen.dart';
import 'package:flutter_app/features/finance/presentation/finance_screen.dart';
import 'package:flutter_app/features/finance/presentation/profit_loss_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_finance/screenshots';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary = tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final path = '$_runDir/$fileName';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _initial;
  _FakeShopNotifier(this._initial);

  @override
  ShopState build() => _initial;
}

void main() {
  setUpAll(loadUiFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const fakeShopState = ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
    memberType: 'OWNER',
    status: 'ACTIVE',
    userShops: [
      {
        'id': 1,
        'name': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
        'role': 'OWNER',
      },
    ],
  );

  final fakeCashSummary = <String, dynamic>{
    'netCashFlow': 28500000.0,
    'totalIn': 45200000.0,
    'totalOut': 16700000.0,
    'cashIn': 18000000.0,
    'bankIn': 27200000.0,
    'cashOut': 6700000.0,
    'bankOut': 10000000.0,
    'openingBalance': 15000000.0,
    'closingBalance': 43500000.0,
    'trend': [
      {'date': '2026-09-01', 'in': 1500000.0, 'out': 500000.0},
      {'date': '2026-09-05', 'in': 3200000.0, 'out': 1200000.0},
      {'date': '2026-09-10', 'in': 4500000.0, 'out': 2100000.0},
      {'date': '2026-09-15', 'in': 6800000.0, 'out': 1900000.0},
      {'date': '2026-09-20', 'in': 8900000.0, 'out': 3400000.0},
      {'date': '2026-09-25', 'in': 11200000.0, 'out': 4200000.0},
      {'date': '2026-09-30', 'in': 9100000.0, 'out': 3400000.0},
    ],
  };

  final fakeExpensesByCategory = <String, dynamic>{
    'total': 16700000.0,
    'categories': [
      {'category': 'RENT', 'amount': 8000000.0, 'count': 1},
      {'category': 'SALARY', 'amount': 5000000.0, 'count': 3},
      {'category': 'UTILITIES', 'amount': 2200000.0, 'count': 2},
      {'category': 'MARKETING', 'amount': 1500000.0, 'count': 4},
    ],
    'recentItems': [
      {
        'id': 101,
        'category': 'RENT',
        'amount': 8000000.0,
        'date': '2026-09-05',
        'description': 'Tiền thuê mặt bằng tháng 9/2026',
      },
      {
        'id': 102,
        'category': 'UTILITIES',
        'amount': 2200000.0,
        'date': '2026-09-15',
        'description': 'Tiền điện nước và internet',
      },
    ],
  };

  final fakeTransactions = <String, dynamic>{
    'items': [
      {
        'id': 1,
        'code': 'PT-202609-001',
        'type': 'RECEIPT',
        'category': 'SALES',
        'amount': 370000.0,
        'date': '2026-09-30T10:15:00',
        'description': 'Thu tiền đơn bán hàng DH-202609-001',
        'paymentMethod': 'CASH',
      },
      {
        'id': 2,
        'code': 'PC-202609-002',
        'type': 'PAYMENT',
        'category': 'UTILITIES',
        'amount': 1200000.0,
        'date': '2026-09-29T16:30:00',
        'description': 'Tiền điện thắp sáng tháng 9',
        'paymentMethod': 'BANK_TRANSFER',
      },
      {
        'id': 3,
        'code': 'PT-202609-003',
        'type': 'RECEIPT',
        'category': 'SALES',
        'amount': 850000.0,
        'date': '2026-09-29T14:20:00',
        'description': 'Thu tiền bán lẻ quầy POS',
        'paymentMethod': 'QR_TRANSFER',
      },
    ],
    'total': 3,
  };

  final fakePnl = <String, dynamic>{
    'revenue': 125000000.0,
    'cogs': 78000000.0,
    'grossProfit': 47000000.0,
    'operatingExpenses': 16700000.0,
    'netProfit': 30300000.0,
  };

  final today = DateTime.now().toIso8601String().split('T').first;

  final fakeDailyClosing = <String, dynamic>{
    'id': 1,
    'date': today,
    'status': 'PENDING',
    'openingCash': 2000000.0,
    'expectedCash': 5420000.0,
    'cashSales': 3420000.0,
    'bankSales': 4200000.0,
    'otherIncome': 0.0,
    'cashExpenses': 0.0,
    'actualCash': null,
    'difference': 0.0,
  };

  final fakeDailyClosingList = <String, dynamic>{
    'items': [
      {
        'id': 10,
        'date': '2026-09-29',
        'openingCash': 2000000.0,
        'expectedCash': 6150000.0,
        'actualCash': 6150000.0,
        'difference': 0.0,
        'status': 'CLOSED',
      },
    ],
  };

  group('Finance & Cashflow Visual Audit', () {
    testWidgets('Capture Finance Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('finance_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            cashSummaryProvider.overrideWith((ref, args) => Future.value(fakeCashSummary)),
            expensesByCategoryForPeriodProvider.overrideWith(
              (ref, args) => Future.value(fakeExpensesByCategory),
            ),
            transactionsProvider.overrideWith((ref, args) => Future.value(fakeTransactions)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: FinanceScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '01_finance_overview_desktop.png');

      expect(find.text('Tài chính & sổ cái'), findsOneWidget);
      expect(find.text('Dòng tiền thuần'), findsWidgets);
      expect(find.text('Thu chi & đối soát'), findsOneWidget);
    });

    testWidgets('Capture Finance Screen Mobile (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('finance_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            cashSummaryProvider.overrideWith((ref, args) => Future.value(fakeCashSummary)),
            expensesByCategoryForPeriodProvider.overrideWith(
              (ref, args) => Future.value(fakeExpensesByCategory),
            ),
            transactionsProvider.overrideWith((ref, args) => Future.value(fakeTransactions)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: FinanceScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '02_finance_overview_mobile.png');

      expect(find.text('Tài chính & sổ cái'), findsOneWidget);
    });

    testWidgets('Capture Profit & Loss Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('pnl_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            profitLossProvider.overrideWith((ref, args) => Future.value(fakePnl)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ProfitLossScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '03_profit_loss_desktop.png');

      expect(find.text('Kết quả kinh doanh'), findsOneWidget);
      expect(find.text('Doanh thu thuần'), findsWidgets);
      expect(find.text('Lợi nhuận ròng'), findsWidgets);
    });

    testWidgets('Capture Profit & Loss Screen Mobile (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('pnl_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            profitLossProvider.overrideWith((ref, args) => Future.value(fakePnl)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ProfitLossScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '04_profit_loss_mobile.png');

      expect(find.text('Kết quả kinh doanh'), findsOneWidget);
    });

    testWidgets('Capture Daily Closing Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('daily_closing_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            dailyClosingProvider.overrideWith((ref, date) => Future.value(fakeDailyClosing)),
            dailyClosingsListProvider.overrideWith((ref, page) => Future.value(fakeDailyClosingList)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: DailyClosingScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '05_daily_closing_desktop.png');

      expect(find.text('Kết ca & Khóa sổ'), findsOneWidget);
    });

    testWidgets('Capture Expense Ledger Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('expense_ledger_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            expensesByCategoryProvider.overrideWith((ref) => Future.value(fakeExpensesByCategory)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ExpenseLedgerScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '06_expense_ledger_desktop.png');

      expect(find.text('Sổ chi phí'), findsOneWidget);
      expect(find.text('Tổng chi phí tháng này'), findsOneWidget);
    });
  });
}
