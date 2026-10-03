import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/features/auth/providers/auth_provider.dart';
import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter_app/features/settings/presentation/shop_profile_screen.dart';
import 'package:flutter_app/features/settings/presentation/staff_management_screen.dart';
import 'package:flutter_app/features/settings/presentation/tax_config_screen.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import 'package:flutter_app/features/settings/providers/tax_config_provider.dart';
import '../support/load_ui_fonts.dart';

const String _runDir =
    'BA_DOCUMENTS/TEST_RUNS/run_20260930_settings/screenshots';

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

class _FakeTaxConfigNotifier extends TaxConfigNotifier {
  final TaxConfig _initial;
  _FakeTaxConfigNotifier(this._initial);

  @override
  TaxConfig build() => _initial;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super();

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    if (path.contains('/shop-members/pending')) {
      return <Map<String, dynamic>>[];
    }
    if (path.contains('/shop-roles')) {
      return [
        {
          'id': 1,
          'name': 'Quản lý kho',
          'description': 'Toàn quyền điều hành kho và bán hàng',
        },
        {
          'id': 2,
          'name': 'Thu ngân POS',
          'description': 'Bán hàng POS và kết ca',
        },
        {
          'id': 3,
          'name': 'Kế toán viên',
          'description': 'Nhập xuất hóa đơn và đối soát thuế',
        },
      ];
    }
    if (path.contains('/shop-members')) {
      return [
        {
          'id': 1,
          'username': 'admin',
          'fullName': 'Bùi Tấn Dũng (Chủ hộ kinh doanh)',
          'roleName': 'Chủ sở hữu',
          'role': {'id': 1, 'name': 'Chủ sở hữu'},
          'status': 'ACTIVE',
          'isOwner': true,
        },
        {
          'id': 2,
          'username': 'nv_thungan',
          'fullName': 'Nguyễn Thị Hoa',
          'roleName': 'Thu ngân POS',
          'role': {'id': 2, 'name': 'Thu ngân POS'},
          'status': 'ACTIVE',
          'isOwner': false,
        },
        {
          'id': 3,
          'username': 'nv_thukho',
          'fullName': 'Trần Văn Nam',
          'roleName': 'Quản lý kho',
          'role': {'id': 1, 'name': 'Quản lý kho'},
          'status': 'ACTIVE',
          'isOwner': false,
        },
      ];
    }
    return {};
  }
}

class _FakeSystemRepository extends SystemRepository {
  _FakeSystemRepository() : super(_FakeApiClient());

  @override
  Future<Map<String, dynamic>> getShopProfile() async {
    return {
      'shopName': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
      'shop_name': 'Cửa hàng Thực phẩm & Tạp hóa Thông minh',
      'phone': '0901234567',
      'address': '123 Đường Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
      'taxCode': '0312345678',
      'tax_code': '0312345678',
      'email': 'contact@smartstock.vn',
      'website': 'https://smartstock-tax.vercel.app',
      'ownerName': 'Bùi Tấn Dũng',
      'owner_name': 'Bùi Tấn Dũng',
      'ownerId': '079090123456',
      'bizLicense': 'GPKD-41A8012345',
      'receiptFooter': 'Cảm ơn quý khách và hẹn gặp lại!',
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
    token: 'fake_jwt_token',
    user: {
      'id': 1,
      'fullName': 'Bùi Tấn Dũng',
      'email': 'tandung@smartstock.vn',
      'role': 'OWNER',
    },
  );

  final fakeTaxConfig = createDefaultVerifiedTaxConfig(
    businessType: BusinessType.distribution,
  );

  group('Settings & System Visual Audit', () {
    testWidgets('Capture Settings Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('settings_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            systemRepoProvider.overrideWithValue(_FakeSystemRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '01_settings_overview_desktop.png');

      expect(find.text('Cài đặt hệ thống'), findsOneWidget);
    });

    testWidgets('Capture Settings Screen Mobile (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('settings_mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            authProvider.overrideWith(() => _FakeAuthNotifier(fakeAuthState)),
            systemRepoProvider.overrideWithValue(_FakeSystemRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '02_settings_overview_mobile.png');

      expect(find.text('Cài đặt hệ thống'), findsOneWidget);
    });

    testWidgets('Capture Tax Config Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('tax_config_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            taxConfigProvider.overrideWith(() => _FakeTaxConfigNotifier(fakeTaxConfig)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: TaxConfigScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '03_tax_config_desktop.png');

      expect(find.text('Cấu hình Thuế 2026'), findsOneWidget);
    });

    testWidgets('Capture Staff Management Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('staff_management_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            apiClientProvider.overrideWithValue(_FakeApiClient()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: StaffManagementScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '04_staff_management_desktop.png');

      expect(find.text('Quản lý nhân viên'), findsOneWidget);
    });

    testWidgets('Capture Shop Profile Screen Desktop (1440x900)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const key = ValueKey('shop_profile_desktop');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProvider.overrideWith(() => _FakeShopNotifier(fakeShopState)),
            systemRepoProvider.overrideWithValue(_FakeSystemRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(AppColors.primary),
            home: const RepaintBoundary(
              key: key,
              child: ShopProfileScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _capture(tester, key, '05_shop_profile_desktop.png');

      expect(find.text('Thông tin cửa hàng'), findsOneWidget);
    });
  });
}
