import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/localization/app_language.dart';
import 'package:flutter_app/core/localization/app_localizations.dart';
import 'package:flutter_app/core/localization/locale_provider.dart';
import 'package:flutter_app/core/localization/translations/app_translations.dart';
import 'package:flutter_app/core/localization/translations/en.dart';
import 'package:flutter_app/core/localization/translations/vi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization Unit Tests - AppLanguage', () {
    test('AppLanguage contains vi and en with valid locales', () {
      expect(AppLanguage.vi.code, 'vi');
      expect(AppLanguage.vi.countryCode, 'VN');
      expect(AppLanguage.vi.locale, const Locale('vi', 'VN'));
      expect(AppLanguage.vi.flag, '🇻🇳');

      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.en.countryCode, 'US');
      expect(AppLanguage.en.locale, const Locale('en', 'US'));
      expect(AppLanguage.en.flag, '🇺🇸');
    });

    test('AppLanguage.fromCode handles various formats and defaults to vi', () {
      expect(AppLanguage.fromCode('vi'), AppLanguage.vi);
      expect(AppLanguage.fromCode('vi_VN'), AppLanguage.vi);
      expect(AppLanguage.fromCode('vi-VN'), AppLanguage.vi);
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('en_US'), AppLanguage.en);
      expect(AppLanguage.fromCode('en-US'), AppLanguage.en);
      expect(AppLanguage.fromCode(''), AppLanguage.vi);
      expect(AppLanguage.fromCode(null), AppLanguage.vi);
      expect(AppLanguage.fromCode('fr'), AppLanguage.vi);
    });

    test('AppLanguage.fromLocale resolves correctly', () {
      expect(AppLanguage.fromLocale(const Locale('en')), AppLanguage.en);
      expect(AppLanguage.fromLocale(const Locale('vi')), AppLanguage.vi);
      expect(AppLanguage.fromLocale(null), AppLanguage.vi);
    });
  });

  group('Localization Unit Tests - Translation Dictionaries Integrity', () {
    const vi = ViTranslations();
    const en = EnTranslations();

    void verifyNonEmpty(String Function(AppTranslations) getter, String name) {
      final viVal = getter(vi);
      final enVal = getter(en);
      expect(viVal.isNotEmpty, isTrue, reason: 'VI $name should not be empty');
      expect(enVal.isNotEmpty, isTrue, reason: 'EN $name should not be empty');
    }

    test('Common translations are non-empty for both vi and en', () {
      verifyNonEmpty((t) => t.common.appTitle, 'appTitle');
      verifyNonEmpty((t) => t.common.save, 'save');
      verifyNonEmpty((t) => t.common.cancel, 'cancel');
      verifyNonEmpty((t) => t.common.delete, 'delete');
      verifyNonEmpty((t) => t.common.edit, 'edit');
      verifyNonEmpty((t) => t.common.search, 'search');
      verifyNonEmpty((t) => t.common.filter, 'filter');
      verifyNonEmpty((t) => t.common.loading, 'loading');
      verifyNonEmpty((t) => t.common.retry, 'retry');
      verifyNonEmpty((t) => t.common.confirm, 'confirm');
    });

    test('Auth translations are non-empty for both vi and en', () {
      verifyNonEmpty((t) => t.auth.login, 'login');
      verifyNonEmpty((t) => t.auth.register, 'register');
      verifyNonEmpty((t) => t.auth.forgotPassword, 'forgotPassword');
      verifyNonEmpty((t) => t.auth.email, 'email');
      verifyNonEmpty((t) => t.auth.password, 'password');
      verifyNonEmpty((t) => t.auth.logout, 'logout');
      verifyNonEmpty((t) => t.auth.logoutConfirmTitle, 'logoutConfirmTitle');
      verifyNonEmpty((t) => t.auth.logoutConfirmMsg, 'logoutConfirmMsg');
    });

    test('Nav translations are non-empty for both vi and en', () {
      verifyNonEmpty((t) => t.nav.home, 'home');
      verifyNonEmpty((t) => t.nav.sales, 'sales');
      verifyNonEmpty((t) => t.nav.inventory, 'inventory');
      verifyNonEmpty((t) => t.nav.finance, 'finance');
      verifyNonEmpty((t) => t.nav.settings, 'settings');
      verifyNonEmpty((t) => t.nav.helpCenter, 'helpCenter');
      verifyNonEmpty((t) => t.nav.viewingScope, 'viewingScope');
    });

    test('Settings translations are non-empty for both vi and en', () {
      verifyNonEmpty((t) => t.settings.systemSettings, 'systemSettings');
      verifyNonEmpty((t) => t.settings.subtitle, 'subtitle');
      verifyNonEmpty((t) => t.settings.searchHint, 'searchHint');
      verifyNonEmpty((t) => t.settings.language, 'language');
      verifyNonEmpty((t) => t.settings.selectLanguage, 'selectLanguage');
      verifyNonEmpty((t) => t.settings.brandColor, 'brandColor');
      verifyNonEmpty(
        (t) => t.settings.appearanceAndTheme,
        'appearanceAndTheme',
      );
      verifyNonEmpty((t) => t.settings.appWallpaper, 'appWallpaper');
      verifyNonEmpty((t) => t.settings.userAvatar, 'userAvatar');
      verifyNonEmpty((t) => t.settings.costingMethod, 'costingMethod');
      verifyNonEmpty((t) => t.settings.taxConfig, 'taxConfig');
      verifyNonEmpty((t) => t.settings.logoutButton, 'logoutButton');

      // Test parameter interpolation
      expect(vi.settings.searchResultsFound(5), contains('5'));
      expect(en.settings.searchResultsFound(5), contains('5'));
      expect(vi.settings.itemsCount(3), contains('3'));
      expect(en.settings.itemsCount(3), contains('3'));
      expect(vi.settings.currentLanguage('Tiếng Việt'), contains('Tiếng Việt'));
      expect(en.settings.currentLanguage('English'), contains('English'));
    });

    test('Tax & Dashboard & Sales translations are non-empty', () {
      verifyNonEmpty((t) => t.tax.taxConfiguration, 'taxConfiguration');
      verifyNonEmpty((t) => t.tax.householdTax, 'householdTax');
      verifyNonEmpty((t) => t.dashboard.overview, 'overview');
      verifyNonEmpty((t) => t.dashboard.revenue, 'revenue');
      verifyNonEmpty((t) => t.inventory.inventoryTitle, 'inventoryTitle');
      verifyNonEmpty((t) => t.sales.salesTitle, 'salesTitle');
    });
  });

  group('Localization Unit Tests - AppLocalizations & Delegate', () {
    test('AppLocalizations.getTranslations returns matching instance', () {
      expect(
        AppLocalizations.getTranslations(AppLanguage.vi),
        isA<ViTranslations>(),
      );
      expect(
        AppLocalizations.getTranslations(AppLanguage.en),
        isA<EnTranslations>(),
      );
    });

    test('Delegate supports vi and en', () {
      const delegate = AppLocalizations.delegate;
      expect(delegate.isSupported(const Locale('vi')), isTrue);
      expect(delegate.isSupported(const Locale('en')), isTrue);
      expect(delegate.isSupported(const Locale('fr')), isFalse);
    });
  });

  group('Localization Unit Tests - LocaleNotifier & Persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('LocaleNotifier starts at AppLanguage.vi by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final lang = container.read(localeProvider);
      expect(lang, AppLanguage.vi);
      expect(container.read(translationsProvider), isA<ViTranslations>());
    });

    test(
      'LocaleNotifier.setLanguage updates state, Intl locale, and persists to SharedPreferences',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(localeProvider.notifier);
        await notifier.setLanguage(AppLanguage.en);

        expect(container.read(localeProvider), AppLanguage.en);
        expect(container.read(translationsProvider), isA<EnTranslations>());
        expect(Intl.defaultLocale, 'en_US');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_language_code'), 'en');

        // Switch back to vi
        await notifier.setLanguage(AppLanguage.vi);
        expect(container.read(localeProvider), AppLanguage.vi);
        expect(container.read(translationsProvider), isA<ViTranslations>());
        expect(Intl.defaultLocale, 'vi_VN');
        expect(prefs.getString('app_language_code'), 'vi');
      },
    );
  });
}
