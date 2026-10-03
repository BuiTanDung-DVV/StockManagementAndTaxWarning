import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:flutter_app/features/auth/presentation/login_screen.dart';
import 'package:flutter_app/features/auth/presentation/onboarding_screen.dart';
import 'package:flutter_app/features/auth/presentation/otp_verification_screen.dart';
import 'package:flutter_app/features/auth/presentation/register_screen.dart';
import 'package:flutter_app/features/auth/presentation/waiting_approval_screen.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_auth/screenshots';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary =
      tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final path = '$_runDir/$fileName';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _initial;
  _FakeShopNotifier(this._initial);

  @override
  ShopState build() => _initial;

  @override
  Future<void> loadUserShops() async {}
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    return {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    return {'success': true};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
    SharedPreferences.setMockInitialValues({});
  });

  const fakeShopState = ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
    memberType: 'OWNER',
    status: 'ACTIVE',
  );

  const fakeAuthState = AuthState(isLoggedIn: false);

  group('Auth Visual Audit', () {
    testWidgets('01_login_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('login_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsWidgets);
      await _capture(tester, key, '01_login_desktop.png');
    });

    testWidgets('02_login_mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('login_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsWidgets);
      await _capture(tester, key, '02_login_mobile.png');
    });

    testWidgets('03_register_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('register_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: RegisterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tạo tài khoản mới'), findsWidgets);
      await _capture(tester, key, '03_register_desktop.png');
    });

    testWidgets('04_register_mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('register_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: RegisterScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tạo tài khoản mới'), findsWidgets);
      await _capture(tester, key, '04_register_mobile.png');
    });

    testWidgets('05_forgot_password_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('forgot_password_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ForgotPasswordScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu?'), findsWidgets);
      await _capture(tester, key, '05_forgot_password_desktop.png');
    });

    testWidgets('06_otp_verification_mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('otp_verification_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: OtpVerificationScreen(
                email: 'admin@smartstock.vn',
                fullName: 'Nguyễn Văn Chủ',
                password: 'Password@2026',
                accountType: 'SHOP',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xác thực tài khoản'), findsWidgets);
      await _capture(tester, key, '06_otp_verification_mobile.png');
    });

    testWidgets('07_onboarding_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('onboarding_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  isLoggedIn: true,
                  isOnboarded: false,
                  user: {
                    'id': 1,
                    'fullName': 'Nguyễn Văn Chủ',
                    'username': 'chunv',
                    'accountType': 'SHOP',
                  },
                ),
              ),
            ),
            shopProvider.overrideWith(
              () => _FakeShopNotifier(
                const ShopState(isLoading: false, currentShopId: null),
              ),
            ),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: OnboardingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      await _capture(tester, key, '07_onboarding_desktop.png');
    });

    testWidgets('08_waiting_approval_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('waiting_approval_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  isLoggedIn: true,
                  isOnboarded: true,
                  user: {
                    'id': 2,
                    'fullName': 'Trần Văn Nhân Viên',
                    'username': 'nhanvientv',
                    'accountType': 'PERSONAL',
                  },
                ),
              ),
            ),
            shopProvider.overrideWith(
              () => _FakeShopNotifier(
                const ShopState(isLoading: false, status: 'PENDING'),
              ),
            ),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: WaitingApprovalScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đang chờ duyệt'), findsWidgets);
      await _capture(tester, key, '08_waiting_approval_desktop.png');
    });
  });
}
