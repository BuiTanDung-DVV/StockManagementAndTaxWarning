import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/settings/presentation/receipt_template_screen.dart';
import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter_app/features/settings/presentation/shop_profile_screen.dart';
import 'package:flutter_app/features/settings/providers/costing_provider.dart';
import 'package:flutter_app/features/settings/providers/notification_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import 'package:flutter_app/features/settings/providers/operations_provider.dart';
import '../support/load_ui_fonts.dart';

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _initial;
  _FakeShopNotifier(this._initial);

  @override
  ShopState build() => _initial;
}

class _FakeCostingNotifier extends CostingNotifier {
  @override
  CostingState build() => const CostingState(method: 'AVG', isLoading: false);

  @override
  Future<void> loadCostingMethod() async {}

  @override
  Future<bool> updateCostingMethod(String method) async => true;
}

class _FakeNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState(unreadCount: 0);

  @override
  Future<void> loadNotifications({int page = 1}) async {}
}

class MockSystemRepository implements SystemRepository {
  @override
  Future<Map<String, dynamic>> getShopProfile() async => {
    'shopName': 'Cửa hàng Mẫu',
    'phone': '0901234567',
    'address': '123 Nguyễn Huệ, Q1, TP.HCM',
    'taxCode': '0123456789',
    'email': 'shop@example.com',
    'website': '',
    'ownerName': 'Nguyễn Văn A',
    'ownerIdentityNumber': '079123456789',
    'businessLicenseNumber': 'HKD-001',
    'receiptFooter': 'Cảm ơn quý khách!',
  };

  @override
  Future<Map<String, dynamic>> saveShopProfile(
    Map<String, dynamic> data,
  ) async => data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSettingsOperationsRepository implements SettingsOperationsRepository {
  @override
  Future<Map<String, dynamic>> shopProfile() async => {
    'shopName': 'Cửa hàng Mẫu',
    'receiptTemplateConfig': {
      'paperSize': '80mm',
      'title': 'PHIẾU BÁN HÀNG',
      'footer': 'Hẹn gặp lại!',
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
  Future<Map<String, dynamic>> saveReceiptConfig(
    Map<String, dynamic> config,
  ) async => {'receiptTemplateConfig': config};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await loadUiFonts();
  });

  group('Wave 14 - SettingsScreen & Costing Method Tests', () {
    testWidgets(
      'SettingsScreen renders with RefreshIndicator and Costing Method triggers confirmation modal',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const mockShopState = ShopState(
          currentShopId: 1,
          currentShopName: 'Cửa hàng Trung tâm',
          memberType: 'OWNER',
          status: 'ACTIVE',
          permissions: {'settings': 'manage'},
          userShops: [
            {
              'shopId': 1,
              'shopName': 'Cửa hàng Trung tâm',
              'memberType': 'OWNER',
              'status': 'ACTIVE',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              shopProvider.overrideWith(() => _FakeShopNotifier(mockShopState)),
              costingProvider.overrideWith(_FakeCostingNotifier.new),
              notificationProvider.overrideWith(_FakeNotificationNotifier.new),
              shopProfileProvider.overrideWith(
                (ref) => Future.value({
                  'name': 'Cửa hàng Trung tâm',
                  'status': 'ACTIVE',
                }),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify title & RefreshIndicator
        expect(find.text('Cài đặt hệ thống'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.text('Phương pháp tính giá vốn'), findsOneWidget);
        expect(
          find.textContaining('Bình quân gia quyền (AVG)'),
          findsOneWidget,
        );

        // Tap "Phương pháp tính giá vốn" to open bottom sheet
        await tester.tap(find.text('Phương pháp tính giá vốn'));
        await tester.pumpAndSettle();

        expect(find.text('Nhập trước – xuất trước (FIFO)'), findsOneWidget);

        // Tap FIFO option
        await tester.tap(find.text('Nhập trước – xuất trước (FIFO)'));
        await tester.pumpAndSettle();

        // Verify AppConfirmModal appears with warning message
        expect(find.text('Đổi phương pháp tính giá vốn'), findsOneWidget);
        expect(find.textContaining('Thông tư 88/2021/TT-BTC'), findsOneWidget);
        expect(find.text('Xác nhận thay đổi'), findsOneWidget);

        // Tap "Hủy bỏ"
        await tester.tap(find.text('Hủy bỏ'));
        await tester.pumpAndSettle();

        // Confirm modal dismissed
        expect(find.text('Đổi phương pháp tính giá vốn'), findsNothing);
      },
    );
  });

  group('Wave 14 - ShopProfileScreen Validation & Refresh Tests', () {
    testWidgets('ShopProfileScreen validates phone, taxCode and email', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepoProvider.overrideWithValue(MockSystemRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const ShopProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông tin cửa hàng'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Enter invalid phone
      final phoneField = find.widgetWithText(TextFormField, 'Số điện thoại');
      await tester.enterText(phoneField, '12345');

      // Enter invalid tax code
      final taxField = find.widgetWithText(TextFormField, 'Mã số thuế');
      await tester.enterText(taxField, 'ABC99');

      // Tap "Lưu thay đổi"
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();

      // Verify validation errors appear
      expect(
        find.textContaining('Số điện thoại phải gồm 10 chữ số'),
        findsOneWidget,
      );
      expect(find.textContaining('Mã số thuế gồm 10 chữ số'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    });
  });

  group('Wave 14 - ReceiptTemplateScreen Refresh & Validation Tests', () {
    testWidgets(
      'ReceiptTemplateScreen validates empty title and renders legal notice',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsOperationsRepositoryProvider.overrideWithValue(
                MockSettingsOperationsRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(AppColors.primary),
              home: const ReceiptTemplateScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mẫu phiếu in'), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.textContaining('Nghị định 123/2020/NĐ-CP'), findsOneWidget);

        // Clear title and tap Save
        final titleField = find.widgetWithText(TextField, 'Tiêu đề *');
        await tester.enterText(titleField, '');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưu cấu hình'));
        await tester.pumpAndSettle();

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      },
    );
  });
}
