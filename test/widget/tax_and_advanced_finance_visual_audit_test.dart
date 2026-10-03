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
import 'package:flutter_app/features/finance/presentation/daily_closing_screen.dart';
import 'package:flutter_app/features/finance/presentation/purchase_no_invoice_screen.dart';
import 'package:flutter_app/features/finance/presentation/salary_ledger_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
import 'package:flutter_app/features/tax/screens/tax_estimate_screen.dart';
import 'package:flutter_app/features/tax/services/tax_service.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_tax_advanced/screenshots';

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
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {'success': true};
  @override
  Future<dynamic> put(String path, {dynamic data}) async => {'success': true};
}

class _FakeTaxService extends TaxService {
  _FakeTaxService() : super(_FakeApiClient());

  @override
  Future<Map<String, dynamic>> getTaxEstimate(
    String period,
    String year,
  ) async {
    return {
      'shopName': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
      'taxCode': '0312345678',
      'period': period,
      'year': year,
      'totalRevenue': 150000000.0,
      'taxableRevenue': 150000000.0,
      'vatOwed': 1500000.0,
      'pitOwed': 750000.0,
      'taxExempt': false,
      'effectiveVatRate': 1.0,
      'effectivePitRate': 0.5,
      'status': 'OK',
    };
  }
}

class _FakeFinanceRepo extends FinanceRepository {
  _FakeFinanceRepo() : super(_FakeApiClient());

  @override
  Future<Map<String, dynamic>> findPurchasesNoInvoice({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return {
      'data': [
        {
          'id': 1,
          'recordCode': 'BK-2026-001',
          'sellerName': 'Nguyễn Văn Nông (Nông dân)',
          'sellerAddress': 'Xã Đức Hòa, Long An',
          'totalAmount': 12500000.0,
          'approvalStatus': 'APPROVED',
          'createdAt': '2026-09-28T09:00:00Z',
          'items': [
            {'productName': 'Gạo ST25 tươi', 'quantity': 500, 'price': 25000},
          ],
        },
        {
          'id': 2,
          'recordCode': 'BK-2026-002',
          'sellerName': 'Trần Thị Thu (Hộ làm vườn)',
          'sellerAddress': 'Hóc Môn, TP.HCM',
          'totalAmount': 6800000.0,
          'approvalStatus': 'PENDING',
          'createdAt': '2026-09-29T14:30:00Z',
          'items': [
            {
              'productName': 'Rau củ hữu cơ Đà Lạt',
              'quantity': 340,
              'price': 20000,
            },
          ],
        },
      ],
      'total': 2,
      'totalPages': 1,
      'page': 1,
      'totalAmount': 19300000.0,
    };
  }

  @override
  Future<Map<String, dynamic>> getDailyClosing(String date) async {
    return {
      'date': date,
      'totalIncome': 12500000.0,
      'totalExpense': 4200000.0,
      'cashIncome': 8500000.0,
      'cashExpense': 1200000.0,
      'bankIncome': 4000000.0,
      'bankExpense': 3000000.0,
      'totalSales': 12500000.0,
      'totalReturns': 0.0,
      'orderCount': 28,
      'expectedCash': 17300000.0,
      'openingCash': 10000000.0,
      'closingCash': 17300000.0,
      'status': 'DRAFT',
      'notes': 'Ca làm việc kết thúc đúng chỉ tiêu',
    };
  }

  @override
  Future<Map<String, dynamic>> getDailyClosings({
    int page = 1,
    int limit = 20,
  }) async {
    return {'items': <dynamic>[], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> findTransactions({
    int page = 1,
    int limit = 20,
    String? type,
    String? category,
    String? from,
    String? to,
    int? accountId,
  }) async {
    return {
      'items': [
        {
          'id': 201,
          'transactionCode': 'TX-SALARY-01',
          'type': 'EXPENSE',
          'category': 'SALARY',
          'amount': 4500000.0,
          'date': '2026-09-28',
          'description': 'Tạm ứng lương tuần 4 cho NV Bán hàng',
          'accountName': 'Quỹ tiền mặt tại quầy',
        },
        {
          'id': 202,
          'transactionCode': 'TX-SALARY-02',
          'type': 'EXPENSE',
          'category': 'SALARY',
          'amount': 5500000.0,
          'date': '2026-09-30',
          'description': 'Lương cứng thủ kho tháng 9/2026',
          'accountName': 'Tài khoản MB Bank',
        },
      ],
      'total': 2,
      'totalPages': 1,
      'page': 1,
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
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

  const fakeAuthState = AuthState(
    isLoggedIn: true,
    token: 'fake_jwt_token',
    user: {
      'id': 1,
      'fullName': 'Bùi Tấn Dũng',
      'email': 'tandung@smartstock.vn',
      'role': 'OWNER',
    },
  );

  final fakeTaxConfig = createDefaultVerifiedTaxConfig(
    businessType: BusinessType.distribution,
  );

  group('Tax & Advanced Operations Visual Audit', () {
    testWidgets('01_tax_estimate_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('tax_estimate_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            taxConfigProvider.overrideWith(
              () => _FakeTaxConfigNotifier(fakeTaxConfig),
            ),
            taxServiceProvider.overrideWithValue(_FakeTaxService()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: TaxEstimateScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaxEstimateScreen), findsOneWidget);
      await _capture(tester, key, '01_tax_estimate_desktop.png');
    });

    testWidgets('02_tax_estimate_mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('tax_estimate_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            taxConfigProvider.overrideWith(
              () => _FakeTaxConfigNotifier(fakeTaxConfig),
            ),
            taxServiceProvider.overrideWithValue(_FakeTaxService()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: TaxEstimateScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaxEstimateScreen), findsOneWidget);
      await _capture(tester, key, '02_tax_estimate_mobile.png');
    });

    testWidgets('03_purchase_no_invoice_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('purchase_no_invoice_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            financeRepoProvider.overrideWithValue(_FakeFinanceRepo()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: PurchaseNoInvoiceScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PurchaseNoInvoiceScreen), findsOneWidget);
      await _capture(tester, key, '03_purchase_no_invoice_desktop.png');
    });

    testWidgets('04_daily_closing_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('daily_closing_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            financeRepoProvider.overrideWithValue(_FakeFinanceRepo()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: DailyClosingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DailyClosingScreen), findsOneWidget);
      await _capture(tester, key, '04_daily_closing_desktop.png');
    });

    testWidgets('05_salary_ledger_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('salary_ledger_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            financeRepoProvider.overrideWithValue(_FakeFinanceRepo()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: SalaryLedgerScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SalaryLedgerScreen), findsOneWidget);
      await _capture(tester, key, '05_salary_ledger_desktop.png');
    });
  });
}
