import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';
import '../../sales/providers/sales_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../suppliers/providers/supplier_provider.dart';
import '../../settings/providers/system_provider.dart';
import '../../settings/providers/notification_provider.dart';
import '../../settings/providers/costing_provider.dart';
import '../../settings/providers/tax_config_provider.dart';

// ─── Auth State ───
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? token;
  final Map<String, dynamic>? user;
  final String? error;
  final String? accountType; // 'SHOP' | 'PERSONAL'
  final bool isOnboarded;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.token,
    this.user,
    this.error,
    this.accountType,
    this.isOnboarded = true,
  });
  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? token,
    Map<String, dynamic>? user,
    String? error,
    String? accountType,
    bool? isOnboarded,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    token: token ?? this.token,
    user: user ?? this.user,
    error: error,
    accountType: accountType ?? this.accountType,
    isOnboarded: isOnboarded ?? this.isOnboarded,
  );

  bool get isShopOwner => accountType == 'SHOP';
}

// ─── Auth Notifier ───
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> init() async {
    await _api.loadToken();
    if (_api.token != null) {
      state = AuthState(isLoggedIn: true, token: _api.token);
      // Reload shops on app restart
      await ref.read(shopProvider.notifier).loadUserShops();
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final token = data['access_token'] ?? data['token'] ?? '';
      final refreshToken = data['refresh_token'];
      await _api.saveToken(token, refreshToken);

      final user = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'])
          : null;
      final accountType = user?['accountType'] as String? ?? 'PERSONAL';
      final isOnboarded = user?['isOnboarded'] as bool? ?? true;

      // Initialize shop provider with shops from login response
      final shops = data['shops'] as List? ?? [];
      ref.read(shopProvider.notifier).initFromLogin(shops);

      state = AuthState(
        isLoggedIn: true,
        token: token,
        user: user,
        accountType: accountType,
        isOnboarded: isOnboarded,
      );

      return true;
    } catch (e) {
      String msg = 'Không thể đăng nhập. Vui lòng thử lại';
      if (e is DioException && e.error is ApiException) {
        msg = (e.error as ApiException).message;
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  void updateUser(Map<String, dynamic> updated) {
    state = state.copyWith(user: updated);
  }

  Future<bool> completeOnboarding({
    String? username,
    String? phone,
    required String fullName,
    String? shopName,
    String? ownerName,
    String? address,
    String? shopCode,
    String? shopId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final Map<String, dynamic> data = {'fullName': fullName};
      if (username != null && username.isNotEmpty) { data['username'] = username; }
      if (phone != null && phone.isNotEmpty) { data['phone'] = phone; }
      if (shopName != null && shopName.isNotEmpty) { data['shopName'] = shopName; }
      if (ownerName != null && ownerName.isNotEmpty) { data['ownerName'] = ownerName; }
      if (address != null && address.isNotEmpty) { data['address'] = address; }
      if (shopCode != null && shopCode.isNotEmpty) { data['shopCode'] = shopCode; }
      if (shopId != null && shopId.isNotEmpty) { data['shopId'] = shopId; }

      final response = await _api.post('/auth/complete-onboarding', data: data);
      final updatedUser = response['user'] is Map
          ? Map<String, dynamic>.from(response['user'])
          : null;
      // Reload shops to get the updated status (ACTIVE / PENDING)
      await ref.read(shopProvider.notifier).loadUserShops();

      if (updatedUser != null) {
        state = state.copyWith(
          user: {...?state.user, ...updatedUser},
          isOnboarded: true,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isOnboarded: true, isLoading: false);
      }

      return true;
    } catch (e) {
      String msg = 'Không thể hoàn tất onboarding. Vui lòng thử lại.';
      if (e is DioException && e.error is ApiException) {
        msg = (e.error as ApiException).message;
      } else if (e.toString().contains('bắt buộc') ||
          e.toString().contains('Không tìm thấy')) {
        msg = e.toString();
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    state = const AuthState();
    await _api.clearToken();
    ref.read(shopProvider.notifier).clear();

    // Invalidate all data providers to clear cache and prevent data leaks
    ref.invalidate(salesListProvider);
    ref.invalidate(salesSummaryProvider);
    ref.invalidate(salesDetailProvider);
    ref.invalidate(stockProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(warehousesProvider);
    ref.invalidate(xntReportProvider);
    ref.invalidate(expiringProductsProvider);
    ref.invalidate(slowMovingProvider);
    ref.invalidate(purchaseOrdersProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(cashSummaryProvider);
    ref.invalidate(profitLossProvider);
    ref.invalidate(invoiceReconciliationProvider);
    ref.invalidate(expensesByCategoryProvider);
    ref.invalidate(dailyClosingsListProvider);
    ref.invalidate(dailyClosingProvider);
    ref.invalidate(cashAccountsProvider);
    ref.invalidate(forecastsProvider);
    ref.invalidate(budgetPlansProvider);
    ref.invalidate(invoiceListProvider);
    ref.invalidate(invoiceSummaryProvider);
    ref.invalidate(purchasesNoInvoiceProvider);
    ref.invalidate(taxObligationsProvider);
    ref.invalidate(customerListProvider);
    ref.invalidate(customerDetailProvider);
    ref.invalidate(debtAgingProvider);
    ref.invalidate(overdueDebtsProvider);
    ref.invalidate(productListProvider);
    ref.invalidate(productDetailProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(supplierListProvider);
    ref.invalidate(supplierDetailProvider);
    ref.invalidate(shopProfileProvider);
    ref.invalidate(activityLogsProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(costingProvider);
    ref.invalidate(taxConfigProvider);
  }

  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _api.get(
        '/auth/search-shops',
        params: {'q': query},
      );
      if (response is List) {
        return response
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
