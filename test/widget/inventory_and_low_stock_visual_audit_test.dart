import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_screen.dart';
import 'package:flutter_app/features/inventory/presentation/xnt_report_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/products/presentation/product_list_screen.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';
import 'package:flutter_app/features/products/providers/tag_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260929_inventory/screenshots';

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

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
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
        'status': 'ACTIVE',
        'isActive': true,
      },
    ],
    isLoading: false,
  );

  final dummyStockItems = [
    {
      'id': 1,
      'product': {
        'id': 101,
        'name': 'Gạo ST25 Ông Cua Túi 5kg',
        'sku': 'GAO-ST25-5K',
        'unit': 'Túi',
      },
      'currentQuantity': 45,
      'minStock': 10,
      'warehouseCount': 1,
    },
    {
      'id': 2,
      'product': {
        'id': 102,
        'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'sku': 'SUA-VNM-1L',
        'unit': 'Hộp',
      },
      'currentQuantity': 6,
      'minStock': 20,
      'warehouseCount': 1,
    },
    {
      'id': 3,
      'product': {
        'id': 103,
        'name': 'Dầu ăn Simply Canola 1L',
        'sku': 'DAU-SIM-1L',
        'unit': 'Chai',
      },
      'currentQuantity': 0,
      'minStock': 15,
      'warehouseCount': 1,
    },
  ];

  final dummyLowStock = [
    {
      'id': 2,
      'product': {
        'id': 102,
        'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'sku': 'SUA-VNM-1L',
        'unit': 'Hộp',
      },
      'currentQuantity': 6,
      'minStock': 20,
      'warehouseCount': 1,
    },
    {
      'id': 3,
      'product': {
        'id': 103,
        'name': 'Dầu ăn Simply Canola 1L',
        'sku': 'DAU-SIM-1L',
        'unit': 'Chai',
      },
      'currentQuantity': 0,
      'minStock': 15,
      'warehouseCount': 1,
    },
    {
      'id': 4,
      'product': {
        'id': 104,
        'name': 'Nước mắm Nam Ngư Đệ Nhị 900ml',
        'sku': 'MAM-NN-900',
        'unit': 'Chai',
      },
      'currentQuantity': 4,
      'minStock': 12,
      'warehouseCount': 1,
    },
  ];

  final dummyExpiring = [
    {
      'id': 201,
      'product': {
        'id': 105,
        'name': 'Sữa chua có đường Ba Vì lốc 4 hộp',
        'sku': 'SC-BAVI-4H',
        'unit': 'Lốc',
      },
      'currentQuantity': 18,
      'expiryDate': DateTime.now()
          .add(const Duration(days: 5))
          .toIso8601String(),
      'lotNumber': 'LO-202609A',
    },
  ];

  final dummySlowMoving = [
    {
      'id': 301,
      'product': {
        'id': 106,
        'name': 'Hạt dẻ cười Mỹ rang muối hũ 500g',
        'sku': 'HAT-DE-500G',
        'unit': 'Hũ',
      },
      'currentQuantity': 25,
      'stockValue': 4750000.0,
      'daysSinceLastSale': 45,
    },
  ];

  final dummyAbcAnalysis = {
    'totalRevenue': 125000000.0,
    'classificationRevenue': 125000000.0,
    'negativeReturnAdjustment': 0.0,
    'returnedMoreThanSoldSkuCount': 0,
    'totalStockValue': 345000000.0,
    'skuCount': 350,
    'timezone': 'Asia/Ho_Chi_Minh',
    'period': {'from': '2026-09-01', 'to': '2026-09-29'},
    'grades': [
      {
        'grade': 'A',
        'name': 'Chủ lực',
        'skuCount': 70,
        'revenueShare': 0.70,
        'stockValue': 185000000.0,
      },
      {
        'grade': 'B',
        'name': 'Ổn định',
        'skuCount': 105,
        'revenueShare': 0.20,
        'stockValue': 95000000.0,
      },
      {
        'grade': 'C',
        'name': 'Bổ trợ',
        'skuCount': 175,
        'revenueShare': 0.10,
        'stockValue': 65000000.0,
      },
    ],
    'items': [
      {
        'productId': 101,
        'name': 'Gạo ST25 Ông Cua Túi 5kg',
        'sku': 'GAO-ST25-5K',
        'category': 'Gạo & Ngũ cốc',
        'grade': 'A',
        'revenue': 38500000.0,
        'quantitySold': 210,
        'currentStock': 45,
        'unit': 'Túi',
      },
      {
        'productId': 102,
        'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'sku': 'SUA-VNM-1L',
        'category': 'Sữa & Bơ sữa',
        'grade': 'A',
        'revenue': 24600000.0,
        'quantitySold': 680,
        'currentStock': 6,
        'unit': 'Hộp',
      },
    ],
  };

  final dummyCategoriesSummary = [
    {'name': 'Gạo & Lương thực', 'value': 120000000.0, 'skuCount': 42},
    {'name': 'Sữa & Chế phẩm', 'value': 85000000.0, 'skuCount': 68},
    {'name': 'Dầu ăn & Gia vị', 'value': 75000000.0, 'skuCount': 110},
    {'name': 'Bánh kẹo & Đồ ăn vặt', 'value': 65000000.0, 'skuCount': 130},
  ];

  final dummyProductsList = [
    {
      'id': 101,
      'name': 'Gạo ST25 Ông Cua Túi 5kg',
      'sku': 'GAO-ST25-5K',
      'sellingPrice': 185000,
      'costPrice': 140000,
      'currentStock': 45,
      'minStock': 10,
      'unit': 'Túi',
      'tags': <dynamic>['Bán chạy'],
      'category': 'Gạo & Ngũ cốc',
    },
    {
      'id': 102,
      'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
      'sku': 'SUA-VNM-1L',
      'sellingPrice': 38000,
      'costPrice': 29000,
      'currentStock': 6,
      'minStock': 20,
      'unit': 'Hộp',
      'tags': <dynamic>['Sắp hết'],
      'category': 'Sữa & Bơ sữa',
    },
    {
      'id': 103,
      'name': 'Dầu ăn Simply Canola 1L',
      'sku': 'DAU-SIM-1L',
      'sellingPrice': 65000,
      'costPrice': 52000,
      'currentStock': 0,
      'minStock': 15,
      'unit': 'Chai',
      'tags': <dynamic>[],
      'category': 'Dầu ăn & Gia vị',
    },
  ];

  final dummyXntData = {
    'summary': {
      'openingStock': 180,
      'totalImport': 250,
      'totalExport': 379,
      'closingStock': 51,
      'openingSkuCount': 2,
      'importedSkuCount': 2,
      'exportedSkuCount': 2,
      'closingSkuCount': 2,
    },
    'items': [
      {
        'id': 101,
        'sku': 'GAO-ST25-5K',
        'name': 'Gạo ST25 Ông Cua Túi 5kg',
        'productName': 'Gạo ST25 Ông Cua Túi 5kg',
        'unit': 'Túi',
        'openingStock': 60,
        'imported': 50,
        'totalImport': 50,
        'exported': 65,
        'totalExport': 65,
        'closingStock': 45,
      },
      {
        'id': 102,
        'sku': 'SUA-VNM-1L',
        'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'productName': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'unit': 'Hộp',
        'openingStock': 120,
        'imported': 200,
        'totalImport': 200,
        'exported': 314,
        'totalExport': 314,
        'closingStock': 6,
      },
    ],
  };

  group('Inventory & Low Stock Warning Visual Audit', () {
    testWidgets('Capture Inventory Screen Desktop (1440x900)', (tester) async {
      const screenKey = ValueKey('inventory_desktop_key');
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            stockPageProvider(null).overrideWith(
              (ref) => Future.value({
                'items': dummyStockItems,
                'total': 350,
                'productTotal': 350,
                'page': 1,
                'totalPages': 1,
              }),
            ),
            lowStockProvider.overrideWith((ref) => Future.value(dummyLowStock)),
            expiringProductsProvider.overrideWith(
              (ref) => Future.value(dummyExpiring),
            ),
            slowMovingProvider.overrideWith(
              (ref) => Future.value(dummySlowMoving),
            ),
            inventoryCategoriesSummaryProvider.overrideWith(
              (ref) => Future.value(dummyCategoriesSummary),
            ),
            inventoryAbcProvider.overrideWith(
              (ref, args) => Future.value(dummyAbcAnalysis),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: screenKey,
              child: InventoryScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '01_inventory_overview_desktop.png');

      expect(find.text('Quản lý kho'), findsOneWidget);
      expect(find.text('Dưới định mức'), findsWidgets);
      expect(find.text('Sắp/quá hạn'), findsWidgets);
    });

    testWidgets('Capture Inventory Screen Mobile (390x844)', (tester) async {
      const screenKey = ValueKey('inventory_mobile_key');
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            stockPageProvider(null).overrideWith(
              (ref) => Future.value({
                'items': dummyStockItems,
                'total': 350,
                'productTotal': 350,
                'page': 1,
                'totalPages': 1,
              }),
            ),
            lowStockProvider.overrideWith((ref) => Future.value(dummyLowStock)),
            expiringProductsProvider.overrideWith(
              (ref) => Future.value(dummyExpiring),
            ),
            slowMovingProvider.overrideWith(
              (ref) => Future.value(dummySlowMoving),
            ),
            inventoryCategoriesSummaryProvider.overrideWith(
              (ref) => Future.value(dummyCategoriesSummary),
            ),
            inventoryAbcProvider.overrideWith(
              (ref, args) => Future.value(dummyAbcAnalysis),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: screenKey,
              child: InventoryScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '02_inventory_overview_mobile.png');

      expect(find.text('Quản lý kho'), findsOneWidget);
    });

    testWidgets(
      'Capture Product List Screen with Stock Badges & Out-of-stock (Desktop & Mobile)',
      (tester) async {
        const screenKey = ValueKey('product_list_desktop_key');
        await tester.binding.setSurfaceSize(const Size(1440, 900));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _FakeAuthNotifier(
                  const AuthState(
                    user: {'id': 1, 'name': 'Chủ cửa hàng', 'role': 'OWNER'},
                  ),
                ),
              ),
              shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': dummyProductsList,
                  'total': 3,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              availableTagsProvider.overrideWith(
                (ref) => Future.value([
                  TagModel(
                    id: 1,
                    name: 'Bán chạy',
                    type: 'product',
                    color: '#9C27B0',
                  ),
                  TagModel(
                    id: 2,
                    name: 'Sắp hết',
                    type: 'product',
                    color: '#FF9800',
                  ),
                ]),
              ),
              topProductsProvider.overrideWith(
                (ref, args) => Future.value([
                  {'name': 'Gạo ST25 Ông Cua Túi 5kg'},
                ]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const RepaintBoundary(
                key: screenKey,
                child: ProductListScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await _capture(
          tester,
          screenKey,
          '03_product_list_stock_badges_desktop.png',
        );

        expect(find.text('Danh mục sản phẩm'), findsOneWidget);
        expect(find.text('Gạo ST25 Ông Cua Túi 5kg'), findsOneWidget);
        expect(find.text('Sữa tươi Tiệt trùng Vinamilk 1L'), findsOneWidget);
        expect(find.text('Dầu ăn Simply Canola 1L'), findsOneWidget);

        // Mobile capture
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpAndSettle();
        await _capture(
          tester,
          screenKey,
          '04_product_list_stock_badges_mobile.png',
        );
      },
    );

    testWidgets('Capture XNT Report Screen (1440x900)', (tester) async {
      const screenKey = ValueKey('xnt_report_key');
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            xntReportProvider.overrideWith(
              (ref, args) => Future.value(dummyXntData),
            ),
            slowMovingProvider.overrideWith(
              (ref) => Future.value(dummySlowMoving),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: screenKey,
              child: XntReportScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '05_xnt_report_desktop.png');

      expect(find.text('Báo cáo XNT Kho'), findsOneWidget);
      expect(find.text('Gạo ST25 Ông Cua Túi 5kg'), findsOneWidget);
    });

    testWidgets('Capture Stock Take Screen (1440x900)', (tester) async {
      const screenKey = ValueKey('stock_take_key');
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            stockProvider(
              null,
            ).overrideWith((ref) => Future.value(dummyStockItems)),
            stockTakesProvider.overrideWith(
              (ref, page) => Future.value({
                'items': [
                  {
                    'id': 1,
                    'code': 'KK-202609-001',
                    'createdAt': '2026-09-28T09:30:00.000Z',
                    'status': 'COMPLETED',
                    'totalProducts': 24,
                    'totalDifference': -2,
                    'note': 'Kiểm kê định kỳ cuối tháng 9',
                  },
                ],
                'total': 1,
                'page': 1,
                'totalPages': 1,
              }),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: screenKey,
              child: StockTakeScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '06_stock_take_desktop.png');

      expect(find.text('Kiểm kê Kho'), findsOneWidget);
      expect(find.text('Gạo ST25 Ông Cua Túi 5kg'), findsOneWidget);
      expect(find.text('Dầu ăn Simply Canola 1L'), findsOneWidget);

      // Test tìm kiếm sản phẩm theo tên
      await tester.enterText(find.byType(TextField), 'Simply');
      await tester.pumpAndSettle();
      expect(find.text('Dầu ăn Simply Canola 1L'), findsOneWidget);
      expect(find.text('Gạo ST25 Ông Cua Túi 5kg'), findsNothing);

      // Test tìm kiếm không có kết quả
      await tester.enterText(find.byType(TextField), 'Không tồn tại 999');
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy sản phẩm'), findsOneWidget);
    });
  });
}
