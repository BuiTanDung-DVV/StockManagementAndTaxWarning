import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_navigation_back_button.dart';
import 'package:flutter_app/features/inventory/providers/inventory_provider.dart';
import 'package:flutter_app/features/products/presentation/product_detail_screen.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('product load failure uses a user-facing message and keeps back', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productDetailProvider.overrideWith(
            (ref, id) => Future<Map<String, dynamic>>.error(
              Exception('Product not found'),
            ),
          ),
          inventoryMovementsProvider.overrideWith(
            (ref, args) => Future<Map<String, dynamic>>.value({
              'items': <dynamic>[],
              'total': 0,
              'page': 1,
              'totalPages': 1,
            }),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const ProductDetailScreen(id: 999999),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppNavigationBackButton), findsOneWidget);
    expect(
      find.textContaining('Không thể tải thông tin sản phẩm.'),
      findsOneWidget,
    );
    expect(find.text('Quay lại danh sách'), findsOneWidget);
    expect(find.textContaining('Product not found'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
