import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web shell reports the real mobile viewport to Flutter', () {
    final source = File('web/index.html').readAsStringSync();
    final viewportTags = RegExp(
      '<meta[^>]+name="viewport"[^>]*>',
    ).allMatches(source).map((match) => match.group(0)!).toList();

    expect(viewportTags, hasLength(1));
    expect(viewportTags.single, contains('width=device-width'));
    expect(viewportTags.single, contains('initial-scale=1.0'));
  });
}
