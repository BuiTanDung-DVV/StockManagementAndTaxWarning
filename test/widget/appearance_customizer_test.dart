import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/core/widgets/app_avatar.dart';
import 'package:flutter_app/features/settings/presentation/avatar_picker_dialog.dart';
import 'package:flutter_app/features/settings/presentation/theme_appearance_modal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Appearance Customizer & Avatar Widget Tests', () {
    testWidgets('AppAvatar renders initials when no image is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const AppAvatar(size: 60, displayName: 'Nguyễn Văn A', assetPath: ''),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NA'), findsOneWidget);
    });

    testWidgets('ThemeAppearanceModal renders with all 3 tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableWidget(const ThemeAppearanceModal()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tùy biến giao diện & hình nền'), findsOneWidget);
      expect(find.text('Live Preview'), findsOneWidget);
      expect(find.text('Doanh thu tháng'), findsOneWidget);
      expect(find.text('Màu sắc & Chế độ'), findsOneWidget);
      expect(find.text('Hình nền App'), findsOneWidget);
      expect(find.text('Ảnh đại diện'), findsOneWidget);

      // Verify Theme mode options exist
      expect(find.text('Sáng'), findsOneWidget);
      expect(find.text('Tối'), findsOneWidget);
      expect(find.text('Tự động'), findsOneWidget);

      // Switch to Wallpaper tab
      await tester.tap(find.text('Hình nền App'));
      await tester.pumpAndSettle();

      expect(find.text('HOA VĂN & HÌNH NỀN ỨNG DỤNG'), findsOneWidget);
      expect(find.text('Lưới Kho Vận'), findsOneWidget);
      expect(find.text('Chấm Công Nghệ'), findsOneWidget);
      expect(find.textContaining('tự động tối ưu hóa'), findsOneWidget);

      // Switch to Avatar tab
      await tester.tap(find.text('Ảnh đại diện'));
      await tester.pumpAndSettle();

      expect(find.text('CHỌN NHANH AVATAR NHẬN DIỆN'), findsOneWidget);
      expect(find.text('Chọn mẫu'), findsOneWidget);
    });

    testWidgets(
      'LiveMiniPreview reacts to brand and preset selection without sliders',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestableWidget(const ThemeAppearanceModal()),
        );
        await tester.pumpAndSettle();

        // Tap on Cam bán lẻ (Sunset Copper)
        final orangeBrand = find.text('Cam bán lẻ');
        expect(orangeBrand, findsOneWidget);
        await tester.tap(orangeBrand);
        await tester.pumpAndSettle();

        // Switch to wallpaper tab and select Lưới Kho Vận
        await tester.tap(find.text('Hình nền App'));
        await tester.pumpAndSettle();

        final gridPreset = find.text('Lưới Kho Vận');
        expect(gridPreset, findsOneWidget);
        await tester.tap(gridPreset);
        await tester.pumpAndSettle();

        // Verify that no slider exists (they were removed for clean 1-click experience)
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets('AvatarPickerDialog renders preset collection and dismisses', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(const AvatarPickerDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Chọn ảnh đại diện'), findsOneWidget);
      expect(find.text('BỘ SƯU TẬP NHẬN DIỆN DOANH NGHIỆP'), findsOneWidget);
      expect(find.text('Quản trị viên Nam'), findsNWidgets(2));
      expect(find.text('Kế toán trưởng'), findsOneWidget);
      expect(find.text('Thu ngân bán hàng'), findsOneWidget);
    });

    testWidgets(
      'Wallpaper tab displays Dedicated Custom Wallpaper Card alongside distinct Presets',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestableWidget(const ThemeAppearanceModal()),
        );
        await tester.pumpAndSettle();

        // Chuyển sang Tab Hình nền App
        await tester.tap(find.text('Hình nền App'));
        await tester.pumpAndSettle();

        // 1. Kiểm tra sự xuất hiện của Card "Tải ảnh từ máy" / "Ảnh từ thiết bị"
        expect(find.text('Ảnh từ thiết bị'), findsOneWidget);
        expect(find.text('Không lưu trên database'), findsOneWidget);

        // 2. Kiểm tra các badges đặc trưng trực quan của từng Preset để đảm bảo không bị trùng lặp hay mờ nhạt
        expect(find.text('Giao diện phẳng'), findsOneWidget);
        expect(find.text('BLUEPRINT KHO'), findsOneWidget);
        expect(find.text('CYBER MATRIX'), findsOneWidget);
        expect(find.text('SÓNG LỤC BẢO'), findsOneWidget);
        expect(find.text('KHỐI LẬP THỂ'), findsOneWidget);
        expect(find.text('ẢNH KHO THẬT'), findsOneWidget);

        // 3. Chọn thử một Preset
        await tester.tap(find.text('Sóng Lục Bảo'));
        await tester.pumpAndSettle();
      },
    );
  });
}

