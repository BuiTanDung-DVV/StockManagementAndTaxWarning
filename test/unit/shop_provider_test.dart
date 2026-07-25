import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
