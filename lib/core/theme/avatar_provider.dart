import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../assets/app_assets.dart';

const _kAvatarPresetKey = 'user_avatar_preset_v2';
const _kAvatarCustomPathKey = 'user_avatar_custom_path_v2';
const _kAvatarBase64Key = 'user_avatar_base64_v2';
const _kAvatarNetworkUrlKey = 'user_avatar_network_url_v2';

enum AppAvatarPreset {
  adminM(
    id: 'admin_m',
    label: 'Quản trị viên Nam',
    assetPath: AppAssets.avatarAdminM,
    category: 'Quản trị',
  ),
  adminF(
    id: 'admin_f',
    label: 'Nữ Quản lý',
    assetPath: AppAssets.avatarAdminF,
    category: 'Quản trị',
  ),
  accountant(
    id: 'accountant',
    label: 'Kế toán trưởng',
    assetPath: AppAssets.avatarAccountant,
    category: 'Tài chính - Thuế',
  ),
  cashier(
    id: 'cashier',
    label: 'Thu ngân bán hàng',
    assetPath: AppAssets.avatarCashier,
    category: 'Bán lẻ',
  ),
  warehouse(
    id: 'warehouse',
    label: 'Thủ kho logistics',
    assetPath: AppAssets.avatarWarehouse,
    category: 'Kho vận',
  ),
  aiBot(
    id: 'ai_bot',
    label: 'Trợ lý AI SmartStock',
    assetPath: AppAssets.avatarAiBot,
    category: 'Công nghệ',
  ),
  mascot(
    id: 'mascot',
    label: 'Linh vật hệ thống',
    assetPath: AppAssets.aiMascot,
    category: 'Nhận diện',
  ),
  logo(
    id: 'logo',
    label: 'Biểu tượng SmartStock',
    assetPath: AppAssets.appIcon,
    category: 'Nhận diện',
  );

  final String id;
  final String label;
  final String assetPath;
  final String category;

  const AppAvatarPreset({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.category,
  });

  String localizedLabel(bool isEnglish) {
    if (!isEnglish) return label;
    switch (this) {
      case AppAvatarPreset.adminM:
        return 'Administrator (Male)';
      case AppAvatarPreset.adminF:
        return 'Manager (Female)';
      case AppAvatarPreset.accountant:
        return 'Chief Accountant';
      case AppAvatarPreset.cashier:
        return 'POS Cashier';
      case AppAvatarPreset.warehouse:
        return 'Warehouse Keeper';
      case AppAvatarPreset.aiBot:
        return 'SmartStock AI Assistant';
      case AppAvatarPreset.mascot:
        return 'System Mascot';
      case AppAvatarPreset.logo:
        return 'SmartStock Logo';
    }
  }

  String localizedCategory(bool isEnglish) {
    if (!isEnglish) return category;
    switch (this) {
      case AppAvatarPreset.adminM:
      case AppAvatarPreset.adminF:
        return 'Administration';
      case AppAvatarPreset.accountant:
        return 'Finance & Tax';
      case AppAvatarPreset.cashier:
        return 'Retail';
      case AppAvatarPreset.warehouse:
        return 'Logistics';
      case AppAvatarPreset.aiBot:
        return 'Technology';
      case AppAvatarPreset.mascot:
      case AppAvatarPreset.logo:
        return 'Branding';
    }
  }

  static AppAvatarPreset? fromId(String? id) {
    if (id == null) return null;
    for (final p in AppAvatarPreset.values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

@immutable
class UserAvatarState {
  final AppAvatarPreset? preset;
  final String? customImagePath;
  final String? customBase64;
  final String? networkUrl;

  const UserAvatarState({
    this.preset = AppAvatarPreset.adminM,
    this.customImagePath,
    this.customBase64,
    this.networkUrl,
  });

  bool get hasCustomImage =>
      customImagePath != null ||
      customBase64 != null ||
      (networkUrl != null && networkUrl!.isNotEmpty);

  String? get effectiveAssetPath => preset?.assetPath;

  UserAvatarState copyWith({
    AppAvatarPreset? preset,
    String? customImagePath,
    String? customBase64,
    String? networkUrl,
    bool clearPreset = false,
    bool clearCustom = false,
  }) {
    return UserAvatarState(
      preset: clearPreset ? null : (preset ?? this.preset),
      customImagePath: clearCustom
          ? null
          : (customImagePath ?? this.customImagePath),
      customBase64: clearCustom ? null : (customBase64 ?? this.customBase64),
      networkUrl: clearCustom ? null : (networkUrl ?? this.networkUrl),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserAvatarState &&
        other.preset == preset &&
        other.customImagePath == customImagePath &&
        other.customBase64 == customBase64 &&
        other.networkUrl == networkUrl;
  }

  @override
  int get hashCode =>
      Object.hash(preset, customImagePath, customBase64, networkUrl);
}

final userAvatarProvider =
    NotifierProvider<UserAvatarNotifier, UserAvatarState>(
      UserAvatarNotifier.new,
    );

class UserAvatarNotifier extends Notifier<UserAvatarState> {
  @override
  UserAvatarState build() {
    _load();
    return const UserAvatarState(preset: AppAvatarPreset.adminM);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetId = prefs.getString(_kAvatarPresetKey);
    final customPath = prefs.getString(_kAvatarCustomPathKey);
    final base64Data = prefs.getString(_kAvatarBase64Key);
    final url = prefs.getString(_kAvatarNetworkUrlKey);

    state = UserAvatarState(
      preset: presetId != null
          ? AppAvatarPreset.fromId(presetId)
          : (customPath == null && base64Data == null && url == null
                ? AppAvatarPreset.adminM
                : null),
      customImagePath: customPath,
      customBase64: base64Data,
      networkUrl: url,
    );
  }

  Future<void> setPreset(AppAvatarPreset preset) async {
    state = state.copyWith(preset: preset, clearCustom: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAvatarPresetKey, preset.id);
    await prefs.remove(_kAvatarCustomPathKey);
    await prefs.remove(_kAvatarBase64Key);
    await prefs.remove(_kAvatarNetworkUrlKey);
  }

  Future<void> setCustomImage({String? filePath, String? base64Data}) async {
    state = state.copyWith(
      clearPreset: true,
      customImagePath: filePath,
      customBase64: base64Data,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAvatarPresetKey);
    if (filePath != null) {
      await prefs.setString(_kAvatarCustomPathKey, filePath);
    } else {
      await prefs.remove(_kAvatarCustomPathKey);
    }
    if (base64Data != null) {
      await prefs.setString(_kAvatarBase64Key, base64Data);
    } else {
      await prefs.remove(_kAvatarBase64Key);
    }
  }

  Future<void> setNetworkUrl(String url) async {
    state = state.copyWith(
      clearPreset: true,
      clearCustom: true,
      networkUrl: url,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAvatarPresetKey);
    await prefs.remove(_kAvatarCustomPathKey);
    await prefs.remove(_kAvatarBase64Key);
    await prefs.setString(_kAvatarNetworkUrlKey, url);
  }

  Future<void> resetDefault() async {
    state = const UserAvatarState(preset: AppAvatarPreset.adminM);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAvatarPresetKey);
    await prefs.remove(_kAvatarCustomPathKey);
    await prefs.remove(_kAvatarBase64Key);
    await prefs.remove(_kAvatarNetworkUrlKey);
  }
}
