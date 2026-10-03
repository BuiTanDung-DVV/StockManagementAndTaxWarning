import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/settings/presentation/activity_log_screen.dart';
import 'package:flutter_app/features/settings/presentation/backup_restore_screen.dart';
import 'package:flutter_app/features/settings/presentation/change_password_screen.dart';
import 'package:flutter_app/features/settings/presentation/notification_list_screen.dart';
import 'package:flutter_app/features/settings/presentation/profile_screen.dart';
import 'package:flutter_app/features/settings/presentation/receipt_template_screen.dart';
import 'package:flutter_app/features/settings/providers/notification_provider.dart';
import 'package:flutter_app/features/settings/providers/operations_provider.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_system_advanced/screenshots';

Future<void> _capture(WidgetTester tester, Key key, String fileName) async {
  final boundaryFinder = find.byKey(key);
  final boundary =
      tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  final path = '$_runDir/$fileName';
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}

class _FakeShopNotifier extends ShopNotifier {
  final ShopState _initial;
  _FakeShopNotifier(this._initial);

  @override
  ShopState build() => _initial;

  @override
  Future<void> loadUserShops() async {}
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeNotificationNotifier extends NotificationNotifier {
  final NotificationState _initial;
  _FakeNotificationNotifier(this._initial);

  @override
  NotificationState build() => _initial;

  @override
  Future<void> loadNotifications({int page = 1}) async {}

  @override
  Future<void> loadUnreadCount() async {}
}

class _FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    if (path.contains('profile')) {
      return {
        'id': 1,
        'fullName': 'Bùi Tấn Dũng',
        'email': 'tandung@smartstock.vn',
        'phone': '0901234567',
        'role': 'OWNER',
      };
    }
    return {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {'success': true};
  @override
  Future<dynamic> put(String path, {dynamic data}) async => {'success': true};
}

class _FakeSystemRepository extends SystemRepository {
  _FakeSystemRepository() : super(_FakeApiClient());

  @override
  Future<Map<String, dynamic>> getLogs({int page = 1, int limit = 50}) async {
    return {
      'items': [
        {
          'id': 101,
          'action': 'LOGIN',
          'description': 'Đăng nhập hệ thống thành công từ Chrome / Windows',
          'userName': 'Bùi Tấn Dũng',
          'createdAt': '2026-09-30T08:15:00Z',
        },
        {
          'id': 102,
          'action': 'UPDATE_TAX_CONFIG',
          'description': 'Cập nhật cấu hình thuế Nghị định 141/2026 (GTGT 1%, TNCN 0.5%)',
          'userName': 'Bùi Tấn Dũng',
          'createdAt': '2026-09-30T09:30:00Z',
        },
        {
          'id': 103,
          'action': 'CREATE_ORDER',
          'description': 'Tạo đơn bán hàng POS #HD-2026-0042 trị giá 450.000 ₫',
          'userName': 'Nguyễn Thị Hoa',
          'createdAt': '2026-09-30T10:05:00Z',
        },
      ],
      'total': 3,
      'totalPages': 1,
      'page': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> getShopProfile() async {
    return {
      'shopName': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
      'phone': '0901234567',
      'address': '123 Đường Nguyễn Huệ, Quận 1, TP.HCM',
      'receiptFooter': 'Cảm ơn quý khách và hẹn gặp lại!',
    };
  }
}

class _FakeSettingsOperationsRepository extends SettingsOperationsRepository {
  _FakeSettingsOperationsRepository() : super(_FakeApiClient());

  @override
  Future<Map<String, dynamic>> shopProfile() async {
    return {
      'shopName': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
      'phone': '0901234567',
      'address': '123 Đường Nguyễn Huệ, Quận 1, TP.HCM',
      'receiptFooter': 'Cảm ơn quý khách và hẹn gặp lại!',
      'receiptTemplateConfig': {
        'paperSize': '80mm',
        'title': 'PHIẾU BÁN HÀNG',
        'footer': 'Cảm ơn quý khách và hẹn gặp lại!',
        'showLogo': true,
        'showShopInfo': true,
        'showCustomer': true,
        'showSku': true,
        'showDiscount': true,
        'showPayment': true,
        'showQr': true,
      },
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadUiFonts();
    SharedPreferences.setMockInitialValues({});
  });

  const fakeShopState = ShopState(
    currentShopId: 1,
    currentShopName: 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
    memberType: 'OWNER',
    status: 'ACTIVE',
    userShops: [
      {
        'id': 1,
        'name': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
        'role': 'OWNER',
      },
    ],
  );

  const fakeAuthState = AuthState(
    isLoggedIn: true,
    token: 'fake_jwt_token',
    user: {
      'id': 1,
      'fullName': 'Bùi Tấn Dũng',
      'email': 'tandung@smartstock.vn',
      'role': 'OWNER',
    },
  );

  const fakeNotifState = NotificationState(
    unreadCount: 2,
    items: [
      {
        'id': 1,
        'title': 'Cảnh báo tồn kho tối thiểu',
        'body': 'Sữa tươi Tiệt trùng Vinamilk còn 3 hộp dưới mức an toàn (10 hộp).',
        'isRead': false,
        'createdAt': '2026-09-30T10:00:00Z',
      },
      {
        'id': 2,
        'title': 'Nhắc hạn nộp tờ khai thuế',
        'body': 'Kỳ khai thuế Quý 3/2026 sẽ đến hạn vào ngày 31/10/2026.',
        'isRead': false,
        'createdAt': '2026-09-30T08:30:00Z',
      },
    ],
  );

  group('System Operations Visual Audit', () {
    testWidgets('01_profile_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('profile_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      await _capture(tester, key, '01_profile_desktop.png');
    });

    testWidgets('02_change_password_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('change_password_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ChangePasswordScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordScreen), findsOneWidget);
      await _capture(tester, key, '02_change_password_desktop.png');
    });

    testWidgets('03_backup_restore_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('backup_restore_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            settingsOperationsRepositoryProvider.overrideWithValue(
              _FakeSettingsOperationsRepository(),
            ),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: BackupRestoreScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackupRestoreScreen), findsOneWidget);
      await _capture(tester, key, '03_backup_restore_desktop.png');
    });

    testWidgets('04_notification_list_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('notification_list_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            notificationProvider.overrideWith(
              () => _FakeNotificationNotifier(fakeNotifState),
            ),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: NotificationListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationListScreen), findsOneWidget);
      await _capture(tester, key, '04_notification_list_desktop.png');
    });

    testWidgets('05_activity_log_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('activity_log_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            systemRepoProvider.overrideWithValue(_FakeSystemRepository()),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ActivityLogScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActivityLogScreen), findsOneWidget);
      await _capture(tester, key, '05_activity_log_desktop.png');
    });

    testWidgets('06_receipt_template_desktop', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('receipt_template_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            settingsOperationsRepositoryProvider.overrideWithValue(
              _FakeSettingsOperationsRepository(),
            ),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ReceiptTemplateScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptTemplateScreen), findsOneWidget);
      await _capture(tester, key, '06_receipt_template_desktop.png');
    });
  });
}
