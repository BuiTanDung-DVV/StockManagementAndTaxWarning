import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/sales/presentation/sales_list_screen.dart';
import 'package:flutter_app/features/sales/providers/sales_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(390, 844), Size(1280, 900)]) {
    testWidgets('sales return insights fit ${size.width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesListProvider.overrideWith((ref, args) async => _orders),
            salesSummaryProvider.overrideWith((ref, args) async => _summary),
            paymentSummaryProvider.overrideWith((ref, args) async => _payments),
            topReturnedProductsProvider.overrideWith(
              (ref, args) async => _returns,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const SalesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final returnMetric = find.textContaining(
        'Tỷ lệ hàng trả',
        skipOffstage: false,
      );
      final returnPanel = find.text(
        'Sản phẩm bị trả nhiều',
        skipOffstage: false,
      );
      expect(returnMetric, findsOneWidget);
      await tester.ensureVisible(returnMetric);
      await tester.pumpAndSettle();
      expect(find.text('1,25%', skipOffstage: false), findsOneWidget);
      expect(returnPanel, findsOneWidget);
      await tester.ensureVisible(returnPanel);
      await tester.pumpAndSettle();
      expect(
        find.text('Đá 1x2 · Tân Việt Chuyên dụng', skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

const _summary = <String, dynamic>{
  'orderCount': 20,
  'netSalesRevenue': 100000000,
  'grossProfit': 22000000,
  'returnNetSalesRevenue': 1250000,
  'returnRatePct': 1.25,
  'daily': [
    {'date': '2026-08-07', 'revenue': 12000000},
    {'date': '2026-08-08', 'revenue': 13000000},
    {'date': '2026-08-09', 'revenue': 14000000},
    {'date': '2026-08-10', 'revenue': 15000000},
    {'date': '2026-08-11', 'revenue': 16000000},
    {'date': '2026-08-12', 'revenue': 14000000},
    {'date': '2026-08-13', 'revenue': 16000000},
  ],
};

const _payments = <dynamic>[
  {'method': 'CASH', 'count': 12, 'total': 60000000},
  {'method': 'BANK_TRANSFER', 'count': 8, 'total': 40000000},
];

const _returns = <dynamic>[
  {
    'id': 3080,
    'name': 'Đá 1x2 · Tân Việt Chuyên dụng',
    'unit': 'm³',
    'returnCount': 2,
    'quantity': 8,
    'value': 2424000,
    'latestReason': 'Hoàn lại hàng nguyên vẹn',
  },
];

const _orders = <String, dynamic>{
  'items': [
    {
      'id': 1,
      'orderCode': 'SO-001',
      'status': 'COMPLETED',
      'totalAmount': 5000000,
      'paidAmount': 5000000,
      'customer': {'name': 'Công ty Kiến Tạo'},
    },
  ],
  'page': 1,
  'totalPages': 1,
  'total': 1,
};
