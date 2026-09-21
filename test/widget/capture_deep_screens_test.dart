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
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import 'package:flutter_app/features/suppliers/presentation/supplier_list_screen.dart';
import 'package:flutter_app/features/suppliers/providers/supplier_provider.dart';
import 'package:flutter_app/features/finance/presentation/supplier_payables_aging_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_obligation_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_calculator_screen.dart';
import 'package:flutter_app/features/finance/presentation/tax_declaration_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/sales/presentation/customer_debt_screen.dart';
import 'package:flutter_app/features/sales/presentation/order_detail_screen.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/inventory/presentation/stock_take_screen.dart';
import 'package:flutter_app/features/inventory/presentation/purchase_order_screen.dart';
import 'package:flutter_app/features/inventory/presentation/xnt_report_screen.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/settings/presentation/staff_management_screen.dart';
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

class _DeepMockApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    if (path.startsWith('/shop-members/pending')) {
      return [];
    }
    if (path.startsWith('/shop-members')) {
      return [
        {
          'id': 1,
          'userId': 1,
          'username': 'quanly01',
          'fullName': 'Nguyễn Văn Quản Lý',
          'role': 'MANAGER',
          'roleName': 'Quản lý cửa hàng',
          'status': 'ACTIVE',
          'phone': '0901112233',
          'email': 'quanly@smartstock.vn',
          'avatarUrl': null,
        },
        {
          'id': 2,
          'userId': 2,
          'username': 'thungan01',
          'fullName': 'Trần Thị Thu Ngân',
          'role': 'CASHIER',
          'roleName': 'Thu ngân chính',
          'status': 'ACTIVE',
          'phone': '0904445566',
          'email': 'thungan@smartstock.vn',
          'avatarUrl': null,
        },
        {
          'id': 3,
          'userId': 3,
          'username': 'thukho01',
          'fullName': 'Lê Văn Thủ Kho',
          'role': 'WAREHOUSE',
          'roleName': 'Thủ kho tổng',
          'status': 'ACTIVE',
          'phone': '0907778899',
          'email': 'thukho@smartstock.vn',
          'avatarUrl': null,
        },
      ];
    }
    if (path.startsWith('/shop-roles')) {
      return [
        {'id': 1, 'name': 'Quản lý cửa hàng', 'code': 'MANAGER'},
        {'id': 2, 'name': 'Thu ngân', 'code': 'CASHIER'},
        {'id': 3, 'name': 'Thủ kho', 'code': 'WAREHOUSE'},
      ];
    }
    if (path.startsWith('/tax/config')) {
      return {
        'thresholds': {
          'tier1': 50000000.0,
          'tier2': 70000000.0,
          'tier3': 80000000.0,
          'tier4': 100000000.0,
        },
        'taxRates': {
          'wholesale_retail': {'vat': 0.01, 'pit': 0.005},
          'manufacturing_transport': {'vat': 0.03, 'pit': 0.015},
          'services': {'vat': 0.05, 'pit': 0.02},
          'other': {'vat': 0.02, 'pit': 0.01},
        },
        'shopConfig': {'businessSector': 'TRADE', 'applyVatReduction': false},
        'policy': {'sourceCode': 'TT40_2021_BTC'},
        'fiscalYear': 2026,
      };
    }
    if (path.startsWith('/tax-reference-data')) {
      return {
        'forms': [
          {
            'code': '01_CNKD',
            'name': 'Tờ khai 01/CNKD',
            'description':
                'Tờ khai thuế đối với hộ kinh doanh, cá nhân kinh doanh',
            'status': 'READY',
            'iconKey': 'article',
          },
          {
            'code': '01_2_BK_HDKD',
            'name': 'Phụ lục 01-2/BK-HĐKD',
            'description': 'Bảng kê hoạt động kinh doanh trong kỳ',
            'status': 'READY',
            'iconKey': 'list',
          },
        ],
        'supportLinks': [
          {
            'title': 'Cổng thông tin Thuế điện tử',
            'description': 'Tra cứu nghĩa vụ thuế cá nhân và hộ kinh doanh',
            'url': 'https://thuedientu.gdt.gov.vn',
            'iconKey': 'account_balance',
            'colorRole': 'primary',
          },
        ],
      };
    }
    if (path.startsWith('/customer-receivables') ||
        path.startsWith('/customers/receivables')) {
      return {
        'items': [
          {
            'id': 1,
            'orderId': 103,
            'orderCode': 'DH-2026-003',
            'customerId': 3,
            'customerName': 'Lê Hoàng Cường',
            'customerPhone': '0933112233',
            'totalAmount': 890000,
            'paidAmount': 0,
            'remaining': 890000,
            'status': 'OVERDUE',
            'daysOverdue': 5,
            'dueDate': '2026-09-14T00:00:00Z',
            'createdAt': '2026-09-10T14:00:00Z',
          },
          {
            'id': 2,
            'orderId': 104,
            'orderCode': 'DH-2026-004',
            'customerId': 4,
            'customerName': 'Công ty TNHH Song Mã',
            'customerPhone': '0903889900',
            'totalAmount': 15500000,
            'paidAmount': 5000000,
            'remaining': 10500000,
            'status': 'UNPAID',
            'daysOverdue': 0,
            'dueDate': '2026-09-25T00:00:00Z',
            'createdAt': '2026-09-18T09:30:00Z',
          },
        ],
        'summary': {
          'outstanding': 11390000,
          'overdue': 890000,
          'customerCount': 2,
          'receivableCount': 2,
        },
        'total': 2,
        'page': 1,
        'totalPages': 1,
      };
    }
    if (path.startsWith('/shop-profile')) {
      return {
        'id': 1,
        'name': 'Cửa hàng mẫu SmartStock',
        'phone': '0901234567',
        'address': '123 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
        'taxCode': '0312345678',
      };
    }
    return {};
  }
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
    final bytes = byteData!.buffer.asUint8List();
    file.writeAsBytesSync(bytes);

    final artifactFile = File(
      'C:/Users/tandu/.gemini/antigravity-ide/brain/a6e928e6-da84-4f33-b6f4-7ef3b12290c5/screenshots/$fileName',
    );
    artifactFile.parent.createSync(recursive: true);
    artifactFile.writeAsBytesSync(bytes);
  }

  Map<String, dynamic> mockXntData() => {
    'summary': {
      'openingSkuCount': 3,
      'importedSkuCount': 2,
      'exportedSkuCount': 3,
      'closingSkuCount': 3,
    },
    'items': [
      {
        'productId': 1,
        'name': 'Cà phê Arabica Cầu Đất 500g',
        'sku': 'CF-ARA-500',
        'unit': 'Gói',
        'openingStock': 20,
        'importQty': 35,
        'imported': 35,
        'totalImport': 35,
        'exportQty': 10,
        'exported': 10,
        'totalExport': 10,
        'closingStock': 45,
      },
      {
        'productId': 2,
        'name': 'Trà Oolong Bảo Lộc 250g',
        'sku': 'TEA-OOL-250',
        'unit': 'Hộp',
        'openingStock': 12,
        'importQty': 0,
        'imported': 0,
        'totalImport': 0,
        'exportQty': 4,
        'exported': 4,
        'totalExport': 4,
        'closingStock': 8,
      },
      {
        'productId': 3,
        'name': 'Bột Cacao Nguyên Chất Đắk Lắk 500g',
        'sku': 'COCOA-500',
        'unit': 'Hũ',
        'openingStock': 40,
        'importQty': 30,
        'imported': 30,
        'totalImport': 30,
        'exportQty': 8,
        'exported': 8,
        'totalExport': 8,
        'closingStock': 62,
      },
    ],
  };

  final deepOverrides = [
    shopProvider.overrideWith(_MockShop.new),
    apiClientProvider.overrideWithValue(_DeepMockApiClient()),
    shopProfileProvider.overrideWith(
      (ref) async => {
        'id': 1,
        'name': 'Cửa hàng mẫu SmartStock',
        'phone': '0901234567',
        'address': '123 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
        'taxCode': '0312345678',
      },
    ),
    supplierListProvider.overrideWith(
      (ref, args) async => {
        'items': [
          {
            'id': 1,
            'name': 'Công ty Cổ phần Cà phê Cầu Đất Farm',
            'taxCode': '0314892011',
            'phone': '0908123456',
            'email': 'contact@caudatfarm.vn',
            'paymentTermDays': 30,
            'status': 'ACTIVE',
          },
          {
            'id': 2,
            'name': 'Hợp tác xã Chè Bảo Lộc Organic',
            'taxCode': '5801234567',
            'phone': '0912345678',
            'email': 'baoloc.tea@gmail.com',
            'paymentTermDays': 15,
            'status': 'ACTIVE',
          },
          {
            'id': 3,
            'name': 'Nông trường Cacao Đắk Lắk Buôn Ma Thuột',
            'taxCode': '6009876543',
            'phone': '0987654321',
            'email': 'daklakcocoa@agri.vn',
            'paymentTermDays': 45,
            'status': 'ACTIVE',
          },
        ],
        'total': 3,
        'page': 1,
        'totalPages': 1,
      },
    ),
    supplierPayablesAgingProvider.overrideWith(
      (ref, asOf) async => {
        'asOf': asOf,
        'summary': {
          'totalOutstanding': 18300000,
          'overdueOutstanding': 5800000,
          'overdueRatio': 0.317,
          'payableCount': 3,
          'supplierCount': 2,
        },
        'buckets': {
          'current': 12500000,
          'past30': 5800000,
          'past60': 0,
          'past90': 0,
        },
        'suppliers': [
          {
            'name': 'Công ty CP Cà phê Cầu Đất',
            'supplierName': 'Công ty CP Cà phê Cầu Đất',
            'totalOutstanding': 12500000,
            'overdueOutstanding': 0,
            'overdueRatio': 0.0,
            'payableCount': 2,
          },
          {
            'name': 'HTX Chè Bảo Lộc',
            'supplierName': 'HTX Chè Bảo Lộc',
            'totalOutstanding': 5800000,
            'overdueOutstanding': 5800000,
            'overdueRatio': 1.0,
            'payableCount': 1,
          },
        ],
        'items': [
          {
            'id': 1,
            'supplierId': 1,
            'supplierName': 'Công ty CP Cà phê Cầu Đất',
            'purchaseOrderId': 201,
            'purchaseOrderCode': 'PO-2026-001',
            'amount': 8500000,
            'paidAmount': 2000000,
            'remaining': 6500000,
            'dueDate': '2026-09-30',
            'daysOverdue': 0,
            'bucket': 'current',
          },
          {
            'id': 2,
            'supplierId': 2,
            'supplierName': 'HTX Chè Bảo Lộc',
            'purchaseOrderId': 202,
            'purchaseOrderCode': 'PO-2026-002',
            'amount': 5800000,
            'paidAmount': 0,
            'remaining': 5800000,
            'dueDate': '2026-09-14',
            'daysOverdue': 5,
            'bucket': 'past30',
          },
          {
            'id': 3,
            'supplierId': 1,
            'supplierName': 'Công ty CP Cà phê Cầu Đất',
            'purchaseOrderId': 203,
            'purchaseOrderCode': 'PO-2026-003',
            'amount': 6000000,
            'paidAmount': 0,
            'remaining': 6000000,
            'dueDate': '2026-10-15',
            'daysOverdue': 0,
            'bucket': 'current',
          },
        ],
      },
    ),
    salesDetailProvider(101).overrideWith(
      (ref) async => {
        'id': 101,
        'orderCode': 'DH-2026-001',
        'createdAt': '2026-09-19T10:30:00Z',
        'status': 'COMPLETED',
        'customer': {'id': 1, 'name': 'Nguyễn Văn An', 'phone': '0901234567'},
        'customerName': 'Nguyễn Văn An',
        'totalAmount': 450000,
        'paidAmount': 450000,
        'notes': 'Giao hàng buổi sáng, khách thanh toán chuyển khoản',
        'items': [
          {
            'id': 1,
            'productName': 'Cà phê Arabica Cầu Đất 500g',
            'sku': 'CF-ARA-500',
            'quantity': 2,
            'unitPrice': 185000,
            'subtotal': 370000,
            'unit': 'Gói',
          },
          {
            'id': 2,
            'productName': 'Bột Cacao Nguyên Chất 500g',
            'sku': 'COCOA-500',
            'quantity': 0.5,
            'unitPrice': 160000,
            'subtotal': 80000,
            'unit': 'Hũ',
          },
        ],
      },
    ),
    stockProvider(null).overrideWith(
      (ref) async => [
        {
          'product': {
            'id': 1,
            'name': 'Cà phê Arabica Cầu Đất 500g',
            'sku': 'CF-ARA-500',
            'unit': 'Gói',
            'minStock': 10,
          },
          'warehouse': {'name': 'Kho chính'},
          'currentQuantity': 45,
        },
        {
          'product': {
            'id': 2,
            'name': 'Trà Oolong Bảo Lộc Đặc Biệt 250g',
            'sku': 'TEA-OOL-250',
            'unit': 'Hộp',
            'minStock': 15,
          },
          'warehouse': {'name': 'Kho chính'},
          'currentQuantity': 8,
        },
        {
          'product': {
            'id': 3,
            'name': 'Bột Cacao Nguyên Chất Đắk Lắk 500g',
            'sku': 'COCOA-500',
            'unit': 'Hũ',
            'minStock': 10,
          },
          'warehouse': {'name': 'Kho phụ'},
          'currentQuantity': 62,
        },
      ],
    ),
    purchaseOrdersProvider(1).overrideWith(
      (ref) async => {
        'items': [
          {
            'id': 201,
            'orderCode': 'PO-2026-001',
            'orderDate': '2026-09-15T09:00:00Z',
            'supplier': {'name': 'Công ty CP Cà phê Cầu Đất'},
            'supplierName': 'Công ty CP Cà phê Cầu Đất',
            'totalAmount': 8500000,
            'status': 'COMPLETED',
            'invoiceNumber': 'HD-009123',
          },
          {
            'id': 202,
            'orderCode': 'PO-2026-002',
            'orderDate': '2026-09-18T14:30:00Z',
            'supplier': {'name': 'HTX Chè Bảo Lộc'},
            'supplierName': 'HTX Chè Bảo Lộc',
            'totalAmount': 5800000,
            'status': 'PENDING',
            'invoiceNumber': 'HD-009456',
          },
        ],
        'total': 2,
        'page': 1,
        'totalPages': 1,
      },
    ),
    xntReportProvider((
      from:
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-01',
      to: DateTime.now().toIso8601String().split('T').first,
      warehouseId: null,
    )).overrideWith((ref) async => mockXntData()),
    slowMovingProvider.overrideWith((ref) async => []),
    taxObligationsProvider.overrideWith(
      (ref) async => {
        'items': [
          {
            'id': 1,
            'period': 'Quý 3/2026',
            'status': 'pending',
            'vatDeclared': 1450000,
            'pitDeclared': 725000,
            'vatPaid': 0,
            'pitPaid': 325000,
            'dueDate': '2026-10-30',
          },
          {
            'id': 2,
            'period': 'Quý 2/2026',
            'status': 'done',
            'vatDeclared': 1200000,
            'pitDeclared': 600000,
            'vatPaid': 1200000,
            'pitPaid': 600000,
            'dueDate': '2026-07-30',
          },
        ],
        'totalOwed': 1850000,
      },
    ),
    profitLossProvider((from: '2026-09-01', to: '2026-09-19')).overrideWith(
      (ref) async => {
        'revenue': 145000000.0,
        'cogs': 85000000.0,
        'grossProfit': 60000000.0,
        'operatingExpenses': 15000000.0,
        'netProfit': 45000000.0,
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

  // 1. Supplier List Screen
  testWidgets('Capture Supplier List Screen', (tester) async {
    const key = ValueKey('suppliers_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const SupplierListScreen(), '/suppliers'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'suppliers-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const SupplierListScreen(), '/suppliers'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'suppliers-mobile.png');
  });

  // 2. Supplier Payables Aging Screen
  testWidgets('Capture Supplier Payables Aging Screen', (tester) async {
    const key = ValueKey('supplier_payables_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const SupplierPayablesAgingScreen(),
            '/supplier-payables-aging',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'supplier-payables-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const SupplierPayablesAgingScreen(),
            '/supplier-payables-aging',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'supplier-payables-mobile.png');
  });

  // 3. Customer Debt Screen
  testWidgets('Capture Customer Debt Screen', (tester) async {
    const key = ValueKey('customer_debt_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const CustomerDebtScreen(), '/customer-debts'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await capture(tester, key, 'customer-debts-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const CustomerDebtScreen(), '/customer-debts'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await capture(tester, key, 'customer-debts-mobile.png');
  });

  // 4. Order Detail Screen
  testWidgets('Capture Order Detail Screen', (tester) async {
    const key = ValueKey('order_detail_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const OrderDetailScreen(id: 101),
            '/sales/101',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'order-detail-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const OrderDetailScreen(id: 101),
            '/sales/101',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'order-detail-mobile.png');
  });

  // 5. Stock Take Screen
  testWidgets('Capture Stock Take Screen', (tester) async {
    const key = ValueKey('stock_take_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const StockTakeScreen(), '/stock-take'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'stock-take-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const StockTakeScreen(), '/stock-take'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'stock-take-mobile.png');
  });

  // 6. Purchase Order Screen
  testWidgets('Capture Purchase Order Screen', (tester) async {
    const key = ValueKey('purchase_orders_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const PurchaseOrderScreen(),
            '/purchase-orders',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'purchase-orders-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const PurchaseOrderScreen(),
            '/purchase-orders',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'purchase-orders-mobile.png');
  });

  // 7. XNT Report Screen
  testWidgets('Capture XNT Report Screen', (tester) async {
    const key = ValueKey('xnt_report_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const XntReportScreen(), '/xnt-report'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'xnt-report-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const XntReportScreen(), '/xnt-report'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'xnt-report-mobile.png');
  });

  // 8. Tax Obligation Screen
  testWidgets('Capture Tax Obligation Screen', (tester) async {
    const key = ValueKey('tax_obligations_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const TaxObligationScreen(),
            '/tax-obligations',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-obligations-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const TaxObligationScreen(),
            '/tax-obligations',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-obligations-mobile.png');
  });

  // 9. Tax Calculator Screen
  testWidgets('Capture Tax Calculator Screen', (tester) async {
    const key = ValueKey('tax_calculator_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const TaxCalculatorScreen(),
            '/tax-calculator',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-calculator-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const TaxCalculatorScreen(),
            '/tax-calculator',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-calculator-mobile.png');
  });

  // 10. Tax Declaration Screen
  testWidgets('Capture Tax Declaration Screen', (tester) async {
    const key = ValueKey('tax_declaration_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const TaxDeclarationScreen(),
            '/tax-declaration',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-declaration-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(
            const TaxDeclarationScreen(),
            '/tax-declaration',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-declaration-mobile.png');
  });

  // 11. Staff Management Screen
  testWidgets('Capture Staff Management Screen', (tester) async {
    const key = ValueKey('staff_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const StaffManagementScreen(), '/staff'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await capture(tester, key, 'staff-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: deepOverrides,
          child: buildTestScreen(const StaffManagementScreen(), '/staff'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await capture(tester, key, 'staff-mobile.png');
  });
}
