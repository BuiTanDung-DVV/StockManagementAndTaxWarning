import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/finance/presentation/profit_loss_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_declaration_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/finance/providers/tax_reference_provider.dart';
import 'package:flutter_app/features/inventory/presentation/inventory_screen.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20261001_compliance/screenshots';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary =
      tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
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

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeTaxConfigNotifier extends TaxConfigNotifier {
  final TaxConfig _initial;
  _FakeTaxConfigNotifier(this._initial);

  @override
  TaxConfig build() => _initial;
}

class _FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async => {};
}

final _mockReferenceData = TaxReferenceData(
  forms: const [
    TaxDeclarationFormReference(
      code: '01/CNKD',
      name: 'Tờ khai 01/CNKD (Thông tư 40/2021/TT-BTC)',
      description:
          'Tờ khai thuế đối với cá nhân kinh doanh nộp thuế theo phương pháp kê khai hoặc khoán doanh thu.',
      status: 'READY',
      iconKey: 'article',
    ),
    TaxDeclarationFormReference(
      code: '01-2/BK-HĐKD',
      name: 'Phụ lục 01-2/BK-HĐKD',
      description:
          'Bảng kê chi tiết hoạt động kinh doanh vật tư, hàng hóa và dịch vụ bán lẻ.',
      status: 'READY',
      iconKey: 'list',
    ),
  ],
  supportLinks: const [
    TaxSupportLinkReference(
      title: 'Cổng thông tin Thuế điện tử',
      description: 'Nộp tờ khai XML trực tuyến tới Tổng cục Thuế',
      url: 'https://thuedientu.gdt.gov.vn',
      iconKey: 'account_balance',
      colorRole: 'primary',
    ),
  ],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
    SharedPreferences.setMockInitialValues({});
  });

  const fakeShopState = ShopState(
    currentShopId: 1,
    currentShopName: 'Hộ kinh doanh SmartStock',
    memberType: 'OWNER',
    status: 'ACTIVE',
    userShops: [
      {
        'id': 1,
        'name': 'Hộ kinh doanh SmartStock',
        'role': 'OWNER',
      },
    ],
  );

  const fakeAuthState = AuthState(
    isLoggedIn: true,
    token: 'fake_jwt_token',
    user: {
      'id': 1,
      'fullName': 'Nguyễn Văn Chủ',
      'email': 'chuho@smartstock.vn',
      'role': 'OWNER',
    },
  );

  final fakeTaxConfig = createDefaultVerifiedTaxConfig(
    businessType: BusinessType.distribution,
  );

  group('Data Logging and Compliance Visual Audit', () {
    testWidgets('01_profit_loss_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('profit_loss_desktop');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProfileProvider.overrideWith(
              (ref) async => {
                'shopName': 'Hộ kinh doanh SmartStock',
                'taxCode': '0312345678',
                'address': 'Số 123 Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
              },
            ),
            profitLossProvider.overrideWith((ref, arg) async {
              return {
                'revenue': 285000000.0,
                'cogs': 175000000.0,
                'grossProfit': 110000000.0,
                'operatingExpenses': 42000000.0,
                'netProfit': 68000000.0,
              };
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(key: key, child: ProfitLossScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Tổng quan lãi và lỗ'), findsOneWidget);
      expect(find.text('Xuất PDF'), findsOneWidget);
      expect(find.text('Đổi kỳ báo cáo'), findsOneWidget);
      await _capture(tester, key, '01_profit_loss_desktop.png');
    });

    testWidgets('02_tax_declaration_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('tax_declaration_desktop');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            taxConfigProvider.overrideWith(
              () => _FakeTaxConfigNotifier(fakeTaxConfig),
            ),
            taxReferenceDataProvider.overrideWith(
              (ref) async => _mockReferenceData,
            ),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
            shopProfileProvider.overrideWith(
              (ref) async => {
                'shopName': 'Hộ kinh doanh SmartStock',
                'taxCode': '0312345678',
                'address': 'Số 123 Đường Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
              },
            ),
            profitLossProvider.overrideWith((ref, arg) async {
              return {
                'revenue': 185000000.0,
                'cogs': 120000000.0,
                'grossProfit': 65000000.0,
                'operatingExpenses': 25000000.0,
                'netProfit': 40000000.0,
              };
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(key: key, child: TaxDeclarationScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Kê khai thuế'), findsOneWidget);
      expect(find.textContaining('Hạn nộp tờ khai:'), findsOneWidget);
      expect(find.textContaining('Điều 44 Luật Quản lý Thuế'), findsOneWidget);
      await _capture(tester, key, '02_tax_declaration_desktop.png');
    });

    testWidgets('03_stock_take_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('stock_take_desktop');

      final dummyStockItems = [
        {
          'id': 1,
          'currentQuantity': 2,
          'product': {
            'name': 'Sữa tươi tiệt trùng Vinamilk 1L',
            'sku': 'VNM-1L-01',
            'unit': 'Hộp',
            'minStock': 10,
          },
          'warehouse': {'name': 'Kho Trung Tâm'},
        },
        {
          'id': 2,
          'currentQuantity': 50,
          'product': {
            'name': 'Gạo thơm lài đặc sản ST25 5kg',
            'sku': 'GAO-ST25-5K',
            'unit': 'Túi',
            'minStock': 15,
          },
          'warehouse': {'name': 'Kho Bán Lẻ'},
        },
        {
          'id': 3,
          'currentQuantity': 1,
          'product': {
            'name': 'Dầu ăn Neptune Gold 1L',
            'sku': 'DA-NEP-1L',
            'unit': 'Chai',
            'minStock': 8,
          },
          'warehouse': {'name': 'Kho Bán Lẻ'},
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            stockProvider.overrideWith((ref, arg) async => dummyStockItems),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(key: key, child: StockTakeScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Kiểm kê Kho'), findsOneWidget);
      expect(find.text('Tất cả (3)'), findsOneWidget);
      expect(find.text('Cảnh báo thiếu (2)'), findsOneWidget);
      expect(find.text('Tồn an toàn (1)'), findsOneWidget);
      await _capture(tester, key, '03_stock_take_desktop.png');
    });

    testWidgets('04_inventory_screen_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('inventory_screen_desktop');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            stockPageProvider.overrideWith((ref, arg) async => {
              'items': [
                {
                  'id': 1,
                  'currentQuantity': 5,
                  'product': {'name': 'Nước ngọt Coca-Cola 330ml', 'minStock': 24},
                },
              ],
              'total': 1,
            }),
            lowStockProvider.overrideWith((ref) async => [
              {
                'id': 1,
                'name': 'Nước ngọt Coca-Cola 330ml',
                'currentStock': 5,
                'minStock': 24,
              },
            ]),
            expiringProductsProvider.overrideWith((ref) async => []),
            slowMovingProvider.overrideWith((ref) async => []),
            inventoryCategoriesSummaryProvider.overrideWith((ref) async => []),
            inventoryAbcProvider.overrideWith((ref, arg) async => {
              'A': {'count': 10, 'percent': 70.0},
              'B': {'count': 20, 'percent': 20.0},
              'C': {'count': 30, 'percent': 10.0},
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(key: key, child: InventoryScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Quản lý kho'), findsOneWidget);
      await _capture(tester, key, '04_inventory_screen_desktop.png');
    });
  });
}
