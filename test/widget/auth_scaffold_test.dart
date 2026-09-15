import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/auth_scaffold.dart';
import '../support/load_ui_fonts.dart';

Widget _buildTestApp({
  Widget? body,
  String? title,
  String? subtitle,
  bool canPop = false,
  VoidCallback? onPop,
  Widget? footer,
  double maxWidth = 460,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme(AppColors.primary),
    home: AuthScaffold(
      title: title ?? 'Đăng nhập tài khoản',
      subtitle:
          subtitle ?? 'Nhập thông tin xác thực để bắt đầu phiên làm việc.',
      canPop: canPop,
      onPop: onPop,
      footer: footer,
      maxWidth: maxWidth,
      body:
          body ??
          Column(
            children: [
              const TextField(decoration: InputDecoration(labelText: 'Email')),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(labelText: 'Mật khẩu'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () {}, child: const Text('Xác nhận')),
            ],
          ),
    ),
  );
}

void main() {
  setUpAll(loadUiFonts);
  testWidgets('renders mobile layout (390px) without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập tài khoản'), findsOneWidget);
    expect(
      find.text('Nhập thông tin xác thực để bắt đầu phiên làm việc.'),
      findsOneWidget,
    );
    expect(find.text('Xác nhận'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders tablet layout (768px) without overflow', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập tài khoản'), findsOneWidget);
    expect(find.text('Xác nhận'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders desktop dual-column layout (1440px) with brand panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(footer: const Text('Đã có tài khoản? Đăng nhập ngay')),
    );
    await tester.pumpAndSettle();

    // Brand panel visible on desktop
    expect(find.text('Quản lý cửa hàng, rõ từng con số.'), findsOneWidget);
    expect(find.text('Bán hàng và công nợ khách hàng'), findsOneWidget);

    // Form and footer visible
    expect(find.text('Đăng nhập tài khoản'), findsOneWidget);
    expect(find.text('Đã có tài khoản? Đăng nhập ngay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('triggers onPop callback when back button is tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var popped = false;
    await tester.pumpWidget(
      _buildTestApp(canPop: true, onPop: () => popped = true),
    );
    await tester.pumpAndSettle();

    final backButtonFinder = find.byTooltip('Quay lại');
    expect(backButtonFinder, findsOneWidget);
    await tester.tap(backButtonFinder);
    await tester.pumpAndSettle();

    expect(popped, isTrue);
  });
}
