import 'dart:ui' show PointerDeviceKind;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_insights_widgets.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(loadUiFonts);
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────
  // UNIT TESTS: Calendar Aggregation & Models
  // ─────────────────────────────────────────────────────────
  group('aggregateDailyFlow unit tests', () {
    test('returns empty list for empty input', () {
      final result = aggregateDailyFlow([]);
      expect(result, isEmpty);
    });

    test('preserves daily entries when count <= maxBuckets', () {
      final items = [
        const DailyFlowEntry(
          date: '2026-09-01',
          income: 1000000,
          expense: 500000,
        ),
        const DailyFlowEntry(
          date: '2026-09-02',
          income: 2000000,
          expense: 800000,
        ),
        const DailyFlowEntry(
          date: '2026-09-03',
          income: 1500000,
          expense: 300000,
        ),
      ];

      final buckets = aggregateDailyFlow(items, maxBuckets: 7);
      expect(buckets.length, 3);
      expect(buckets[0].label, '01/09');
      expect(buckets[0].income, 1000000);
      expect(buckets[0].expense, 500000);
      expect(buckets[1].label, '02/09');
      expect(buckets[2].label, '03/09');
    });

    test(
      'aggregates 30 daily points into sensible calendar buckets of consecutive date ranges without loss',
      () {
        final items = List.generate(30, (index) {
          final day = (index + 1).toString().padLeft(2, '0');
          return DailyFlowEntry(
            date: '2026-09-$day',
            income: (index + 1) * 100000.0,
            expense: (index + 1) * 50000.0,
          );
        });

        final totalInputIncome = items.fold<double>(
          0,
          (sum, it) => sum + it.income,
        );
        final totalInputExpense = items.fold<double>(
          0,
          (sum, it) => sum + it.expense,
        );

        final buckets = aggregateDailyFlow(items, maxBuckets: 7);

        expect(buckets.length, lessThanOrEqualTo(7));
        expect(buckets.length, greaterThan(1));

        // Strictly verifies zero data loss and exact preservation of totals
        final totalBucketIncome = buckets.fold<double>(
          0,
          (sum, b) => sum + b.income,
        );
        final totalBucketExpense = buckets.fold<double>(
          0,
          (sum, b) => sum + b.expense,
        );

        expect(totalBucketIncome, equals(totalInputIncome));
        expect(totalBucketExpense, equals(totalInputExpense));

        // Labels should cover date ranges formatted on two lines
        expect(buckets.first.label, contains('01–'));
        expect(buckets.first.tooltipDate, contains('01/09/2026'));
        expect(buckets.last.label, contains('–30'));
        expect(buckets.last.label, contains('Thg 09'));
      },
    );

    test(
      'formats ranges as deliberate two lines and single-day chunks as one date without fake range',
      () {
        final items = List.generate(
          7,
          (i) => DailyFlowEntry(
            date: '2026-09-0${i + 1}',
            income: 1000000.0 * (i + 1),
            expense: 500000.0 * (i + 1),
          ),
        );

        // With maxBuckets: 4, chunkSize = (7 / 4).ceil() = 2
        // Chunks: [01..02], [03..04], [05..06], [07]
        final buckets = aggregateDailyFlow(items, maxBuckets: 4);
        expect(buckets.length, 4);

        // Buckets 0-2 are 2-day ranges formatted as two lines (range newline month)
        expect(buckets[0].label, '01–02\nThg 09');
        expect(buckets[0].tooltipDate, '01/09/2026 – 02/09/2026');
        expect(buckets[1].label, '03–04\nThg 09');
        expect(buckets[2].label, '05–06\nThg 09');

        // Bucket 3 is a single day: must show one date '07/09', NEVER '07–07/09'
        expect(buckets[3].label, '07/09');
        expect(buckets[3].label, isNot(contains('07–07')));
        expect(buckets[3].tooltipDate, '07/09/2026');

        // Preserves all totals exactly
        final totalIncome = buckets.fold<double>(0, (s, b) => s + b.income);
        final totalExpense = buckets.fold<double>(0, (s, b) => s + b.expense);
        expect(totalIncome, 28000000.0);
        expect(totalExpense, 14000000.0);
      },
    );

    test('formats cross-month date ranges across two lines with dates', () {
      final items = [
        const DailyFlowEntry(date: '2026-08-30', income: 100, expense: 50),
        const DailyFlowEntry(date: '2026-08-31', income: 100, expense: 50),
        const DailyFlowEntry(date: '2026-09-01', income: 100, expense: 50),
        const DailyFlowEntry(date: '2026-09-02', income: 100, expense: 50),
      ];

      // Aggregate into 2 buckets of 2 days: [30/08..31/08] and [01/09..02/09]
      final bucketsSameMonth = aggregateDailyFlow(items, maxBuckets: 2);
      expect(bucketsSameMonth[0].label, '30–31\nThg 08');
      expect(bucketsSameMonth[1].label, '01–02\nThg 09');

      // When a single chunk spans across months: e.g. maxBuckets: 1
      final bucketCrossMonth = aggregateDailyFlow(items, maxBuckets: 1);
      expect(bucketCrossMonth[0].label, '30/08\n– 02/09');
      expect(bucketCrossMonth[0].tooltipDate, '30/08/2026 – 02/09/2026');
    });
  });

  // ─────────────────────────────────────────────────────────
  // WIDGET TESTS: Panel 1 - Thu - chi trong kỳ
  // ─────────────────────────────────────────────────────────
  group('DashboardCashFlowCard', () {
    testWidgets(
      'displays totals text and distinguishes net cash flow from profit',
      (tester) async {
        final cashData = {
          'income': 15000000,
          'expense': 6000000,
          'netCashFlow': 9000000,
          'cashBalance': 50000000,
          'period': {'from': '2026-09-01', 'to': '2026-09-30'},
          'dailyFlow': [
            {'date': '2026-09-01', 'income': 10000000, 'expense': 4000000},
            {'date': '2026-09-02', 'income': 5000000, 'expense': 2000000},
          ],
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardCashFlowCard(
                  cashAsync: AsyncValue.data(cashData),
                  currentLabel: 'Tháng 9/2026',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Thu – chi trong kỳ'), findsOneWidget);
        expect(find.text('Tổng thu'), findsOneWidget);
        expect(find.text('Tổng chi'), findsOneWidget);
        expect(find.text('Dòng tiền thuần'), findsOneWidget);

        // Verifies net cash flow is NOT mislabeled as profit
        expect(find.text('Lợi nhuận thuần'), findsNothing);
        expect(find.text('Lợi nhuận ròng'), findsNothing);

        expect(find.textContaining('15.000.000'), findsWidgets);
        expect(find.textContaining('6.000.000'), findsWidgets);
        expect(find.textContaining('+9.000.000'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('displays empty state for zero cashflow without fake bars', (
      tester,
    ) async {
      final cashData = {
        'income': 0,
        'expense': 0,
        'netCashFlow': 0,
        'cashBalance': 0,
        'period': {'from': '2026-09-01', 'to': '2026-09-30'},
        'dailyFlow': [
          {'date': '2026-09-01', 'income': 0, 'expense': 0},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardCashFlowCard(
                cashAsync: AsyncValue.data(cashData),
                currentLabel: 'Tháng 9/2026',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có phát sinh thu – chi trong kỳ.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'displays error state and handles retry when data is invalid or missing required fields',
      (tester) async {
        var retried = false;
        // Corrupted data missing 'netCashFlow'
        final corruptedData = {'income': 10000, 'dailyFlow': []};

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardCashFlowCard(
                  cashAsync: AsyncValue.data(corruptedData),
                  currentLabel: 'Tháng 9/2026',
                  onRetry: () => retried = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Dữ liệu dòng tiền chưa đầy đủ hoặc không khả dụng.'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);

        await tester.tap(find.text('Thử lại'));
        expect(retried, isTrue);
      },
    );
  });

  // ─────────────────────────────────────────────────────────
  // WIDGET TESTS: Panel 2 - Kết quả bán hàng
  // ─────────────────────────────────────────────────────────
  group('DashboardSalesPerformanceCard', () {
    testWidgets(
      'displays rows with Vietnamese formatting and signed differences',
      (tester) async {
        final currentData = {
          'netSalesRevenue': 50000000,
          'totalCogs': 30000000,
          'grossProfit': 20000000,
          'totalOrders': 150,
        };

        final previousData = {
          'netSalesRevenue': 40000000,
          'totalCogs': 25000000,
          'grossProfit': 15000000,
          'totalOrders': 120,
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardSalesPerformanceCard(
                  currentSales: AsyncValue.data(currentData),
                  comparisonSales: AsyncValue.data(previousData),
                  currentLabel: 'T9/2026',
                  previousLabel: 'T8/2026',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kết quả bán hàng'), findsOneWidget);
        expect(find.text('Doanh thu thuần'), findsOneWidget);
        expect(find.text('Giá vốn (COGS)'), findsOneWidget);
        expect(find.text('Lợi nhuận gộp'), findsOneWidget);
        expect(find.text('Số đơn hàng'), findsOneWidget);

        // Current amounts
        expect(find.textContaining('50.000.000'), findsOneWidget);
        expect(find.textContaining('30.000.000'), findsOneWidget);
        expect(find.textContaining('20.000.000'), findsOneWidget);
        expect(find.text('150'), findsOneWidget);

        // Previous amounts
        expect(find.textContaining('40.000.000'), findsOneWidget);
        expect(find.textContaining('25.000.000'), findsOneWidget);
        expect(find.textContaining('15.000.000'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);

        // Differences
        expect(find.textContaining('+10.000.000'), findsOneWidget);
        expect(find.textContaining('+5.000.000'), findsWidgets);
        expect(find.text('+30'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows dash for missing previous period without fabricating zero',
      (tester) async {
        final currentData = {
          'netSalesRevenue': 50000000,
          'totalCogs': 30000000,
          'grossProfit': -5000000, // signed negative gross profit
          'totalOrders': 150,
        };

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardSalesPerformanceCard(
                  currentSales: AsyncValue.data(currentData),
                  comparisonSales: null, // No comparison period
                  currentLabel: 'T9/2026',
                  previousLabel: 'T8/2026',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kết quả bán hàng'), findsOneWidget);
        // Signed negative gross profit
        expect(find.textContaining('-5.000.000'), findsOneWidget);
        // '—' dashes for missing previous period and differences
        expect(find.text('—'), findsNWidgets(8));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays comparison error state with inline error and retry when comparison fails',
      (tester) async {
        final currentData = {
          'netSalesRevenue': 50000000,
          'totalCogs': 30000000,
          'grossProfit': 20000000,
          'totalOrders': 150,
        };

        var retriedComparison = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardSalesPerformanceCard(
                  currentSales: AsyncValue.data(currentData),
                  comparisonSales: AsyncValue.error(
                    Exception('Network error'),
                    StackTrace.empty,
                  ),
                  currentLabel: 'T9/2026',
                  previousLabel: 'T8/2026',
                  onRetryComparison: () => retriedComparison = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kết quả bán hàng'), findsOneWidget);
        expect(
          find.text('Không thể tải số liệu kỳ đối chiếu (T8/2026).'),
          findsOneWidget,
        );
        expect(find.text('Lỗi tải'), findsWidgets);

        final retryButtons = find.text('Thử lại');
        expect(retryButtons, findsOneWidget);
        await tester.tap(retryButtons);
        expect(retriedComparison, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ─────────────────────────────────────────────────────────
  // WIDGET TESTS: Panel 3 - Giá trị tồn kho theo nhóm
  // ─────────────────────────────────────────────────────────
  group('DashboardInventoryCategoryCard', () {
    testWidgets(
      'displays explicit snapshot label, sorts descending, and aggregates remainder into Nhóm khác',
      (tester) async {
        final categories = [
          {'name': 'Gạch ốp lát', 'skuCount': 20, 'value': 20000000},
          {
            'name':
                'Thiết bị vệ sinh cao cấp với tên danh mục rất dài để kiểm tra độ rộng',
            'skuCount': 10,
            'value': 50000000,
          },
          {'name': 'Sơn & Hóa chất', 'skuCount': 15, 'value': 15000000},
          {'name': 'Vật liệu thô', 'skuCount': 5, 'value': 10000000},
          {'name': 'Đèn chiếu sáng', 'skuCount': 12, 'value': 8000000},
          {'name': 'Dụng cụ kim khí', 'skuCount': 8, 'value': 4000000},
          {'name': 'Phụ kiện', 'skuCount': 6, 'value': 2000000},
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardInventoryCategoryCard(
                  categoriesAsync: AsyncValue.data(categories),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Giá trị tồn kho theo nhóm'), findsOneWidget);
        // Explicit snapshot label required
        expect(
          find.text('Tồn kho hiện tại · theo giá vốn; không theo kỳ báo cáo'),
          findsOneWidget,
        );

        // Total value: 50M + 20M + 15M + 10M + 8M + 4M + 2M = 109.000.000 ₫
        expect(find.textContaining('109.000.000'), findsOneWidget);

        // Top 5 items are displayed individually
        expect(find.textContaining('Thiết bị vệ sinh cao cấp'), findsOneWidget);
        expect(find.text('Gạch ốp lát'), findsOneWidget);
        expect(find.text('Sơn & Hóa chất'), findsOneWidget);
        expect(find.text('Vật liệu thô'), findsOneWidget);
        expect(find.text('Đèn chiếu sáng'), findsOneWidget);

        // Remainder (Dụng cụ kim khí: 4M + Phụ kiện: 2M = 6M, 8 + 6 = 14 SKU) aggregated into 'Nhóm khác'
        expect(find.text('Nhóm khác'), findsOneWidget);
        expect(find.textContaining('6.000.000'), findsOneWidget);
        expect(find.text('14 SKU'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows empty placeholder when categories data is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const Scaffold(
            body: DashboardInventoryCategoryCard(
              categoriesAsync: AsyncValue.data([]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa có dữ liệu tồn kho dương theo nhóm.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'retains zero-valuation categories with positive stock and calculates SKU totals and zero bar width',
      (tester) async {
        final categories = [
          {'name': 'Vật tư giá trị cao', 'skuCount': 5, 'value': 20000000},
          {'name': 'Hàng khuyến mãi 0 đồng', 'skuCount': 8, 'value': 0},
          {'name': 'Vật tư phụ', 'skuCount': 3, 'value': 5000000},
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardInventoryCategoryCard(
                  categoriesAsync: AsyncValue.data(categories),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('25.000.000'), findsOneWidget);
        expect(find.textContaining('16 SKU'), findsOneWidget);
        expect(find.text('Hàng khuyến mãi 0 đồng'), findsOneWidget);
        expect(find.text('8 SKU'), findsOneWidget);
        expect(find.textContaining(RegExp(r'^0\s+₫$')), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is FractionallySizedBox && widget.widthFactor == 0,
          ),
          findsOneWidget,
        );
        expect(find.text('0.0%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays all-zero valuation categories safely without division by zero',
      (tester) async {
        final categories = [
          {'name': 'Nhóm quà tặng A', 'skuCount': 12, 'value': 0},
          {'name': 'Nhóm quà tặng B', 'skuCount': 8, 'value': 0},
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardInventoryCategoryCard(
                  categoriesAsync: AsyncValue.data(categories),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(RegExp(r'^0\s+₫$')), findsWidgets);
        expect(find.textContaining('20 SKU'), findsOneWidget);
        expect(find.text('Nhóm quà tặng A'), findsOneWidget);
        expect(find.text('Nhóm quà tặng B'), findsOneWidget);
        expect(find.text('Không có giá trị'), findsOneWidget);
        // Zero valuation uses neutral non-data ring without fabricated PieChartSectionData:
        expect(find.byType(PieChart), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'inventory category donut renders value-share center label and segment totals',
      (tester) async {
        final categories = [
          {'name': 'Gạch ốp lát', 'skuCount': 20, 'value': 20000000},
          {'name': 'Sơn & Hóa chất', 'skuCount': 15, 'value': 30000000},
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardInventoryCategoryCard(
                  categoriesAsync: AsyncValue.data(categories),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Donut chart is rendered when positive valuation exists
        expect(find.byType(PieChart), findsOneWidget);
        // Center label clearly indicates value share
        expect(find.text('Cơ cấu'), findsOneWidget);
        expect(find.text('giá vốn'), findsOneWidget);
        expect(find.textContaining('50.000.000'), findsOneWidget);
        final chart = tester.widget<PieChart>(find.byType(PieChart));
        expect(chart.data.sections.map((section) => section.value), [
          30000000,
          20000000,
        ]);
        expect(
          chart.data.sections.fold<double>(
            0,
            (sum, section) => sum + section.value,
          ),
          50000000,
        );
        expect(find.text('60.0%'), findsOneWidget);
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await pointer.addPointer(location: Offset.zero);
        await pointer.moveTo(
          tester.getCenter(find.byType(PieChart)) + const Offset(50, 15),
        );
        await tester.pumpAndSettle();
        expect(find.text('60.0%'), findsNWidgets(2));
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label ?? '').contains('Sơn & Hóa chất:'),
          ),
          findsOneWidget,
        );
        await pointer.removePointer();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays error state with retry when inventory category data is malformed',
      (tester) async {
        var retried = false;
        final malformedCategories = [
          {'name': 'Nhóm lỗi', 'skuCount': -1, 'value': 1000},
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardInventoryCategoryCard(
                  categoriesAsync: AsyncValue.data(malformedCategories),
                  onRetry: () => retried = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Dữ liệu giá trị tồn kho không hợp lệ.'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);
        await tester.tap(find.text('Thử lại'));
        expect(retried, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ─────────────────────────────────────────────────────────
  // WIDGET TESTS: Panel 4 - Hàng chạm mức tồn tối thiểu
  // ─────────────────────────────────────────────────────────
  group('DashboardLowStockCard', () {
    testWidgets(
      'calculates deficit, keeps individual units per row, and routes to /inventory?issue=low-stock',
      (tester) async {
        final lowStockList = [
          {
            'id': 1,
            'shopId': 2,
            'productId': 101,
            'quantity': 3,
            'currentQuantity': 3,
            'minStock': 10,
            'product': {
              'id': 101,
              'name': 'Sơn Dulux ngoại thất',
              'sku': 'SON-01',
              'unit': 'Thùng',
              'minStock': 10,
            },
          },
          {
            'id': 2,
            'shopId': 2,
            'productId': 102,
            'quantity': 15,
            'currentQuantity': 15,
            'minStock': 50,
            'product': {
              'id': 102,
              'name': 'Xi măng Hà Tiên',
              'sku': 'XM-02',
              'unit': 'Bao',
              'minStock': 50,
            },
          },
        ];

        var navigatedRoute = '';
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: SingleChildScrollView(
                  child: DashboardLowStockCard(
                    lowStockAsync: AsyncValue.data(lowStockList),
                    isAllShops: true,
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/inventory',
              builder: (context, state) {
                navigatedRoute = state.uri.toString();
                return const Scaffold(body: Text('Inventory Page'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            theme: AppTheme.lightTheme(AppColors.primary),
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hàng chạm mức tồn tối thiểu'), findsOneWidget);
        expect(find.textContaining('Ảnh chụp tức thời'), findsOneWidget);
        expect(
          find.text('CH #2'),
          findsWidgets,
        ); // All-shops shop disambiguation

        // Row 1: Sơn Dulux: tồn 3 Thùng, tối thiểu 10 Thùng, thiếu -7 Thùng
        expect(find.text('Sơn Dulux ngoại thất'), findsOneWidget);
        expect(find.text('3 Thùng'), findsOneWidget);
        expect(find.text('10 Thùng'), findsOneWidget);
        expect(find.text('-7 Thùng'), findsOneWidget);

        // Row 2: Xi măng Hà Tiên: tồn 15 Bao, tối thiểu 50 Bao, thiếu -35 Bao (no summing unlike units)
        expect(find.text('Xi măng Hà Tiên'), findsOneWidget);
        expect(find.text('15 Bao'), findsOneWidget);
        expect(find.text('50 Bao'), findsOneWidget);
        expect(find.text('-35 Bao'), findsOneWidget);

        // Test "Xem tất cả (2)" routing
        expect(find.text('Xem tất cả (2)'), findsOneWidget);
        await tester.tap(find.text('Xem tất cả (2)'));
        await tester.pumpAndSettle();
        expect(navigatedRoute, equals('/inventory?issue=low-stock'));
      },
    );

    testWidgets(
      'shows healthy reassuring empty state when low stock items are empty',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DashboardLowStockCard(
                  lowStockAsync: AsyncValue.data([]),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mức tồn ổn định'), findsOneWidget);
        expect(
          find.text(
            'Không có mặt hàng chạm mức tồn tối thiểu trong phạm vi đang xem.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'accurately calculates deficit and displays negative stock quantity',
      (tester) async {
        final negativeStockList = [
          {
            'productId': 201,
            'name': 'Gạch granite chống trơn',
            'sku': 'GACH-01',
            'unit': 'Hộp',
            'currentQuantity': -5,
            'minStock': 10,
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardLowStockCard(
                  lowStockAsync: AsyncValue.data(negativeStockList),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gạch granite chống trơn'), findsOneWidget);
        expect(find.text('-5 Hộp'), findsOneWidget);
        expect(find.text('10 Hộp'), findsOneWidget);
        // Deficit is max(10 - (-5), 0) = 15 -> formatted as '-15 Hộp'
        expect(find.text('-15 Hộp'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'displays error state with retry when low stock records are malformed or missing required fields',
      (tester) async {
        var retried = false;
        final malformedList = [
          {'name': 'Sản phẩm lỗi', 'currentQuantity': 2, 'minStock': 10},
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DashboardLowStockCard(
                  lowStockAsync: AsyncValue.data(malformedList),
                  onRetry: () => retried = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Dữ liệu tồn kho tối thiểu không hợp lệ.'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);
        await tester.tap(find.text('Thử lại'));
        expect(retried, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders product name full width without maxLines cap and full readable SKU at 390px text1.5',
      (tester) async {
        tester.view.physicalSize = const Size(390, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final lowStockItems = [
          {
            'id': 1,
            'shopId': 1,
            'productId': 1,
            'currentQuantity': -2,
            'minStock': 20,
            'product': {
              'id': 1,
              'name': 'Sơn ngoại thất bền màu cao cấp chống thấm đặc biệt',
              'sku': 'SON-NGOAI-THAT-001',
              'unit': 'Thùng',
              'minStock': 20,
            },
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 800),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: DashboardLowStockCard(
                    isAllShops: true,
                    lowStockAsync: AsyncValue.data(lowStockItems),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Product name is rendered in full without truncation cap
        expect(
          find.text('Sơn ngoại thất bền màu cao cấp chống thấm đặc biệt'),
          findsOneWidget,
        );
        // SKU is fully readable without aggressive ellipsis
        expect(find.text('SON-NGOAI-THAT-001'), findsOneWidget);
        expect(find.text('CH #1'), findsOneWidget);
        // Deficit badge is visible on separate wrapping row
        expect(find.text('Thiếu 22 Thùng'), findsOneWidget);
        expect(find.text('Tồn: '), findsOneWidget);
        expect(find.text('-2 Thùng'), findsOneWidget);
        expect(find.text('Mức tối thiểu: '), findsOneWidget);
        expect(find.text('20 Thùng'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ─────────────────────────────────────────────────────────
  // RESPONSIVE & ACCESSIBILITY TESTS (390px, 1440px, TextScaler 1.5)
  // ─────────────────────────────────────────────────────────
  group('Dashboard insights responsive layout', () {
    for (final config in [
      (width: 390.0, scale: 1.0, name: 'Mobile 390px'),
      (width: 390.0, scale: 1.5, name: 'Mobile 390px Scaler 1.5'),
      (width: 1440.0, scale: 1.0, name: 'Desktop 1440px'),
      (width: 1440.0, scale: 1.5, name: 'Desktop 1440px Scaler 1.5'),
    ]) {
      testWidgets('renders all 4 panels smoothly at ${config.name}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(config.width, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cashData = {
          'income': 15000000000,
          'expense': 3000000000,
          'netCashFlow': 12000000000,
          'cashBalance': 18416843500,
          'dailyFlow': [
            {
              'date': '2026-09-01',
              'income': 10000000000,
              'expense': 2000000000,
            },
            {'date': '2026-09-02', 'income': 5000000000, 'expense': 1000000000},
          ],
        };

        final salesData = {
          'netSalesRevenue': 12345678900,
          'totalCogs': 9888889900,
          'grossProfit': 2456789000,
          'totalOrders': 1234,
        };

        final categories = [
          {
            'name': 'Thiết bị vệ sinh một khối mẫu lớn',
            'skuCount': 15,
            'value': 8500000000,
          },
          {
            'name': 'Gạch ốp lát granite cao cấp xuất khẩu',
            'skuCount': 22,
            'value': 3200000000,
          },
        ];

        final lowStock = [
          {
            'id': 1,
            'shopId': 1,
            'productId': 101,
            'quantity': 5,
            'currentQuantity': 5,
            'minStock': 20,
            'product': {
              'id': 101,
              'name': 'Sơn Dulux ngoại thất bền màu tối ưu',
              'sku': 'SON-DULUX-01',
              'unit': 'Thùng',
              'minStock': 20,
            },
          },
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: MediaQuery(
              data: const MediaQueryData().copyWith(
                size: Size(config.width, 1400),
                textScaler: TextScaler.linear(config.scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      DashboardSalesPerformanceCard(
                        currentSales: AsyncValue.data(salesData),
                        comparisonSales: AsyncValue.data(salesData),
                        currentLabel: 'T9/2026',
                        previousLabel: 'T8/2026',
                      ),
                      const SizedBox(height: 16),
                      DashboardCashFlowCard(
                        cashAsync: AsyncValue.data(cashData),
                        currentLabel: 'T9/2026',
                      ),
                      const SizedBox(height: 16),
                      DashboardInventoryCategoryCard(
                        categoriesAsync: AsyncValue.data(categories),
                      ),
                      const SizedBox(height: 16),
                      DashboardLowStockCard(
                        lowStockAsync: AsyncValue.data(lowStock),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kết quả bán hàng'), findsOneWidget);
        expect(find.text('Thu – chi trong kỳ'), findsOneWidget);
        expect(find.text('Giá trị tồn kho theo nhóm'), findsOneWidget);
        expect(find.text('Hàng chạm mức tồn tối thiểu'), findsOneWidget);

        final err = tester.takeException();
        if (err is FlutterError) {
          debugPrint(err.toString());
        }
        expect(err, isNull);
      });
    }
  });

  // ─────────────────────────────────────────────────────────
  // RBAC GATING TEST: Role without inventory does not watch inventory providers
  // ─────────────────────────────────────────────────────────
  testWidgets(
    'DashboardScreen does not render inventory cards when role lacks inventory permission',
    (tester) async {
      var inventoryCategoriesWatched = false;
      var lowStockWatched = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(_NoInventoryShopNotifier.new),
            salesSummaryProvider.overrideWith(
              (ref, period) async => {
                'orderCount': 10,
                'totalOrders': 10,
                'netSalesRevenue': 5000000,
                'grossProfit': 1000000,
                'totalCogs': 4000000,
                'daily': [],
                'period': {'from': period.from, 'to': period.to},
                'timezone': 'Asia/Ho_Chi_Minh',
              },
            ),
            topProductsProvider.overrideWith((ref, period) async => []),
            recentTransactionsProvider.overrideWith((ref) async => []),
            dashboardActionProvider.overrideWith(
              (ref) async => DashboardActionData(
                asOf: DateTime(2026, 9, 9),
                items: const [],
                healthySummary: const [],
              ),
            ),
            inventoryCategoriesSummaryProvider.overrideWith((ref) {
              inventoryCategoriesWatched = true;
              return [];
            }),
            lowStockProvider.overrideWith((ref) {
              lowStockWatched = true;
              return [];
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: DashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inventory providers must NOT be watched or rendered when user lacks inventory permission
      expect(inventoryCategoriesWatched, isFalse);
      expect(lowStockWatched, isFalse);
      expect(find.text('Giá trị tồn kho theo nhóm'), findsNothing);
      expect(find.text('Hàng chạm mức tồn tối thiểu'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NoInventoryShopNotifier extends ShopNotifier {
  @override
  ShopState build() => const ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng nhân viên bán hàng',
    memberType: 'STAFF',
    status: 'ACTIVE',
    isLoading: false,
    userShops: [
      {
        'shopId': 1,
        'shopName': 'Cửa hàng nhân viên bán hàng',
        'status': 'ACTIVE',
        'memberType': 'STAFF',
        'permissions': ['sales'], // NO inventory, NO finance
      },
    ],
  );
}
