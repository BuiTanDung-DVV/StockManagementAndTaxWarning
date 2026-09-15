import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/load_ui_fonts.dart';

class _FakeApiClient extends ApiClient {
  final paths = <String>[];
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    paths.add(path);
    return <String, dynamic>{'success': true};
  }
}

Widget _testApp({_FakeApiClient? api}) {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api ?? _FakeApiClient())],
    child: MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      home: const ForgotPasswordScreen(),
    ),
  );
}

void main() {
  setUpAll(loadUiFonts);
  testWidgets('reset rejects mismatched password then shows success', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeApiClient();
    await tester.pumpWidget(_testApp(api: api));
    await tester.enterText(find.byType(TextField).first, 'ui-test@gmail.com');
    await tester.tap(find.text('Gửi Mã Xác Thực OTP'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'TestOnly@2026');
    await tester.enterText(fields.at(2), 'different');
    final submit = find.text('Xác Nhận Đặt Lại Mật Khẩu');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
    expect(api.paths.where((path) => path == '/auth/reset-password'), isEmpty);
    await tester.enterText(fields.at(2), 'TestOnly@2026');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Đặt lại thành công'), findsOneWidget);
    expect(find.text('Quay lại Đăng nhập'), findsOneWidget);
    expect(
      api.paths.where((path) => path == '/auth/reset-password'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('desktop hiển thị bố cục khôi phục hai vùng', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    expect(find.text('Khôi phục quyền truy cập an toàn.'), findsOneWidget);
    expect(find.text('Tìm tài khoản của bạn'), findsOneWidget);
    expect(find.textContaining('không xác nhận công khai Gmail'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('màn OTP dùng icon mắt và cho phép đổi Gmail', (tester) async {
    tester.view.physicalSize = const Size(1100, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.enterText(
      find.byType(TextField).first,
      'registered.user@gmail.com',
    );
    await tester.tap(find.text('Gửi Mã Xác Thực OTP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Dùng Gmail khác'), findsOneWidget);
    expect(find.byTooltip('Hiện mật khẩu'), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_off_rounded), findsNWidgets(2));

    await tester.tap(find.byTooltip('Hiện mật khẩu').first);
    await tester.pump();
    expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);

    await tester.tap(find.text('Dùng Gmail khác'));
    await tester.pump();
    expect(find.text('Tìm tài khoản của bạn'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
