import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/assets/app_assets.dart';
import 'package:flutter_app/core/theme/app_background_provider.dart';
import 'package:flutter_app/core/theme/avatar_provider.dart';
import 'package:flutter_app/core/theme/theme_provider.dart';

void main() {
  group('Theme & Background Unit Tests', () {
    test(
      'AppWallpaperPreset resolves IDs correctly and provides fallbacks',
      () {
        expect(AppWallpaperPreset.fromId(null), AppWallpaperPreset.none);
        expect(
          AppWallpaperPreset.fromId('invalid_id'),
          AppWallpaperPreset.none,
        );
        expect(
          AppWallpaperPreset.fromId('warehouse_grid'),
          AppWallpaperPreset.warehouseGrid,
        );
        expect(
          AppWallpaperPreset.fromId('tech_dots'),
          AppWallpaperPreset.techDots,
        );
        expect(
          AppWallpaperPreset.fromId('mesh_emerald'),
          AppWallpaperPreset.meshEmerald,
        );
        expect(
          AppWallpaperPreset.fromId('geometric'),
          AppWallpaperPreset.geometric,
        );
        expect(
          AppWallpaperPreset.fromId('warehouse_panorama'),
          AppWallpaperPreset.warehousePanorama,
        );
      },
    );

    test('AppAvatarPreset resolves IDs correctly', () {
      expect(AppAvatarPreset.fromId(null), isNull);
      expect(AppAvatarPreset.fromId('unknown'), isNull);
      expect(AppAvatarPreset.fromId('admin_m'), AppAvatarPreset.adminM);
      expect(AppAvatarPreset.fromId('admin_f'), AppAvatarPreset.adminF);
      expect(AppAvatarPreset.fromId('accountant'), AppAvatarPreset.accountant);
      expect(AppAvatarPreset.fromId('cashier'), AppAvatarPreset.cashier);
      expect(AppAvatarPreset.fromId('warehouse'), AppAvatarPreset.warehouse);
      expect(AppAvatarPreset.fromId('ai_bot'), AppAvatarPreset.aiBot);
      expect(AppAvatarPreset.fromId('mascot'), AppAvatarPreset.mascot);
      expect(AppAvatarPreset.fromId('logo'), AppAvatarPreset.logo);
    });

    test('AppBackgroundState handles copyWith and flags correctly', () {
      const state1 = AppBackgroundState();
      expect(state1.hasBackground, isFalse);
      expect(state1.isCustom, isFalse);
      expect(state1.opacity, 0.08);

      final state2 = state1.copyWith(
        preset: AppWallpaperPreset.techDots,
        opacity: 0.15,
        blurRadius: 4.0,
      );
      expect(state2.hasBackground, isTrue);
      expect(state2.isCustom, isFalse);
      expect(state2.preset, AppWallpaperPreset.techDots);
      expect(state2.opacity, 0.15);
      expect(state2.blurRadius, 4.0);

      final state3 = state2.copyWith(customBase64: 'fake_base64_data');
      expect(state3.isCustom, isTrue);
      expect(state3.hasBackground, isTrue);

      final state4 = state3.copyWith(clearCustom: true);
      expect(state4.isCustom, isFalse);
      expect(state4.customBase64, isNull);
    });

    test('UserAvatarState handles copyWith and flags correctly', () {
      const avatar1 = UserAvatarState(preset: AppAvatarPreset.adminM);
      expect(avatar1.hasCustomImage, isFalse);
      expect(avatar1.effectiveAssetPath, AppAssets.avatarAdminM);

      final avatar2 = avatar1.copyWith(
        clearPreset: true,
        customImagePath: '/path/to/img.png',
      );
      expect(avatar2.hasCustomImage, isTrue);
      expect(avatar2.preset, isNull);
      expect(avatar2.effectiveAssetPath, isNull);
    });

    test('AppThemeModeSetting has valid labels and descriptions', () {
      for (final mode in AppThemeModeSetting.values) {
        expect(mode.label.isNotEmpty, isTrue);
        expect(mode.description.isNotEmpty, isTrue);
      }
    });

    test('AppAssets contains valid theme and appearance asset paths', () {
      expect(AppAssets.palette, 'assets/icon/palette_icon.svg');
      expect(AppAssets.wallpaper, 'assets/icon/wallpaper_icon.svg');
      expect(AppAssets.avatar, 'assets/icon/avatar_icon.svg');
      expect(AppAssets.check, 'assets/icon/check_icon.svg');
      expect(AppAssets.close, 'assets/icon/close_icon.svg');
      expect(AppAssets.sun, 'assets/icon/sun_icon.svg');
      expect(AppAssets.moon, 'assets/icon/moon_icon.svg');
      expect(AppAssets.systemMode, 'assets/icon/system_mode_icon.svg');
      expect(AppAssets.upload, 'assets/icon/upload_icon.svg');
      expect(AppAssets.refresh, 'assets/icon/refresh_icon.svg');

      expect(AppAssets.avatarAdminM, 'assets/icon/avatar_admin_m.svg');
      expect(AppAssets.avatarAdminF, 'assets/icon/avatar_admin_f.svg');
      expect(AppAssets.avatarAccountant, 'assets/icon/avatar_accountant.svg');
      expect(AppAssets.avatarCashier, 'assets/icon/avatar_cashier.svg');
      expect(AppAssets.avatarWarehouse, 'assets/icon/avatar_warehouse.svg');
      expect(AppAssets.avatarAiBot, 'assets/icon/avatar_ai_bot.svg');

      expect(AppAssets.bgWarehouseGrid, 'assets/icon/bg_warehouse_grid.svg');
      expect(AppAssets.bgTechDots, 'assets/icon/bg_tech_dots.svg');
      expect(AppAssets.bgMeshEmerald, 'assets/icon/bg_mesh_emerald.svg');
      expect(
        AppAssets.bgGeometricShapes,
        'assets/icon/bg_geometric_shapes.svg',
      );
    });
  });
}
