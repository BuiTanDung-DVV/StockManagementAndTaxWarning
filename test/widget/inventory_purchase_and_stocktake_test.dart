import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/inventory/presentation/purchase_order_detail_screen.dart';
import 'package:flutter_app/features/inventory/presentation/purchase_order_screen.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_history_screen.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 10 - Purchase Order Detail Tests', () {
    testWidgets(
      'Pending PO shows Approve and Cancel buttons with confirmation modal',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final pendingPo = {
          'id': 101,
          'orderCode': 'PO-TEST-101',
          'status': 'PENDING',
          'supplier': {'id': 1, 'name': 'Nhà Cung Cấp Alpha'},
          'totalAmount': 5000000,
          'orderDate': '2026-09-20T08:00:00Z',
          'invoiceNumber': 'HD-001',
          'items': [
            {
              'product': {'id': 1, 'name': 'Cà phê Robusta', 'sku': 'CF-01'},
              'quantity': 50,
              'unitPrice': 100000,
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: PurchaseOrderDetailScreen(purchaseOrder: pendingPo),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check header and info
        expect(find.text('Chi Tiết Đơn Nhập'), findsOneWidget);
        expect(find.text('PO-TEST-101'), findsOneWidget);
        expect(find.text('Chờ xử lý'), findsOneWidget);

        // Check Action Buttons
        final approveBtn = find.text('Duyệt Nhập Kho');
        final cancelBtn = find.text('Hủy đơn');
        expect(approveBtn, findsOneWidget);
        expect(cancelBtn, findsOneWidget);

        // Tap Cancel button -> verify AppConfirmModal appears
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(find.text('Xác nhận hủy đơn'), findsOneWidget);
        expect(
          find.text(
            'Bạn có chắc chắn muốn hủy đơn nhập hàng này? Đơn sẽ chuyển sang trạng thái Đã hủy.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Completed PO hides action buttons and displays Completed status',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final completedPo = {
          'id': 102,
          'orderCode': 'PO-TEST-102',
          'status': 'COMPLETED',
          'supplier': {'id': 2, 'name': 'Nhà Cung Cấp Beta'},
          'totalAmount': 12000000,
          'orderDate': '2026-09-18T08:00:00Z',
          'invoiceNumber': 'HD-002',
          'items': [],
        };

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: PurchaseOrderDetailScreen(purchaseOrder: completedPo),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Hoàn thành'), findsOneWidget);
        expect(find.text('Duyệt Nhập Kho'), findsNothing);
        expect(find.text('Hủy đơn'), findsNothing);
      },
    );
  });

  group('Wave 10 - Stock Take History Tests', () {
    testWidgets(
      'Stock take history displays items, modal sheet and cancel confirm',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockStockTakes = {
          'items': [
            {
              'id': 201,
              'code': 'ST-20260920-001',
              'status': 'DRAFT',
              'createdAt': '2026-09-20T09:00:00Z',
              'warehouse': {'name': 'Kho Tổng'},
              'items': [
                {
                  'product': {'name': 'Sữa tươi tiệt trùng', 'sku': 'MILK-01'},
                  'systemQuantity': 20,
                  'actualQuantity': 18,
                  'difference': -2,
                },
              ],
            },
          ],
          'total': 1,
          'page': 1,
          'totalPages': 1,
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              stockTakesProvider.overrideWith(
                (ref, page) async => mockStockTakes,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const StockTakeHistoryScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check header and RefreshIndicator
        expect(find.text('Lịch sử kiểm kê'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.text('ST-20260920-001'), findsOneWidget);

        // Tap popup menu on draft item
        final moreBtn = find.byType(PopupMenuButton<String>);
        expect(moreBtn, findsOneWidget);
        await tester.tap(moreBtn);
        await tester.pumpAndSettle();

        // Check Cancel action in popup menu
        final cancelAction = find.text('Hủy phiếu');
        expect(cancelAction, findsOneWidget);

        await tester.tap(cancelAction);
        await tester.pumpAndSettle();

        // Verify confirmation dialog
        expect(find.text('Hủy phiếu kiểm kê'), findsOneWidget);
        expect(
          find.text(
            'Bạn có chắc chắn muốn hủy phiếu kiểm kê này? Dữ liệu kiểm đếm sẽ không được cập nhật vào kho.',
          ),
          findsOneWidget,
        );

        // Dismiss dialog
        await tester.tap(find.text('Quay lại'));
        await tester.pumpAndSettle();

        // Tap on the stock take item card to open details bottom sheet
        await tester.tap(find.text('ST-20260920-001'));
        await tester.pumpAndSettle();

        // BottomSheet should show items
        expect(find.text('Chi tiết ST-20260920-001'), findsOneWidget);
        expect(find.text('Sữa tươi tiệt trùng'), findsOneWidget);
        expect(find.text('-2 (Thiếu)'), findsOneWidget);

        // Drain any pending toast timers
        await tester.pump(const Duration(seconds: 4));
      },
    );
  });

  group('Wave 10 - Inventory List Screens RefreshIndicator Tests', () {
    testWidgets('PurchaseOrderScreen has RefreshIndicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockPoData = {
        'items': [
          {
            'id': 301,
            'orderCode': 'PO-301',
            'status': 'PENDING',
            'supplier': {'name': 'NCC Test'},
            'totalAmount': 2000000,
            'orderDate': '2026-09-20',
          },
        ],
        'total': 1,
        'page': 1,
        'totalPages': 1,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseOrdersProvider.overrideWith(
              (ref, page) async => mockPoData,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const PurchaseOrderScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đơn Mua Nhập Hàng'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('PO-301'), findsOneWidget);
    });

    testWidgets('StockTakeScreen has RefreshIndicator', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockStockList = [
        {
          'id': 401,
          'product': {
            'name': 'Bánh mì sandwich',
            'sku': 'BM-01',
            'unit': 'ổ',
            'minStock': 10,
          },
          'currentQuantity': 25,
          'warehouse': {'name': 'Kho Lạnh'},
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockProvider.overrideWith(
              (ref, warehouseId) async => mockStockList,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const StockTakeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kiểm kê Kho'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Bánh mì sandwich'), findsOneWidget);
    });
  });
}
