import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });

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

    expect(find.text('Tuần này'), findsOneWidget);
    expect(find.text('Tháng này'), findsOneWidget);
    expect(find.text('6 tháng'), findsOneWidget);
    expect(find.text('Năm nay'), findsOneWidget);

    await tester.tap(find.text('6 tháng'));
    await tester.pumpAndSettle();
    expect(selected, '6_months');
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
}
