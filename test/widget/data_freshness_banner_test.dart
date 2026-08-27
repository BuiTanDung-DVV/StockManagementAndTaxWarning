import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/utils/data_freshness.dart';
import 'package:flutter_app/core/widgets/data_freshness_banner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cảnh báo độ mới dữ liệu vừa màn hình mobile 390px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: DataFreshnessBanner(
              assessment: DataFreshnessAssessment(
                state: DataFreshnessState.unavailable,
                latestDate: null,
                daysBehind: 23,
              ),
              dataLabel: 'bán hàng',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Chưa thể kiểm tra'), findsOneWidget);
    expect(find.textContaining('Backend'), findsNothing);
    expect(find.textContaining('DB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('không chiếm chỗ khi dữ liệu đã cập nhật đủ kỳ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: const Scaffold(
          body: DataFreshnessBanner(
            assessment: DataFreshnessAssessment(
              state: DataFreshnessState.current,
              latestDate: null,
              daysBehind: 0,
            ),
            dataLabel: 'thu chi',
          ),
        ),
      ),
    );

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.textContaining('Dữ liệu'), findsNothing);
  });
}
