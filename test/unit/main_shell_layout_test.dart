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

  test('keeps two-item aggregate navigation intentionally compact', () {
    expect(mobileNavigationItemWidth(540, 2), 190);
    expect(mobileNavigationItemWidth(320, 2), 152);
    expect(mobileNavigationItemWidth(540, 5), closeTo(104.8, 0.01));
  });

  test('hides AI assistant on POS and QR payment flows', () {
    expect(shouldShowAiAssistant(location: '/', viewportWidth: 390), isTrue);
    expect(
      shouldShowAiAssistant(location: '/pos', viewportWidth: 390),
      isFalse,
    );
    expect(
      shouldShowAiAssistant(location: '/pos/checkout', viewportWidth: 799),
      isFalse,
    );
    expect(
      shouldShowAiAssistant(location: '/pos', viewportWidth: 800),
      isFalse,
    );
    expect(
      shouldShowAiAssistant(location: '/qr-payment', viewportWidth: 1440),
      isFalse,
    );
  });

  test('shows the shared utility header only on top-level workspaces', () {
    expect(shouldShowShellUtilityHeader('/'), isTrue);
    expect(shouldShowShellUtilityHeader('/sales'), isTrue);
    expect(shouldShowShellUtilityHeader('/customer-debts'), isTrue);
    expect(shouldShowShellUtilityHeader('/settings'), isTrue);
    expect(shouldShowShellUtilityHeader('/pos'), isFalse);
    expect(shouldShowShellUtilityHeader('/products/42'), isFalse);
  });

  test('shows shop QR only for a specific shop', () {
    expect(shouldShowShopPaymentQr(isAllShops: false), isTrue);
    expect(shouldShowShopPaymentQr(isAllShops: true), isFalse);
  });
}
