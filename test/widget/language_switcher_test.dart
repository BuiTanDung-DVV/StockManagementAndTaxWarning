import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/localization/app_localizations.dart';
import 'package:flutter_app/core/localization/locale_provider.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter_app/features/settings/providers/costing_provider.dart';
import 'package:flutter_app/features/settings/providers/notification_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import '../support/load_ui_fonts.dart';

class _MockShopNotifier extends ShopNotifier {
  @override
  ShopState build() => const ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng Mẫu',
    memberType: 'OWNER',
    status: 'ACTIVE',
    permissions: {'settings': 'manage'},
    userShops: [
      {
        'shopId': 1,
        'shopName': 'Cửa hàng Mẫu',
        'memberType': 'OWNER',
        'status': 'ACTIVE',
      },
    ],
  );
}

class _MockCostingNotifier extends CostingNotifier {
  @override
  CostingState build() => const CostingState(method: 'AVG', isLoading: false);
  @override
  Future<void> loadCostingMethod() async {}
}

class _MockNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState(unreadCount: 0);
  @override
  Future<void> loadNotifications({int page = 1}) async {}
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Language Switcher tests - switch between Vietnamese and English in Settings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(_MockShopNotifier.new),
            costingProvider.overrideWith(_MockCostingNotifier.new),
            notificationProvider.overrideWith(_MockNotificationNotifier.new),
            shopProfileProvider.overrideWith(
              (ref) =>
                  Future.value({'name': 'Cửa hàng Mẫu', 'status': 'ACTIVE'}),
            ),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              final appLang = ref.watch(localeProvider);
              return MaterialApp(
                theme: AppTheme.lightTheme(AppColors.primary),
                locale: appLang.locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('vi', 'VN'),
                  Locale('vi'),
                  Locale('en', 'US'),
                  Locale('en'),
                ],
                home: const SettingsScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initially rendered in Vietnamese
      expect(find.text('Cài đặt hệ thống'), findsOneWidget);
      expect(find.text('Ngôn ngữ hiển thị'), findsOneWidget);
      expect(find.textContaining('Tiếng Việt'), findsWidgets);
      expect(find.text('Phương pháp tính giá vốn'), findsOneWidget);

      // 2. Open Language picker
      await tester.tap(find.text('Ngôn ngữ hiển thị'));
      await tester.pumpAndSettle();

      // Bottom sheet shows language options
      expect(find.text('Chọn ngôn ngữ hiển thị'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // 3. Switch to English
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // 4. Verify whole screen switches to English
      expect(find.text('System Settings'), findsOneWidget);
      expect(find.text('Display Language'), findsOneWidget);
      expect(find.text('Costing Method'), findsOneWidget);
      expect(find.text('Log Out Account'), findsOneWidget);

      // 5. Open Language picker again and switch back to Vietnamese
      await tester.tap(find.text('Display Language'));
      await tester.pumpAndSettle();

      expect(find.text('Select Display Language'), findsOneWidget);
      await tester.tap(find.text('Tiếng Việt'));
      await tester.pumpAndSettle();

      // 6. Verify back to Vietnamese
      expect(find.text('Cài đặt hệ thống'), findsOneWidget);
      expect(find.text('Ngôn ngữ hiển thị'), findsOneWidget);
      expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
    },
  );
}
