import 'package:flutter/material.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_pagination_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pagination values accept numeric API fields and safe fallbacks', () {
    expect(paginationValue({'page': 3}, 'page', fallback: 1), 3);
    expect(paginationValue({'page': '4'}, 'page', fallback: 1), 4);
    expect(paginationValue({}, 'totalPages', fallback: 1), 1);
  });

  testWidgets('pagination enables only valid navigation directions', (
    tester,
  ) async {
    final selectedPages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: AppPaginationBar(
            currentPage: 2,
            totalPages: 3,
            totalItems: 45,
            itemLabel: 'bản ghi',
            onPageChanged: selectedPages.add,
          ),
        ),
      ),
    );

    expect(find.text('45 bản ghi · Trang 2/3'), findsOneWidget);
    await tester.tap(find.text('Trước'));
    await tester.tap(find.text('Sau'));
    expect(selectedPages, [1, 3]);
  });

  testWidgets('compact catalog footer hides useless one-page controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pages = <int>[];
    Future<void> show(int pageCount) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(
          body: AppPaginationBar(
            currentPage: 1,
            totalPages: pageCount,
            totalItems: 21,
            itemLabel: 'sản phẩm',
            compactNavigation: true,
            onPageChanged: pages.add,
          ),
        ),
      ),
    );
    await show(1);
    expect(find.byType(IconButton), findsNothing);
    await show(2);
    expect(find.byTooltip('Trang trước'), findsOneWidget);
    await tester.tap(find.byTooltip('Trang sau'));
    expect(pages, [2]);
    expect(tester.takeException(), isNull);
  });
}
