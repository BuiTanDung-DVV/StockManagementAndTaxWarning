import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inactive owner membership never grants owner access', () {
    const state = ShopState(
      currentShopId: 1,
      memberType: 'OWNER',
      status: 'ACTIVE',
      membershipEnabled: false,
      userShops: [
        {
          'shopId': 1,
          'memberType': 'OWNER',
          'status': 'ACTIVE',
          'isActive': false,
        },
      ],
      isLoading: false,
    );

    expect(state.isOwner, isFalse);
    expect(state.isActive, isFalse);
    expect(state.hasPermission('settings', 'full'), isFalse);
  });

  test('pending membership never grants configured permissions', () {
    const state = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'PENDING',
      permissions: {'sales': 'full'},
      userShops: [
        {
          'shopId': 1,
          'memberType': 'EMPLOYEE',
          'status': 'PENDING',
          'isActive': true,
          'permissions': {'sales': 'full'},
        },
      ],
      isLoading: false,
    );

    expect(state.hasPermission('sales', 'view'), isFalse);
  });

  test('all-shops mode is view-only across permitted active shops', () {
    const state = ShopState(
      currentShopName: 'Tất cả cửa hàng (Tổng quát)',
      status: 'ACTIVE',
      isAllShops: true,
      userShops: [
        {
          'shopId': 1,
          'memberType': 'OWNER',
          'status': 'ACTIVE',
          'isActive': true,
        },
        {
          'shopId': 2,
          'memberType': 'EMPLOYEE',
          'status': 'ACTIVE',
          'isActive': true,
          'permissions': {'inventory': 'view'},
        },
      ],
      isLoading: false,
    );

    expect(state.isOwner, isFalse);
    expect(state.hasPermission('sales'), isTrue);
    expect(state.hasPermission('inventory'), isTrue);
    expect(state.hasPermission('finance'), isTrue);
    expect(state.hasPermission('sales', 'edit'), isFalse);
    expect(state.hasPermission('settings'), isFalse);
  });

  test('switches from all shops to a shop whose id comes as text', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(shopProvider.notifier);

    notifier.initFromLogin([
      {
        'shopId': '1',
        'shopName': 'Cửa hàng Một',
        'memberType': 'OWNER',
        'status': 'ACTIVE',
        'isActive': true,
      },
      {
        'shopId': '2',
        'shopName': 'Cửa hàng Hai',
        'memberType': 'OWNER',
        'status': 'ACTIVE',
        'isActive': true,
      },
    ]);
    notifier.switchShop(-1);
    expect(container.read(shopProvider).isAllShops, isTrue);

    notifier.switchShop(2);
    final selected = container.read(shopProvider);
    expect(selected.isAllShops, isFalse);
    expect(selected.currentShopId, 2);
    expect(selected.currentShopName, 'Cửa hàng Hai');
  });
}
