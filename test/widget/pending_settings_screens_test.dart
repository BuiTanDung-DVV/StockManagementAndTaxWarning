import 'package:flutter/material.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/backup_restore_screen.dart';
import 'package:flutter_app/features/settings/presentation/product_category_management_screen.dart';
import 'package:flutter_app/features/settings/presentation/receipt_template_screen.dart';
import 'package:flutter_app/features/settings/presentation/shipping_carrier_screen.dart';
import 'package:flutter_app/features/settings/providers/operations_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOperationsRepository extends SettingsOperationsRepository {
  _FakeOperationsRepository() : super(ApiClient());

  Map<String, dynamic>? createdCategory;
  Map<String, dynamic>? createdCarrier;
  Map<String, dynamic>? savedReceiptConfig;

  @override
  Future<List<dynamic>> categories({String? search}) async => [
    {
      'id': 1,
      'name': 'Vật liệu xây dựng hoàn thiện',
      'description': 'Nhóm hàng đang sử dụng',
      'productCount': 18,
      'isActive': true,
    },
  ];

  @override
  Future<List<dynamic>> carriers() async => [
    {
      'id': 1,
      'name': 'Giao Hàng Nhanh',
      'code': 'GHN',
      'phone': '1900636677',
      'defaultFee': 25000,
      'isActive': true,
    },
  ];

  @override
  Future<Map<String, dynamic>> shopProfile() async => {
    'shopName': 'Cửa hàng kiểm thử',
    'phone': '0900000000',
    'address': 'Hà Nội',
    'receiptTemplateConfig': {
      'paperSize': '80mm',
      'showLogo': true,
      'showShopInfo': true,
      'showCustomer': true,
      'showSku': true,
      'showDiscount': true,
      'showPayment': true,
      'showQr': true,
    },
  };

  @override
  Future<void> createCategory(Map<String, dynamic> data) async {
    createdCategory = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> createCarrier(Map<String, dynamic> data) async {
    createdCarrier = Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>> saveReceiptConfig(
    Map<String, dynamic> config,
  ) async {
    savedReceiptConfig = Map<String, dynamic>.from(config);
    return {'receiptTemplateConfig': config};
  }
}

Widget _app(Widget screen, {_FakeOperationsRepository? repository}) =>
    ProviderScope(
      overrides: [
        settingsOperationsRepositoryProvider.overrideWithValue(
          repository ?? _FakeOperationsRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(AppColors.primary),
        builder: BotToastInit(),
        navigatorObservers: [BotToastNavigatorObserver()],
        home: screen,
      ),
    );

void main() {
  final screens = <String, Widget>{
    'categories': const ProductCategoryManagementScreen(),
    'receipt': const ReceiptTemplateScreen(),
    'carriers': const ShippingCarrierScreen(),
    'backup': const BackupRestoreScreen(),
  };

  for (final width in [390.0, 768.0, 1440.0]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} has no overflow at ${width.toInt()}px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(entry.value));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('category form submits entered values', (tester) async {
    final repository = _FakeOperationsRepository();
    await tester.pumpWidget(
      _app(const ProductCategoryManagementScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm danh mục'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên danh mục *'),
      'Thiết bị tưới',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mô tả'),
      'Dùng trong nông nghiệp',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(repository.createdCategory?['name'], 'Thiết bị tưới');
    expect(
      repository.createdCategory?['description'],
      'Dùng trong nông nghiệp',
    );
  });

  testWidgets('shipping carrier form submits normalized input fields', (
    tester,
  ) async {
    final repository = _FakeOperationsRepository();
    await tester.pumpWidget(
      _app(const ShippingCarrierScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm đơn vị'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên *'),
      'Viettel Post',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Mã *'), 'VTP');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phí mặc định'),
      '30000',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(repository.createdCarrier?['name'], 'Viettel Post');
    expect(repository.createdCarrier?['code'], 'VTP');
    expect(repository.createdCarrier?['defaultFee'], 30000);
  });

  testWidgets('receipt template saves the selected paper size', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeOperationsRepository();
    await tester.pumpWidget(
      _app(const ReceiptTemplateScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Khổ A4'));
    await tester.pump();
    await tester.ensureVisible(find.text('Lưu cấu hình'));
    await tester.tap(find.text('Lưu cấu hình'));
    await tester.pumpAndSettle();

    expect(repository.savedReceiptConfig?['paperSize'], 'A4');
    await tester.pump(const Duration(seconds: 4));
  });
}
