import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
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

  const employeeShopState = ShopState(
    currentShopId: 1,
    memberType: 'EMPLOYEE',
    status: 'ACTIVE',
    permissions: {'sales': 'view', 'inventory': 'view'},
    userShops: [
      {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
    ],
    isLoading: false,
  );

  final employeeAuthState = const AuthState(
    isLoggedIn: true,
    accountType: 'PERSONAL',
    user: {
      'id': 2,
      'username': 'warehouse_staff',
      'fullName': 'Nhân viên kho',
    },
  );

  const ownerShopState = ShopState(
    currentShopId: 1,
    memberType: 'OWNER',
    status: 'ACTIVE',
    permissions: {'sales': 'manage', 'finance': 'manage', 'inventory': 'manage'},
    userShops: [
      {'shopId': 1, 'memberType': 'OWNER', 'status': 'ACTIVE'},
    ],
    isLoading: false,
  );

  final ownerAuthState = const AuthState(
    isLoggedIn: true,
    accountType: 'SHOP',
    user: {
      'id': 1,
      'username': 'shop_owner',
      'fullName': 'Chủ cửa hàng',
    },
  );

  const accountantShopState = ShopState(
    currentShopId: 1,
    memberType: 'EMPLOYEE',
    status: 'ACTIVE',
    permissions: {'finance': 'view'},
    userShops: [
      {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
    ],
    isLoading: false,
  );

  final accountantAuthState = const AuthState(
    isLoggedIn: true,
    accountType: 'PERSONAL',
    user: {
      'id': 3,
      'username': 'accountant',
      'fullName': 'Kế toán viên',
    },
  );

  group('Settings Role & Permission Gating', () {
    testWidgets(
      'Staff management is visible only to shop owners, hidden from employees',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shopProvider.overrideWith(() => _FakeShopNotifier(employeeShopState)),
              authProvider.overrideWith(() => _FakeAuthNotifier(employeeAuthState)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const Scaffold(body: SettingsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Employee should NOT see Staff management or Tax Support
        expect(find.text('Danh sách nhân viên'), findsNothing);
        expect(find.text('Kênh hỗ trợ thuế'), findsNothing);

        // Now test Owner
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shopProvider.overrideWith(() => _FakeShopNotifier(ownerShopState)),
              authProvider.overrideWith(() => _FakeAuthNotifier(ownerAuthState)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const Scaffold(body: SettingsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Owner should see Staff management and Tax Support
        expect(find.text('Danh sách nhân viên'), findsOneWidget);
        expect(find.text('Kênh hỗ trợ thuế'), findsOneWidget);
      },
    );

    testWidgets('Finance permission gates Tax Support menu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(accountantShopState)),
            authProvider.overrideWith(() => _FakeAuthNotifier(accountantAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Accountant has finance permission, so Tax Support is visible, but staff management is not
      expect(find.text('Kênh hỗ trợ thuế'), findsOneWidget);
      expect(find.text('Danh sách nhân viên'), findsNothing);
    });
  });

  group('TaxObligationReminder Date & Invalidation Tests', () {
    testWidgets('Due today displays "Đến hạn hôm nay" accurately', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taxObligationsProvider.overrideWith(
              (ref) => Future.value({
                'items': [
                  {
                    'id': 1,
                    'period': 'Quý 1/2026',
                    'dueDate': now.toIso8601String(),
                    'vatDeclared': 1000000,
                    'vatPaid': 0,
                    'pitDeclared': 500000,
                    'pitPaid': 0,
                    'status': 'pending',
                  },
                ],
              }),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: TaxObligationReminder()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đến hạn hôm nay'), findsOneWidget);
      expect(find.textContaining('Quý 1/2026'), findsOneWidget);
    });

    testWidgets('Overdue date displays "Quá hạn"', (tester) async {
      final past = DateTime.now().subtract(const Duration(days: 2));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taxObligationsProvider.overrideWith(
              (ref) => Future.value({
                'items': [
                  {
                    'id': 2,
                    'period': 'Quý 4/2025',
                    'dueDate': past.toIso8601String(),
                    'vatDeclared': 500000,
                    'vatPaid': 0,
                    'pitDeclared': 0,
                    'pitPaid': 0,
                    'status': 'pending',
                  },
                ],
              }),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: TaxObligationReminder()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Quá hạn'), findsOneWidget);
    });

    testWidgets('Null or invalid date displays "Chờ nộp" without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taxObligationsProvider.overrideWith(
              (ref) => Future.value({
                'items': [
                  {
                    'id': 3,
                    'period': 'Quý 2/2026',
                    'dueDate': null,
                    'vatDeclared': 500000,
                    'vatPaid': 0,
                    'status': 'pending',
                  },
                ],
              }),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: TaxObligationReminder()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chờ nộp'), findsOneWidget);
    });

    testWidgets('Completed status is excluded from pending reminders', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taxObligationsProvider.overrideWith(
              (ref) => Future.value({
                'items': [
                  {
                    'id': 4,
                    'period': 'Quý 1/2026',
                    'dueDate': DateTime.now().toIso8601String(),
                    'vatDeclared': 500000,
                    'vatPaid': 500000,
                    'status': 'done',
                  },
                ],
              }),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: TaxObligationReminder()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đến hạn hôm nay'), findsNothing);
      expect(find.textContaining('Quý 1/2026'), findsNothing);
    });
  });

  group('Dashboard Cash Balance KPI & Navigation Tests', () {
    Widget buildDashboardApp(List<dynamic> overrides) {
      return ProviderScope(
        overrides: [
          salesSummaryProvider.overrideWith(
            (ref, args) => Future.value({
              'totalRevenue': 1000000,
              'grossProfit': 200000,
              'orderCount': 5,
            }),
          ),
          topProductsProvider.overrideWith((ref, args) => Future.value([])),
          recentTransactionsProvider.overrideWith((ref) => Future.value([])),
          inventoryCategoriesSummaryProvider.overrideWith((ref) => Future.value([])),
          lowStockProvider.overrideWith((ref) => Future.value([])),
          taxObligationsProvider.overrideWith((ref) => Future.value({'items': []})),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const Scaffold(body: DashboardScreen()),
        ),
      );
    }

    testWidgets('Valid 0 cashBalance displays "0 ₫" and "Tại ..."', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardApp([
          shopProvider.overrideWith(() => _FakeShopNotifier(ownerShopState)),
          authProvider.overrideWith(() => _FakeAuthNotifier(ownerAuthState)),
          cashSummaryProvider.overrideWith(
            (ref, args) => Future.value({'cashBalance': 0}),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 ₫'), findsOneWidget);
      expect(find.textContaining('Tại '), findsOneWidget);
    });

    testWidgets('Missing or null cashBalance displays "Chưa có số liệu" and "Chưa có số dư"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardApp([
          shopProvider.overrideWith(() => _FakeShopNotifier(ownerShopState)),
          authProvider.overrideWith(() => _FakeAuthNotifier(ownerAuthState)),
          cashSummaryProvider.overrideWith(
            (ref, args) => Future.value({'cashBalance': null}),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có số liệu'), findsOneWidget);
      expect(find.text('Chưa có số dư'), findsOneWidget);
    });

    testWidgets('Invalid cashBalance string displays "Chưa có số liệu"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardApp([
          shopProvider.overrideWith(() => _FakeShopNotifier(ownerShopState)),
          authProvider.overrideWith(() => _FakeAuthNotifier(ownerAuthState)),
          cashSummaryProvider.overrideWith(
            (ref, args) => Future.value({'cashBalance': 'invalid_cash'}),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có số liệu'), findsOneWidget);
      expect(find.text('Chưa có số dư'), findsOneWidget);
    });

    testWidgets('API error displays "Chưa tải được" and "Lỗi tải dữ liệu"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardApp([
          shopProvider.overrideWith(() => _FakeShopNotifier(ownerShopState)),
          authProvider.overrideWith(() => _FakeAuthNotifier(ownerAuthState)),
          cashSummaryProvider.overrideWith(
            (ref, args) => Future.error(Exception('Server error')),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa tải được'), findsOneWidget);
      expect(find.text('Lỗi tải dữ liệu'), findsOneWidget);
    });

    testWidgets('Unauthorized user displays "Không có quyền" and "Cần quyền tài chính"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildDashboardApp([
          shopProvider.overrideWith(() => _FakeShopNotifier(employeeShopState)),
          authProvider.overrideWith(() => _FakeAuthNotifier(employeeAuthState)),
          cashSummaryProvider.overrideWith(
            (ref, args) => Future.value({'cashBalance': 5000000}),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không có quyền'), findsOneWidget);
      expect(find.text('Cần quyền tài chính'), findsOneWidget);
    });
  });
}
