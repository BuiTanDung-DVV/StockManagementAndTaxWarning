import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_animations.dart';
import 'package:flutter_app/features/finance/presentation/purchase_no_invoice_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/presentation/purchase_order_detail_screen.dart';
import 'package:flutter_app/features/inventory/presentation/purchase_order_screen.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_history_screen.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_screen.dart';
import 'package:flutter_app/features/inventory/presentation/xnt_report_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _state;
  _FakeShopNotifier(this._state);

  @override
  ShopState build() => _state;
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 19: Inventory Subsystem Audit Tests', () {
    testWidgets(
      'PurchaseOrderDetailScreen displays AppEmpty when data is empty',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const PurchaseOrderDetailScreen(purchaseOrder: {}),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text('Không tìm thấy thông tin đơn nhập hàng'),
          findsOneWidget,
        );
        expect(find.byType(AppEmpty), findsOneWidget);
      },
    );

    testWidgets(
      'PurchaseOrderDetailScreen renders RefreshIndicator, items and clean quantity format',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final poData = {
          'id': 101,
          'orderCode': 'PO-2026-001',
          'orderDate': '2026-09-20T10:00:00.000Z',
          'supplierName': 'Công ty CP Thép Việt Nhật',
          'invoiceNumber': 'HD-00123',
          'status': 'PENDING',
          'totalAmount': 5000000,
          'items': [
            {
              'productId': 1,
              'productName': 'Thép cuộn phi 10',
              'quantity': 5,
              'unitPrice': 1000000,
              'subtotal': 5000000,
            },
          ],
        };

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: PurchaseOrderDetailScreen(purchaseOrder: poData),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Kiểm tra thông tin PO
        expect(find.text('PO-2026-001'), findsOneWidget);
        expect(find.text('Công ty CP Thép Việt Nhật'), findsOneWidget);
        expect(find.text('HD-00123'), findsOneWidget);
        expect(find.text('Thép cuộn phi 10'), findsOneWidget);

        // Kiểm tra định dạng số lượng không bị dính .0
        expect(find.textContaining('SL: 5 x'), findsOneWidget);

        // Kiểm tra cử chỉ RefreshIndicator
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'PurchaseOrderDetailScreen shows AppEmpty when items list is empty',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final poData = {
          'id': 102,
          'orderCode': 'PO-2026-EMPTY',
          'status': 'COMPLETED',
          'totalAmount': 0,
          'items': [],
        };

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: PurchaseOrderDetailScreen(purchaseOrder: poData),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Đơn nhập không có sản phẩm nào'), findsOneWidget);
        expect(find.byType(AppEmpty), findsOneWidget);
      },
    );

    testWidgets(
      'PurchaseOrderScreen displays AppInlineError when provider fails',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            purchaseOrdersProvider.overrideWith(
              (ref, page) => Future<Map<String, dynamic>>.error(
                Exception('Không thể kết nối máy chủ'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const PurchaseOrderScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(AppInlineError), findsOneWidget);
        expect(
          find.textContaining('Không tải được danh sách đơn hàng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'StockTakeScreen displays AppInlineError when error occurs and renders items with parseQuantity',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            stockProvider(null).overrideWith(
              (ref) async => [
                {
                  'productId': 1,
                  'product': {
                    'name': 'Xi măng Hà Tiên',
                    'sku': 'XM-01',
                    'unit': 'Bao',
                    'minStock': 20,
                  },
                  'warehouse': {'name': 'Kho Chính'},
                  'currentQuantity': 10,
                },
              ],
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const StockTakeScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Xi măng Hà Tiên'), findsOneWidget);
        expect(find.text('10 Bao'), findsOneWidget);
        expect(find.text('Min: 20'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'StockTakeHistoryScreen displays refreshable empty state with AppEmpty',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            stockTakesProvider(1).overrideWith(
              (ref) async => {
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
              home: const StockTakeHistoryScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Chưa có phiếu kiểm kê nào'), findsOneWidget);
        expect(find.byType(AppEmpty), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets('XntReportScreen displays AppInlineError on failure', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          xntReportProvider.overrideWith(
            (ref, args) => Future<Map<String, dynamic>>.error(
              Exception('Lỗi kết nối báo cáo XNT'),
            ),
          ),
          slowMovingProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const XntReportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppInlineError), findsOneWidget);
      expect(
        find.textContaining('Không tải được dữ liệu báo cáo'),
        findsOneWidget,
      );
    });

    testWidgets(
      'PurchaseNoInvoiceScreen displays refreshable AppEmpty when empty and AppInlineError on failure',
      (tester) async {
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
            purchasesNoInvoiceProvider.overrideWith(
              (ref, args) async => {
                'items': [],
                'totalPages': 1,
                'filteredAmountTotal': 0,
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
              home: const PurchaseNoInvoiceScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Chưa có bảng kê nào'), findsWidgets);
        expect(find.byType(AppEmpty), findsWidgets);
        expect(find.byType(RefreshIndicator), findsWidgets);
      },
    );
  });
}
