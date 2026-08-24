import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tax estimate never leaves an old report visible after API failure', () {
    final source = File(
      'lib/features/tax/screens/tax_estimate_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_reportData = null;'));
    expect(source, contains('_errorMessage ='));
    expect(source, contains('AppInlineError('));
    expect(source, contains('onRetry: _fetchEstimate'));
    expect(
      source,
      contains('Không thể tải báo cáo của kỳ đã chọn.'),
    );
  });
}
