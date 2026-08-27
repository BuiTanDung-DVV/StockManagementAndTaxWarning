import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/chart_widgets.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard treats an empty sales period as no activity', () {
    expect(
      dashboardHasSalesActivity(revenue: 0, grossProfit: 0, orderCount: 0),
      isFalse,
    );
    expect(
      dashboardHasSalesActivity(revenue: 1, grossProfit: 0, orderCount: 0),
      isTrue,
    );
  });

  test('dashboard month labels continue through the current year', () {
    final current = List.generate(
      7,
      (index) => {'date': '2026-${(index + 1).toString().padLeft(2, '0')}'},
    );
    final previous = List.generate(
      12,
      (index) => {'date': '2025-${(index + 1).toString().padLeft(2, '0')}'},
    );

    expect(dashboardChartPeriodLabel(current, previous, 0), '01/2026');
    expect(dashboardChartPeriodLabel(current, previous, 7), '08/2026');
    expect(dashboardChartPeriodLabel(current, previous, 11), '12/2026');
    expect(dashboardChartGroupWidth(current, previous, isMobile: true), 76);
  });

  testWidgets('top products reflows into readable mobile rows', (tester) async {
    final products = List.generate(
      10,
      (index) => {
        'id': index + 1,
        'name': 'Bồn cầu một khối mẫu ${index + 1} cho công trình',
        'unit': 'Bộ',
        'value': 60000000 - index * 2500000,
        'quantity': 20 - index,
        'previousValue': 30000000,
        'growthPct': 100 - index * 8.33,
        'growthStatus': 'COMPARABLE',
        'marginPct': 22.5,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: DashboardTopProductsRevenueChart(
              items: products,
              period: '01/03–13/08/2026',
              comparisonPeriod: '01/03–13/08/2025',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top sản phẩm bán chạy'), findsOneWidget);
    expect(find.textContaining('Bồn cầu một khối mẫu 1'), findsOneWidget);
    expect(find.text('20 Bộ'), findsOneWidget);
    expect(find.textContaining('▲'), findsWidgets);
    expect(find.text('Tăng trưởng so với 01/03–13/08/2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'top products display backend growth status without recalculation',
    (tester) async {
      final products = [
        {
          'id': 1,
          'name': 'Xi măng PCB40',
          'unit': 'Bao',
          'value': 15000000,
          'quantity': 120,
          'previousValue': 10000000,
          'growthPct': -12.5,
          'growthStatus': 'COMPARABLE',
          'marginPct': 18.2,
        },
        {
          'id': 2,
          'name': 'Sơn ngoại thất',
          'unit': 'Thùng',
          'value': 12000000,
          'quantity': 24,
          'previousValue': null,
          'growthPct': null,
          'growthStatus': 'NEW',
          'marginPct': 21.5,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: DashboardTopProductsRevenueChart(
                items: products,
                period: '01/08–20/08/2026',
                comparisonPeriod: '01/07–20/07/2026',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('▼ 12,5%'), findsOneWidget);
      expect(find.text('Mới'), findsOneWidget);
      expect(find.text('Tăng trưởng so với 01/07–20/07/2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty top products uses a compact full-width state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: const Scaffold(
          body: SizedBox(
            width: 620,
            child: DashboardTopProductsRevenueChart(
              items: [],
              period: '01/08–13/08/2026',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Chưa có doanh thu sản phẩm trong kỳ này.'),
      findsOneWidget,
    );
    final renderedHeight = tester
        .getSize(find.byType(DashboardTopProductsRevenueChart))
        .height;
    expect(renderedHeight, lessThanOrEqualTo(244));
    expect(renderedHeight, greaterThanOrEqualTo(220));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recent orders show business date without partial export action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: DashboardRecentOrdersList([
                {
                  'id': 101,
                  'orderCode': 'SO101',
                  'orderDate': '2026-08-20T02:30:00.000Z',
                  'totalAmount': 1250000,
                  'customer': {'name': 'Khách hàng Kiến Tạo'},
                },
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ngày giao dịch'), findsOneWidget);
      expect(find.text('20/08/2026'), findsOneWidget);
      expect(find.text('Xuất Excel'), findsNothing);
      expect(find.text('Xem tất cả'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard period filter remains complete and clickable', (
    tester,
  ) async {
    var selected = 'month';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TimeFilterBar(
              selected,
              (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('Tuần'), findsOneWidget);
    expect(find.text('Tháng'), findsOneWidget);
    expect(find.text('Quý'), findsOneWidget);
    expect(find.text('Năm'), findsOneWidget);

    await tester.tap(find.text('Quý'));
    await tester.pumpAndSettle();
    expect(selected, 'quarter');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard revenue chart exposes unit and horizontal scrolling', (
    tester,
  ) async {
    final current = List.generate(
      31,
      (index) => {
        'date': '2026-07-${(index + 1).toString().padLeft(2, '0')}',
        'revenue': (index + 1) * 1000000,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 620,
            child: ComparisonBarChart(
              current,
              current,
              'Tháng này',
              'Tháng trước',
              filterWidget: TimeFilterBar('month', (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đơn vị: đồng'), findsOneWidget);
    expect(find.text('01/07'), findsOneWidget);

    final horizontalScrollable = tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .where((widget) => widget.axisDirection == AxisDirection.right);
    expect(horizontalScrollable, isNotEmpty);

    final state = tester.state<ScrollableState>(
      find.byWidget(horizontalScrollable.first),
    );
    expect(state.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('comparison bars keep earlier period on the left', (
    tester,
  ) async {
    final current = [
      {'date': '2026-08-01', 'revenue': 20000000},
    ];
    final previous = [
      {'date': '2026-07-01', 'revenue': 10000000},
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ComparisonBarChart(
              current,
              previous,
              'Tháng 08/2026',
              'Tháng 07/2026',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rods = chart.data.barGroups.single.barRods;
    expect(rods[0].toY, 10000000);
    expect(rods[0].color, const Color(0xFF6F9FA3));
    expect(rods[1].toY, 20000000);
    expect(rods[1].color, AppColors.primary);
  });

  testWidgets('sales chart keeps revenue first and gross profit second', (
    tester,
  ) async {
    final revenueColor = AppColors.primary;
    final profitColor = AppColors.warning;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 280,
            child: MiniGroupedBarChart(
              primaryValues: [10000000, 8000000],
              secondaryValues: [2500000, -500000],
              labels: ['19/08', '20/08'],
              primaryLabel: 'Doanh thu thuần',
              secondaryLabel: 'Lợi nhuận gộp',
              primaryColor: revenueColor,
              secondaryColor: profitColor,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Doanh thu thuần'), findsOneWidget);
    expect(find.text('Lợi nhuận gộp'), findsOneWidget);
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(2));
    expect(chart.data.barGroups.first.barRods, hasLength(2));
    expect(chart.data.barGroups.first.barRods[0].toY, 10000000);
    expect(chart.data.barGroups.first.barRods[0].color, revenueColor);
    expect(chart.data.barGroups.first.barRods[1].toY, 2500000);
    expect(chart.data.barGroups.first.barRods[1].color, profitColor);
    expect(chart.data.minY, lessThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart explains when only the previous period has revenue', (
    tester,
  ) async {
    final current = [
      {'date': '2026-08-01', 'revenue': 0},
    ];
    final previous = [
      {'date': '2026-07-01', 'revenue': 10000000},
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ComparisonBarChart(
              current,
              previous,
              'Kỳ hiện tại',
              'Kỳ trước',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Kỳ hiện tại chưa có doanh thu; các cột đang hiển thị số liệu kỳ trước để đối chiếu.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
