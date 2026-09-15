import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/auth/presentation/login_screen.dart';
import 'package:flutter_app/features/auth/presentation/register_screen.dart';
import 'package:flutter_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:flutter_app/features/auth/presentation/otp_verification_screen.dart';
import 'package:flutter_app/features/auth/presentation/onboarding_screen.dart';
import 'package:flutter_app/features/auth/presentation/waiting_approval_screen.dart';
import '../support/load_ui_fonts.dart';

class _Auth extends AuthNotifier {
  _Auth({this.onboarded = true});
  final bool onboarded;
  @override
  AuthState build() => AuthState(isOnboarded: onboarded);
  @override
  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoggedIn: true);
    return true;
  }
}

class _Shop extends ShopNotifier {
  _Shop(this.pending);
  final bool pending;
  @override
  ShopState build() =>
      ShopState(isLoading: false, status: pending ? 'PENDING' : 'ACTIVE');
}

class _NoNetwork extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async =>
      throw ApiException('Offline test');
  @override
  Future<dynamic> post(String path, {dynamic data}) async =>
      throw ApiException('Offline test');
}

Widget _app(
  Widget screen, {
  bool dark = false,
  GoRouter? router,
  bool onboarded = true,
  bool pending = false,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _Auth(onboarded: onboarded)),
      shopProvider.overrideWith(() => _Shop(pending)),
      apiClientProvider.overrideWithValue(_NoNetwork()),
    ],
    child: router == null
        ? MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark
                ? AppTheme.darkTheme(const Color(0xFF0F766E))
                : AppTheme.lightTheme(const Color(0xFF0F766E)),
            builder: BotToastInit(),
            home: screen,
          )
        : MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(const Color(0xFF0F766E)),
            builder: BotToastInit(),
            routerConfig: router,
          ),
  );
}

void main() {
  setUpAll(loadUiFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final width in [390.0, 1440.0]) {
    for (final role in ['Chủ cửa hàng', 'Nhân viên']) {
      testWidgets('onboarding $role form at $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(const OnboardingScreen()));
        await tester.pumpAndSettle();
        for (var step = 0; step < 2; step++) {
          await tester.ensureVisible(find.text('Tiếp tục'));
          await tester.tap(find.text('Tiếp tục'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.text(role));
        await tester.tap(find.text(role));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Hoàn tất thông tin'));
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsWidgets);
      });
    }
  }
  testWidgets('registration scrolls with keyboard open', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(const RegisterScreen()));
    await tester.pumpAndSettle();
    final confirm = find.byType(TextField).last;
    await tester.ensureVisible(confirm);
    await tester.enterText(confirm, 'TestOnly@2026');
    await tester.pumpAndSettle();
    expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(400));
    expect(tester.takeException(), isNull);
  });
  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'forgot': const ForgotPasswordScreen(),
    'otp': const OtpVerificationScreen(
      email: 'test@example.invalid',
      fullName: 'Test',
      password: '',
      accountType: 'PERSONAL',
    ),
    'onboarding': const OnboardingScreen(),
    'waiting': const WaitingApprovalScreen(),
  };
  for (final entry in screens.entries) {
    for (final width in [390.0, 768.0, 960.0, 1440.0]) {
      testWidgets('${entry.key} has no layout exception at width $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture'),
            child: _app(entry.value),
          ),
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile(
              '../../BA_DOCUMENTS/UI_AUDIT/auth_home_redesign_2026-09-08/screenshots/${entry.key}-${width.toInt()}.png',
            ),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
  testWidgets('login dark theme supports enlarged text on narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(const LoginScreen(), dark: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits short desktop viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(entry.value));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
  testWidgets('registration keeps password validation and exposes API errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const RegisterScreen()));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Đăng ký & Nhận mã OTP');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Kiểm tra giao diện');
    await tester.enterText(fields.at(1), 'ui-test@gmail.com');
    await tester.enterText(fields.at(2), 'TestOnly@2026');
    await tester.enterText(fields.at(3), 'different');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(fields.at(3), 'TestOnly@2026');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.tap(find.byTooltip('Hiện mật khẩu').first);
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(2)).obscureText, isFalse);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Offline test'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  for (final flow in [
    (onboarded: true, pending: false, target: '/'),
    (onboarded: false, pending: false, target: '/onboarding'),
    (onboarded: true, pending: true, target: '/waiting-approval'),
  ]) {
    testWidgets('successful login navigates to ${flow.target}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
          for (final route in ['/', '/onboarding', '/waiting-approval'])
            GoRoute(
              path: route,
              builder: (_, _) => Scaffold(body: Text('Đích $route')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          const SizedBox.shrink(),
          router: router,
          onboarded: flow.onboarded,
          pending: flow.pending,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'ui-test');
      await tester.enterText(find.byType(TextField).last, 'test-input');
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Đích ${flow.target}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
