import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/app_page_header.dart';

void main() {
  group('shouldShowPageBackButton', () {
    test('ẩn khi không có lịch sử điều hướng', () {
      expect(
        shouldShowPageBackButton(location: '/products', canPop: false),
        isFalse,
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
