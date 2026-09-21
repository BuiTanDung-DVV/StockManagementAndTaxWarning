import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_animations.dart';
import 'package:flutter_app/features/customers/presentation/customer_detail_screen.dart';
import 'package:flutter_app/features/customers/providers/customer_provider.dart';
import 'package:flutter_app/features/sales/presentation/order_detail_screen.dart';
import 'package:flutter_app/features/sales/presentation/return_detail_screen.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
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

  group('Wave 17: Sales & Customer Audit Tests', () {
    testWidgets(
      'CustomerDetailScreen displays RefreshIndicator and customer data',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            customerDetailProvider(1).overrideWith((ref) async {
              return {
                'id': 1,
                'name': 'Nguyễn Văn A',
                'phone': '0901234567',
                'email': 'vana@example.com',
                'address': '123 Lê Duẩn, Hà Nội',
                'customerType': 'RETAIL',
                'totalDebt': 1500000,
                'creditLimit': 5000000,
              };
            }),
            customerReceivablesProvider(1).overrideWith((ref) async => []),
            customerEvidenceProvider(1).overrideWith((ref) async => []),
            salesListProvider.overrideWith((ref, arg) async {
              return {'items': [], 'total': 0, 'page': 1, 'totalPages': 1};
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const CustomerDetailScreen(id: 1),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Xác minh tên khách hàng và thông tin hiển thị
        expect(find.text('Nguyễn Văn A'), findsWidgets);
        expect(find.text('0901234567'), findsOneWidget);

        // Xác minh RefreshIndicator tồn tại
        expect(find.byType(RefreshIndicator), findsOneWidget);

        // Xác minh AppEmpty hiển thị khi danh sách đơn hàng rỗng
        expect(find.byType(AppEmpty), findsOneWidget);
        expect(find.text('Chưa có đơn hàng'), findsOneWidget);
      },
    );

    testWidgets(
      'CustomerDetailScreen displays AppInlineError with retry when error occurs',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer(
          overrides: [
            customerDetailProvider(99).overrideWith(
              (ref) => Future<Map<String, dynamic>>.error(
                Exception('Mạng không khả dụng'),
              ),
            ),
            customerReceivablesProvider(99).overrideWith((ref) async => []),
            customerEvidenceProvider(99).overrideWith((ref) async => []),
            salesListProvider.overrideWith(
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
              home: const CustomerDetailScreen(id: 99),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Xác minh AppInlineError hiển thị
        expect(find.byType(AppInlineError), findsOneWidget);
        expect(find.textContaining('Mạng không khả dụng'), findsOneWidget);
      },
    );

    testWidgets(
      'OrderDetailScreen renders with RefreshIndicator and order details',
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
            salesDetailProvider(10).overrideWith((ref) async {
              return {
                'id': 10,
                'orderCode': 'DH-2026-10',
                'createdAt': '2026-09-20T10:00:00.000Z',
                'customerName': 'Trần Thị B',
                'status': 'COMPLETED',
                'totalAmount': 450000,
                'paidAmount': 450000,
                'items': [
                  {
                    'productName': 'Bút ký cao cấp Parker',
                    'quantity': 2,
                    'unitPrice': 225000,
                    'subtotal': 450000,
                  },
                ],
                'payments': [
                  {
                    'amount': 450000,
                    'method': 'TRANSFER',
                    'paidAt': '2026-09-20T10:05:00.000Z',
                  },
                ],
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
              home: const OrderDetailScreen(id: 10),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Xác minh chi tiết đơn hàng
        expect(find.text('DH-2026-10'), findsOneWidget);
        expect(find.text('Bút ký cao cấp Parker'), findsOneWidget);
        expect(find.text('Đã trả đủ'), findsOneWidget);

        // Xác minh RefreshIndicator hiện diện
        expect(find.byType(RefreshIndicator), findsOneWidget);
      },
    );

    testWidgets('ReturnDetailScreen shows AppEmpty when returnInfo is empty', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const ReturnDetailScreen(returnInfo: {}),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Xác minh AppEmpty hiển thị
      expect(find.byType(AppEmpty), findsOneWidget);
      expect(
        find.text('Không tìm thấy thông tin phiếu trả hàng'),
        findsOneWidget,
      );
      expect(find.text('Quay lại danh sách đơn hàng'), findsOneWidget);
    });

    testWidgets('ReturnDetailScreen displays valid return info correctly', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final returnData = {
        'id': 5,
        'returnCode': 'RET-2026-005',
        'reason': 'Hàng bị lỗi bao bì khi vận chuyển',
        'refundedAmount': 250000,
        'createdAt': '2026-09-20T11:00:00.000Z',
        'items': [
          {
            'productName': 'Bộ sạc nhanh 65W GaN',
            'quantity': 1,
            'unitPrice': 250000,
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: ReturnDetailScreen(returnInfo: returnData),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Xác minh thông tin phiếu trả hàng hiển thị đúng
      expect(find.text('RET-2026-005'), findsOneWidget);
      expect(find.text('Hàng bị lỗi bao bì khi vận chuyển'), findsOneWidget);
      expect(find.text('Bộ sạc nhanh 65W GaN'), findsOneWidget);
    });
  });
}
