import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/theme/app_background_provider.dart';
import 'package:flutter_app/core/theme/avatar_provider.dart';
import 'package:flutter_app/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeNotifier & BrandColorNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'ThemeModeNotifier defaults to light and updates with persistence',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(themeModeProvider), ThemeMode.light);

        await container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.dark);
        expect(container.read(themeModeProvider), ThemeMode.dark);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_theme_mode'), 'dark');

        // Create new container to test restoration
        final container2 = ProviderContainer();
        addTearDown(container2.dispose);
        container2.read(themeModeProvider); // Trigger build() and _load()
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(container2.read(themeModeProvider), ThemeMode.dark);
      },
    );

    test('BrandColorNotifier handles new palette colors', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(brandColorProvider), AppBrandColor.tealSmartStock);

      await container
          .read(brandColorProvider.notifier)
          .setBrandColor(AppBrandColor.royalPurple);
      expect(container.read(brandColorProvider), AppBrandColor.royalPurple);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('brand_color'), 'royalPurple');
    });
  });

  group('BackgroundConfigNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'BackgroundConfigNotifier defaults to none and serializes properly',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initial = container.read(backgroundConfigProvider);
        expect(initial.mode, AppBackgroundMode.none);
        expect(initial.opacity, 0.20);
        expect(initial.blur, 12.0);

        // Set gradient
        await container
            .read(backgroundConfigProvider.notifier)
            .setGradient(AppGradientPreset.cosmicNight);

        final state2 = container.read(backgroundConfigProvider);
        expect(state2.mode, AppBackgroundMode.gradient);
        expect(state2.gradientPreset, AppGradientPreset.cosmicNight);

        // Set sliders
        await container
            .read(backgroundConfigProvider.notifier)
            .setOpacity(0.35);
        await container.read(backgroundConfigProvider.notifier).setBlur(18.0);

        final state3 = container.read(backgroundConfigProvider);
        expect(state3.opacity, 0.35);
        expect(state3.blur, 18.0);

        // Reset
        await container
            .read(backgroundConfigProvider.notifier)
            .resetToDefault();
        expect(
          container.read(backgroundConfigProvider).mode,
          AppBackgroundMode.none,
        );
      },
    );

    test('AppBackgroundConfig json serialization round-trip', () {
      const original = AppBackgroundConfig(
        mode: AppBackgroundMode.presetWallpaper,
        gradientPreset: AppGradientPreset.mintBreeze,
        patternPreset: AppPatternPreset.blueprintGrid,
        wallpaperPreset: AppWallpaperPreset.smartLogistics,
        customImageUrl: 'https://example.com/custom.jpg',
        opacity: 0.40,
        blur: 15.0,
      );

      final json = original.toJson();
      final restored = AppBackgroundConfig.fromJson(json);

      expect(restored.mode, original.mode);
      expect(restored.gradientPreset, original.gradientPreset);
      expect(restored.patternPreset, original.patternPreset);
      expect(restored.wallpaperPreset, original.wallpaperPreset);
      expect(restored.customImageUrl, original.customImageUrl);
      expect(restored.opacity, original.opacity);
      expect(restored.blur, original.blur);
    });
  });

  group('UserAvatarNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'UserAvatarNotifier defaults to ceo_leader and selects presets',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initial = container.read(userAvatarProvider);
        expect(initial.presetId, 'ceo_leader');
        expect(initial.hasCustomUrl, false);

        await container
            .read(userAvatarProvider.notifier)
            .selectPreset('finance_pro');
        final state2 = container.read(userAvatarProvider);
        expect(state2.presetId, 'finance_pro');
        expect(state2.currentPreset.label, 'Kế toán trưởng');
        expect(state2.currentPreset.emoji, '📊');

        // Custom url
        await container
            .read(userAvatarProvider.notifier)
            .setCustomUrl('https://example.com/avatar.png');
        final state3 = container.read(userAvatarProvider);
        expect(state3.hasCustomUrl, true);
        expect(state3.customUrl, 'https://example.com/avatar.png');

        // Reset
        await container.read(userAvatarProvider.notifier).resetToDefault();
        final state4 = container.read(userAvatarProvider);
        expect(state4.presetId, 'ceo_leader');
        expect(state4.hasCustomUrl, false);
      },
    );
  });
}
