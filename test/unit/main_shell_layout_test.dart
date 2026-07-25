import 'package:flutter_app/features/shell/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AI assistant is hidden on mobile POS to keep checkout unobstructed',
    () {
      expect(
        shouldShowAiAssistant(location: '/pos', viewportWidth: 390),
        isFalse,
      );
      expect(
        shouldShowAiAssistant(location: '/pos/checkout', viewportWidth: 799),
        isFalse,
      );
    },
  );

  test('AI assistant remains available outside mobile POS', () {
    expect(
      shouldShowAiAssistant(location: '/sales', viewportWidth: 390),
      isTrue,
    );
    expect(
      shouldShowAiAssistant(location: '/pos', viewportWidth: 1200),
      isTrue,
    );
  });
}
