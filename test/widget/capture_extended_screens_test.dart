import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/notification_provider.dart';
import 'package:flutter_app/features/sales/presentation/sales_list_screen.dart';
import 'package:flutter_app/features/sales/presentation/pos_screen.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/products/presentation/product_list_screen.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';
import 'package:flutter_app/features/products/providers/tag_provider.dart';
import 'package:flutter_app/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/customers/presentation/customer_list_screen.dart';
import 'package:flutter_app/features/customers/providers/customer_provider.dart';
import 'package:flutter_app/features/finance/presentation/finance_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/settings/presentation/notification_list_screen.dart';
import 'package:flutter_app/features/shell/main_shell.dart';
import '../support/load_ui_fonts.dart';

class _MockShop extends ShopNotifier {
  @override
  ShopState build() => const ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng mẫu SmartStock',
    memberType: 'OWNER',
    status: 'ACTIVE',
    isLoading: false,
    userShops: [
      {
        'shopId': 1,
        'shopName': 'Cửa hàng mẫu SmartStock',
        'status': 'ACTIVE',
        'memberType': 'OWNER',
      },
    ],
  );
}

class _MockNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState(
    items: [
      {
        'id': 1,
        'title': 'Cảnh báo tồn kho dưới định mức',
        'message':
            'Trà Oolong Bảo Lộc chỉ còn 8 hộp (định mức tối thiểu 15 hộp). Cần lên kế hoạch nhập hàng.',
        'type': 'INVENTORY_LOW',
        'createdAt': '2026-09-19T09:15:00Z',
        'isRead': false,
      },
      {
        'id': 2,
        'title': 'Khách hàng Minh Khang phát sinh công nợ',
        'message': 'Đơn hàng DH-2026-003 chưa thanh toán số tiền 890.000 ₫.',
        'type': 'DEBT_REMINDER',
        'createdAt': '2026-09-18T16:40:00Z',
        'isRead': true,
      },
      {
        'id': 3,
        'title': 'Doanh thu ngày đạt mục tiêu',
        'message':
            'Doanh thu ngày 18/09 đã vượt chỉ tiêu ngày với tổng 15.400.000 ₫.',
        'type': 'SALES_MILESTONE',
        'createdAt': '2026-09-18T21:00:00Z',
        'isRead': true,
      },
    ],
    unreadCount: 1,
    isLoading: false,
  );
}

void main() {
  setUpAll(loadUiFonts);
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> capture(WidgetTester tester, Key key, String fileName) async {
    final boundaryFinder = find.byKey(key);
    final boundary =
        tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1.0),
    );
    final byteData = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    final file = File('BA_DOCUMENTS/TEST_RUNS/screenshots_audit/$fileName');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
  }

  final commonOverrides = [
    shopProvider.overrideWith(_MockShop.new),
    notificationProvider.overrideWith(_MockNotificationNotifier.new),
    salesListProvider.overrideWith(
      (ref, args) async => {
        'items': [
          {
            'id': 101,
            'orderCode': 'DH-2026-001',
            'createdAt': '2026-09-19T10:30:00Z',
            'totalAmount': 450000,
            'status': 'COMPLETED',
            'customerName': 'Nguyễn Văn An',
            'itemCount': 3,
            'paymentStatus': 'PAID',
            'shopId': 1,
          },
          {
            'id': 102,
            'orderCode': 'DH-2026-002',
            'createdAt': '2026-09-19T11:15:00Z',
            'totalAmount': 1250000,
            'status': 'COMPLETED',
            'customerName': 'Trần Thị Bình',
            'itemCount': 5,
            'paymentStatus': 'PAID',
            'shopId': 1,
          },
          {
            'id': 103,
            'orderCode': 'DH-2026-003',
            'createdAt': '2026-09-19T14:00:00Z',
            'totalAmount': 890000,
            'status': 'PENDING',
            'customerName': 'Lê Hoàng Cường',
            'itemCount': 2,
            'paymentStatus': 'UNPAID',
            'shopId': 1,
          },
        ],
        'total': 3,
        'page': 1,
        'totalPages': 1,
      },
    ),
    productListProvider.overrideWith(
      (ref, args) async => {
        'items': [
          {
            'id': 1,
            'name': 'Cà phê Arabica Cầu Đất 500g',
            'sku': 'CF-ARA-500',
            'barcode': '8936012345678',
            'price': 185000,
            'sellingPrice': 185000,
            'costPrice': 120000,
            'stock': 45,
            'currentStock': 45,
            'minStock': 10,
            'unit': 'Gói',
            'categoryName': 'Cà phê hạt',
            'status': 'ACTIVE',
          },
          {
            'id': 2,
            'name': 'Trà Oolong Bảo Lộc Đặc Biệt 250g',
            'sku': 'TEA-OOL-250',
            'barcode': '8936012345679',
            'price': 140000,
            'sellingPrice': 140000,
            'costPrice': 85000,
            'stock': 8,
            'currentStock': 8,
            'minStock': 15,
            'unit': 'Hộp',
            'categoryName': 'Trà thảo mộc',
            'status': 'ACTIVE',
          },
          {
            'id': 3,
            'name': 'Bột Cacao Nguyên Chất Đắk Lắk 500g',
            'sku': 'COCOA-500',
            'barcode': '8936012345680',
            'price': 160000,
            'sellingPrice': 160000,
            'costPrice': 105000,
            'stock': 62,
            'currentStock': 62,
            'minStock': 10,
            'unit': 'Hũ',
            'categoryName': 'Đồ uống hòa tan',
            'status': 'ACTIVE',
          },
        ],
        'total': 3,
        'page': 1,
        'totalPages': 1,
      },
    ),
    categoriesProvider.overrideWith(
      (ref) async => [
        'Tất cả',
        'Cà phê hạt',
        'Trà thảo mộc',
        'Đồ uống hòa tan',
      ],
    ),
    availableTagsProvider.overrideWith(
      (ref) async => [
        TagModel(id: 1, name: 'Bán chạy', color: '#10B981'),
        TagModel(id: 2, name: 'Khuyến mãi', color: '#F59E0B'),
      ],
    ),
    stockPageProvider.overrideWith(
      (ref, args) async => {
        'items': [
          {
            'id': 1,
            'name': 'Cà phê Arabica Cầu Đất 500g',
            'sku': 'CF-ARA-500',
            'currentStock': 45,
            'reservedStock': 5,
            'availableStock': 40,
            'minStock': 10,
            'maxStock': 100,
            'unit': 'Gói',
            'status': 'NORMAL',
          },
          {
            'id': 2,
            'name': 'Trà Oolong Bảo Lộc Đặc Biệt 250g',
            'sku': 'TEA-OOL-250',
            'currentStock': 8,
            'reservedStock': 0,
            'availableStock': 8,
            'minStock': 15,
            'maxStock': 60,
            'unit': 'Hộp',
            'status': 'LOW_STOCK',
          },
        ],
        'total': 2,
        'page': 1,
        'totalPages': 1,
      },
    ),
    lowStockProvider.overrideWith(
      (ref) async => [
        {
          'id': 2,
          'name': 'Trà Oolong Bảo Lộc Đặc Biệt 250g',
          'sku': 'TEA-OOL-250',
          'stock': 8,
          'minStock': 15,
          'unit': 'Hộp',
        },
      ],
    ),
    expiringProductsProvider.overrideWith((ref) async => []),
    slowMovingProvider.overrideWith((ref) async => []),
    inventoryCategoriesSummaryProvider.overrideWith(
      (ref) async => [
        {
          'category': 'Cà phê',
          'productCount': 12,
          'totalStock': 250,
          'stockValue': 35000000,
          'unit': 'Gói',
          'growthStatus': 'HIGH',
        },
      ],
    ),
    warehousesProvider.overrideWith(
      (ref) async => [
        {'id': 1, 'name': 'Kho Trung Tâm', 'isDefault': true},
      ],
    ),
    customerListProvider.overrideWith(
      (ref, args) async => {
        'items': [
          {
            'id': 1,
            'name': 'Công ty TNHH Minh Khang',
            'phone': '0901234567',
            'email': 'minhkhang@example.com',
            'customerGroup': 'Bán buôn',
            'debt': 15500000,
            'totalSpent': 124000000,
            'orderCount': 18,
          },
          {
            'id': 2,
            'name': 'Nguyễn Thu Thủy',
            'phone': '0912345678',
            'email': 'thuthuy@example.com',
            'customerGroup': 'Khách lẻ VIP',
            'debt': 0,
            'totalSpent': 8500000,
            'orderCount': 9,
          },
        ],
        'total': 2,
        'page': 1,
        'totalPages': 1,
      },
    ),
    cashSummaryProvider.overrideWith(
      (ref, period) async => {
        'income': 45000000,
        'expense': 12500000,
        'netCashFlow': 32500000,
        'cashBalance': 18416843500,
        'period': {'name': 'custom', 'from': period.from, 'to': period.to},
        'dailyFlow': [
          {'date': '2026-09-01', 'income': 12000000, 'expense': 4500000},
          {'date': '2026-09-05', 'income': 18500000, 'expense': 3200000},
          {'date': '2026-09-10', 'income': 24000000, 'expense': 8100000},
          {'date': '2026-09-15', 'income': 15000000, 'expense': 5600000},
          {'date': '2026-09-19', 'income': 28500000, 'expense': 6200000},
        ],
      },
    ),
    salesSummaryProvider.overrideWith(
      (ref, period) async => {
        'orderCount': 3,
        'totalOrders': 3,
        'netSalesRevenue': 2590000,
        'totalRevenue': 2590000,
        'grossProfit': 1135000,
        'totalCogs': 1455000,
        'returnNetSalesRevenue': 0,
        'returnRatePct': 0,
        'timezone': 'Asia/Ho_Chi_Minh',
        'period': {'from': period.from, 'to': period.to},
        'daily': [
          {
            'date': period.from,
            'revenue': 2590000,
            'cogs': 1455000,
            'grossProfit': 1135000,
            'marginPct': 43.8,
            'orderCount': 3,
          },
        ],
      },
    ),
    paymentSummaryProvider.overrideWith(
      (ref, period) async => [
        {'method': 'CASH', 'name': 'Tiền mặt', 'amount': 450000, 'count': 1},
        {
          'method': 'BANK_TRANSFER',
          'name': 'Chuyển khoản',
          'amount': 1250000,
          'count': 1,
        },
        {'method': 'DEBT', 'name': 'Ghi nợ', 'amount': 890000, 'count': 1},
      ],
    ),
    topReturnedProductsProvider.overrideWith((ref, period) async => []),
    inventoryAbcProvider.overrideWith(
      (ref, period) async => {
        'totalRevenue': 14245000,
        'classificationRevenue': 14245000,
        'negativeReturnAdjustment': 0,
        'returnedMoreThanSoldSkuCount': 0,
        'grades': ['A', 'B', 'C'],
        'items': [
          {
            'productId': 1,
            'name': 'Cà phê Arabica Cầu Đất 500g',
            'sku': 'CF-ARA-500',
            'grade': 'A',
            'revenue': 8325000,
            'percentage': 58.4,
          },
          {
            'productId': 3,
            'name': 'Bột Cacao Nguyên Chất Đắk Lắk 500g',
            'sku': 'COCOA-500',
            'grade': 'B',
            'revenue': 4800000,
            'percentage': 33.7,
          },
          {
            'productId': 2,
            'name': 'Trà Oolong Bảo Lộc Đặc Biệt 250g',
            'sku': 'TEA-OOL-250',
            'grade': 'C',
            'revenue': 1120000,
            'percentage': 7.9,
          },
        ],
      },
    ),
    expensesByCategoryForPeriodProvider.overrideWith(
      (ref, period) async => {
        'total': 12500000,
        'categories': [
          {
            'category': 'PURCHASE',
            'categoryName': 'Nhập hàng hóa',
            'total': 8500000,
          },
          {
            'category': 'SHIPPING',
            'categoryName': 'Vận chuyển',
            'total': 2500000,
          },
          {
            'category': 'PACKAGING',
            'categoryName': 'Bao bì & phụ liệu',
            'total': 1500000,
          },
        ],
      },
    ),
  ];

  Widget buildTestScreen(Widget child, String path) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(AppColors.primary),
      routerConfig: GoRouter(
        initialLocation: path,
        routes: [
          GoRoute(
            path: path,
            builder: (_, _) => MainShell(child: child),
          ),
        ],
      ),
    );
  }

  // 1. Sales List Screen
  testWidgets('Capture Sales List Screen', (tester) async {
    const key = ValueKey('sales_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const SalesListScreen(), '/sales'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'sales-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const SalesListScreen(), '/sales'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'sales-mobile.png');
  });

  // 2. POS Screen
  testWidgets('Capture POS Screen', (tester) async {
    const key = ValueKey('pos_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const PosScreen(), '/pos'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'pos-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const PosScreen(), '/pos'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'pos-mobile.png');
  });

  // 3. Products Screen
  testWidgets('Capture Product List Screen', (tester) async {
    const key = ValueKey('products_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const ProductListScreen(), '/products'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'products-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const ProductListScreen(), '/products'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'products-mobile.png');
  });

  // 4. Inventory Screen
  testWidgets('Capture Inventory Screen', (tester) async {
    const key = ValueKey('inventory_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const InventoryScreen(), '/inventory'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'inventory-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const InventoryScreen(), '/inventory'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'inventory-mobile.png');
  });

  // 5. Customer List Screen
  testWidgets('Capture Customer List Screen', (tester) async {
    const key = ValueKey('customer_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const CustomerListScreen(), '/customers'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'customers-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const CustomerListScreen(), '/customers'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'customers-mobile.png');
  });

  // 6. Finance Screen
  testWidgets('Capture Finance Screen', (tester) async {
    const key = ValueKey('finance_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const FinanceScreen(), '/finance'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'finance-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(const FinanceScreen(), '/finance'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'finance-mobile.png');
  });

  // 7. Notification List Screen
  testWidgets('Capture Notifications Screen', (tester) async {
    const key = ValueKey('notifications_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(
            const NotificationListScreen(),
            '/notifications',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'notifications-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: commonOverrides,
          child: buildTestScreen(
            const NotificationListScreen(),
            '/notifications',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'notifications-mobile.png');
  });
}
