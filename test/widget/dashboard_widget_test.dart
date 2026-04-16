import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DashboardScreen Should render loading without crashing', (
    tester,
  ) async {
    // Wrap with ProviderScope to allow riverpod tests
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: DashboardScreen())),
      ),
    );

    // Initial state involves loading (Shimmer)
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Check if the quick actions section logic displays correctly
    expect(find.text('Thao tác nhanh'), findsOneWidget);
  });
}
