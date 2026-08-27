import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/app_shimmer.dart';
import 'package:flutter_app/core/theme/app_theme.dart';

void main() {
  testWidgets('scrollable shimmer list does not overflow a short viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: const Scaffold(
          body: SizedBox(
            height: 260,
            child: ShimmerList(
              scrollable: true,
              padding: EdgeInsets.only(bottom: 112),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.byType(ShimmerListTile), findsWidgets);
  });
}
