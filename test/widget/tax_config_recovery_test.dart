import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/tax_config_screen.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';

class _FakeTaxConfigNotifier extends TaxConfigNotifier {
  bool refreshed = false;

  @override
  TaxConfig build() {
    return const TaxConfig(
      businessType: BusinessType.distribution,
      vatReduction20: false,
      thresholds: null, // isLoaded == false
      rates: {},
      isLoading: false,
      errorMessage: 'Không thể kết nối máy chủ cấu hình thuế.',
    );
  }

  @override
  Future<void> refresh() async {
    refreshed = true;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'TaxConfigScreen displays error view, recovery button and disabled save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeNotifier = _FakeTaxConfigNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taxConfigProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const TaxConfigScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify error message and guidance are shown
      expect(
        find.text('Không thể kết nối máy chủ cấu hình thuế.'),
        findsOneWidget,
      );
      expect(
        find.text('Kiểm tra lại kết nối mạng hoặc thử tải lại cấu hình.'),
        findsOneWidget,
      );

      // Verify "Thử lại" button is present and tap triggers refresh()
      final retryButton = find.widgetWithText(ElevatedButton, 'Thử lại');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();
      expect(fakeNotifier.refreshed, isTrue);

      // Verify Save button tooltip indicates config is not ready
      expect(find.byTooltip('Chưa có cấu hình hợp lệ để lưu'), findsOneWidget);

      // Verify FAB is disabled
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
    },
  );
}
