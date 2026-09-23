import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../assets/app_assets.dart';

const _kBgPresetKey = 'app_background_preset_v2';
const _kBgOpacityKey = 'app_background_opacity_v2';
const _kBgBlurKey = 'app_background_blur_v2';
const _kBgCustomPathKey = 'app_background_custom_path_v2';
const _kBgCustomBase64Key = 'app_background_custom_base64_v2';
const _kBgIsCustomActiveKey = 'app_background_is_custom_active_v2';

enum AppWallpaperPreset {
  none(
    id: 'none',
    label: 'Mặc định (Không nền)',
    assetPath: '',
    description: 'Nền phẳng tối giản, tối ưu tốc độ và độ tập trung',
    defaultOpacityLight: 0.0,
    defaultOpacityDark: 0.0,
  ),
  warehouseGrid(
    id: 'warehouse_grid',
    label: 'Lưới Kho Vận',
    assetPath: AppAssets.bgWarehouseGrid,
    description: 'Họa tiết lưới kệ kho thông minh, hiện đại',
    defaultOpacityLight: 0.12,
    defaultOpacityDark: 0.16,
  ),
  techDots(
    id: 'tech_dots',
    label: 'Chấm Công Nghệ',
    assetPath: AppAssets.bgTechDots,
    description: 'Ma trận điểm vi mạch số hóa công nghệ cao',
    defaultOpacityLight: 0.12,
    defaultOpacityDark: 0.16,
  ),
  meshEmerald(
    id: 'mesh_emerald',
    label: 'Sóng Lục Bảo',
    assetPath: AppAssets.bgMeshEmerald,
    description: 'Lớp sóng gradient mềm mại mang năng lượng thịnh vượng',
    defaultOpacityLight: 0.14,
    defaultOpacityDark: 0.18,
  ),
  geometric(
    id: 'geometric',
    label: 'Khối Hình Học',
    assetPath: AppAssets.bgGeometricShapes,
    description: 'Khối đa giác lập thể thanh lịch và gọn gàng',
    defaultOpacityLight: 0.12,
    defaultOpacityDark: 0.16,
  ),
  warehousePanorama(
    id: 'warehouse_panorama',
    label: 'Kho Hàng Thực Tế',
    assetPath: AppAssets.authWarehousePanoramaV2,
    description: 'Toàn cảnh trung tâm phân phối kho bãi SmartStock',
    defaultOpacityLight: 0.08,
    defaultOpacityDark: 0.12,
  );

  final String id;
  final String label;
  final String assetPath;
  final String description;
  final double defaultOpacityLight;
  final double defaultOpacityDark;

  const AppWallpaperPreset({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.description,
    this.defaultOpacityLight = 0.12,
    this.defaultOpacityDark = 0.16,
  });

  static AppWallpaperPreset fromId(String? id) {
    if (id == null) return AppWallpaperPreset.none;
    for (final preset in AppWallpaperPreset.values) {
      if (preset.id == id) return preset;
    }
    return AppWallpaperPreset.none;
  }
}

@immutable
class AppBackgroundState {
  final AppWallpaperPreset preset;
  final double opacity;
  final double blurRadius;
  final String? customImagePath;
  final String? customBase64;
  final bool isCustomActive;

  const AppBackgroundState({
    this.preset = AppWallpaperPreset.none,
    this.opacity = 0.08,
    this.blurRadius = 0.0,
    this.customImagePath,
    this.customBase64,
    this.isCustomActive = false,
  });

  /// Kiểm tra xem người dùng đã tải/lưu ảnh tùy chỉnh trên thiết bị chưa.
  bool get hasCustomImage =>
      (customImagePath != null && customImagePath!.isNotEmpty) ||
      (customBase64 != null && customBase64!.isNotEmpty);

  /// Trạng thái đang kích hoạt ảnh tùy chỉnh từ thiết bị.
  bool get isCustom =>
      (isCustomActive && hasCustomImage) ||
      (preset == AppWallpaperPreset.none && hasCustomImage && isCustomActive);

  /// Kiểm tra có đang áp dụng bất kỳ hình nền nào không.
  bool get hasBackground =>
      (isCustom && hasCustomImage) || preset != AppWallpaperPreset.none;

  double getEffectiveOpacity(bool isDark) {
    if (isCustom) return isDark ? 0.14 : 0.12;
    return isDark ? preset.defaultOpacityDark : preset.defaultOpacityLight;
  }

  AppBackgroundState copyWith({
    AppWallpaperPreset? preset,
    double? opacity,
    double? blurRadius,
    String? customImagePath,
    String? customBase64,
    bool? isCustomActive,
    bool clearCustom = false,
  }) {
    final nextCustomPath = clearCustom
        ? null
        : (customImagePath ?? this.customImagePath);
    final nextCustomBase64 = clearCustom
        ? null
        : (customBase64 ?? this.customBase64);
    final hasNewCustomData =
        (customImagePath != null || customBase64 != null) && !clearCustom;

    return AppBackgroundState(
      preset: preset ?? this.preset,
      opacity: opacity ?? this.opacity,
      blurRadius: blurRadius ?? this.blurRadius,
      customImagePath: nextCustomPath,
      customBase64: nextCustomBase64,
      isCustomActive: clearCustom
          ? false
          : (isCustomActive ?? (hasNewCustomData ? true : this.isCustomActive)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppBackgroundState &&
        other.preset == preset &&
        other.opacity == opacity &&
        other.blurRadius == blurRadius &&
        other.customImagePath == customImagePath &&
        other.customBase64 == customBase64 &&
        other.isCustomActive == isCustomActive;
  }

  @override
  int get hashCode => Object.hash(
    preset,
    opacity,
    blurRadius,
    customImagePath,
    customBase64,
    isCustomActive,
  );
}

final appBackgroundProvider =
    NotifierProvider<AppBackgroundNotifier, AppBackgroundState>(
      AppBackgroundNotifier.new,
    );

class AppBackgroundNotifier extends Notifier<AppBackgroundState> {
  @override
  AppBackgroundState build() {
    _load();
    return const AppBackgroundState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetId = prefs.getString(_kBgPresetKey);
    final opacity = prefs.getDouble(_kBgOpacityKey) ?? 0.12;
    final blur = prefs.getDouble(_kBgBlurKey) ?? 0.0;
    final customPath = prefs.getString(_kBgCustomPathKey);
    final customBase64 = prefs.getString(_kBgCustomBase64Key);
    final isCustomActive =
        prefs.getBool(_kBgIsCustomActiveKey) ??
        (customBase64 != null || customPath != null);

    state = AppBackgroundState(
      preset: AppWallpaperPreset.fromId(presetId),
      opacity: opacity.clamp(0.01, 0.35),
      blurRadius: blur.clamp(0.0, 20.0),
      customImagePath: customPath,
      customBase64: customBase64,
      isCustomActive: isCustomActive,
    );
  }

  /// Chọn preset mẫu có sẵn.
  /// LƯU Ý: Giữ nguyên ảnh tùy chỉnh đã lưu ở máy để người dùng có thể chọn lại bất kỳ lúc nào.
  Future<void> setPreset(AppWallpaperPreset preset) async {
    state = state.copyWith(preset: preset, isCustomActive: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBgPresetKey, preset.id);
    await prefs.setBool(_kBgIsCustomActiveKey, false);
  }

  /// Kích hoạt lại ảnh tùy chỉnh đã có trên máy.
  Future<void> selectCustomImage() async {
    if (state.hasCustomImage) {
      state = state.copyWith(
        preset: AppWallpaperPreset.none,
        isCustomActive: true,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBgIsCustomActiveKey, true);
      await prefs.setString(_kBgPresetKey, AppWallpaperPreset.none.id);
    }
  }

  Future<void> setOpacity(double opacity) async {
    final clamped = opacity.clamp(0.01, 0.35);
    state = state.copyWith(opacity: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBgOpacityKey, clamped);
  }

  Future<void> setBlurRadius(double blur) async {
    final clamped = blur.clamp(0.0, 20.0);
    state = state.copyWith(blurRadius: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBgBlurKey, clamped);
  }

  /// Lưu ảnh tùy chỉnh cục bộ trên máy người dùng (SharedPreferences).
  /// TUYỆT ĐỐI KHÔNG GỬI LÊN SERVER/DB.
  Future<void> setCustomImage({String? filePath, String? base64Data}) async {
    state = state.copyWith(
      preset: AppWallpaperPreset.none,
      customImagePath: filePath,
      customBase64: base64Data,
      isCustomActive: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBgIsCustomActiveKey, true);
    await prefs.setString(_kBgPresetKey, AppWallpaperPreset.none.id);
    if (filePath != null) {
      await prefs.setString(_kBgCustomPathKey, filePath);
    }
    if (base64Data != null) {
      await prefs.setString(_kBgCustomBase64Key, base64Data);
    }
  }

  /// Xóa ảnh tùy chỉnh khỏi bộ nhớ máy người dùng nếu muốn dọn dẹp.
  Future<void> removeCustomImage() async {
    state = state.copyWith(clearCustom: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBgCustomPathKey);
    await prefs.remove(_kBgCustomBase64Key);
    await prefs.setBool(_kBgIsCustomActiveKey, false);
  }

  Future<void> resetDefault() async {
    state = const AppBackgroundState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBgPresetKey);
    await prefs.remove(_kBgOpacityKey);
    await prefs.remove(_kBgBlurKey);
    await prefs.remove(_kBgCustomPathKey);
    await prefs.remove(_kBgCustomBase64Key);
    await prefs.remove(_kBgIsCustomActiveKey);
  }
}
