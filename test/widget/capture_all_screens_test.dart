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
import 'package:flutter_app/features/auth/presentation/onboarding_screen.dart';
import 'package:flutter_app/features/auth/presentation/waiting_approval_screen.dart';
import 'package:flutter_app/features/auth/presentation/otp_verification_screen.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter_app/features/settings/presentation/tax_config_screen.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
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

class _MockTaxConfig extends TaxConfigNotifier {
  @override
  TaxConfig build() {
    return const TaxConfig(
      businessType: BusinessType.distribution,
      vatReduction20: false,
      thresholds: RevenueThresholds(
        tier1: 50000000,
        tier2: 70000000,
        tier3: 85000000,
        tier4: 100000000,
      ),
      rates: {
        BusinessType.distribution: TaxRates(vat: 0.01, pit: 0.005),
        BusinessType.services: TaxRates(vat: 0.05, pit: 0.02),
        BusinessType.manufacturing: TaxRates(vat: 0.03, pit: 0.015),
        BusinessType.other: TaxRates(vat: 0.02, pit: 0.01),
      },
      fiscalYear: 2026,
      policySourceCode: 'Thông tư 40/2021/TT-BTC',
      isLoading: false,
      errorMessage: null,
    );
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
    file.writeAsBytesSync(byteData!.buffer.asUint8List());
  }

  testWidgets('Capture Onboarding Screen', (tester) async {
    const key = ValueKey('onboarding_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'onboarding-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'onboarding-mobile.png');
  });

  testWidgets('Capture Waiting Approval Screen', (tester) async {
    const key = ValueKey('waiting_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const WaitingApprovalScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'waiting-approval-desktop.png');
  });

  testWidgets('Capture OTP Verification Screen', (tester) async {
    const key = ValueKey('otp_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const OtpVerificationScreen(
              email: 'demo-user@gmail.com',
              fullName: 'Nguyễn Văn Demo',
              password: 'Password123!',
              accountType: 'OWNER',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'otp-desktop.png');
  });

  testWidgets('Capture Dashboard Screen', (tester) async {
    const key = ValueKey('dashboard_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            shopProvider.overrideWith(_MockShop.new),
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
            theme: AppTheme.lightTheme(AppColors.primary),
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const MainShell(child: DashboardScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'dashboard-desktop.png');

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            shopProvider.overrideWith(_MockShop.new),
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
            inventoryCategoriesSummaryProvider.overrideWith((ref) async => []),
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
            theme: AppTheme.lightTheme(AppColors.primary),
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const MainShell(child: DashboardScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'dashboard-mobile.png');
  });

  testWidgets('Capture Tax Config Screen', (tester) async {
    const key = ValueKey('tax_config_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            shopProvider.overrideWith(_MockShop.new),
            taxConfigProvider.overrideWith(_MockTaxConfig.new),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(AppColors.primary),
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => const MainShell(child: TaxConfigScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'tax-config-desktop.png');
  });

  testWidgets('Capture Settings Screen', (tester) async {
    const key = ValueKey('settings_capture');
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [shopProvider.overrideWith(_MockShop.new)],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(AppColors.primary),
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
    await capture(tester, key, 'settings-desktop.png');
  });
}
