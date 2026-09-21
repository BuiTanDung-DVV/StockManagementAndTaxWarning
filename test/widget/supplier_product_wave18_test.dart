import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_animations.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/products/presentation/product_detail_screen.dart';
import 'package:flutter_app/features/products/presentation/tag_management_screen.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';
import 'package:flutter_app/features/products/providers/tag_provider.dart';
import 'package:flutter_app/features/suppliers/presentation/supplier_detail_screen.dart';
import 'package:flutter_app/features/suppliers/providers/supplier_provider.dart';
import '../support/load_ui_fonts.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _state;
  _FakeAuthNotifier(this._state);

  @override
  AuthState build() => _state;
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 18: Supplier & Product Audit Tests', () {
    testWidgets(
      'SupplierDetailScreen displays RefreshIndicator and supplier data',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            supplierDetailProvider(1).overrideWith((ref) async {
              return {
                'id': 1,
                'name': 'Công ty Vật liệu Xây dựng Miền Bắc',
                'contactName': 'Trần Văn C',
                'phone': '0912345678',
                'email': 'mienbac@vlxd.vn',
                'address': 'Km 12 Quốc lộ 1A, Hà Nội',
                'taxCode': '0101234567',
                'bankName': 'Vietcombank',
                'bankAccount': '00110022334455',
                'paymentTerms': 30,
                'balance': 45000000,
                'totalPurchase': 250000000,
              };
            }),
            supplierListProvider.overrideWith(
              (ref, arg) async => {
                'items': [],
                'total': 0,
                'page': 1,
                'totalPages': 1,
              },
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const SupplierDetailScreen(id: 1),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Xác minh thông tin nhà cung cấp hiển thị
        expect(find.text('Công ty Vật liệu Xây dựng Miền Bắc'), findsOneWidget);
        expect(find.text('0101234567'), findsOneWidget);
        expect(find.text('Trần Văn C'), findsOneWidget);

        // Xác minh RefreshIndicator hiện diện
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'SupplierDetailScreen displays AppInlineError with retry when error occurs',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            supplierDetailProvider(99).overrideWith(
              (ref) => Future<Map<String, dynamic>>.error(
                Exception('Mất kết nối máy chủ'),
              ),
            ),
            supplierListProvider.overrideWith(
              (ref, arg) async => {
                'items': [],
                'total': 0,
                'page': 1,
                'totalPages': 1,
              },
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const SupplierDetailScreen(id: 99),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Xác minh AppInlineError hiển thị
        expect(find.byType(AppInlineError), findsOneWidget);
        expect(find.textContaining('Mất kết nối máy chủ'), findsOneWidget);
      },
    );

    testWidgets(
      'ProductDetailScreen renders with RefreshIndicator and product details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            productDetailProvider(5).overrideWith((ref) async {
              return {
                'id': 5,
                'name': 'Sơn chống thấm Kova 20kg',
                'sku': 'KOV-CT-20',
                'barcode': '893500123456',
                'unit': 'Thùng',
                'costPrice': 620000,
                'sellingPrice': 790000,
                'wholesalePrice': 750000,
                'currentStock': 24,
                'minStock': 10,
                'description': 'Sơn chống thấm ngoại thất cao cấp',
                'tags': ['Sơn', 'Chống thấm'],
              };
            }),
            inventoryMovementsProvider((productId: 5, page: 1)).overrideWith((
              ref,
            ) async {
              return {
                'items': [
                  {
                    'id': 1,
                    'movementType': 'IN',
                    'quantity': 15,
                    'notes': 'Nhập kho theo PO-2026-001',
                    'createdAt': '2026-09-20T08:30:00.000Z',
                  },
                ],
                'total': 1,
                'page': 1,
                'totalPages': 1,
              };
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductDetailScreen(id: 5),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Xác minh thông tin sản phẩm và lịch sử kho
        expect(find.text('Sơn chống thấm Kova 20kg'), findsOneWidget);
        expect(find.text('Nhập kho theo PO-2026-001'), findsOneWidget);

        // Xác minh RefreshIndicator hiện diện
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'ProductDetailScreen displays AppInlineError with retry when error occurs',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            productDetailProvider(88).overrideWith(
              (ref) => Future<Map<String, dynamic>>.error(
                Exception('Sản phẩm không tồn tại'),
              ),
            ),
            inventoryMovementsProvider((
              productId: 88,
              page: 1,
            )).overrideWith((ref) async => {'items': [], 'total': 0}),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ProductDetailScreen(id: 88),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Xác minh AppInlineError hiển thị
        expect(find.byType(AppInlineError), findsOneWidget);
        expect(find.textContaining('Sản phẩm không tồn tại'), findsOneWidget);
      },
    );

    testWidgets('TagManagementScreen displays RefreshIndicator and tag items', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(
                isLoggedIn: true,
                accountType: 'SHOP',
                user: {'id': 1, 'name': 'Chủ cửa hàng'},
              ),
            ),
          ),
          tagListProvider('product').overrideWith((ref) async {
            return [
              TagModel(
                id: 1,
                name: 'Vật liệu bán chạy',
                color: '#EF4444',
                type: 'product',
              ),
              TagModel(
                id: 2,
                name: 'Hàng dễ vỡ',
                color: '#F59E0B',
                type: 'product',
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const TagManagementScreen(type: 'product'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Xác minh nhãn hiển thị
      expect(find.text('Vật liệu bán chạy'), findsOneWidget);
      expect(find.text('Hàng dễ vỡ'), findsOneWidget);

      // Xác minh RefreshIndicator hiện diện
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets(
      'TagManagementScreen shows AppEmpty and RefreshIndicator when tag list is empty',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  isLoggedIn: true,
                  accountType: 'SHOP',
                  user: {'id': 1, 'name': 'Chủ cửa hàng'},
                ),
              ),
            ),
            tagListProvider('product').overrideWith((ref) async => []),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const TagManagementScreen(type: 'product'),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Xác minh AppEmpty hiển thị
        expect(find.byType(AppEmpty), findsOneWidget);
        expect(find.text('Chưa có nhãn nào'), findsOneWidget);

        // Xác minh RefreshIndicator hiện diện
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );
  });
}
