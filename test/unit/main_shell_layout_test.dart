import 'package:flutter_app/features/shell/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses bottom navigation on compact viewports', () {
    expect(navigationModeForWidth(390), MainShellNavigationMode.bottomBar);
    expect(navigationModeForWidth(799), MainShellNavigationMode.bottomBar);
  });

  test('uses navigation rail on medium viewports', () {
    expect(navigationModeForWidth(800), MainShellNavigationMode.rail);
    expect(navigationModeForWidth(1099), MainShellNavigationMode.rail);
  });

  test('uses sidebar on expanded viewports', () {
    expect(navigationModeForWidth(1100), MainShellNavigationMode.sidebar);
    expect(navigationModeForWidth(1440), MainShellNavigationMode.sidebar);
  });

  test('shows AI assistant except on mobile POS', () {
    expect(shouldShowAiAssistant(location: '/', viewportWidth: 390), isTrue);
    expect(
      shouldShowAiAssistant(location: '/pos', viewportWidth: 390),
      isFalse,
    );
    expect(
      shouldShowAiAssistant(location: '/pos/checkout', viewportWidth: 799),
      isFalse,
    );
    expect(shouldShowAiAssistant(location: '/pos', viewportWidth: 800), isTrue);
  });
}
