import 'package:flutter_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all-shops settings does not request a single-shop profile', () {
    final state = ShopState(
      isAllShops: true,
      isLoading: false,
      currentShopName: 'Tất cả cửa hàng (Tổng quát)',
      userShops: const [
        {'shopId': 1, 'status': 'ACTIVE', 'isActive': true},
        {'shopId': 2, 'status': 'ACTIVE', 'isActive': true},
        {'shopId': 3, 'status': 'INACTIVE', 'isActive': false},
      ],
    );

    expect(settingsShouldLoadShopProfile(state), isFalse);
    expect(settingsActiveShopCount(state), 2);
    expect(
      settingsAllShopsSummary(state),
      'Đang xem dữ liệu tổng hợp của 2 cửa hàng.',
    );
  });

  test('specific-shop settings loads its shop profile', () {
    const state = ShopState(
      currentShopId: 7,
      currentShopName: 'Cửa hàng Kiến Tạo',
      isLoading: false,
    );

    expect(settingsShouldLoadShopProfile(state), isTrue);
  });
}
