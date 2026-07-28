import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DashboardScreen renders empty shop state without crashing', (
    tester,
  ) async {
    // Wrap with ProviderScope to allow riverpod tests
    await tester.pumpWidget(const ProviderScope(child: _DashboardTestApp()));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Chưa có cửa hàng'), findsOneWidget);
  });
}

class _DashboardTestApp extends StatelessWidget {
  const _DashboardTestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme(AppColors.primary),
      home: const Scaffold(body: DashboardScreen()),
    );
  }
}
