import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/utils/toast_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'package:bot_toast/bot_toast.dart';

Duration? _providerRetry(int retryCount, Object error) {
  if (error is ApiException && error.statusCode != null) return null;
  if (retryCount >= 2) return null;
  return Duration(milliseconds: 500 * (retryCount + 1));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  Intl.defaultLocale = 'vi_VN';

  // Load auth token from storage before app starts
  final apiClient = ApiClient();
  await apiClient.loadToken();

  runApp(
    ProviderScope(
      retry: _providerRetry,
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state to react to login/logout
    ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final brandColor = ref.watch(brandColorProvider);
    final router = ref.watch(routerProvider);

    // Đồng bộ hóa AppColors động toàn cục trước khi dựng widget tree
    AppColors.updateColors(brandColor.color, brandColor.isDark);

    return MaterialApp.router(
      title: 'Quản lý Bán hàng & Kho hàng',
      scrollBehavior: const AppScrollBehavior(),
      scaffoldMessengerKey: ToastService.scaffoldMessengerKey,
      builder: BotToastInit(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(brandColor.color),
      darkTheme: AppTheme.darkTheme(brandColor.color),
      themeMode: themeMode,
      locale: const Locale('vi', 'VN'),
      localizationsDelegates: const [
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
      routerConfig: router,
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
