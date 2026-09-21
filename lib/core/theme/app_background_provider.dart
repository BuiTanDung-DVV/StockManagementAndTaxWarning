import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBackgroundConfigKey = 'app_background_config_v1';

enum AppBackgroundMode {
  none('Mặc định', 'Giao diện tối giản, sạch sẽ'),
  gradient('Gradient chuyển màu', 'Dải màu nghệ thuật chuyển tiếp mượt mà'),
  pattern('Họa tiết tinh tế', 'Lưới hình học hiện đại và tinh gọn'),
  presetWallpaper(
    'Bộ sưu tập hình nền',
    'Ảnh không gian kinh doanh & kiến trúc cao cấp',
  ),
  customUrl('Ảnh nền tùy chỉnh', 'Sử dụng liên kết hình ảnh cá nhân');

  final String label;
  final String description;
  const AppBackgroundMode(this.label, this.description);
}

enum AppGradientPreset {
  auroraBorealis(
    'Bắc cực quang',
    [Color(0xFF0F766E), Color(0xFF1E1B4B), Color(0xFF0B1420)],
    [0.0, 0.5, 1.0],
  ),
  cosmicNight(
    'Vũ trụ sâu thẳm',
    [Color(0xFF1E1B4B), Color(0xFF311042), Color(0xFF070B12)],
    [0.0, 0.6, 1.0],
  ),
  sunriseGlow(
    'Bình minh ấm áp',
    [Color(0xFFC65D18), Color(0xFFBE185D), Color(0xFF4C0519)],
    [0.0, 0.55, 1.0],
  ),
  mintBreeze(
    'Gió bạc hà',
    [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF134E4A)],
    [0.0, 0.5, 1.0],
  ),
  royalVelvet(
    'Nhung hoàng gia',
    [Color(0xFF6B21A8), Color(0xFF3B0764), Color(0xFF0F172A)],
    [0.0, 0.6, 1.0],
  ),
  cyberMidnight(
    'Đêm công nghệ',
    [Color(0xFF0284C7), Color(0xFF1E293B), Color(0xFF020617)],
    [0.0, 0.5, 1.0],
  ),
  emeraldForest(
    'Ngọc lục bảo',
    [Color(0xFF065F46), Color(0xFF064E3B), Color(0xFF022C22)],
    [0.0, 0.5, 1.0],
  );

  final String label;
  final List<Color> colors;
  final List<double> stops;
  const AppGradientPreset(this.label, this.colors, this.stops);
}

enum AppPatternPreset {
  dotsGrid('Lưới chấm ma trận', 'Họa tiết chấm tinh xảo công nghệ cao'),
  blueprintGrid('Lưới tọa độ', 'Đường kẻ cấu trúc kiến trúc vững chắc'),
  geometricWaves(
    'Sóng hình học',
    'Đường lượn sóng mềm mại, chuyển động êm dịu',
  );

  final String label;
  final String description;
  const AppPatternPreset(this.label, this.description);
}

enum AppWallpaperPreset {
  modernOffice(
    'Văn phòng hiện đại',
    'https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=1600&auto=format&fit=crop',
  ),
  smartLogistics(
    'Trung tâm kho vận thông minh',
    'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?q=80&w=1600&auto=format&fit=crop',
  ),
  minimalArchitecture(
    'Kiến trúc tối giản',
    'https://images.unsplash.com/photo-1513694203232-719a280e022f?q=80&w=1600&auto=format&fit=crop',
  ),
  cityTwilight(
    'Hoàng hôn đô thị',
    'https://images.unsplash.com/photo-1519501025264-65ba15a82390?q=80&w=1600&auto=format&fit=crop',
  );

  final String label;
  final String url;
  const AppWallpaperPreset(this.label, this.url);
}

@immutable
class AppBackgroundConfig {
  final AppBackgroundMode mode;
  final AppGradientPreset gradientPreset;
  final AppPatternPreset patternPreset;
  final AppWallpaperPreset wallpaperPreset;
  final String customImageUrl;
  final double opacity;
  final double blur;

  const AppBackgroundConfig({
    this.mode = AppBackgroundMode.none,
    this.gradientPreset = AppGradientPreset.auroraBorealis,
    this.patternPreset = AppPatternPreset.dotsGrid,
    this.wallpaperPreset = AppWallpaperPreset.modernOffice,
    this.customImageUrl = '',
    this.opacity = 0.20,
    this.blur = 12.0,
  });

  AppBackgroundConfig copyWith({
    AppBackgroundMode? mode,
    AppGradientPreset? gradientPreset,
    AppPatternPreset? patternPreset,
    AppWallpaperPreset? wallpaperPreset,
    String? customImageUrl,
    double? opacity,
    double? blur,
  }) {
    return AppBackgroundConfig(
      mode: mode ?? this.mode,
      gradientPreset: gradientPreset ?? this.gradientPreset,
      patternPreset: patternPreset ?? this.patternPreset,
      wallpaperPreset: wallpaperPreset ?? this.wallpaperPreset,
      customImageUrl: customImageUrl ?? this.customImageUrl,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'gradientPreset': gradientPreset.name,
    'patternPreset': patternPreset.name,
    'wallpaperPreset': wallpaperPreset.name,
    'customImageUrl': customImageUrl,
    'opacity': opacity,
    'blur': blur,
  };

  factory AppBackgroundConfig.fromJson(Map<String, dynamic> json) {
    AppBackgroundMode mode = AppBackgroundMode.none;
    AppGradientPreset gradient = AppGradientPreset.auroraBorealis;
    AppPatternPreset pattern = AppPatternPreset.dotsGrid;
    AppWallpaperPreset wallpaper = AppWallpaperPreset.modernOffice;

    try {
      if (json['mode'] != null) {
        mode = AppBackgroundMode.values.firstWhere(
          (e) => e.name == json['mode'],
          orElse: () => AppBackgroundMode.none,
        );
      }
      if (json['gradientPreset'] != null) {
        gradient = AppGradientPreset.values.firstWhere(
          (e) => e.name == json['gradientPreset'],
          orElse: () => AppGradientPreset.auroraBorealis,
        );
      }
      if (json['patternPreset'] != null) {
        pattern = AppPatternPreset.values.firstWhere(
          (e) => e.name == json['patternPreset'],
          orElse: () => AppPatternPreset.dotsGrid,
        );
      }
      if (json['wallpaperPreset'] != null) {
        wallpaper = AppWallpaperPreset.values.firstWhere(
          (e) => e.name == json['wallpaperPreset'],
          orElse: () => AppWallpaperPreset.modernOffice,
        );
      }
    } catch (_) {}

    return AppBackgroundConfig(
      mode: mode,
      gradientPreset: gradient,
      patternPreset: pattern,
      wallpaperPreset: wallpaper,
      customImageUrl: (json['customImageUrl'] as String?) ?? '',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.20,
      blur: (json['blur'] as num?)?.toDouble() ?? 12.0,
    );
  }
}

final backgroundConfigProvider =
    NotifierProvider<BackgroundConfigNotifier, AppBackgroundConfig>(
      BackgroundConfigNotifier.new,
    );

class BackgroundConfigNotifier extends Notifier<AppBackgroundConfig> {
  @override
  AppBackgroundConfig build() {
    _load();
    return const AppBackgroundConfig();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBackgroundConfigKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = AppBackgroundConfig.fromJson(map);
      } catch (_) {}
    }
  }

  Future<void> updateConfig(AppBackgroundConfig config) async {
    state = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBackgroundConfigKey, jsonEncode(config.toJson()));
  }

  Future<void> setMode(AppBackgroundMode mode) =>
      updateConfig(state.copyWith(mode: mode));

  Future<void> setGradient(AppGradientPreset preset) => updateConfig(
    state.copyWith(mode: AppBackgroundMode.gradient, gradientPreset: preset),
  );

  Future<void> setPattern(AppPatternPreset pattern) => updateConfig(
    state.copyWith(mode: AppBackgroundMode.pattern, patternPreset: pattern),
  );

  Future<void> setWallpaper(AppWallpaperPreset wallpaper) => updateConfig(
    state.copyWith(
      mode: AppBackgroundMode.presetWallpaper,
      wallpaperPreset: wallpaper,
    ),
  );

  Future<void> setCustomImageUrl(String url) => updateConfig(
    state.copyWith(mode: AppBackgroundMode.customUrl, customImageUrl: url),
  );

  Future<void> setOpacity(double opacity) =>
      updateConfig(state.copyWith(opacity: opacity.clamp(0.05, 0.80)));

  Future<void> setBlur(double blur) =>
      updateConfig(state.copyWith(blur: blur.clamp(0.0, 30.0)));

  Future<void> resetToDefault() =>
      updateConfig(const AppBackgroundConfig(mode: AppBackgroundMode.none));
}
