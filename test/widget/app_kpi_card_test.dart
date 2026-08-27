import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_ui_components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('actionable KPI card responds to a full-card tap', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 100,
            child: AppKpiCard(
              title: 'Doanh thu',
              value: '10.000.000 ₫',
              color: AppColors.success,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppKpiCard));
    await tester.pump();

    expect(taps, 1);
    expect(find.byType(InkWell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
