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

  testWidgets(
    'auth screens support enlarged text on narrow viewport and desktop',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final targets = [
        const LoginScreen(),
        const RegisterScreen(),
        const ForgotPasswordScreen(),
      ];

      for (final size in [const Size(390, 844), const Size(960, 900)]) {
        await tester.binding.setSurfaceSize(size);
        for (final screen in targets) {
          await tester.pumpWidget(_app(screen, dark: true));
          await tester.pumpAndSettle();

          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            final textButton = find.byType(TextButton).last;
            if (textButton.evaluate().isNotEmpty) {
              await tester.scrollUntilVisible(
                textButton,
                100,
                scrollable: scrollable.first,
              );
            }
          }

          // Assert floating label behavior is always
          final textField = find.byType(TextField).first;
          if (textField.evaluate().isNotEmpty) {
            final theme = Theme.of(tester.element(textField));
            expect(
              theme.inputDecorationTheme.floatingLabelBehavior,
              FloatingLabelBehavior.always,
            );
          }

          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
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
    final submit = find.widgetWithText(FilledButton, 'Đăng ký và nhận mã');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Check new divider text
    expect(find.text('hoặc đăng ký bằng mật khẩu'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Kiểm tra giao diện');
    await tester.enterText(fields.at(1), 'ui-test@gmail.com');

    // Test password disclosure focus
    expect(
      find.text(
        'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Từ 8 ký tự'),
      findsNothing,
    ); // Detailed criteria should be hidden initially

    await tester.tap(fields.at(2)); // Focus password
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Mật khẩu cần ít nhất 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
      ),
      findsNothing,
    );
    expect(find.text('Chưa nhập'), findsOneWidget);
    expect(
      find.text('Từ 8 ký tự'),
      findsOneWidget,
    ); // Detailed criteria shown on focus

    // Test password 4/5 is not sufficient
    await tester.enterText(
      fields.at(2),
      'Password123',
    ); // No special char -> 4/5
    await tester.enterText(
      fields.at(3),
      'Password123',
    ); // Match confirm password
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.text('Khá mạnh'), findsOneWidget); // Score 4 label
    expect(find.text('Ký tự đặc biệt'), findsWidgets); // Unmet criteria visible

    // Test password 5/5
    await tester.enterText(fields.at(2), 'TestOnly@2026');
    await tester.pump();
    expect(
      find.text('Mật khẩu đạt yêu cầu'),
      findsOneWidget,
    ); // Replaces checklist
    expect(
      find.text('Ký tự đặc biệt'),
      findsNothing,
    ); // Criteria checklist hidden when 5/5

    await tester.enterText(fields.at(3), 'different');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.text('Mật khẩu xác nhận chưa khớp'), findsOneWidget);

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

  testWidgets(
    'auth screens geometric assertions (header stable, input/cta sizes, divider symmetry)',
    (tester) async {
      for (final width in [390.0, 768.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1.0;

        final Map<String, double> headerTops = {};

        final screensToTest = {
          'login': const LoginScreen(),
          'register': const RegisterScreen(),
          'forgot': const ForgotPasswordScreen(),
        };

        for (final entry in screensToTest.entries) {
          await tester.pumpWidget(_app(entry.value));
          await tester.pumpAndSettle();

          // 1. Stable header/card top
          final headerFinder = find.text('SmartStock');
          if (headerFinder.evaluate().isNotEmpty) {
            headerTops[entry.key] = tester.getTopLeft(headerFinder).dy;
          }

          // 2. Input and CTA same width, height and alignment
          final ctaFinder = find.byType(FilledButton);
          final inputFinders = find.byType(TextField);

          if (ctaFinder.evaluate().isNotEmpty &&
              inputFinders.evaluate().isNotEmpty) {
            final ctaRect = tester.getRect(ctaFinder.first);
            final inputRect = tester.getRect(inputFinders.first);

            // Trục trái / phải
            expect(inputRect.left, closeTo(ctaRect.left, 2.0));
            expect(inputRect.right, closeTo(ctaRect.right, 2.0));
            expect(inputRect.width, closeTo(ctaRect.width, 2.0));
            expect(ctaRect.height, greaterThanOrEqualTo(52.0));
            expect(inputRect.height, greaterThanOrEqualTo(52.0));
          }

          // 3. Divider symmetry (for login)
          if (entry.key == 'login') {
            final dividerFinder = find.byType(Divider);
            if (dividerFinder.evaluate().length >= 2) {
              final div1 = tester.getRect(dividerFinder.first);
              final div2 = tester.getRect(dividerFinder.last);
              expect(div1.width, closeTo(div2.width, 2.0));
            }
          }
        }

        // Check header top stability across 3 screens
        if (headerTops.length == 3) {
          expect(headerTops['login'], closeTo(headerTops['register']!, 2.0));
          expect(headerTops['login'], closeTo(headerTops['forgot']!, 2.0));
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  testWidgets('desktop common title-Y alignment across auth screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Map<String, double> titleTops = {};

    final screensToTest = {
      'login': const LoginScreen(),
      'register': const RegisterScreen(),
      'forgot': const ForgotPasswordScreen(),
    };

    for (final entry in screensToTest.entries) {
      await tester.pumpWidget(_app(entry.value));
      await tester.pumpAndSettle();

      Finder specificTitleFinder;
      if (entry.key == 'login') {
        specificTitleFinder = find.text('Đăng nhập').first;
      } else if (entry.key == 'register') {
        specificTitleFinder = find.text('Tạo tài khoản mới');
      } else {
        specificTitleFinder = find.text('Quên mật khẩu?');
      }
      titleTops[entry.key] = tester.getTopLeft(specificTitleFinder).dy;
    }

    expect(titleTops['login'], closeTo(titleTops['register']!, 1.0));
    expect(titleTops['login'], closeTo(titleTops['forgot']!, 1.0));
  });
}
