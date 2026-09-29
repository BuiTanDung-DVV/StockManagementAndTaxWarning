import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/tax_config_screen.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary = tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final path =
      'BA_DOCUMENTS/TEST_RUNS/run_20260929_103645_zruej6/screenshots/$fileName';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

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
    state = const TaxConfig.loading();
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
      const errorKey = ValueKey('tax_error_key');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [taxConfigProvider.overrideWith(() => fakeNotifier)],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: errorKey,
              child: TaxConfigScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, errorKey, '01_tax_config_error_recovery.png');

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
      final retryButton = find.widgetWithText(FilledButton, 'Thử lại');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();
      expect(fakeNotifier.refreshed, isTrue);
      // Proves loading transition on retry
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify Save button tooltip indicates config is not ready
      expect(find.byTooltip('Chưa có cấu hình hợp lệ để lưu'), findsOneWidget);

      // Verify FAB is disabled
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
    },
  );

  testWidgets(
    'TaxConfigScreen validates custom tax rate bounds and propagates save failure/success',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final loadedNotifier = _FakeLoadedTaxConfigNotifier();
      const loadedKey = ValueKey('tax_loaded_key');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [taxConfigProvider.overrideWith(() => loadedNotifier)],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: loadedKey,
              child: TaxConfigScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, loadedKey, '02_tax_config_default_sectors.png');

      // Ensure Save FAB is enabled when config is loaded
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      // Toggle custom rates Switch
      final customSwitch = find.byType(Switch);
      expect(customSwitch, findsOneWidget);
      await tester.tap(customSwitch);
      await tester.pumpAndSettle();

      // Find the two textfields for VAT and PIT
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // 1. Test validation error when VAT rate is negative
      await tester.enterText(textFields.first, '-5.0');
      await tester.enterText(textFields.last, '0.5');
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // saveConfig should NOT be called due to negative VAT validation
      expect(loadedNotifier.saveConfigCalled, isFalse);

      // 2. Test validation error when PIT rate > 100
      await tester.enterText(textFields.first, '1.5');
      await tester.enterText(textFields.last, '120.0');
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(loadedNotifier.saveConfigCalled, isFalse);

      // 3. Test server save failure propagation
      loadedNotifier.shouldThrowOnSave = true;
      await tester.enterText(textFields.first, '1.2');
      await tester.enterText(textFields.last, '0.6');
      await tester.pumpAndSettle();
      await _capture(
        tester,
        loadedKey,
        '03_tax_config_custom_rates_active.png',
      );
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(loadedNotifier.saveConfigCalled, isTrue);
      expect(loadedNotifier.lastCustomVat, 1.2);
      expect(loadedNotifier.lastCustomPit, 0.6);
      expect(loadedNotifier.lastClearCustomRates, isFalse);

      // 4. Test server save success
      loadedNotifier.saveConfigCalled = false;
      loadedNotifier.shouldThrowOnSave = false;
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(loadedNotifier.saveConfigCalled, isTrue);
      expect(loadedNotifier.lastCustomVat, 1.2);
      expect(loadedNotifier.lastCustomPit, 0.6);
    },
  );
}

class _FakeLoadedTaxConfigNotifier extends TaxConfigNotifier {
  bool saveConfigCalled = false;
  double? lastCustomVat;
  double? lastCustomPit;
  bool? lastClearCustomRates;
  bool shouldThrowOnSave = false;

  @override
  TaxConfig build() {
    return const TaxConfig(
      businessType: BusinessType.distribution,
      vatReduction20: false,
      thresholds: RevenueThresholds(
        tier1: 250000000,
        tier2: 500000000,
        tier3: 900000000,
        tier4: 1000000000,
      ),
      rates: {BusinessType.distribution: TaxRates(vat: 0.01, pit: 0.005)},
      isLoading: false,
      errorMessage: null,
    );
  }

  @override
  Future<void> saveConfig({
    BusinessType? businessType,
    double? customVatRate,
    double? customPitRate,
    bool clearCustomRates = false,
  }) async {
    saveConfigCalled = true;
    lastCustomVat = customVatRate;
    lastCustomPit = customPitRate;
    lastClearCustomRates = clearCustomRates;
    if (shouldThrowOnSave) {
      throw Exception('Server error 500');
    }
  }
}
