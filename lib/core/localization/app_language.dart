import 'package:flutter/material.dart';

/// Danh sách ngôn ngữ được hỗ trợ trong ứng dụng SmartStock
enum AppLanguage {
  vi(
    code: 'vi',
    countryCode: 'VN',
    label: 'Tiếng Việt',
    englishLabel: 'Vietnamese',
    flag: '🇻🇳',
  ),
  en(
    code: 'en',
    countryCode: 'US',
    label: 'English',
    englishLabel: 'Tiếng Anh',
    flag: '🇺🇸',
  );

  final String code;
  final String countryCode;
  final String label;
  final String englishLabel;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.countryCode,
    required this.label,
    required this.englishLabel,
    required this.flag,
  });

  Locale get locale => Locale(code, countryCode);

  /// Chuyển đổi từ mã ngôn ngữ (e.g. 'vi', 'en', 'vi_VN', 'en-US')
  static AppLanguage fromCode(String? code) {
    if (code == null || code.isEmpty) return AppLanguage.vi;
    final normalized = code.toLowerCase().replaceAll('-', '_');
    if (normalized.startsWith('en')) return AppLanguage.en;
    return AppLanguage.vi;
  }

  /// Chuyển đổi từ Locale của Flutter
  static AppLanguage fromLocale(Locale? locale) {
    if (locale == null) return AppLanguage.vi;
    return fromCode(locale.languageCode);
  }
}
