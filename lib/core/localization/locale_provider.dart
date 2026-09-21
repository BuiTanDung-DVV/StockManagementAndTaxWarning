import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_localizations.dart';
import 'translations/app_translations.dart';

const _kLanguageKey = 'app_language_code';

/// Notifier quản lý ngôn ngữ hiển thị toàn ứng dụng
class LocaleNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _loadFromPreferences();
    return AppLanguage.vi;
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kLanguageKey);
      if (savedCode != null && savedCode.isNotEmpty) {
        final language = AppLanguage.fromCode(savedCode);
        state = language;
        _syncIntlLocale(language);
      }
    } catch (_) {
      // Giữ nguyên ngôn ngữ mặc định nếu SharedPreferences có lỗi
    }
  }

  /// Đổi ngôn ngữ và lưu trữ bền vững
  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    state = language;
    _syncIntlLocale(language);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguageKey, language.code);
    } catch (_) {}
  }

  void _syncIntlLocale(AppLanguage language) {
    Intl.defaultLocale = language == AppLanguage.vi ? 'vi_VN' : 'en_US';
  }
}

/// Provider cung cấp ngôn ngữ hiện tại
final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(
  LocaleNotifier.new,
);

/// Provider cung cấp kho từ điển hiện tại (truy cập tiện lợi từ Provider/Service)
final translationsProvider = Provider<AppTranslations>((ref) {
  final language = ref.watch(localeProvider);
  return AppLocalizations.getTranslations(language);
});
