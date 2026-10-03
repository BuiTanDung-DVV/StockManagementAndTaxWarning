import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/presentation/login_screen.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

class _MockShopNotifier extends ShopNotifier {
  @override
  ShopState build() => const ShopState();

  @override
  Future<void> loadUserShops() async {}
}

class _MockAuthNotifier extends AuthNotifier {
  int loginCalls = 0;
  String? lastUsername;
  String? lastPassword;
  bool _mockManualLogout = false;

  void simulateManualLogout() {
    _mockManualLogout = true;
  }

  @override
  bool get wasManualLogout => _mockManualLogout;

  @override
  void clearManualLogout() {
    _mockManualLogout = false;
  }

  @override
  AuthState build() => const AuthState();

  @override
  Future<bool> login(String username, String password) async {
    loginCalls++;
    lastUsername = username;
    lastPassword = password;
    return true;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'LoginScreen renders remember me checkbox symmetrically with forgot password',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            shopProvider.overrideWith(() => _MockShopNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: LoginScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Ghi nhớ đăng nhập'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Tap on the text to toggle checkbox
      await tester.tap(find.text('Ghi nhớ đăng nhập'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final checkboxAfter = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxAfter.value, isTrue);
    },
  );

  testWidgets(
    'LoginScreen prefills credentials and auto-logins when remembered',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_remember_login': true,
        'auth_saved_username': 'admin@kientao.com',
        'auth_saved_password': 'mypassword123',
      });

      final mockAuth = _MockAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuth),
            shopProvider.overrideWith(() => _MockShopNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: LoginScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify fields are prefilled
      expect(find.text('admin@kientao.com'), findsOneWidget);
      expect(find.text('mypassword123'), findsOneWidget);

      // Checkbox should be checked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // Auto-login should have been triggered
      expect(mockAuth.loginCalls, equals(1));
      expect(mockAuth.lastUsername, equals('admin@kientao.com'));
      expect(mockAuth.lastPassword, equals('mypassword123'));
    },
  );

  testWidgets(
    'LoginScreen does not auto-login immediately after manual logout',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_remember_login': true,
        'auth_saved_username': 'admin@kientao.com',
        'auth_saved_password': 'mypassword123',
      });

      final mockAuth = _MockAuthNotifier();
      mockAuth.simulateManualLogout();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuth),
            shopProvider.overrideWith(() => _MockShopNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const Scaffold(body: LoginScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fields are still prefilled and checkbox is checked
      expect(find.text('admin@kientao.com'), findsOneWidget);
      expect(find.text('mypassword123'), findsOneWidget);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // But auto-login was NOT triggered because user just logged out
      expect(mockAuth.loginCalls, equals(0));
      // Flag should have been reset for next session
      expect(mockAuth.wasManualLogout, isFalse);
    },
  );
}
