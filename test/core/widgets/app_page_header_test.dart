import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/widgets/app_page_header.dart';
import 'package:flutter_app/core/theme/app_theme.dart';

import '../../support/load_ui_fonts.dart';

void main() {
  setUpAll(loadUiFonts);
  for (final scenario in [
    (320.0, 1.5),
    (390.0, 1.0),
    (640.0, 1.0),
    (704.0, 1.0),
    (830.0, 1.0),
    (880.0, 1.0),
    (1280.0, 1.0),
  ]) {
    testWidgets('heading and actions fit ${scenario.$1} at ${scenario.$2}x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scenario.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var activated = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AppPageHeader(
                title: 'Danh mục sản phẩm',
                subtitle: 'Tra cứu hàng hóa và kiểm tra số còn tồn.',
                action: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Hướng dẫn'),
                    ),
                    FilledButton(
                      onPressed: () => activated = true,
                      child: const Text('Thêm sản phẩm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Danh mục sản phẩm'));
      final action = tester.getRect(
        find.widgetWithText(FilledButton, 'Thêm sản phẩm'),
      );
      expect(title.right, lessThanOrEqualTo(scenario.$1 - 16));
      expect(action.right, lessThanOrEqualTo(scenario.$1 - 16));
      expect(title.overlaps(action), isFalse);
      if (scenario.$1 >= 640 && scenario.$2 == 1) {
        expect(
          (title.top - action.top).abs(),
          lessThan(8),
          reason:
              'Keep heading and actions together when the medium width fits',
        );
      }
      await tester.tap(find.text('Thêm sản phẩm'));
      expect(activated, isTrue);
    });
  }
  group('shouldShowPageBackButton', () {
    test('hiện ở màn phụ mở trực tiếp dù không có lịch sử', () {
      expect(
        shouldShowPageBackButton(location: '/products', canPop: false),
        isTrue,
      );
    });

    test('ẩn ở các tab chính dù còn lịch sử', () {
      for (final route in const [
        '/',
        '/sales',
        '/inventory',
        '/finance',
        '/settings',
      ]) {
        expect(
          shouldShowPageBackButton(location: route, canPop: true),
          isFalse,
          reason: route,
        );
      }
    });

    test('hiện ở màn phụ khi có lịch sử điều hướng', () {
      for (final route in const [
        '/products',
        '/customers',
        '/debt-aging',
        '/transactions',
      ]) {
        expect(
          shouldShowPageBackButton(location: route, canPop: true),
          isTrue,
          reason: route,
        );
      }
    });
  });
}
