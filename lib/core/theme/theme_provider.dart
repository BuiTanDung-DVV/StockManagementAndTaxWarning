import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorKey = 'brand_color';

enum AppBrandColor {
  luminaBlue('Xanh Hoàng Gia', Color(0xFF2563EB), false),
  emeraldWealth('Lục Thịnh Vượng', Color(0xFF059669), false),
  sunsetCopper('Đồng Hoàng Hôn', Color(0xFFEA580C), false),
  orchidMajesty('Tím Thượng Uyển', Color(0xFF7C3AED), false),
  crimsonRose('Đỏ Hồng Hoa', Color(0xFFDC2626), false),
  steelSlate('Xanh Thạch Bản', Color(0xFF475569), false),
  darkObsidian('Tối Obsidian', Color(0xFF818CF8), true);

  final String label;
  final Color color;
  final bool isDark;
  const AppBrandColor(this.label, this.color, this.isDark);
}

final brandColorProvider = NotifierProvider<BrandColorNotifier, AppBrandColor>(BrandColorNotifier.new);

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

