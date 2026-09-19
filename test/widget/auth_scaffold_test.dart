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
  bool compactAuthLayout = false,
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
      compactAuthLayout: compactAuthLayout,
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

  testWidgets(
    'triggers onPop callback when back button is tapped and has 48x48 area',
    (tester) async {
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

      // Check hit test area is at least 48x48
      final buttonSize = tester.getSize(
        find
            .ancestor(of: backButtonFinder, matching: find.byType(SizedBox))
            .first,
      );
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      // Verify brand is in a Stack to keep it centered
      final stackFinder = find.descendant(
        of: find.byType(SafeArea),
        matching: find.byType(Stack),
      );
      expect(stackFinder, findsOneWidget);

      // Stack should occupy full width to avoid overlap
      final stackSize = tester.getSize(stackFinder);
      expect(
        stackSize.width,
        greaterThanOrEqualTo(300.0),
      ); // Close to full width

      // Verify exact center alignment
      final textFinder = find.text('SmartStock');
      final rowFinder = find
          .ancestor(of: textFinder, matching: find.byType(Row))
          .first;
      final rowCenter = tester.getCenter(rowFinder).dx;
      expect(rowCenter, closeTo(390.0 / 2, 1.0));

      // Verify no intersection and button is on the left
      final buttonRect = tester.getRect(backButtonFinder);
      final rowRect = tester.getRect(rowFinder);
      expect(buttonRect.overlaps(rowRect), isFalse);
      expect(buttonRect.center.dx, lessThan(100.0)); // Near the left edge

      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    },
  );

  testWidgets('renders compact layout successfully and provides input border', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(compactAuthLayout: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final theme = Theme.of(tester.element(find.byType(TextField).first));
    expect(theme.inputDecorationTheme.enabledBorder, isNotNull);
    final enabledBorder =
        theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(enabledBorder.borderSide.color, const Color(0xFF64748B));
  });

  testWidgets('preserves outer theme when compactAuthLayout is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(Colors.purple),
        home: const AuthScaffold(
          compactAuthLayout: false,
          body: TextField(decoration: InputDecoration(labelText: 'Email')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(TextField)));
    expect(theme.colorScheme.primary, Colors.purple);
  });

  testWidgets(
    'renders unified card on desktop compact and gradient on mobile compact',
    (tester) async {
      // 1. Test Mobile Compact (390x844)
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_buildTestApp(compactAuthLayout: true));
      await tester.pumpAndSettle();

      final mobileBgFinder = find.byKey(const Key('mobile_compact_background'));
      expect(mobileBgFinder, findsOneWidget);

      // Background should not be the same as standard surface
      final Container mobileBg = tester.widget<Container>(mobileBgFinder);
      expect(mobileBg.decoration, isA<BoxDecoration>());
      final BoxDecoration bgDecoration = mobileBg.decoration as BoxDecoration;
      expect(bgDecoration.gradient, isNotNull);

      expect(tester.takeException(), isNull);

      // 2. Test Desktop Compact (1440x900)
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(_buildTestApp(compactAuthLayout: true));
      await tester.pumpAndSettle();

      final unifiedCardFinder = find.byKey(const Key('unified_desktop_card'));
      final brandRegionFinder = find.byKey(const Key('unified_brand_region'));
      final formRegionFinder = find.byKey(const Key('unified_form_region'));

      expect(unifiedCardFinder, findsOneWidget);
      expect(brandRegionFinder, findsOneWidget);
      expect(formRegionFinder, findsOneWidget);

      final brandRect = tester.getRect(brandRegionFinder);
      final formRect = tester.getRect(formRegionFinder);

      // Same height (top and bottom equal)
      expect(brandRect.top, closeTo(formRect.top, 1.0));
      expect(brandRect.bottom, closeTo(formRect.bottom, 1.0));

      // Same width
      expect(brandRect.width, closeTo(formRect.width, 1.0));

      // No gap between them
      expect(brandRect.right, closeTo(formRect.left, 1.0));

      // Check warehouse hero geometry
      final heroFinder = find.byKey(const Key('auth_brand_warehouse_hero'));
      expect(heroFinder, findsOneWidget);
      final AspectRatio aspectRatioWidget = tester.widget<AspectRatio>(
        find
            .descendant(of: heroFinder, matching: find.byType(AspectRatio))
            .first,
      );
      expect(aspectRatioWidget.aspectRatio, closeTo(2140 / 735, 0.01));

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets('mobile top padding is stable regardless of form height', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(768, 1024)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      // Small form
      await tester.pumpWidget(_buildTestApp(body: const SizedBox(height: 100)));
      await tester.pumpAndSettle();
      final smallHeaderTop = tester
          .getTopLeft(find.byKey(const Key('auth_mobile_brand_header')))
          .dy;
      final smallCardTop = tester
          .getTopLeft(find.byKey(const Key('auth_form_card')))
          .dy;

      // Large form
      await tester.pumpWidget(_buildTestApp(body: const SizedBox(height: 800)));
      await tester.pumpAndSettle();
      final largeHeaderTop = tester
          .getTopLeft(find.byKey(const Key('auth_mobile_brand_header')))
          .dy;
      final largeCardTop = tester
          .getTopLeft(find.byKey(const Key('auth_form_card')))
          .dy;

      expect(smallHeaderTop, closeTo(largeHeaderTop, 1.0));
      expect(smallCardTop, closeTo(largeCardTop, 1.0));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}
