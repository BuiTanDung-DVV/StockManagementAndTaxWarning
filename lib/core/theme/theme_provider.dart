import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorKey = 'brand_color';
const _kThemeModeKey = 'app_theme_mode_setting';

enum AppBrandColor {
  tealSmartStock('Xanh ngọc SmartStock', Color(0xFF0F766E), false),
  luminaBlue('Xanh SmartStock', Color(0xFF1769AA), false),
  emeraldWealth('Xanh vận hành', Color(0xFF167A5B), false),
  sunsetCopper('Cam bán lẻ', Color(0xFFC65D18), false),
  orchidMajesty('Tím trung tính', Color(0xFF6B5AA6), false),
  crimsonRose('Đỏ thương hiệu', Color(0xFFB73E49), false),
  steelSlate('Xám xanh', Color(0xFF526779), false),
  darkObsidian('Nền tối', Color(0xFF5A9BD5), true);

  final String label;
  final Color color;
  final bool isDark;
  const AppBrandColor(this.label, this.color, this.isDark);
}

enum AppThemeModeSetting {
  light('Sáng', 'Giao diện sáng rõ ràng, tối ưu tương phản'),
  dark('Tối', 'Giao diện nền tối bảo vệ mắt'),
  system('Hệ thống', 'Tự động chuyển theo cài đặt thiết bị');

  final String label;
  final String description;
  const AppThemeModeSetting(this.label, this.description);
}

final themeModeSettingProvider =
    NotifierProvider<ThemeModeSettingNotifier, AppThemeModeSetting>(
      ThemeModeSettingNotifier.new,
    );

final themeProvider = Provider<ThemeMode>((ref) {
  final setting = ref.watch(themeModeSettingProvider);
  switch (setting) {
    case AppThemeModeSetting.light:
      return ThemeMode.light;
    case AppThemeModeSetting.dark:
      return ThemeMode.dark;
    case AppThemeModeSetting.system:
      return ThemeMode.system;
  }
});

class ThemeModeSettingNotifier extends Notifier<AppThemeModeSetting> {
  @override
  AppThemeModeSetting build() {
    _load();
    return AppThemeModeSetting.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kThemeModeKey);
    if (value != null) {
      state = AppThemeModeSetting.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppThemeModeSetting.light,
      );
    }
  }

  Future<void> setThemeMode(AppThemeModeSetting mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
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
