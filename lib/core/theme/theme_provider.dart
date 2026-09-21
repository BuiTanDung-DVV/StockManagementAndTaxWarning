import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorKey = 'brand_color';
const _kThemeModeKey = 'app_theme_mode';

enum AppBrandColor {
  tealSmartStock('Xanh ngọc SmartStock', Color(0xFF0F766E), false),
  luminaBlue('Xanh SmartStock', Color(0xFF1769AA), false),
  emeraldWealth('Xanh vận hành', Color(0xFF167A5B), false),
  sunsetCopper('Cam bán lẻ', Color(0xFFC65D18), false),
  orchidMajesty('Tím trung tính', Color(0xFF6B5AA6), false),
  crimsonRose('Đỏ thương hiệu', Color(0xFFB73E49), false),
  steelSlate('Xám xanh', Color(0xFF526779), false),
  darkObsidian('Nền tối', Color(0xFF5A9BD5), true),
  royalPurple('Tím hoàng gia', Color(0xFF7C3AED), false),
  cyberTeal('Xanh công nghệ', Color(0xFF06B6D4), false),
  midnightIndigo('Xanh chàm huyền bí', Color(0xFF4F46E5), false),
  rubyCrimson('Đỏ hồng ngọc', Color(0xFFE11D48), false),
  amberSunset('Cam hổ phách', Color(0xFFD97706), false),
  roseQuartz('Hồng thạch anh', Color(0xFFE879F9), false);

  final String label;
  final Color color;
  final bool isDark;
  const AppBrandColor(this.label, this.color, this.isDark);
}

final brandColorProvider = NotifierProvider<BrandColorNotifier, AppBrandColor>(
  BrandColorNotifier.new,
);

class BrandColorNotifier extends Notifier<AppBrandColor> {
  @override
  AppBrandColor build() {
    _load();
    return AppBrandColor.tealSmartStock;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kColorKey);
    if (value != null) {
      state = AppBrandColor.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppBrandColor.tealSmartStock,
      );
    }
  }

  Future<void> setBrandColor(AppBrandColor brandColor) async {
    state = brandColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kColorKey, brandColor.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kThemeModeKey);
    if (value != null) {
      switch (value) {
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'light':
          state = ThemeMode.light;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
      }
    } else {
      // Fallback check if legacy brandColor was darkObsidian
      final legacyColor = prefs.getString(_kColorKey);
      if (legacyColor == AppBrandColor.darkObsidian.name) {
        state = ThemeMode.dark;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

/// Backwards compatibility provider for screens listening to themeProvider.
final themeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(themeModeProvider);
  final brandColor = ref.watch(brandColorProvider);
  if (brandColor == AppBrandColor.darkObsidian) {
    return ThemeMode.dark;
  }
  return mode;
});
