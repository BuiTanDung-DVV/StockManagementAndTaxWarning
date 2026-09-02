import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/utils/reporting_period.dart';
import 'package:flutter_app/core/widgets/reporting_period_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final selection = ReportingPeriodSelection(
    periodType: ReportingPeriodType.month,
    anchorDate: DateTime(2026, 8, 26),
    comparisonType: ReportingComparisonType.previousPeriod,
  );

  Widget app({required double width, VoidCallback? onOpen}) => MaterialApp(
    theme: AppTheme.lightTheme(AppColors.primary),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ReportingPeriodControl(
            selection: selection,
            currentLabel: '01/08–26/08/2026',
            comparisonLabel: '01/07–26/07/2026',
            onQuickPeriodChanged: (_) {},
            onOpenEditor: onOpen ?? () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('desktop shows only the three frequent quick periods', (
    tester,
  ) async {
    await tester.pumpWidget(app(width: 900));

    expect(find.text('Tháng'), findsOneWidget);
    expect(find.text('Quý'), findsOneWidget);
    expect(find.text('Năm'), findsOneWidget);
    expect(find.text('Ngày'), findsNothing);
    expect(find.text('Tuần'), findsNothing);
    expect(find.text('Tùy chỉnh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile uses one compact summary row', (tester) async {
    var opened = false;
    await tester.pumpWidget(app(width: 390, onOpen: () => opened = true));

    expect(
      find.text(
        '${reportingPeriodSelectionLabel(selection, DateTime.now())} · Kỳ trước',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('01/08–26/08/2026'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reporting-period-mobile-summary')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('reporting-period-mobile-summary')),
    );
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom comparison opens with both previous-period boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showReportingPeriodEditor(
                context,
                selection: selection,
                today: DateTime(2026, 8, 26),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-comparison-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tự chọn').last);
    await tester.pumpAndSettle();

    expect(find.text('01/07/2026'), findsOneWidget);
    expect(find.text('26/07/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
