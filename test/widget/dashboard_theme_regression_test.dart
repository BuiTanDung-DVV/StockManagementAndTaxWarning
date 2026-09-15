import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/providers/dashboard_action_provider.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/shell/main_shell.dart';
import '../support/load_ui_fonts.dart';

class _Shop extends ShopNotifier {
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

void main() {
  setUpAll(loadUiFonts);
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  for (final scenario in [
    (width: 390.0, scale: 1.0),
    (width: 900.0, scale: 1.0),
    (width: 1280.0, scale: 1.0),
    (width: 1440.0, scale: 1.0),
    (width: 390.0, scale: 1.5),
    (width: 1440.0, scale: 1.5),
  ]) {
    final width = scenario.width;
    testWidgets(
      'dashboard and shell preserve long amounts at $width scale ${scenario.scale}',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const MainShell(child: DashboardScreen()),
            ),
          ],
        );
        addTearDown(router.dispose);
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) {
            debugPrint(details.toString());
          }
          originalErrorHandler?.call(details);
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('dashboard-capture'),
            child: ProviderScope(
              overrides: [
                shopProvider.overrideWith(_Shop.new),
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
                      'name': 'Thiết bị vệ sinh',
                      'skuCount': 15,
                      'value': 8500000000,
                    },
                    {
                      'name': 'Gạch ốp lát',
                      'skuCount': 22,
                      'value': 3200000000,
                    },
                    {
                      'name': 'Sơn & Hóa chất',
                      'skuCount': 8,
                      'value': 1500000000,
                    },
                  ],
                ),
                lowStockProvider.overrideWith(
                  (ref) async => [
                    {
                      'id': 1,
                      'shopId': 1,
                      'productId': 101,
                      'quantity': 5,
                      'currentQuantity': 5,
                      'minStock': 20,
                      'product': {
                        'id': 101,
                        'name': 'Sơn Dulux ngoại thất',
                        'sku': 'SON-DULUX-01',
                        'unit': 'Thùng',
                        'minStock': 20,
                      },
                    },
                  ],
                ),
                recentTransactionsProvider.overrideWith((_) async => []),
                topProductsProvider.overrideWith(
                  (ref, period) async => [
                    {
                      'id': 1,
                      'name': 'Sản phẩm mẫu có tên dài để kiểm tra bố cục',
                      'value': 56000000,
                      'quantity': 120,
                      'unit': 'Bao',
                      'growthStatus': 'NEW',
                    },
                  ],
                ),
                dashboardActionProvider.overrideWith(
                  (_) async => DashboardActionData(
                    asOf: DateTime(2026, 9, 9),
                    items: const [],
                    healthySummary: const [],
                  ),
                ),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme(AppColors.primary),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
                  child: child!,
                ),
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = originalErrorHandler;
        expect(find.text('Tổng quan cửa hàng'), findsOneWidget);
        expect(find.textContaining('12.345.678.900'), findsWidgets);
        expect(find.textContaining('2.456.789.000'), findsWidgets);
        expect(find.textContaining('18.416.843.500'), findsWidgets);
        if (width >= 1280) {
          Rect surface(String type) {
            final owner = find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == type,
                )
                .first;
            final decorated = find
                .descendant(
                  of: owner,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Container &&
                        widget.decoration is BoxDecoration,
                  ),
                )
                .first;
            return tester.getRect(decorated);
          }

          for (final pair in [
            ('_DashboardChart', 'DashboardPriorityList'),
            ('DashboardSalesPerformanceCard', 'DashboardCashFlowCard'),
            ('DashboardInventoryCategoryCard', 'DashboardLowStockCard'),
          ]) {
            final left = surface(pair.$1);
            final right = surface(pair.$2);
            expect(left.top, closeTo(right.top, 1), reason: '${pair.$1} top');
            expect(
              left.bottom,
              closeTo(right.bottom, 1),
              reason: '${pair.$1} bottom',
            );
          }
        }
        if (width == 390 && scenario.scale == 1.0) {
          final revenue = tester.getRect(
            find.textContaining('12.345.678.900').first,
          );
          final profit = tester.getRect(
            find.textContaining('2.456.789.000').first,
          );
          final cash = tester.getRect(
            find.textContaining('18.416.843.500').first,
          );
          expect(
            (revenue.top - profit.top).abs(),
            lessThan(4),
            reason:
                'Mobile KPIs must share two columns instead of four tall cards',
          );
          expect(profit.left, greaterThan(revenue.right));
          expect(cash.top, greaterThan(revenue.bottom));
          expect(
            cash.bottom - revenue.top,
            lessThan(220),
            reason: 'The KPI group must leave room for operational content',
          );
        }
        final layoutError = tester.takeException();
        if (layoutError is FlutterError) {
          debugPrint(layoutError.toString(minLevel: DiagnosticLevel.info));
        }
        expect(layoutError, isNull);
        if (const bool.fromEnvironment('CAPTURE_UI') && scenario.scale == 1.0) {
          await expectLater(
            find.byKey(const ValueKey('dashboard-capture')),
            matchesGoldenFile(
              '../../BA_DOCUMENTS/UI_AUDIT/auth_home_redesign_2026-09-08/screenshots/dashboard-${width.toInt()}.png',
            ),
          );
          if (width >= 1280) {
            for (final card in ['sales', 'inventory']) {
              await tester.ensureVisible(
                find.byKey(Key('dashboard-card-$card')),
              );
              await tester.pumpAndSettle();
              await expectLater(
                find.byKey(const ValueKey('dashboard-capture')),
                matchesGoldenFile(
                  '../../BA_DOCUMENTS/UI_AUDIT/auth_home_redesign_2026-09-08/screenshots/dashboard-${width.toInt()}-$card.png',
                ),
              );
            }
          }
        }
      },
    );
  }
}
