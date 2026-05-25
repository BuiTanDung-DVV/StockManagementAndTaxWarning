import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/utils/toast_service.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load auth token from storage before app starts
  final apiClient = ApiClient();
  await apiClient.loadToken();
  
  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
      ],
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
      scaffoldMessengerKey: ToastService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(brandColor.color),
      darkTheme: AppTheme.darkTheme(brandColor.color),
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      routerConfig: router,
    );
  }
}
