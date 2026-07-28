import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorKey = 'brand_color';

enum AppBrandColor {
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

final brandColorProvider = NotifierProvider<BrandColorNotifier, AppBrandColor>(
  BrandColorNotifier.new,
);

final themeProvider = Provider<ThemeMode>((ref) {
  final brandColor = ref.watch(brandColorProvider);
  return brandColor.isDark ? ThemeMode.dark : ThemeMode.light;
});

class BrandColorNotifier extends Notifier<AppBrandColor> {
  @override
  AppBrandColor build() {
    _load();
    return AppBrandColor.luminaBlue;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kColorKey);
    if (value != null) {
      state = AppBrandColor.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AppBrandColor.luminaBlue,
      );
    }
  }

  Future<void> setBrandColor(AppBrandColor brandColor) async {
    state = brandColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kColorKey, brandColor.name);
  }
}
