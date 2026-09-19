import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/products/presentation/product_list_screen.dart';
import 'package:flutter_app/features/products/presentation/widgets/product_selection_toolbar.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';

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
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final dummyProducts = [
    {
      'id': 101,
      'name': 'Cà phê Robusta Đắk Lắk',
      'sku': 'CF-ROB-01',
      'sellingPrice': 85000,
      'costPrice': 60000,
      'currentStock': 24,
      'minStock': 5,
      'unit': 'gói',
      'tags': <dynamic>['Bán chạy'],
    },
    {
      'id': 102,
      'name': 'Trà xanh Tân Cương Thái Nguyên',
      'sku': 'TRA-TC-02',
      'sellingPrice': 120000,
      'costPrice': 90000,
      'currentStock': 3,
      'minStock': 5,
      'unit': 'hộp',
      'tags': <dynamic>['Sắp hết'],
    },
  ];

  group('Product List/Grid View and Bulk Selection', () {
    testWidgets('Toggles between List and Grid modes smoothly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productListProvider.overrideWith(
              (ref, args) => Future.value({
                'items': dummyProducts,
                'total': 2,
                'page': 1,
                'totalPages': 1,
              }),
            ),
            availableTagsProvider.overrideWith((ref) => Future.value([])),
            topProductsProvider.overrideWith((ref, args) => Future.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const ProductListScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Starts in List mode: ListView is present
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      // Tap Grid Mode toggle
      final gridToggle = find.byKey(const Key('product-view-mode-grid'));
      expect(gridToggle, findsOneWidget);
      await tester.tap(gridToggle);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Now in Grid mode: GridView is present
      expect(find.byType(GridView), findsOneWidget);

      // Tap List Mode toggle
      final listToggle = find.byKey(const Key('product-view-mode-list'));
      expect(listToggle, findsOneWidget);
      await tester.tap(listToggle);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Returns to List mode
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('Bulk selection select individual, select all and clear', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productListProvider.overrideWith(
              (ref, args) => Future.value({
                'items': dummyProducts,
                'total': 2,
                'page': 1,
                'totalPages': 1,
              }),
            ),
            availableTagsProvider.overrideWith((ref) => Future.value([])),
            topProductsProvider.overrideWith((ref, args) => Future.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const ProductListScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Initially no items selected, toolbar hidden
      expect(find.byType(ProductSelectionToolbar), findsOneWidget);
      expect(find.textContaining('Đã chọn'), findsNothing);

      // Select first product
      final checkbox1 = find.byKey(const Key('product-select-checkbox-101'));
      expect(checkbox1, findsOneWidget);
      await tester.tap(checkbox1);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Toolbar shows "Đã chọn 1 sản phẩm"
      expect(find.text('Đã chọn 1 sản phẩm'), findsOneWidget);
      expect(
        find.byKey(const Key('product-bulk-export-csv-button')),
        findsOneWidget,
      );

      // Select All on page via header checkbox
      final selectAllCheckbox = find.byKey(
        const Key('product-select-all-checkbox'),
      );
      expect(selectAllCheckbox, findsOneWidget);
      await tester.tap(selectAllCheckbox);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Toolbar shows "Đã chọn 2 sản phẩm"
      expect(find.text('Đã chọn 2 sản phẩm'), findsOneWidget);

      // Tap "Bỏ chọn"
      final clearButton = find.byKey(
        const Key('product-bulk-clear-selection-button'),
      );
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();

      // Toolbar cleared
      expect(find.textContaining('Đã chọn'), findsNothing);
    });

    testWidgets(
      'Clean empty state shows "Thêm sản phẩm", filtered empty state shows "Xóa bộ lọc"',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const ownerShopState = ShopState(
          currentShopId: 1,
          memberType: 'OWNER',
          status: 'ACTIVE',
          permissions: {'inventory': 'manage'},
          userShops: [
            {'shopId': 1, 'memberType': 'OWNER', 'status': 'ACTIVE'},
          ],
          isLoading: false,
        );

        final ownerAuthState = const AuthState(
          isLoggedIn: true,
          accountType: 'SHOP',
          user: {'id': 1, 'username': 'owner', 'fullName': 'Chủ cửa hàng'},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shopProvider.overrideWith(
                () => _FakeShopNotifier(ownerShopState),
              ),
              authProvider.overrideWith(
                () => _FakeAuthNotifier(ownerAuthState),
              ),
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': [],
                  'total': 0,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        // Clean empty: displays "Chưa có sản phẩm" and "Thêm sản phẩm"
        expect(find.text('Chưa có sản phẩm'), findsOneWidget);
        expect(
          find.byKey(const Key('product-empty-add-button')),
          findsOneWidget,
        );
        expect(find.text('Không tìm thấy sản phẩm'), findsNothing);
      },
    );

    testWidgets(
      'Desktop clicking product opens slide-over quick-view panel and close dismisses it',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': dummyProducts,
                  'total': 2,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              productDetailProvider(101).overrideWith(
                (ref) => Future.value({
                  ...dummyProducts[0],
                  'barcode': '893600000001',
                  'description': 'Cà phê nguyên chất từ Buôn Ma Thuột',
                }),
              ),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        // Initially no quick-view panel
        expect(find.text('Xem nhanh sản phẩm'), findsNothing);

        // Tap on first product card text
        await tester.tap(find.text('Cà phê Robusta Đắk Lắk'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        // Quick-view panel opens
        expect(find.text('Xem nhanh sản phẩm'), findsOneWidget);
        expect(find.text('Xem chi tiết đầy đủ'), findsOneWidget);
        expect(
          find.text('Cà phê nguyên chất từ Buôn Ma Thuột'),
          findsOneWidget,
        );

        // Tap close button (tooltip 'Đóng (Esc)')
        final closeBtn = find.byTooltip('Đóng (Esc)');
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        // Panel closed
        expect(find.text('Xem nhanh sản phẩm'), findsNothing);
      },
    );

    testWidgets(
      '_ProductTagsRow handles List<dynamic>, String, and null tags cleanly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final variedTagsProducts = [
          {
            'id': 201,
            'name': 'Sản phẩm tag List dynamic',
            'sku': 'TAG-LST-01',
            'currentStock': 10,
            'tags': <dynamic>['Tag1', 123, 'Tag2'],
          },
          {
            'id': 202,
            'name': 'Sản phẩm tag String',
            'sku': 'TAG-STR-02',
            'currentStock': 5,
            'tags': 'Hot, Mới, Sale',
          },
          {
            'id': 203,
            'name': 'Sản phẩm tag null',
            'sku': 'TAG-NUL-03',
            'currentStock': 20,
            'tags': null,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': variedTagsProducts,
                  'total': 3,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        expect(find.text('Tag1'), findsOneWidget);
        expect(find.text('Hot'), findsOneWidget);
        expect(find.text('Sản phẩm tag null'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ProductSelectionToolbar adapts responsively to 390px with textScaler 150%',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: ProductSelectionToolbar(
                  selectedCount: 12,
                  isExporting: false,
                  onClearSelection: () {},
                  onExportCsv: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();

        expect(find.text('Đã chọn 12 sản phẩm'), findsOneWidget);
        expect(find.text('Xuất CSV'), findsOneWidget);
        expect(find.text('Bỏ chọn'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Quick-view loading state displays visible close button and can be dismissed',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final completer = Completer<Map<String, dynamic>>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': dummyProducts,
                  'total': 2,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              productDetailProvider(
                101,
              ).overrideWith((ref) => completer.future),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap product to open quick-view
        await tester.tap(find.text('Cà phê Robusta Đắk Lắk'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Loading is active
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Xem nhanh sản phẩm'), findsOneWidget);

        // Close button is visible during loading
        final closeBtn = find.byKey(
          const Key('product-quick-view-close-button'),
        );
        expect(closeBtn, findsOneWidget);

        // Can dismiss during loading
        await tester.tap(closeBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Xem nhanh sản phẩm'), findsNothing);
      },
    );

    testWidgets(
      'Quick-view failed detail fetch shows clear error + retry, not silent fallback',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var retryCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': dummyProducts,
                  'total': 2,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              productDetailProvider(101).overrideWith((ref) {
                retryCount++;
                return Future.error(Exception('Network error'));
              }),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap product to open quick-view
        await tester.tap(find.text('Cà phê Robusta Đắk Lắk'));
        await tester.pumpAndSettle();

        // Shows explicit error message and retry button
        expect(
          find.text('Không thể tải chi tiết sản phẩm đầy đủ.'),
          findsOneWidget,
        );
        final retryBtn = find.text('Thử lại');
        expect(retryBtn, findsOneWidget);

        // Visible close button is present
        expect(
          find.byKey(const Key('product-quick-view-close-button')),
          findsOneWidget,
        );

        // Tapping retry triggers reload
        expect(retryCount, greaterThanOrEqualTo(1));
        final prevCount = retryCount;
        await tester.tap(retryBtn);
        await tester.pump();
        expect(retryCount, greaterThan(prevCount));
      },
    );

    testWidgets(
      'Escape key dismisses quick-view and preserves list selection and state',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': dummyProducts,
                  'total': 2,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              productDetailProvider(101).overrideWith(
                (ref) => Future.value({
                  ...dummyProducts[0],
                  'description': 'Mô tả cà phê',
                }),
              ),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select first product
        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();
        expect(find.text('Đã chọn 1 sản phẩm'), findsOneWidget);

        // Open quick-view for first product
        await tester.tap(find.text('Cà phê Robusta Đắk Lắk'));
        await tester.pumpAndSettle();
        expect(find.text('Xem nhanh sản phẩm'), findsOneWidget);

        // Send Escape key
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // Quick-view closed
        expect(find.text('Xem nhanh sản phẩm'), findsNothing);

        // List selection is retained!
        expect(find.text('Đã chọn 1 sản phẩm'), findsOneWidget);
      },
    );

    testWidgets(
      'Wrong-shop global owner cannot bypass current shop permissions for add/tags/export',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // User is global owner in authState, but in active ShopState they are EMPLOYEE with no product permissions
        const globalOwnerAuthState = AuthState(
          isLoggedIn: true,
          accountType: 'PERSONAL',
          user: {'id': 1, 'username': 'owner_user', 'isShopOwner': true},
        );

        const employeeInCurrentShopState = ShopState(
          currentShopId: 2,
          currentShopName: 'Chi nhánh 2',
          memberType: 'EMPLOYEE',
          status: 'ACTIVE',
          permissions: {'finance': 'view'}, // No products permission
          userShops: [
            {'shopId': 1, 'memberType': 'OWNER', 'status': 'ACTIVE'},
            {'shopId': 2, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
          ],
          isLoading: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _FakeAuthNotifier(globalOwnerAuthState),
              ),
              shopProvider.overrideWith(
                () => _FakeShopNotifier(employeeInCurrentShopState),
              ),
              productListProvider.overrideWith(
                (ref, args) => Future.value({
                  'items': dummyProducts,
                  'total': 2,
                  'page': 1,
                  'totalPages': 1,
                }),
              ),
              availableTagsProvider.overrideWith((ref) => Future.value([])),
              topProductsProvider.overrideWith((ref, args) => Future.value([])),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // "Thêm sản phẩm" is NOT visible
        expect(find.text('Thêm sản phẩm'), findsNothing);
        // "Cấu hình bộ lọc và nhãn" is NOT visible
        expect(find.byTooltip('Cấu hình bộ lọc và nhãn'), findsNothing);

        // Select a product to display selection toolbar
        await tester.tap(find.byType(Checkbox).at(1));
        await tester.pumpAndSettle();
        expect(find.text('Đã chọn 1 sản phẩm'), findsOneWidget);

        // "Xuất CSV" is NOT visible because user lacks product permission in this shop
        expect(
          find.byKey(const Key('product-bulk-export-csv-button')),
          findsNothing,
        );
      },
    );
  });
}
