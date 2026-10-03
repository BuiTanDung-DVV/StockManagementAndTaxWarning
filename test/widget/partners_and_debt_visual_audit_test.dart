import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/customers/presentation/customer_detail_screen.dart';
import 'package:flutter_app/features/customers/presentation/customer_list_screen.dart';
import 'package:flutter_app/features/customers/providers/customer_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/suppliers/presentation/supplier_detail_screen.dart';
import 'package:flutter_app/features/suppliers/presentation/supplier_list_screen.dart';
import 'package:flutter_app/features/suppliers/providers/supplier_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_partners/screenshots';

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
        'role': 'OWNER',
      },
    ],
  );

  final fakeCustomerList = <String, dynamic>{
    'items': [
      {
        'id': 1,
        'code': 'KH-ANPHU',
        'name': 'Công ty TNHH TM DV An Phú',
        'phone': '0903 123 456',
        'email': 'anphu.trade@gmail.com',
        'address': '128 Nguyễn Trãi, Quận 5, TP.HCM',
        'customerType': 'WHOLESALE',
        'taxCode': '0314567890',
        'totalDebt': 18500000,
        'creditLimit': 50000000,
      },
      {
        'id': 2,
        'code': 'KH-MAICHI',
        'name': 'Chị Hoàng Mai Chi (Đại lý Miền Nam)',
        'phone': '0918 765 432',
        'email': 'maichi.retail@yahoo.com',
        'address': '45 Phan Đăng Lưu, Phú Nhuận, TP.HCM',
        'customerType': 'RETAIL',
        'taxCode': null,
        'totalDebt': 2350000,
        'creditLimit': 10000000,
      },
      {
        'id': 3,
        'code': 'KH-QUOCBAO',
        'name': 'Anh Trần Quốc Bảo',
        'phone': '0989 333 888',
        'email': '',
        'address': 'Tân Bình, TP.HCM',
        'customerType': 'RETAIL',
        'taxCode': null,
        'totalDebt': 0,
        'creditLimit': 5000000,
      },
    ],
    'total': 3,
    'page': 1,
    'totalPages': 1,
  };

  final fakeCustomerDetail = <String, dynamic>{
    'id': 1,
    'code': 'KH-ANPHU',
    'name': 'Công ty TNHH TM DV An Phú',
    'phone': '0903 123 456',
    'email': 'anphu.trade@gmail.com',
    'address': '128 Nguyễn Trãi, Quận 5, TP.HCM',
    'customerType': 'WHOLESALE',
    'taxCode': '0314567890',
    'totalDebt': 18500000,
    'creditLimit': 50000000,
  };

  final fakeCustomerReceivables = <dynamic>[
    {
      'id': 101,
      'invoiceNumber': 'HD-202609-088',
      'amount': 18500000,
      'remainingAmount': 18500000,
      'dueDate': '2026-10-15',
      'status': 'OPEN',
    },
  ];

  final fakeCustomerEvidence = <dynamic>[
    {
      'id': 201,
      'title': 'Biên bản đối chiếu công nợ Tháng 09/2026',
      'imageUrl': '',
      'uploadedAt': '2026-09-28T08:30:00Z',
      'createdAt': '2026-09-28T08:30:00Z',
      'note': 'Đã ký xác nhận hai bên',
    },
  ];

  final fakeCustomerOrders = <String, dynamic>{
    'items': [
      {
        'id': 301,
        'orderNumber': 'DH-202609-088',
        'createdAt': '2026-09-25T14:20:00Z',
        'totalAmount': 28500000,
        'status': 'COMPLETED',
        'paymentStatus': 'PARTIAL',
      },
      {
        'id': 302,
        'orderNumber': 'DH-202609-012',
        'createdAt': '2026-09-10T09:15:00Z',
        'totalAmount': 15200000,
        'status': 'COMPLETED',
        'paymentStatus': 'PAID',
      },
    ],
    'total': 2,
    'page': 1,
    'totalPages': 1,
  };

  final fakeSupplierList = <String, dynamic>{
    'items': [
      {
        'id': 1,
        'name': 'Công ty Cổ phần Thực phẩm CP Việt Nam',
        'phone': '028 3822 5555',
        'email': 'contact@cp.com.vn',
        'address': 'KCN Biên Hòa 2, TP. Biên Hòa, Đồng Nai',
        'taxCode': '3600224523',
        'bankName': 'Vietcombank',
        'bankAccount': '0071001234567',
        'paymentTerms': '30 ngày',
        'balance': 45800000,
        'totalPurchase': 250000000,
      },
      {
        'id': 2,
        'name': 'Công ty TNHH Nông sản Sạch Đà Lạt',
        'phone': '0263 381 2345',
        'email': 'sales@dalatfarm.vn',
        'address': 'Phường 8, TP. Đà Lạt, Lâm Đồng',
        'taxCode': '5800456789',
        'bankName': 'BIDV',
        'bankAccount': '6411000098765',
        'paymentTerms': '15 ngày',
        'balance': 8200000,
        'totalPurchase': 62000000,
      },
      {
        'id': 3,
        'name': 'Nhà phân phối Hàng Tiêu dùng Á Châu',
        'phone': '0909 888 999',
        'email': 'achau.distributor@gmail.com',
        'address': 'Quận Bình Tân, TP.HCM',
        'taxCode': '0309876543',
        'bankName': 'Techcombank',
        'bankAccount': '1903344556677',
        'paymentTerms': 'Tiền mặt ngay',
        'balance': 0,
        'totalPurchase': 15000000,
      },
    ],
    'total': 3,
    'page': 1,
    'totalPages': 1,
  };

  final fakeSupplierDetail = <String, dynamic>{
    'id': 1,
    'name': 'Công ty Cổ phần Thực phẩm CP Việt Nam',
    'contactName': 'Nguyễn Văn Minh (Trưởng đại diện)',
    'phone': '028 3822 5555',
    'email': 'contact@cp.com.vn',
    'address': 'KCN Biên Hòa 2, TP. Biên Hòa, Đồng Nai',
    'taxCode': '3600224523',
    'bankName': 'Vietcombank',
    'bankAccount': '0071001234567',
    'paymentTerms': '30 ngày',
    'balance': 45800000,
    'totalPurchase': 250000000,
  };

  Widget buildHarvestShell({
    required Widget child,
    required Size size,
    required Key captureKey,
  }) {
    return ProviderScope(
      overrides: [
        shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
        customerListProvider((
          page: 1,
          search: null,
        )).overrideWith((ref) => Future.value(fakeCustomerList)),
        customerDetailProvider(
          1,
        ).overrideWith((ref) => Future.value(fakeCustomerDetail)),
        customerReceivablesProvider(
          1,
        ).overrideWith((ref) => Future.value(fakeCustomerReceivables)),
        customerEvidenceProvider(
          1,
        ).overrideWith((ref) => Future.value(fakeCustomerEvidence)),
        salesListProvider((
          page: 1,
          status: null,
          customerId: 1,
          search: null,
          from: null,
          to: null,
        )).overrideWith((ref) => Future.value(fakeCustomerOrders)),
        supplierListProvider((
          page: 1,
          search: null,
        )).overrideWith((ref) => Future.value(fakeSupplierList)),
        supplierDetailProvider(
          1,
        ).overrideWith((ref) => Future.value(fakeSupplierDetail)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(AppColors.primary),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: RepaintBoundary(
            key: captureKey,
            child: Container(
              width: size.width,
              height: size.height,
              color: const Color(0xFFF5F8F7),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('Partners & Debt Visual Audit', () {
    testWidgets('Capture Customer List Screen Desktop (1440x900)', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        buildHarvestShell(
          size: const Size(1440, 900),
          captureKey: key,
          child: const CustomerListScreen(),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '01_customer_list_desktop.png');
    });

    testWidgets('Capture Customer List Screen Mobile (390x844)', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        buildHarvestShell(
          size: const Size(390, 844),
          captureKey: key,
          child: const CustomerListScreen(),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '02_customer_list_mobile.png');
    });

    testWidgets('Capture Customer Detail Screen Desktop (1440x900)', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        buildHarvestShell(
          size: const Size(1440, 900),
          captureKey: key,
          child: const CustomerDetailScreen(id: 1),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '03_customer_detail_desktop.png');
    });

    testWidgets('Capture Customer Detail Screen Mobile (390x844)', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        buildHarvestShell(
          size: const Size(390, 844),
          captureKey: key,
          child: const CustomerDetailScreen(id: 1),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '04_customer_detail_mobile.png');
    });

    testWidgets('Capture Supplier List Screen Desktop (1440x900)', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        buildHarvestShell(
          size: const Size(1440, 900),
          captureKey: key,
          child: const SupplierListScreen(),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '05_supplier_list_desktop.png');
    });

    testWidgets('Capture Supplier Detail Screen Desktop (1440x900)', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      await tester.pumpWidget(
        buildHarvestShell(
          size: const Size(1440, 900),
          captureKey: key,
          child: const SupplierDetailScreen(id: 1),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '06_supplier_detail_desktop.png');
    });
  });
}
