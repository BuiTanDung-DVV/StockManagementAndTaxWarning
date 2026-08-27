import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    return <String, dynamic>{'success': true};
  }
}

Widget _testApp() {
  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(_FakeApiClient())],
    child: MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      home: const ForgotPasswordScreen(),
    ),
  );
}

void main() {
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
