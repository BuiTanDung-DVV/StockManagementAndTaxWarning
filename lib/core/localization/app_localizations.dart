import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_language.dart';
import 'translations/app_translations.dart';
import 'translations/en.dart';
import 'translations/vi.dart';

/// Class quản lý tài nguyên địa phương hóa (Localizations) cho SmartStock
class AppLocalizations {
  final AppLanguage language;
  final AppTranslations translations;

  const AppLocalizations(this.language, this.translations);

  static const ViTranslations _vi = ViTranslations();
  static const EnTranslations _en = EnTranslations();

  /// Lấy instance từ BuildContext
  static AppTranslations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations?.translations ?? _vi;
  }

  /// Lấy ngôn ngữ hiện tại từ BuildContext
  static AppLanguage languageOf(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations?.language ?? AppLanguage.vi;
  }

  /// Lấy bản dịch trực tiếp theo AppLanguage (tiện lợi dùng ngoài widget tree)
  static AppTranslations getTranslations(AppLanguage language) {
    switch (language) {
      case AppLanguage.vi:
        return _vi;
      case AppLanguage.en:
        return _en;
    }
  }

  /// Flutter Localizations Delegate
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['vi', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    final language = AppLanguage.fromLocale(locale);
    final translations = AppLocalizations.getTranslations(language);
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations(language, translations),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Extension tiện lợi trên BuildContext để truy cập nhanh từ điển: `context.tr`
extension LocalizationExtension on BuildContext {
  AppTranslations get tr => AppLocalizations.of(this);
  AppLanguage get currentLanguage => AppLocalizations.languageOf(this);
  bool get isVietnamese => currentLanguage == AppLanguage.vi;
  bool get isEnglish => currentLanguage == AppLanguage.en;
}
