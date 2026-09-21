import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAvatarConfigKey = 'app_user_avatar_config_v1';

class PresetAvatarItem {
  final String id;
  final String label;
  final String emoji;
  final Color bgColor;
  final Color textColor;

  const PresetAvatarItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.bgColor,
    required this.textColor,
  });
}

const List<PresetAvatarItem> kPresetAvatars = [
  PresetAvatarItem(
    id: 'ceo_leader',
    label: 'Chủ doanh nghiệp',
    emoji: '👔',
    bgColor: Color(0xFF0F766E),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'finance_pro',
    label: 'Kế toán trưởng',
    emoji: '📊',
    bgColor: Color(0xFF1E3A8A),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'warehouse_master',
    label: 'Quản lý kho',
    emoji: '📦',
    bgColor: Color(0xFFB45309),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'sales_hero',
    label: 'Bán hàng xuất sắc',
    emoji: '💼',
    bgColor: Color(0xFF15803D),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'tech_expert',
    label: 'Kỹ sư công nghệ',
    emoji: '💻',
    bgColor: Color(0xFF4338CA),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'tax_consultant',
    label: 'Cố vấn thuế',
    emoji: '⚖️',
    bgColor: Color(0xFF7E22CE),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'smart_mascot',
    label: 'Linh vật SmartStock',
    emoji: '🚀',
    bgColor: Color(0xFF0284C7),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'ai_assistant',
    label: 'Trợ lý AI',
    emoji: '🤖',
    bgColor: Color(0xFF0D9488),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'crown_vip',
    label: 'Khách hàng VIP',
    emoji: '👑',
    bgColor: Color(0xFFD97706),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'security_shield',
    label: 'Bảo mật an toàn',
    emoji: '🛡️',
    bgColor: Color(0xFF334155),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'diamond_elite',
    label: 'Kim cương vận hành',
    emoji: '💎',
    bgColor: Color(0xFF0891B2),
    textColor: Colors.white,
  ),
  PresetAvatarItem(
    id: 'store_owner',
    label: 'Chủ shop thân thiện',
    emoji: '🏬',
    bgColor: Color(0xFFBE123C),
    textColor: Colors.white,
  ),
];

@immutable
class UserAvatarConfig {
  final String presetId;
  final String customUrl;
  final bool useLetterFallback;

  const UserAvatarConfig({
    this.presetId = 'ceo_leader',
    this.customUrl = '',
    this.useLetterFallback = false,
  });

  bool get hasCustomUrl => customUrl.trim().isNotEmpty;

  PresetAvatarItem get currentPreset {
    return kPresetAvatars.firstWhere(
      (e) => e.id == presetId,
      orElse: () => kPresetAvatars.first,
    );
  }

  UserAvatarConfig copyWith({
    String? presetId,
    String? customUrl,
    bool? useLetterFallback,
  }) {
    return UserAvatarConfig(
      presetId: presetId ?? this.presetId,
      customUrl: customUrl ?? this.customUrl,
      useLetterFallback: useLetterFallback ?? this.useLetterFallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'presetId': presetId,
    'customUrl': customUrl,
    'useLetterFallback': useLetterFallback,
  };

  factory UserAvatarConfig.fromJson(Map<String, dynamic> json) {
    return UserAvatarConfig(
      presetId: (json['presetId'] as String?) ?? 'ceo_leader',
      customUrl: (json['customUrl'] as String?) ?? '',
      useLetterFallback: (json['useLetterFallback'] as bool?) ?? false,
    );
  }
}

final userAvatarProvider =
    NotifierProvider<UserAvatarNotifier, UserAvatarConfig>(
      UserAvatarNotifier.new,
    );

class UserAvatarNotifier extends Notifier<UserAvatarConfig> {
  @override
  UserAvatarConfig build() {
    _load();
    return const UserAvatarConfig();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAvatarConfigKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = UserAvatarConfig.fromJson(map);
      } catch (_) {}
    }
  }

  Future<void> _persist(UserAvatarConfig config) async {
    state = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAvatarConfigKey, jsonEncode(config.toJson()));
  }

  Future<void> selectPreset(String presetId) =>
      _persist(state.copyWith(presetId: presetId, customUrl: ''));

  Future<void> setCustomUrl(String url) =>
      _persist(state.copyWith(customUrl: url.trim()));

  Future<void> resetToDefault() => _persist(const UserAvatarConfig());
}
