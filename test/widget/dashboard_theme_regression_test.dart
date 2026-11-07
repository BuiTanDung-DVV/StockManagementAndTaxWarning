import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/guides/feature_guide_sheet.dart';
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
    (width: 1142.0, scale: 1.0),
    (width: 1280.0, scale: 1.0),
    (width: 1440.0, scale: 1.0),
    (width: 390.0, scale: 1.5),
    (width: 1440.0, scale: 1.5),
  ]) {
    final width = scenario.width;
    testWidgets(
      'dashboard and shell preserve long amounts at $width scale ${scenario.scale}',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 1142 ? 668 : 1000);
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
                taxObligationsProvider.overrideWith(
                  (_) async => {
                    'items': [
                      {
                        'period': 'Q2/2026',
                        'status': 'overdue',
                        'dueDate': '2026-09-21',
                        'vatDeclared': 3000000,
                      },
                      {
                        'period': 'Q3/2026',
                        'status': 'pending',
                        'dueDate': '2026-10-30',
                        'vatDeclared': 7500000,
                      },
                    ],
                  },
                ),
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
        // Checking for exceptions alone misses children painted below a card.
        for (final card
            in find
                .byWidgetPredicate(
                  (w) => w.runtimeType.toString() == '_PastelMetricCard',
                )
                .evaluate()) {
          final cardFinder = find.byElementPredicate(
            (element) => identical(element, card),
          );
          final cardRect = tester.getRect(cardFinder);
          final badges = find.descendant(
            of: cardFinder,
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_ComparisonBadge',
            ),
          );
          for (final badge in badges.evaluate()) {
            final badgeRect = tester.getRect(
              find.byElementPredicate((element) => identical(element, badge)),
            );
            expect(
              badgeRect.bottom,
              lessThanOrEqualTo(cardRect.bottom - 8),
              reason:
                  'Comparison badge must stay inside its card with bottom padding',
            );
            expect(badgeRect.left, greaterThanOrEqualTo(cardRect.left));
            expect(badgeRect.right, lessThanOrEqualTo(cardRect.right));
          }
        }
        if (width == 1142 && scenario.scale == 1.0) {
          final revenue = tester.getRect(
            find.textContaining('12.345.678.900').first,
          );
          final profit = tester.getRect(
            find.textContaining('2.456.789.000').first,
          );
          final cash = tester.getRect(
            find.textContaining('18.416.843.500').first,
          );
          expect(revenue.top, closeTo(profit.top, 2));
          expect(revenue.top, closeTo(cash.top, 2));
          expect(cash.left, greaterThan(profit.left));
          expect(find.text('Trợ lý'), findsOneWidget);
          expect(find.text('Thông báo'), findsOneWidget);
        }
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
            if (scenario.scale > 1.25) {
              expect(
                pair.$1 == '_DashboardChart' ? left.top : right.top,
                greaterThanOrEqualTo(
                  pair.$1 == '_DashboardChart' ? right.bottom : left.bottom,
                ),
                reason: 'Large text stacks full-width reading surfaces',
              );
              continue;
            }
            expect(left.top, closeTo(right.top, 1), reason: '${pair.$1} top');
            if (pair.$1 == '_DashboardChart') {
              // Both panels stay aligned; long action lists scroll inside.
              expect(left.height, lessThanOrEqualTo(440));
              expect(left.bottom, closeTo(right.bottom, 1));
              expect(right.left, greaterThan(left.right));
              continue;
            }
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
        if (const bool.fromEnvironment('CAPTURE_UI_V121') && width == 1142) {
          await expectLater(
            find.byKey(const ValueKey('dashboard-capture')),
            matchesGoldenFile(
              '../../BA_DOCUMENTS/TEST_RUNS/run_20261021_ui_redesign_v121/widget-previews/dashboard-1142.png',
            ),
          );
          showFeatureGuide(
            tester.element(find.byType(DashboardScreen)),
            'dashboard',
          );
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(const ValueKey('dashboard-capture')),
            matchesGoldenFile(
              '../../BA_DOCUMENTS/TEST_RUNS/run_20261021_ui_redesign_v121/widget-previews/dashboard-guide-1142.png',
            ),
          );
        }
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

  testWidgets(
    'Dashboard equal height row expands when action provider resolves with long list',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final completer = Completer<DashboardActionData>();

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
      addTearDown(() {
        FlutterError.onError = originalErrorHandler;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(_Shop.new),
            salesSummaryProvider.overrideWith((ref, period) async => {}),
            cashSummaryProvider.overrideWith((ref, period) async => {}),
            inventoryCategoriesSummaryProvider.overrideWith((ref) async => []),
            lowStockProvider.overrideWith((ref) async => []),
            recentTransactionsProvider.overrideWith((_) async => []),
            topProductsProvider.overrideWith((ref, period) async => []),
            dashboardActionProvider.overrideWith((_) => completer.future),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(AppColors.primary),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            routerConfig: router,
          ),
        ),
      );

      await tester.pump();

      completer.complete(
        DashboardActionData(
          asOf: DateTime(2026, 9, 9),
          items: List.generate(
            4,
            (index) => DashboardActionItem(
              actionKey: 'TEST_$index',
              severity: DashboardActionSeverity.warning,
              priorityScore: 10,
              title:
                  'Action $index Title That Is Extremely Long And Will Definitely Wrap To Multiple Lines When Rendered',
              detail:
                  'Action $index Detail That Is Also Extremely Long And Explains Why This Needs Fixing Quickly',
              badge: 'Warning',
            ),
          ),
          healthySummary: [
            DashboardActionItem(
              actionKey: 'HEALTHY',
              severity: DashboardActionSeverity.healthy,
              priorityScore: 0,
              title: 'Tất cả các chức năng khác hoạt động bình thường',
              detail: 'Không có cảnh báo mới',
              badge: 'OK',
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      Rect surface(String type) {
        final widgets = find
            .byWidgetPredicate((w) => w.runtimeType.toString() == type)
            .evaluate();
        expect(widgets, isNotEmpty, reason: 'Expected to find $type');
        final owner = widgets.first;
        final decorated = find
            .descendant(
              of: find.byWidgetPredicate((w) => w == owner.widget),
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration is BoxDecoration,
              ),
            )
            .first;
        return tester.getRect(decorated);
      }

      final priority = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'DashboardPriorityList',
      );
      await tester.ensureVisible(priority);
      await tester.drag(
        find.descendant(of: priority, matching: find.byType(ListView)),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      final rightCard = surface('DashboardPriorityList');
      final lastActionText = tester.getRect(
        find
            .text(
              'Action 3 Title That Is Extremely Long And Will Definitely Wrap To Multiple Lines When Rendered',
            )
            .first,
      );
      final footerText = tester.getRect(
        find.text('Tất cả các chức năng khác hoạt động bình thường').first,
      );

      expect(lastActionText.bottom, lessThanOrEqualTo(rightCard.bottom));
      expect(footerText.bottom, lessThanOrEqualTo(rightCard.bottom));

      final nextRowCard = surface('DashboardSalesPerformanceCard');
      expect(rightCard.bottom, lessThanOrEqualTo(nextRowCard.top));

      final layoutError = tester.takeException();
      if (layoutError is FlutterError) {
        debugPrint(layoutError.toString(minLevel: DiagnosticLevel.info));
      }
      expect(layoutError, isNull);
    },
  );
}
