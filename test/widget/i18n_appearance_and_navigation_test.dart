import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/localization/app_language.dart';
import 'package:flutter_app/core/localization/app_localizations.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/theme/theme_provider.dart';
import 'package:flutter_app/core/theme/app_background_provider.dart';
import 'package:flutter_app/core/theme/avatar_provider.dart';
import 'package:flutter_app/features/settings/presentation/theme_appearance_modal.dart';
import 'package:flutter_app/features/settings/presentation/avatar_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableApp({
    required Widget child,
    required AppLanguage language,
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: language.locale,
        supportedLocales: const [
          Locale('vi', 'VN'),
          Locale('vi'),
          Locale('en', 'US'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(body: child),
      ),
    );
  }

  group('i18n Appearance & Modal Tests', () {
    testWidgets(
      'ThemeAppearanceModal renders in Vietnamese when locale is vi',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestableApp(
            child: const ThemeAppearanceModal(),
            language: AppLanguage.vi,
          ),
        );
        await tester.pumpAndSettle();

        // Tiêu đề & các Tab tiếng Việt
        expect(find.text('Tùy biến giao diện & hình nền'), findsOneWidget);
        expect(find.text('Màu sắc & Chế độ'), findsOneWidget);
        expect(find.text('Hình nền App'), findsOneWidget);
        expect(find.text('Ảnh đại diện'), findsOneWidget);

        // Tab 0 options tiếng Việt
        expect(find.text('CHẾ ĐỘ HIỂN THỊ'), findsOneWidget);
        expect(find.text('Sáng'), findsOneWidget);
        expect(find.text('Tối'), findsOneWidget);
        expect(find.text('Tự động'), findsOneWidget);
        expect(find.text('BẢNG MÀU THƯƠNG HIỆU'), findsOneWidget);
        expect(find.text('Xanh ngọc SmartStock'), findsOneWidget);

        // Chuyển sang Tab 1: Hình nền
        await tester.tap(find.text('Hình nền App'));
        await tester.pumpAndSettle();

        expect(find.text('HOA VĂN & HÌNH NỀN ỨNG DỤNG'), findsOneWidget);
        expect(find.text('Ảnh từ thiết bị'), findsOneWidget);
        expect(find.text('Không lưu trên database'), findsOneWidget);
        expect(find.text('Sóng Lục Bảo'), findsOneWidget);
        expect(find.text('Khôi phục chuẩn'), findsOneWidget);
        expect(find.text('Hoàn tất'), findsOneWidget);
      },
    );

    testWidgets('ThemeAppearanceModal renders in English when locale is en', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableApp(
          child: const ThemeAppearanceModal(),
          language: AppLanguage.en,
        ),
      );
      await tester.pumpAndSettle();

      // Tiêu đề & các Tab tiếng Anh
      expect(find.text('Theme & Appearance'), findsOneWidget);
      expect(find.text('Colors & Modes'), findsOneWidget);
      expect(find.text('App Wallpaper'), findsOneWidget);
      expect(find.text('Avatar'), findsOneWidget);

      // Tab 0 options tiếng Anh
      expect(find.text('DISPLAY MODE'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('BRAND ACCENT PALETTE'), findsOneWidget);
      expect(find.text('SmartStock Teal'), findsOneWidget);

      // Chuyển sang Tab 1: Wallpaper
      await tester.tap(find.text('App Wallpaper'));
      await tester.pumpAndSettle();

      expect(find.text('PATTERNS & APP WALLPAPERS'), findsOneWidget);
      expect(find.text('Device Image'), findsOneWidget);
      expect(find.text('Not stored on database'), findsOneWidget);
      expect(find.text('Emerald Waves'), findsOneWidget);
      expect(find.text('Reset to default'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Chuyển sang Tab 2: Avatar
      await tester.tap(find.text('Avatar'));
      await tester.pumpAndSettle();

      expect(find.text('QUICK AVATAR SELECTION'), findsOneWidget);
      expect(find.text('Select preset'), findsOneWidget);
      expect(find.text('Administrator (Male)'), findsAtLeastNWidgets(1));
    });

    testWidgets('AvatarPickerDialog renders in English when locale is en', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableApp(
          child: const AvatarPickerDialog(),
          language: AppLanguage.en,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose Avatar'), findsOneWidget);
      expect(
        find.text(
          'Pick from enterprise branding collection or upload your own',
        ),
        findsOneWidget,
      );
      expect(find.text('ENTERPRISE IDENTITY COLLECTION'), findsOneWidget);
      expect(find.text('Reset to default'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Enum localized methods return correct languages', (
      tester,
    ) async {
      // AppBrandColor
      expect(
        AppBrandColor.tealSmartStock.localizedLabel(false),
        'Xanh ngọc SmartStock',
      );
      expect(
        AppBrandColor.tealSmartStock.localizedLabel(true),
        'SmartStock Teal',
      );

      // AppWallpaperPreset
      expect(
        AppWallpaperPreset.meshEmerald.localizedLabel(false),
        'Sóng Lục Bảo',
      );
      expect(
        AppWallpaperPreset.meshEmerald.localizedLabel(true),
        'Emerald Waves',
      );

      // AppAvatarPreset
      expect(AppAvatarPreset.adminM.localizedLabel(false), 'Quản trị viên Nam');
      expect(
        AppAvatarPreset.adminM.localizedLabel(true),
        'Administrator (Male)',
      );
      expect(AppAvatarPreset.adminM.localizedCategory(false), 'Quản trị');
      expect(AppAvatarPreset.adminM.localizedCategory(true), 'Administration');

      // AppThemeModeSetting
      expect(AppThemeModeSetting.system.localizedLabel(false), 'Tự động');
      expect(AppThemeModeSetting.system.localizedLabel(true), 'Auto');
    });
  });
}
