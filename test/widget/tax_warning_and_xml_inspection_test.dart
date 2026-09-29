import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
import 'package:flutter_app/features/tax/screens/tax_estimate_screen.dart';
import 'package:flutter_app/features/tax/services/tax_service.dart';
import 'package:flutter_app/features/finance/presentation/tax_declaration_screen.dart';
import 'package:flutter_app/features/finance/providers/finance_provider.dart';
import 'package:flutter_app/features/finance/providers/tax_reference_provider.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260929_112200_taxwarn/screenshots';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary = tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final path = '$_runDir/$fileName';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

class _MockTaxService extends TaxService {
  _MockTaxService() : super(_FakeApiClient());

  Map<String, dynamic> mockEstimateData = {
    'shopName': 'Cửa hàng SmartStock Mẫu',
    'taxCode': '0101234567',
    'totalRevenue': 150000000.0,
    'vatOwed': 1500000.0,
    'pitOwed': 750000.0,
    'yearlyRevenue': 650000000.0,
    'taxExempt': false,
  };

  bool exportCalled = false;
  String? lastExportPeriod;
  String? lastExportYear;

  @override
  Future<Map<String, dynamic>> getTaxEstimate(
    String period,
    String year,
  ) async {
    return mockEstimateData;
  }

  @override
  Future<void> exportHTKK(String period, String year) async {
    exportCalled = true;
    lastExportPeriod = period;
    lastExportYear = year;
  }
}

class _FakeApiClient extends ApiClient {}

class _LoadedTaxConfigNotifier extends TaxConfigNotifier {
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
      policySourceCode: 'NĐ 141/2026/NĐ-CP & TT 40/2021/TT-BTC',
      fiscalYear: 2026,
      isLoading: false,
      errorMessage: null,
    );
  }
}

final _mockReferenceData = TaxReferenceData(
  forms: const [
    TaxDeclarationFormReference(
      code: '01/CNKD',
      name: 'Tờ khai 01/CNKD (Thông tư 40/2021/TT-BTC)',
      description:
          'Tờ khai thuế đối với cá nhân kinh doanh nộp thuế theo phương pháp kê khai hoặc khoán doanh thu.',
      status: 'READY',
      iconKey: 'article',
    ),
    TaxDeclarationFormReference(
      code: '01-2/BK-HĐKD',
      name: 'Phụ lục 01-2/BK-HĐKD',
      description:
          'Bảng kê chi tiết hoạt động kinh doanh vật tư, hàng hóa và dịch vụ bán lẻ.',
      status: 'READY',
      iconKey: 'list',
    ),
  ],
  supportLinks: const [
    TaxSupportLinkReference(
      title: 'Cổng thông tin Thuế điện tử',
      description: 'Nộp tờ khai XML trực tuyến tới Tổng cục Thuế',
      url: 'https://thuedientu.gdt.gov.vn',
      iconKey: 'account_balance',
      colorRole: 'primary',
    ),
  ],
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Tax Estimate Screen - Capture Normal, Warning & Exempt States', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockTaxService = _MockTaxService();
    const estimateKey = ValueKey('tax_estimate_key');

    // 1. Normal State: Above exemption threshold
    mockTaxService.mockEstimateData = {
      'shopName': 'Cửa hàng SmartStock Mẫu',
      'taxCode': '0101234567',
      'totalRevenue': 150000000.0,
      'vatOwed': 1500000.0,
      'pitOwed': 750000.0,
      'yearlyRevenue': 650000000.0,
      'taxExempt': false,
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxConfigProvider.overrideWith(() => _LoadedTaxConfigNotifier()),
          taxServiceProvider.overrideWithValue(mockTaxService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const RepaintBoundary(
            key: estimateKey,
            child: TaxEstimateScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, estimateKey, '01_tax_estimate_normal.png');

    // Verify UI components
    expect(find.text('Ước Tính & Xuất Thuế (HTKK)'), findsOneWidget);
    expect(find.text('Cảnh báo Nghĩa vụ Thuế'), findsOneWidget);
    expect(find.text('Kết xuất tờ khai (XML / PDF)'), findsOneWidget);

    // 2. Near Threshold Warning State
    mockTaxService.mockEstimateData = {
      'shopName': 'Cửa hàng SmartStock Mẫu',
      'taxCode': '0101234567',
      'totalRevenue': 85000000.0,
      'vatOwed': 850000.0,
      'pitOwed': 425000.0,
      'yearlyRevenue': 920000000.0,
      'taxExempt': false,
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxConfigProvider.overrideWith(() => _LoadedTaxConfigNotifier()),
          taxServiceProvider.overrideWithValue(mockTaxService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const RepaintBoundary(
            key: estimateKey,
            child: TaxEstimateScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, estimateKey, '02_tax_warning_near_threshold.png');

    // 3. Tax Exempt State: Below Threshold
    mockTaxService.mockEstimateData = {
      'shopName': 'Cửa hàng SmartStock Mẫu',
      'taxCode': '0101234567',
      'totalRevenue': 25000000.0,
      'vatOwed': 0.0,
      'pitOwed': 0.0,
      'yearlyRevenue': 80000000.0,
      'taxExempt': true,
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxConfigProvider.overrideWith(() => _LoadedTaxConfigNotifier()),
          taxServiceProvider.overrideWithValue(mockTaxService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const RepaintBoundary(
            key: estimateKey,
            child: TaxEstimateScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, estimateKey, '03_tax_estimate_exempt.png');

    // 4. Test Export button opens format dialog (XML vs PDF) and selecting XML triggers exportHTKK
    final exportBtn = find.text('Kết xuất tờ khai (XML / PDF)');
    expect(exportBtn, findsOneWidget);
    await tester.tap(exportBtn);
    await tester.pumpAndSettle();

    expect(find.text('Chọn định dạng xuất tờ khai'), findsOneWidget);
    expect(find.text('Tệp dữ liệu XML (Chuẩn nộp HTKK)'), findsOneWidget);
    expect(find.text('Bản in PDF (Tờ khai Mẫu 01/CNKD)'), findsOneWidget);

    await tester.tap(find.text('Tệp dữ liệu XML (Chuẩn nộp HTKK)'));
    await tester.pumpAndSettle();
    expect(mockTaxService.exportCalled, isTrue);
  });

  testWidgets('Tax Declaration Screen - Desktop, Mobile & Submission Guidance', (
    tester,
  ) async {
    final mockTaxService = _MockTaxService();
    const declarationKey = ValueKey('tax_declaration_key');

    // 4. Desktop Layout (1440x900)
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxConfigProvider.overrideWith(() => _LoadedTaxConfigNotifier()),
          taxReferenceDataProvider.overrideWith(
            (ref) => Future.value(_mockReferenceData),
          ),
          profitLossProvider.overrideWith(
            (ref, args) => Future.value({
              'revenue': 120000000.0,
              'cost': 80000000.0,
              'profit': 40000000.0,
            }),
          ),
          taxServiceProvider.overrideWithValue(mockTaxService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const RepaintBoundary(
            key: declarationKey,
            child: TaxDeclarationScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, declarationKey, '04_tax_declaration_desktop.png');

    expect(find.text('Kê khai thuế'), findsOneWidget);
    expect(find.text('Mẫu kê khai'), findsOneWidget);
    expect(
      find.text('Tờ khai 01/CNKD (Thông tư 40/2021/TT-BTC)'),
      findsOneWidget,
    );

    // 5. Mobile Layout (390x844)
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taxConfigProvider.overrideWith(() => _LoadedTaxConfigNotifier()),
          taxReferenceDataProvider.overrideWith(
            (ref) => Future.value(_mockReferenceData),
          ),
          profitLossProvider.overrideWith(
            (ref, args) => Future.value({
              'revenue': 120000000.0,
              'cost': 80000000.0,
              'profit': 40000000.0,
            }),
          ),
          taxServiceProvider.overrideWithValue(mockTaxService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(AppColors.primary),
          home: const RepaintBoundary(
            key: declarationKey,
            child: TaxDeclarationScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, declarationKey, '05_tax_declaration_mobile.png');

    // 6. Test and Capture "Nộp tờ khai" Submission Guidance Modal
    final submitButtons = find.text('Nộp tờ khai');
    expect(submitButtons, findsWidgets);
    await tester.tap(submitButtons.first);
    await tester.pumpAndSettle();
    await _capture(tester, declarationKey, '06_tax_submission_guidance.png');
    expect(
      find.text(
        'Ứng dụng chưa tích hợp ký điện tử và nộp tờ khai trực tuyến. Hãy xuất XML đã kiểm tra, sau đó nộp bằng kênh chính thức của cơ quan thuế.',
      ),
      findsOneWidget,
    );
  });
}
