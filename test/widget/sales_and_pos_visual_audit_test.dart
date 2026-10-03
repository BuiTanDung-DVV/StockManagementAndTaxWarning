import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/customers/providers/customer_provider.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';
import 'package:flutter_app/features/products/providers/tag_provider.dart';
import 'package:flutter_app/features/sales/presentation/order_detail_screen.dart';
import 'package:flutter_app/features/sales/presentation/pos_screen.dart';
import 'package:flutter_app/features/sales/presentation/qr_payment_screen.dart';
import 'package:flutter_app/features/sales/presentation/sales_list_screen.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir = 'BA_DOCUMENTS/TEST_RUNS/run_20260930_sales/screenshots';

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

  final dummyProductList = {
    'items': [
      {
        'id': 101,
        'name': 'Gạo ST25 Ông Cua Túi 5kg',
        'sku': 'GAO-ST25-5K',
        'sellingPrice': 185000,
        'costPrice': 140000,
        'currentStock': 45,
        'minStock': 10,
        'unit': 'Túi',
        'taxRate': 5.0,
        'tags': <dynamic>['Bán chạy'],
      },
      {
        'id': 102,
        'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'sku': 'SUA-VNM-1L',
        'sellingPrice': 38000,
        'costPrice': 30000,
        'currentStock': 6,
        'minStock': 20,
        'unit': 'Hộp',
        'taxRate': 8.0,
        'tags': <dynamic>['Sắp hết'],
      },
      {
        'id': 103,
        'name': 'Dầu ăn Simply Canola 1L',
        'sku': 'DAU-SIM-1L',
        'sellingPrice': 65000,
        'costPrice': 52000,
        'currentStock': 25,
        'minStock': 15,
        'unit': 'Chai',
        'taxRate': 8.0,
        'tags': <dynamic>[],
      },
      {
        'id': 104,
        'name': 'Trứng gà Ta Ba Vì Hộp 10 quả',
        'sku': 'TRUNG-BV-10',
        'sellingPrice': 35000,
        'costPrice': 28000,
        'currentStock': 50,
        'minStock': 10,
        'unit': 'Hộp',
        'taxRate': 0.0,
        'tags': <dynamic>['Hàng tươi'],
      },
    ],
    'total': 4,
    'page': 1,
    'totalPages': 1,
  };

  final dummySalesList = {
    'items': [
      {
        'id': 1001,
        'orderCode': 'DH-202609-001',
        'shopId': 1,
        'createdAt': '2026-09-29T10:15:00.000Z',
        'customer': {'id': 1, 'name': 'Nguyễn Văn An', 'phone': '0901234567'},
        'customerName': 'Nguyễn Văn An',
        'status': 'COMPLETED',
        'paymentStatus': 'PAID',
        'paymentMethod': 'BANK_TRANSFER',
        'totalAmount': 420000.0,
        'paidAmount': 420000.0,
        'remainingAmount': 0.0,
        'itemCount': 3,
        'items': [
          {
            'productId': 101,
            'productName': 'Gạo ST25 Ông Cua Túi 5kg',
            'quantity': 2,
            'unitPrice': 185000.0,
            'subtotal': 370000.0,
          },
          {
            'productId': 102,
            'productName': 'Sữa tươi Tiệt trùng Vinamilk 1L',
            'quantity': 1,
            'unitPrice': 38000.0,
            'subtotal': 38000.0,
          },
        ],
      },
      {
        'id': 1002,
        'orderCode': 'DH-202609-002',
        'shopId': 1,
        'createdAt': '2026-09-29T11:30:00.000Z',
        'customer': {'id': 2, 'name': 'Trần Thị Mai', 'phone': '0987654321'},
        'customerName': 'Trần Thị Mai',
        'status': 'COMPLETED',
        'paymentStatus': 'PAID',
        'paymentMethod': 'CASH',
        'totalAmount': 130000.0,
        'paidAmount': 130000.0,
        'remainingAmount': 0.0,
        'itemCount': 2,
        'items': [
          {
            'productId': 103,
            'productName': 'Dầu ăn Simply Canola 1L',
            'quantity': 2,
            'unitPrice': 65000.0,
            'subtotal': 130000.0,
          },
        ],
      },
      {
        'id': 1003,
        'orderCode': 'DH-202609-003',
        'shopId': 1,
        'createdAt': '2026-09-29T14:45:00.000Z',
        'customer': null,
        'customerName': 'Khách mua lẻ',
        'status': 'PENDING',
        'paymentStatus': 'PARTIAL',
        'paymentMethod': 'DEBT',
        'totalAmount': 370000.0,
        'paidAmount': 200000.0,
        'remainingAmount': 170000.0,
        'itemCount': 2,
        'items': [
          {
            'productId': 101,
            'productName': 'Gạo ST25 Ông Cua Túi 5kg',
            'quantity': 2,
            'unitPrice': 185000.0,
            'subtotal': 370000.0,
          },
        ],
      },
    ],
    'total': 3,
    'page': 1,
    'totalPages': 1,
  };

  final dummySalesSummary = {
    'orderCount': 28,
    'netSalesRevenue': 45200000.0,
    'grossProfit': 12800000.0,
    'returnNetSalesRevenue': 0.0,
    'returnRatePct': 0.0,
    'totalCogs': 32400000.0,
  };

  final dummyPaymentSummary = [
    {'paymentMethod': 'BANK_TRANSFER', 'total': 25200000.0, 'count': 16},
    {'paymentMethod': 'CASH', 'total': 18000000.0, 'count': 11},
    {'paymentMethod': 'DEBT', 'total': 2000000.0, 'count': 1},
  ];

  final dummyOrderDetail = {
    'id': 1001,
    'orderCode': 'DH-202609-001',
    'shopId': 1,
    'createdAt': '2026-09-29T10:15:00.000Z',
    'customer': {
      'id': 1,
      'name': 'Nguyễn Văn An',
      'phone': '0901234567',
      'address': 'Số 123 Phố Huế, Q. Hai Bà Trưng, Hà Nội',
    },
    'customerName': 'Nguyễn Văn An',
    'status': 'COMPLETED',
    'paymentStatus': 'PAID',
    'paymentMethod': 'BANK_TRANSFER',
    'totalAmount': 420000.0,
    'paidAmount': 420000.0,
    'discountAmount': 10000.0,
    'taxAmount': 22000.0,
    'subtotal': 408000.0,
    'shippingFee': 0.0,
    'notes': 'Khách thanh toán chuyển khoản VietQR',
    'items': [
      {
        'id': 1,
        'productId': 101,
        'product': {
          'name': 'Gạo ST25 Ông Cua Túi 5kg',
          'sku': 'GAO-ST25-5K',
          'unit': 'Túi',
        },
        'productName': 'Gạo ST25 Ông Cua Túi 5kg',
        'quantity': 2,
        'price': 185000.0,
        'taxRate': 5.0,
        'subtotal': 370000.0,
      },
      {
        'id': 2,
        'productId': 102,
        'product': {
          'name': 'Sữa tươi Tiệt trùng Vinamilk 1L',
          'sku': 'SUA-VNM-1L',
          'unit': 'Hộp',
        },
        'productName': 'Sữa tươi Tiệt trùng Vinamilk 1L',
        'quantity': 1,
        'price': 38000.0,
        'taxRate': 8.0,
        'subtotal': 38000.0,
      },
    ],
    'payments': [
      {
        'id': 1,
        'amount': 420000.0,
        'method': 'BANK_TRANSFER',
        'createdAt': '2026-09-29T10:18:00.000Z',
        'note': 'Chuyển khoản VietQR thành công',
      },
    ],
  };

  final dummyShopProfile = {
    'shopName': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
    'address': 'Số 18 Đại Cồ Việt, Hai Bà Trưng, Hà Nội',
    'phone': '024 3868 9999',
    'taxCode': '0109988776',
  };

  group('Sales & POS Visual Audit', () {
    testWidgets('Capture POS Screen Desktop (1440x900)', (tester) async {
      const screenKey = ValueKey('pos_screen_desktop_key');
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            productListProvider.overrideWith(
              (ref, arg) => Future.value(dummyProductList),
            ),
            availableTagsProvider.overrideWith(
              (ref) => Future.value([
                TagModel(id: 1, name: 'Bán chạy', color: '#10B981'),
                TagModel(id: 2, name: 'Sắp hết', color: '#F59E0B'),
              ]),
            ),
            customerOptionsProvider.overrideWith(
              (ref) => Future.value({'items': []}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: RepaintBoundary(
              key: screenKey,
              child: const ColoredBox(
                color: Color(0xFFF5F8F7),
                child: PosScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bấm chọn sản phẩm để thêm vào giỏ hàng
      final productFinder = find.text('Gạo ST25 Ông Cua Túi 5kg');
      expect(productFinder, findsOneWidget);
      await tester.tap(productFinder);
      await tester.pumpAndSettle();

      await _capture(tester, screenKey, '01_pos_screen_desktop.png');

      expect(find.text('Ghi nhận giao dịch bán hàng'), findsOneWidget);
    });

    testWidgets('Capture POS Screen Mobile (390x844)', (tester) async {
      const screenKey = ValueKey('pos_screen_mobile_key');
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            productListProvider.overrideWith(
              (ref, arg) => Future.value(dummyProductList),
            ),
            availableTagsProvider.overrideWith(
              (ref) => Future.value([
                TagModel(id: 1, name: 'Bán chạy', color: '#10B981'),
                TagModel(id: 2, name: 'Sắp hết', color: '#F59E0B'),
              ]),
            ),
            customerOptionsProvider.overrideWith(
              (ref) => Future.value({'items': []}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: RepaintBoundary(
              key: screenKey,
              child: const ColoredBox(
                color: Color(0xFFF5F8F7),
                child: PosScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '02_pos_screen_mobile.png');

      expect(find.text('Ghi nhận giao dịch bán hàng'), findsOneWidget);
    });

    testWidgets('Capture Sales List Screen Desktop (1440x900)', (tester) async {
      const screenKey = ValueKey('sales_list_desktop_key');
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            salesListProvider.overrideWith(
              (ref, arg) => Future.value(dummySalesList),
            ),
            salesSummaryProvider.overrideWith(
              (ref, arg) => Future.value(dummySalesSummary),
            ),
            paymentSummaryProvider.overrideWith(
              (ref, arg) => Future.value(dummyPaymentSummary),
            ),
            topReturnedProductsProvider.overrideWith(
              (ref, arg) => Future.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: RepaintBoundary(
              key: screenKey,
              child: const ColoredBox(
                color: Color(0xFFF5F8F7),
                child: SalesListScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '03_sales_list_desktop.png');

      expect(find.text('Lịch sử đơn hàng'), findsWidgets);
    });

    testWidgets('Capture Sales List Screen Mobile (390x844)', (tester) async {
      const screenKey = ValueKey('sales_list_mobile_key');
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            salesListProvider.overrideWith(
              (ref, arg) => Future.value(dummySalesList),
            ),
            salesSummaryProvider.overrideWith(
              (ref, arg) => Future.value(dummySalesSummary),
            ),
            paymentSummaryProvider.overrideWith(
              (ref, arg) => Future.value(dummyPaymentSummary),
            ),
            topReturnedProductsProvider.overrideWith(
              (ref, arg) => Future.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: RepaintBoundary(
              key: screenKey,
              child: const ColoredBox(
                color: Color(0xFFF5F8F7),
                child: SalesListScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '04_sales_list_mobile.png');

      expect(find.text('Lịch sử đơn hàng'), findsWidgets);
    });

    testWidgets('Capture Order Detail Screen Desktop (1440x900)', (
      tester,
    ) async {
      const screenKey = ValueKey('order_detail_desktop_key');
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            salesDetailProvider(
              1001,
            ).overrideWith((ref) => Future.value(dummyOrderDetail)),
            shopProfileProvider.overrideWith(
              (ref) => Future.value(dummyShopProfile),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: RepaintBoundary(
              key: screenKey,
              child: const ColoredBox(
                color: Color(0xFFF5F8F7),
                child: OrderDetailScreen(id: 1001),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '05_order_detail_desktop.png');

      expect(find.text('Chi Tiết Đơn Hàng'), findsOneWidget);
      expect(find.text('DH-202609-001'), findsOneWidget);
    });

    testWidgets('Capture QR Payment Screen Mobile (390x844)', (tester) async {
      const screenKey = ValueKey('qr_payment_mobile_key');
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: RepaintBoundary(
              key: screenKey,
              child: const ColoredBox(
                color: Color(0xFFF5F8F7),
                child: QrPaymentScreen(
                  orderId: 1001,
                  orderCode: 'DH-202609-001',
                  totalAmount: 420000.0,
                  bankId: '970436',
                  accountNo: '0123456789',
                  accountName: 'CỬA HÀNG THỰC PHẨM THÔNG MINH',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, screenKey, '06_qr_payment_mobile.png');

      expect(find.text('Thanh toán chuyển khoản'), findsWidgets);
    });
  });
}
