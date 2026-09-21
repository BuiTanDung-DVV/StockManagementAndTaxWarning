import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/localization/app_localizations.dart';
import 'package:flutter_app/core/theme/app_background_provider.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/theme/avatar_provider.dart';
import 'package:flutter_app/core/theme/theme_provider.dart';
import 'package:flutter_app/core/widgets/app_avatar.dart';
import 'package:flutter_app/features/settings/presentation/avatar_picker_dialog.dart';
import 'package:flutter_app/features/settings/presentation/theme_appearance_modal.dart';
import '../support/load_ui_fonts.dart';

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget(Widget child, {ProviderContainer? container}) {
    return UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
      child: MaterialApp(
        theme: AppTheme.lightTheme(const Color(0xFF0F766E)),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('AppAvatar renders preset emoji and edit badge', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      buildTestableWidget(
        AppAvatar(size: 60, showEditBadge: true, onTap: () => tapped = true),
      ),
    );
    await tester.pumpAndSettle();

    // Verify avatar contains camera edit badge
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

    // Verify tap callback
    await tester.tap(find.byType(AppAvatar));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets(
    'ThemeAppearanceModal renders tabs and allows switching settings',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ThemeAppearanceModal.show(context),
              child: const Text('Mở Modal'),
            ),
          ),
          container: container,
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Mở Modal'));
      await tester.pumpAndSettle();

      // Verify modal title and 3 tabs
      expect(find.text('Tùy biến giao diện & hình nền'), findsOneWidget);
      expect(find.text('Màu & Chủ đề'), findsOneWidget);
      expect(find.text('Hình nền'), findsOneWidget);
      expect(find.text('Ảnh đại diện'), findsOneWidget);

      // Switch to dark mode button
      final darkBtn = find.text('Tối');
      expect(darkBtn, findsOneWidget);
      await tester.tap(darkBtn);
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Switch to 'Hình nền' tab
      await tester.tap(find.text('Hình nền'));
      await tester.pumpAndSettle();

      // Select 'Gradient chuyển màu' chip
      final gradientChip = find.text('Gradient chuyển màu');
      expect(gradientChip, findsOneWidget);
      await tester.tap(gradientChip);
      await tester.pumpAndSettle();
      expect(
        container.read(backgroundConfigProvider).mode,
        AppBackgroundMode.gradient,
      );

      // Switch to 'Ảnh đại diện' tab
      await tester.tap(find.text('Ảnh đại diện'));
      await tester.pumpAndSettle();

      // Tap 'Kế toán trưởng' preset
      final financePreset = find.text('Kế toán trưởng');
      expect(financePreset, findsOneWidget);
      await tester.tap(financePreset);
      await tester.pumpAndSettle();
      expect(container.read(userAvatarProvider).presetId, 'finance_pro');
    },
  );

  testWidgets('AvatarPickerDialog renders 12 presets and selects avatar', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      buildTestableWidget(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AvatarPickerDialog.show(context),
            child: const Text('Đổi Avatar'),
          ),
        ),
        container: container,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đổi Avatar'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn ảnh đại diện'), findsOneWidget);
    expect(find.text('BỘ SƯU TẬP AVATAR DOANH NGHIỆP'), findsOneWidget);

    // Select Quản lý kho
    final warehouseItem = find.text('Quản lý kho');
    expect(warehouseItem, findsOneWidget);
    await tester.tap(warehouseItem);
    await tester.pumpAndSettle();

    expect(container.read(userAvatarProvider).presetId, 'warehouse_master');
  });
}
