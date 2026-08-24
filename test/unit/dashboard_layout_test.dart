import 'package:flutter_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_app/features/settings/providers/shop_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard moves the primary action out of compact content', () {
    expect(dashboardUsesCompactLayout(390), isTrue);
    expect(dashboardUsesCompactLayout(648), isTrue);
    expect(dashboardUsesCompactLayout(799), isTrue);
    expect(dashboardUsesCompactLayout(800), isFalse);
  });

  test('dashboard disables write actions in all-shops mode', () {
    const aggregate = ShopState(
      isAllShops: true,
      status: 'ACTIVE',
      userShops: [
        {
          'shopId': 1,
          'memberType': 'OWNER',
          'status': 'ACTIVE',
          'isActive': true,
        },
      ],
      isLoading: false,
    );

    expect(aggregate.hasPermission('sales'), isTrue);
    expect(dashboardCanSell(aggregate), isFalse);
  });

  test('sales and dashboard roles can view sales insights without finance', () {
    const salesUser = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'ACTIVE',
      permissions: {'sales': 'view', 'finance': 'none'},
      userShops: [
        {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
      ],
      isLoading: false,
    );
    const dashboardUser = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'ACTIVE',
      permissions: {'dashboard': 'view', 'finance': 'none'},
      userShops: [
        {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
      ],
      isLoading: false,
    );
    const inventoryOnlyUser = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'ACTIVE',
      permissions: {'inventory': 'view'},
      userShops: [
        {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
      ],
      isLoading: false,
    );

    expect(dashboardCanViewSalesInsights(salesUser), isTrue);
    expect(dashboardCanViewSalesInsights(dashboardUser), isTrue);
    expect(dashboardCanViewSalesInsights(inventoryOnlyUser), isFalse);
  });

  test('refresh keeps sales insights independent from finance permission', () {
    final salesOnly = dashboardRefreshPlan(
      hasSalesInsights: true,
      hasFinance: false,
      hasInventory: false,
    );
    final financeOnly = dashboardRefreshPlan(
      hasSalesInsights: false,
      hasFinance: true,
      hasInventory: false,
    );

    expect(salesOnly.sales, isTrue);
    expect(salesOnly.finance, isFalse);
    expect(financeOnly.sales, isFalse);
    expect(financeOnly.finance, isTrue);
  });

  test('recent orders follow sales permission instead of finance permission', () {
    const salesUser = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'ACTIVE',
      permissions: {'sales': 'view', 'finance': 'none'},
      userShops: [
        {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
      ],
      isLoading: false,
    );
    const financeUser = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'ACTIVE',
      permissions: {'sales': 'none', 'finance': 'view'},
      userShops: [
        {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
      ],
      isLoading: false,
    );
    const dashboardUser = ShopState(
      currentShopId: 1,
      memberType: 'EMPLOYEE',
      status: 'ACTIVE',
      permissions: {'dashboard': 'view', 'sales': 'none'},
      userShops: [
        {'shopId': 1, 'memberType': 'EMPLOYEE', 'status': 'ACTIVE'},
      ],
      isLoading: false,
    );

    expect(dashboardCanViewRecentOrders(salesUser), isTrue);
    expect(dashboardCanViewRecentOrders(financeUser), isFalse);
    expect(dashboardCanViewRecentOrders(dashboardUser), isFalse);
  });
}
