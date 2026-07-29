import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/filter_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter button is hidden when quick filters are shown elsewhere', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: SizedBox(
            width: 648,
            child: FilterBar(
              searchHint: 'Tìm sản phẩm theo tên, SKU...',
              onSearchChanged: (_) {},
              dense: true,
              showSearchIcon: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bộ lọc'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
