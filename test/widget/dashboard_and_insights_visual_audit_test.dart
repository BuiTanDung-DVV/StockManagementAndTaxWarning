import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_dashboard/screenshots';

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

  @override
  Future<void> loadUserShops() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
    SharedPreferences.setMockInitialValues({
      'tab_selection_dashboard': 'THIS_MONTH',
    });
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

  const fakeAllShopsState = ShopState(
    currentShopId: 0,
    currentShopName: 'Tất cả cửa hàng',
    memberType: 'OWNER',
    status: 'ACTIVE',
    isAllShops: true,
    userShops: [
      {
        'id': 1,
        'name': 'Cửa hàng 1 - Quận 1',
        'role': 'OWNER',
      },
      {
        'id': 2,
        'name': 'Cửa hàng 2 - Bình Thạnh',
        'role': 'OWNER',
      },
    ],
  );

  const fakeNoShopState = ShopState(
    currentShopId: null,
    currentShopName: null,
    memberType: null,
    status: 'ACTIVE',
    userShops: [],
  );

  final fakeSalesSummary = <String, dynamic>{
    'totalSales': 125000000.0,
    'totalRevenue': 125000000.0,
    'netSalesRevenue': 125000000.0,
    'totalCogs': 78000000.0,
    'grossProfit': 47000000.0,
    'totalOrders': 142,
    'orderCount': 142,
    'averageOrderValue': 880280.0,
    'cashRevenue': 45000000.0,
    'bankRevenue': 80000000.0,
    'trend': [
      {'date': '01/09', 'revenue': 12000000.0, 'sales': 12000000.0, 'orders': 14},
      {'date': '05/09', 'revenue': 18500000.0, 'sales': 18500000.0, 'orders': 22},
      {'date': '10/09', 'revenue': 15200000.0, 'sales': 15200000.0, 'orders': 18},
      {'date': '15/09', 'revenue': 22000000.0, 'sales': 22000000.0, 'orders': 26},
      {'date': '20/09', 'revenue': 19800000.0, 'sales': 19800000.0, 'orders': 21},
      {'date': '25/09', 'revenue': 24500000.0, 'sales': 24500000.0, 'orders': 28},
      {'date': '30/09', 'revenue': 13000000.0, 'sales': 13000000.0, 'orders': 13},
    ],
    'chart': [
      {'date': '01/09', 'revenue': 12000000.0},
      {'date': '05/09', 'revenue': 18500000.0},
      {'date': '10/09', 'revenue': 15200000.0},
      {'date': '15/09', 'revenue': 22000000.0},
      {'date': '20/09', 'revenue': 19800000.0},
      {'date': '25/09', 'revenue': 24500000.0},
      {'date': '30/09', 'revenue': 13000000.0},
    ],
  };

  final fakePreviousSalesSummary = <String, dynamic>{
    'totalSales': 110000000.0,
    'totalRevenue': 110000000.0,
    'netSalesRevenue': 110000000.0,
    'totalCogs': 70000000.0,
    'grossProfit': 40000000.0,
    'totalOrders': 130,
    'orderCount': 130,
    'averageOrderValue': 846153.0,
    'trend': [
      {'date': '01/08', 'revenue': 10000000.0, 'sales': 10000000.0, 'orders': 12},
      {'date': '05/08', 'revenue': 14000000.0, 'sales': 14000000.0, 'orders': 16},
      {'date': '10/08', 'revenue': 16000000.0, 'sales': 16000000.0, 'orders': 20},
      {'date': '15/08', 'revenue': 19000000.0, 'sales': 19000000.0, 'orders': 22},
      {'date': '20/08', 'revenue': 18000000.0, 'sales': 18000000.0, 'orders': 21},
      {'date': '25/08', 'revenue': 20000000.0, 'sales': 20000000.0, 'orders': 24},
      {'date': '31/08', 'revenue': 13000000.0, 'sales': 13000000.0, 'orders': 15},
    ],
  };

  final fakeCashSummary = <String, dynamic>{
    'income': 45200000.0,
    'expense': 16700000.0,
    'netCashFlow': 28500000.0,
    'totalIn': 45200000.0,
    'totalOut': 16700000.0,
    'cashIn': 18000000.0,
    'bankIn': 27200000.0,
    'cashOut': 6700000.0,
    'bankOut': 10000000.0,
    'openingBalance': 15000000.0,
    'closingBalance': 43500000.0,
    'dailyFlow': [
      {'date': '2026-09-01', 'income': 1500000.0, 'expense': 500000.0},
      {'date': '2026-09-05', 'income': 3200000.0, 'expense': 1200000.0},
      {'date': '2026-09-10', 'income': 4500000.0, 'expense': 2100000.0},
      {'date': '2026-09-15', 'income': 6800000.0, 'expense': 1900000.0},
      {'date': '2026-09-20', 'income': 8900000.0, 'expense': 3400000.0},
      {'date': '2026-09-25', 'income': 11200000.0, 'expense': 4200000.0},
      {'date': '2026-09-30', 'income': 9100000.0, 'expense': 3400000.0},
    ],
  };

  final fakeRecentTransactions = <Map<String, dynamic>>[
    {
      'id': 1,
      'code': 'HD-202609-001',
      'type': 'SALE',
      'amount': 350000.0,
      'date': '2026-09-30T10:15:00',
      'paymentMethod': 'CASH',
      'customerName': 'Nguyễn Văn An',
    },
    {
      'id': 2,
      'code': 'PC-202609-002',
      'type': 'EXPENSE',
      'amount': 1200000.0,
      'date': '2026-09-29T16:30:00',
      'paymentMethod': 'BANK_TRANSFER',
      'description': 'Tiền điện tháng 9',
    },
    {
      'id': 3,
      'code': 'HD-202609-003',
      'type': 'SALE',
      'amount': 850000.0,
      'date': '2026-09-29T14:20:00',
      'paymentMethod': 'QR_TRANSFER',
      'customerName': 'Lê Thị Bình',
    },
  ];

  final fakeTopProducts = <Map<String, dynamic>>[
    {
      'productId': 1,
      'productName': 'Gạo ST25 Ông Cua Túi 5kg',
      'sku': 'GAO-ST25-5KG',
      'quantitySold': 85,
      'revenue': 17000000.0,
    },
    {
      'productId': 2,
      'productName': 'Dầu ăn Neptune Gold 1L',
      'sku': 'DAU-NEPTUNE-1L',
      'quantitySold': 62,
      'revenue': 3100000.0,
    },
    {
      'productId': 3,
      'productName': 'Sữa tươi Vinamilk 100% 1L',
      'sku': 'SUA-VML-1L',
      'quantitySold': 48,
      'revenue': 1680000.0,
    },
  ];

  final fakeInventoryCategories = <Map<String, dynamic>>[
    {'category': 'Lương thực', 'totalProducts': 24, 'totalValue': 45000000.0},
    {'category': 'Gia vị & Dầu ăn', 'totalProducts': 38, 'totalValue': 28000000.0},
    {'category': 'Sữa & Bánh kẹo', 'totalProducts': 52, 'totalValue': 35000000.0},
  ];

  final fakeLowStock = <Map<String, dynamic>>[
    {
      'id': 5,
      'name': 'Đường tinh luyện Biên Hòa 1kg',
      'sku': 'DUONG-BH-1KG',
      'quantity': 3,
      'minStock': 20,
    },
    {
      'id': 8,
      'name': 'Nước mắm Nam Ngư Đệ Nhị 900ml',
      'sku': 'MAM-NN-900ML',
      'quantity': 2,
      'minStock': 15,
    },
  ];

  final fakeActionItems = <DashboardActionItem>[
    const DashboardActionItem(
      actionKey: 'low_stock_warning',
      severity: DashboardActionSeverity.warning,
      priorityScore: 90,
      title: '2 sản phẩm sắp hết hàng',
      detail: 'Cần bổ sung đơn nhập kho để đảm bảo cung ứng bán lẻ.',
      badge: 'Cần xử lý',
      count: 2,
    ),
    const DashboardActionItem(
      actionKey: 'tax_threshold_alert',
      severity: DashboardActionSeverity.info,
      priorityScore: 70,
      title: 'Doanh thu đạt 83.3% ngưỡng thuế',
      detail: 'Doanh thu tích lũy 125/150 triệu ₫ trong năm hiện tại.',
      badge: 'Cảnh báo thuế',
      amount: 125000000.0,
    ),
  ];

  final fakeActionData = DashboardActionData(
    asOf: DateTime(2026, 9, 30, 10, 0),
    items: fakeActionItems,
    healthySummary: const [],
  );

  group('Dashboard & Smart Insights Visual Audit', () {
    testWidgets('Capture Dashboard Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('dashboard_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            salesSummaryProvider.overrideWith((ref, args) {
              if (args.from.compareTo('2026-09') < 0) {
                return Future.value(fakePreviousSalesSummary);
              }
              return Future.value(fakeSalesSummary);
            }),
            cashSummaryProvider.overrideWith((ref, args) => Future.value(fakeCashSummary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value(fakeRecentTransactions)),
            topProductsProvider.overrideWith((ref, args) => Future.value(fakeTopProducts)),
            inventoryCategoriesSummaryProvider.overrideWith((ref) => Future.value(fakeInventoryCategories)),
            lowStockProvider.overrideWith((ref) => Future.value(fakeLowStock)),
            dashboardActionProvider.overrideWith((ref) => Future.value(fakeActionData)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '01_dashboard_desktop.png');

      expect(find.text('Tổng quan cửa hàng'), findsOneWidget);
      expect(find.text('Doanh thu thuần'), findsWidgets);
    });

    testWidgets('Capture Dashboard Mobile (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('dashboard_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            salesSummaryProvider.overrideWith((ref, args) {
              if (args.from.compareTo('2026-09') < 0) {
                return Future.value(fakePreviousSalesSummary);
              }
              return Future.value(fakeSalesSummary);
            }),
            cashSummaryProvider.overrideWith((ref, args) => Future.value(fakeCashSummary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value(fakeRecentTransactions)),
            topProductsProvider.overrideWith((ref, args) => Future.value(fakeTopProducts)),
            inventoryCategoriesSummaryProvider.overrideWith((ref) => Future.value(fakeInventoryCategories)),
            lowStockProvider.overrideWith((ref) => Future.value(fakeLowStock)),
            dashboardActionProvider.overrideWith((ref) => Future.value(fakeActionData)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '02_dashboard_mobile.png');

      expect(find.text('Tổng quan cửa hàng'), findsOneWidget);
    });

    testWidgets('Capture Dashboard All Shops View Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('dashboard_all_shops');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeAllShopsState)),
            salesSummaryProvider.overrideWith((ref, args) {
              if (args.from.compareTo('2026-09') < 0) {
                return Future.value(fakePreviousSalesSummary);
              }
              return Future.value(fakeSalesSummary);
            }),
            cashSummaryProvider.overrideWith((ref, args) => Future.value(fakeCashSummary)),
            recentTransactionsProvider.overrideWith((ref) => Future.value(fakeRecentTransactions)),
            topProductsProvider.overrideWith((ref, args) => Future.value(fakeTopProducts)),
            inventoryCategoriesSummaryProvider.overrideWith((ref) => Future.value(fakeInventoryCategories)),
            lowStockProvider.overrideWith((ref) => Future.value(fakeLowStock)),
            dashboardActionProvider.overrideWith((ref) => Future.value(fakeActionData)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '03_dashboard_all_shops_desktop.png');

      expect(find.text('Tổng quan tất cả cửa hàng'), findsOneWidget);
    });

    testWidgets('Capture Dashboard No Shop State Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('dashboard_no_shop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeNoShopState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '04_dashboard_no_shop_desktop.png');
    });
  });
}
