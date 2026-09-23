import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/theme/app_background_provider.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/theme/avatar_provider.dart';
import 'package:flutter_app/core/theme/theme_provider.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/presentation/avatar_picker_dialog.dart';
import 'package:flutter_app/features/settings/presentation/profile_screen.dart';
import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter_app/features/settings/presentation/theme_appearance_modal.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/shell/main_shell.dart';
import '../support/load_ui_fonts.dart';

class _MockAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isLoggedIn: true,
    user: {
      'fullName': 'Nguyễn Văn Quản Lý',
      'email': 'admin@smartstock.vn',
      'phone': '0912345678',
      'username': 'admin_smartstock',
      'role': 'OWNER',
    },
  );
}

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

class _MockThemeModeSetting extends ThemeModeSettingNotifier {
  final AppThemeModeSetting _setting;
  _MockThemeModeSetting(this._setting);
  @override
  AppThemeModeSetting build() => _setting;
}

class _MockBrandColor extends BrandColorNotifier {
  final AppBrandColor _color;
  _MockBrandColor(this._color);
  @override
  AppBrandColor build() => _color;
}

class _MockAppBackground extends AppBackgroundNotifier {
  final AppBackgroundState _bg;
  _MockAppBackground(this._bg);
  @override
  AppBackgroundState build() => _bg;
}

class _MockAvatar extends UserAvatarNotifier {
  final UserAvatarState _av;
  _MockAvatar(this._av);
  @override
  UserAvatarState build() => _av;
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
    final file = File(
      'BA_DOCUMENTS/TEST_RUNS/appearance_inspection_screenshots/$fileName',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
  }

  group('Appearance Visual Inspection & Screenshot Generator', () {
    testWidgets('01 - Modal Tab 0: Mau sac & Che do', (tester) async {
      const key = ValueKey('modal_tab0_capture');
      await tester.binding.setSurfaceSize(const Size(720, 860));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const Scaffold(
                backgroundColor: Color(0xFFF1F5F9),
                body: Center(child: ThemeAppearanceModal()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '01_modal_tab0_color_mode.png');
    });

    testWidgets('02 - Modal Tab 1: Hinh nen App', (tester) async {
      const key = ValueKey('modal_tab1_capture');
      await tester.binding.setSurfaceSize(const Size(720, 1150));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const Scaffold(
                backgroundColor: Color(0xFFF1F5F9),
                body: Center(child: ThemeAppearanceModal()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Click on "Hình nền App" tab
      await tester.tap(find.text('Hình nền App'));
      await tester.pumpAndSettle();
      // Cuộn danh sách xuống để hiển thị đầy đủ các thẻ hình nền
      await tester.drag(
        find.text('HOA VĂN & HÌNH NỀN ỨNG DỤNG'),
        const Offset(0, -380),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '02_modal_tab1_wallpaper.png');
    });

    testWidgets('03 - Modal Tab 2: Anh dai dien', (tester) async {
      const key = ValueKey('modal_tab2_capture');
      await tester.binding.setSurfaceSize(const Size(720, 860));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const Scaffold(
                backgroundColor: Color(0xFFF1F5F9),
                body: Center(child: ThemeAppearanceModal()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Click on "Ảnh đại diện" tab
      await tester.tap(find.text('Ảnh đại diện'));
      await tester.pumpAndSettle();
      await capture(tester, key, '03_modal_tab2_avatar.png');
    });

    testWidgets('04 - Dialog Bo suu tap Avatar Doanh Nghiep', (tester) async {
      const key = ValueKey('avatar_dialog_capture');
      await tester.binding.setSurfaceSize(const Size(640, 780));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const Scaffold(
                backgroundColor: Color(0xFFE2E8F0),
                body: Center(child: AvatarPickerDialog()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '04_dialog_avatar_picker.png');
    });

    testWidgets('05 - Dashboard: Sang + Luc bao SmartStock + Khong nen', (
      tester,
    ) async {
      const key = ValueKey('dashboard_light_default_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.tealSmartStock),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(preset: AppWallpaperPreset.none),
                ),
              ),
              salesSummaryProvider.overrideWith(
                (ref, period) async => {
                  'orderCount': 1234,
                  'totalOrders': 1234,
                  'netSalesRevenue': 12345678900,
                  'grossProfit': 2456789000,
                  'totalCogs': 9888889900,
                  'returnNetSalesRevenue': 0,
                  'returnRatePct': 0,
                  'timezone': 'Asia/Ho_Chi_Minh',
                  'period': {'from': period.from, 'to': period.to},
                  'daily': [
                    {
                      'date': period.from,
                      'revenue': 12345678900,
                      'cogs': 9888889900,
                      'grossProfit': 2456789000,
                      'marginPct': 19.9,
                      'orderCount': 1234,
                    },
                  ],
                },
              ),
              cashSummaryProvider.overrideWith(
                (ref, period) async => {
                  'income': 15000000000,
                  'expense': 3000000000,
                  'netCashFlow': 12000000000,
                  'cashBalance': 18416843500,
                  'period': {
                    'name': 'custom',
                    'from': period.from,
                    'to': period.to,
                  },
                  'dailyFlow': [
                    {
                      'date': period.from,
                      'income': 15000000000,
                      'expense': 3000000000,
                    },
                  ],
                },
              ),
              inventoryCategoriesSummaryProvider.overrideWith(
                (ref) async => [
                  {
                    'category': 'Cà phê rang xay',
                    'productCount': 28,
                    'totalStock': 450,
                    'stockValue': 45000000,
                    'unit': 'Gói',
                    'growthStatus': 'HIGH',
                  },
                ],
              ),
              dashboardActionProvider.overrideWith(
                (_) async => DashboardActionData(
                  asOf: DateTime(2026, 9, 19),
                  items: const [],
                  healthySummary: const [],
                ),
              ),
              taxObligationsProvider.overrideWith((ref) async => {'items': []}),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.tealSmartStock.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        const MainShell(child: DashboardScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '05_dashboard_light_teal_none.png');
    });

    testWidgets('06 - Dashboard: Toi + Xanh Duong Cong Nghe + Cham Cong Nghe', (
      tester,
    ) async {
      const key = ValueKey('dashboard_dark_tech_dots_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.dark),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.luminaBlue),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(
                    preset: AppWallpaperPreset.techDots,
                    opacity: 0.12,
                  ),
                ),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.adminM),
                ),
              ),
              salesSummaryProvider.overrideWith(
                (ref, period) async => {
                  'orderCount': 1234,
                  'totalOrders': 1234,
                  'netSalesRevenue': 12345678900,
                  'grossProfit': 2456789000,
                  'totalCogs': 9888889900,
                  'returnNetSalesRevenue': 0,
                  'returnRatePct': 0,
                  'timezone': 'Asia/Ho_Chi_Minh',
                  'period': {'from': period.from, 'to': period.to},
                  'daily': [
                    {
                      'date': period.from,
                      'revenue': 12345678900,
                      'cogs': 9888889900,
                      'grossProfit': 2456789000,
                      'marginPct': 19.9,
                      'orderCount': 1234,
                    },
                  ],
                },
              ),
              cashSummaryProvider.overrideWith(
                (ref, period) async => {
                  'income': 15000000000,
                  'expense': 3000000000,
                  'netCashFlow': 12000000000,
                  'cashBalance': 18416843500,
                  'period': {
                    'name': 'custom',
                    'from': period.from,
                    'to': period.to,
                  },
                  'dailyFlow': [
                    {
                      'date': period.from,
                      'income': 15000000000,
                      'expense': 3000000000,
                    },
                  ],
                },
              ),
              inventoryCategoriesSummaryProvider.overrideWith(
                (ref) async => [
                  {
                    'category': 'Cà phê rang xay',
                    'productCount': 28,
                    'totalStock': 450,
                    'stockValue': 45000000,
                    'unit': 'Gói',
                    'growthStatus': 'HIGH',
                  },
                ],
              ),
              dashboardActionProvider.overrideWith(
                (_) async => DashboardActionData(
                  asOf: DateTime(2026, 9, 19),
                  items: const [],
                  healthySummary: const [],
                ),
              ),
              taxObligationsProvider.overrideWith((ref) async => {'items': []}),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme(AppBrandColor.luminaBlue.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        const MainShell(child: DashboardScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '06_dashboard_dark_lumina_techdots.png');
    });

    testWidgets('07 - Dashboard: Sang + Cam Ban Le + Luoi Kho Van', (
      tester,
    ) async {
      const key = ValueKey('dashboard_light_copper_grid_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.sunsetCopper),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(
                    preset: AppWallpaperPreset.warehouseGrid,
                    opacity: 0.12,
                  ),
                ),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.adminF),
                ),
              ),
              salesSummaryProvider.overrideWith(
                (ref, period) async => {
                  'orderCount': 1234,
                  'totalOrders': 1234,
                  'netSalesRevenue': 12345678900,
                  'grossProfit': 2456789000,
                  'totalCogs': 9888889900,
                  'returnNetSalesRevenue': 0,
                  'returnRatePct': 0,
                  'timezone': 'Asia/Ho_Chi_Minh',
                  'period': {'from': period.from, 'to': period.to},
                  'daily': [
                    {
                      'date': period.from,
                      'revenue': 12345678900,
                      'cogs': 9888889900,
                      'grossProfit': 2456789000,
                      'marginPct': 19.9,
                      'orderCount': 1234,
                    },
                  ],
                },
              ),
              cashSummaryProvider.overrideWith(
                (ref, period) async => {
                  'income': 15000000000,
                  'expense': 3000000000,
                  'netCashFlow': 12000000000,
                  'cashBalance': 18416843500,
                  'period': {
                    'name': 'custom',
                    'from': period.from,
                    'to': period.to,
                  },
                  'dailyFlow': [
                    {
                      'date': period.from,
                      'income': 15000000000,
                      'expense': 3000000000,
                    },
                  ],
                },
              ),
              inventoryCategoriesSummaryProvider.overrideWith(
                (ref) async => [
                  {
                    'category': 'Cà phê rang xay',
                    'productCount': 28,
                    'totalStock': 450,
                    'stockValue': 45000000,
                    'unit': 'Gói',
                    'growthStatus': 'HIGH',
                  },
                ],
              ),
              dashboardActionProvider.overrideWith(
                (_) async => DashboardActionData(
                  asOf: DateTime(2026, 9, 19),
                  items: const [],
                  healthySummary: const [],
                ),
              ),
              taxObligationsProvider.overrideWith((ref) async => {'items': []}),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.sunsetCopper.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        const MainShell(child: DashboardScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '07_dashboard_light_copper_grid.png');
    });

    testWidgets('08 - Dashboard: Sang + Luc Bao Thinh Vuong + Song Luc Bao', (
      tester,
    ) async {
      const key = ValueKey('dashboard_light_mesh_emerald_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.emeraldWealth),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(
                    preset: AppWallpaperPreset.meshEmerald,
                    opacity: 0.15,
                  ),
                ),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.accountant),
                ),
              ),
              salesSummaryProvider.overrideWith(
                (ref, period) async => {
                  'orderCount': 1234,
                  'totalOrders': 1234,
                  'netSalesRevenue': 12345678900,
                  'grossProfit': 2456789000,
                  'totalCogs': 9888889900,
                  'returnNetSalesRevenue': 0,
                  'returnRatePct': 0,
                  'timezone': 'Asia/Ho_Chi_Minh',
                  'period': {'from': period.from, 'to': period.to},
                  'daily': [
                    {
                      'date': period.from,
                      'revenue': 12345678900,
                      'cogs': 9888889900,
                      'grossProfit': 2456789000,
                      'marginPct': 19.9,
                      'orderCount': 1234,
                    },
                  ],
                },
              ),
              cashSummaryProvider.overrideWith(
                (ref, period) async => {
                  'income': 15000000000,
                  'expense': 3000000000,
                  'netCashFlow': 12000000000,
                  'cashBalance': 18416843500,
                  'period': {
                    'name': 'custom',
                    'from': period.from,
                    'to': period.to,
                  },
                  'dailyFlow': [
                    {
                      'date': period.from,
                      'income': 15000000000,
                      'expense': 3000000000,
                    },
                  ],
                },
              ),
              inventoryCategoriesSummaryProvider.overrideWith(
                (ref) async => [
                  {
                    'category': 'Cà phê rang xay',
                    'productCount': 28,
                    'totalStock': 450,
                    'stockValue': 45000000,
                    'unit': 'Gói',
                    'growthStatus': 'HIGH',
                  },
                ],
              ),
              dashboardActionProvider.overrideWith(
                (_) async => DashboardActionData(
                  asOf: DateTime(2026, 9, 19),
                  items: const [],
                  healthySummary: const [],
                ),
              ),
              taxObligationsProvider.overrideWith((ref) async => {'items': []}),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.emeraldWealth.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        const MainShell(child: DashboardScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '08_dashboard_light_mesh_emerald.png');
    });

    testWidgets('09 - Dashboard: Toi + Tim Thach Anh + Khoi Hinh Hoc', (
      tester,
    ) async {
      const key = ValueKey('dashboard_dark_geometric_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.dark),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.orchidMajesty),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(
                    preset: AppWallpaperPreset.geometric,
                    opacity: 0.12,
                  ),
                ),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.aiBot),
                ),
              ),
              salesSummaryProvider.overrideWith(
                (ref, period) async => {
                  'orderCount': 1234,
                  'totalOrders': 1234,
                  'netSalesRevenue': 12345678900,
                  'grossProfit': 2456789000,
                  'totalCogs': 9888889900,
                  'returnNetSalesRevenue': 0,
                  'returnRatePct': 0,
                  'timezone': 'Asia/Ho_Chi_Minh',
                  'period': {'from': period.from, 'to': period.to},
                  'daily': [
                    {
                      'date': period.from,
                      'revenue': 12345678900,
                      'cogs': 9888889900,
                      'grossProfit': 2456789000,
                      'marginPct': 19.9,
                      'orderCount': 1234,
                    },
                  ],
                },
              ),
              cashSummaryProvider.overrideWith(
                (ref, period) async => {
                  'income': 15000000000,
                  'expense': 3000000000,
                  'netCashFlow': 12000000000,
                  'cashBalance': 18416843500,
                  'period': {
                    'name': 'custom',
                    'from': period.from,
                    'to': period.to,
                  },
                  'dailyFlow': [
                    {
                      'date': period.from,
                      'income': 15000000000,
                      'expense': 3000000000,
                    },
                  ],
                },
              ),
              inventoryCategoriesSummaryProvider.overrideWith(
                (ref) async => [
                  {
                    'category': 'Cà phê rang xay',
                    'productCount': 28,
                    'totalStock': 450,
                    'stockValue': 45000000,
                    'unit': 'Gói',
                    'growthStatus': 'HIGH',
                  },
                ],
              ),
              dashboardActionProvider.overrideWith(
                (_) async => DashboardActionData(
                  asOf: DateTime(2026, 9, 19),
                  items: const [],
                  healthySummary: const [],
                ),
              ),
              taxObligationsProvider.overrideWith((ref) async => {'items': []}),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme(AppBrandColor.orchidMajesty.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) =>
                        const MainShell(child: DashboardScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '09_dashboard_dark_geometric.png');
    });

    testWidgets('10 - Settings: Sang + Mac dinh + Initials', (tester) async {
      const key = ValueKey('settings_light_default_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authProvider.overrideWith(_MockAuth.new),
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.tealSmartStock),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(preset: AppWallpaperPreset.none),
                ),
              ),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.tealSmartStock.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const MainShell(child: SettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '10_settings_light_default.png');
    });

    testWidgets('11 - Settings: Toi + Xanh Duong Cong Nghe + Avatar Admin M', (
      tester,
    ) async {
      const key = ValueKey('settings_dark_admin_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authProvider.overrideWith(_MockAuth.new),
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.dark),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.luminaBlue),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(
                    preset: AppWallpaperPreset.techDots,
                    opacity: 0.12,
                  ),
                ),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.adminM),
                ),
              ),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme(AppBrandColor.luminaBlue.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const MainShell(child: SettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '11_settings_dark_admin.png');
    });

    testWidgets('12 - Settings: Sang + Cam Ban Le + Avatar AI Bot', (
      tester,
    ) async {
      const key = ValueKey('settings_light_aibot_capture');
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authProvider.overrideWith(_MockAuth.new),
              shopProvider.overrideWith(_MockShop.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.sunsetCopper),
              ),
              appBackgroundProvider.overrideWith(
                () => _MockAppBackground(
                  const AppBackgroundState(
                    preset: AppWallpaperPreset.warehouseGrid,
                    opacity: 0.12,
                  ),
                ),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.aiBot),
                ),
              ),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.sunsetCopper.color),
              routerConfig: GoRouter(
                initialLocation: '/',
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const MainShell(child: SettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '12_settings_light_copper_aibot.png');
    });

    testWidgets('13 - Profile: Sang + Avatar Quan tri vien Nam', (
      tester,
    ) async {
      const key = ValueKey('profile_light_admin_m_capture');
      await tester.binding.setSurfaceSize(const Size(800, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authProvider.overrideWith(_MockAuth.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.tealSmartStock),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.adminM),
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.tealSmartStock.color),
              home: const ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '13_profile_screen_admin_m.png');
    });

    testWidgets('14 - Profile: Toi + Avatar Nu Quan Ly', (tester) async {
      const key = ValueKey('profile_dark_admin_f_capture');
      await tester.binding.setSurfaceSize(const Size(800, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authProvider.overrideWith(_MockAuth.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.dark),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.luminaBlue),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.adminF),
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme(AppBrandColor.luminaBlue.color),
              home: const ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '14_profile_screen_admin_f.png');
    });

    testWidgets('15 - Profile: Sang + Avatar Tro ly AI SmartStock', (
      tester,
    ) async {
      const key = ValueKey('profile_light_aibot_capture');
      await tester.binding.setSurfaceSize(const Size(800, 900));
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              authProvider.overrideWith(_MockAuth.new),
              themeModeSettingProvider.overrideWith(
                () => _MockThemeModeSetting(AppThemeModeSetting.light),
              ),
              brandColorProvider.overrideWith(
                () => _MockBrandColor(AppBrandColor.sunsetCopper),
              ),
              userAvatarProvider.overrideWith(
                () => _MockAvatar(
                  const UserAvatarState(preset: AppAvatarPreset.aiBot),
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(AppBrandColor.sunsetCopper.color),
              home: const ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, '15_profile_screen_aibot.png');
    });
  });
}
