import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_insights_widgets.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final width in [390.0, 660.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('insights visual width $width text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final panels = <String, Widget>{
          'sales': const DashboardSalesPerformanceCard(
            currentLabel: 'Tháng 9/2026',
            previousLabel: 'Tháng 8/2026',
            currentSales: AsyncData({
              'netSalesRevenue': 12345678900,
              'totalCogs': 9888889900,
              'grossProfit': 2456789000,
              'orderCount': 1234,
            }),
            comparisonSales: AsyncData({
              'netSalesRevenue': 13456789000,
              'totalCogs': 10000000000,
              'grossProfit': 3456789000,
              'orderCount': 1500,
            }),
          ),
          'cash': DashboardCashFlowCard(
            currentLabel: 'Tháng 9/2026',
            cashAsync: AsyncData({
              'income': 21000000000,
              'expense': 8400000000,
              'netCashFlow': 12600000000,
              'dailyFlow': List.generate(
                7,
                (i) => {
                  'date': '2026-09-0${i + 1}',
                  'income': 3000000000,
                  'expense': 1200000000,
                },
              ),
            }),
          ),
          'categories': DashboardInventoryCategoryCard(
            categoriesAsync: AsyncData(
              List.generate(
                7,
                (i) => {
                  'name':
                      '${i + 1}. Thiết bị vệ sinh và vật tư xây dựng cao cấp nhập khẩu',
                  'skuCount': 12 + i,
                  'value': (7 - i) * 1200000000,
                },
              ),
            ),
          ),
          'stock': DashboardLowStockCard(
            isAllShops: true,
            lowStockAsync: AsyncData(
              List.generate(
                5,
                (i) => {
                  'id': i + 1,
                  'shopId': i + 1,
                  'productId': i + 1,
                  'currentQuantity': i - 2,
                  'minStock': 20,
                  'product': {
                    'id': i + 1,
                    'name':
                        'Sơn ngoại thất bền màu cao cấp chống thấm đặc biệt',
                    'sku': 'SON-NGOAI-THAT-00${i + 1}',
                    'unit': i.isEven ? 'Thùng' : 'Bao',
                    'minStock': 20,
                  },
                },
              ),
            ),
          ),
        };
        for (final entry in panels.entries) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 2400),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(
                      key: ValueKey(entry.key),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: entry.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} $width $scale',
          );
          if (const bool.fromEnvironment('CAPTURE_UI')) {
            await expectLater(
              find.byKey(ValueKey(entry.key)),
              matchesGoldenFile(
                '../../BA_DOCUMENTS/dashboard-insights-screenshots/${entry.key}-${width.toInt()}-$scale.png',
              ),
            );
          }
        }
      });
    }
  }
}
