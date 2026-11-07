import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_store_provider.dart';
import '../../../core/offline/offline_session.dart';
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
import '../services/google_auth_service.dart';

// ─── Auth State ───
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? token;
  final Map<String, dynamic>? user;
  final String? error;
  final String? accountType; // 'SHOP' | 'PERSONAL'
  final bool isOnboarded;
  final bool isOfflineSession;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.token,
    this.user,
    this.error,
    this.accountType,
    this.isOnboarded = true,
    this.isOfflineSession = false,
  });
  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    String? token,
    Map<String, dynamic>? user,
    String? error,
    String? accountType,
    bool? isOnboarded,
    bool? isOfflineSession,
  }) => AuthState(
    isLoading: isLoading ?? this.isLoading,
    isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    token: token ?? this.token,
    user: user ?? this.user,
    error: error,
    accountType: accountType ?? this.accountType,
    isOnboarded: isOnboarded ?? this.isOnboarded,
    isOfflineSession: isOfflineSession ?? this.isOfflineSession,
  );

  bool get isShopOwner => accountType == 'SHOP';
}

// ─── Auth Notifier ───
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final api = ref.watch(apiClientProvider);
    void handleSessionExpired() {
      Future.microtask(() async {
        if (!state.isLoggedIn) return;
        await logout();
      });
    }

    api.onSessionExpired = handleSessionExpired;
    ref.onDispose(() {
      if (identical(api.onSessionExpired, handleSessionExpired)) {
        api.onSessionExpired = null;
      }
    });
    if (api.token != null && api.token!.isNotEmpty) {
      Future.microtask(() => init());
      return const AuthState(isLoading: true);
    }
    if (!api.sessionRestoreCompleted) {
      Future.microtask(() => init());
    }
    return AuthState(isLoading: !api.sessionRestoreCompleted);
  }

  bool _wasManualLogout = false;
  int _sessionVersion = 0;
  Future<void>? _reconnectFuture;
  bool get wasManualLogout => _wasManualLogout;
  void clearManualLogout() => _wasManualLogout = false;

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> init() async {
    final version = _sessionVersion;
    try {
      await _api.loadToken();
    } catch (_) {
      state = const AuthState(error: 'Không thể khôi phục phiên đăng nhập.');
      return;
    }
    if (version != _sessionVersion) return;
    if (_api.token != null) {
      // Prevent fetching if already populated (e.g. from login)
      if (state.user != null) return;

      try {
        // Both requests use the restored token and are independent. Wait for
        // both before handling an auth failure so a late shop response cannot
        // repopulate the store after logout has cleared it.
        final responses = await Future.wait<dynamic>([
          _api.get('/profile'),
          _api.get('/my-shops'),
        ]);
        if (version != _sessionVersion) return;
        if (_api.token == null) {
          ref.read(shopProvider.notifier).clear();
          state = const AuthState();
          return;
        }
        final profile = responses.first;
        if (responses[1] is! List) {
          throw const FormatException('Danh sách cửa hàng không hợp lệ.');
        }
        ref.read(shopProvider.notifier).initFromLogin(responses[1] as List);
        if (profile is Map) {
          final user = Map<String, dynamic>.from(profile);
          state = state.copyWith(
            isLoading: false,
            isLoggedIn: true,
            token: _api.token,
            user: user,
            accountType: user['accountType'] as String?,
            isOnboarded: user['isOnboarded'] as bool? ?? true,
          );
        } else {
          state = AuthState(isLoggedIn: true, token: _api.token);
        }
      } catch (e) {
        if (version != _sessionVersion) return;
        // If profile fetch fails due to explicit auth error (401/403), logout
        bool isUnauthorized = false;
        if (e is DioException) {
          isUnauthorized = const [401, 403].contains(e.response?.statusCode);
        } else if (e is ApiException) {
          isUnauthorized = const [401, 403].contains(e.statusCode);
        } else {
          final eStr = e.toString().toLowerCase();
          if (eStr.contains('hết hạn') || eStr.contains('401')) {
            isUnauthorized = true;
          }
        }

        if (isUnauthorized) {
          await logout();
          return;
        }

        final status = e is ApiException
            ? e.statusCode
            : e is DioException
            ? e.response?.statusCode
            : -1;
        if ((status == null || const [502, 503, 504].contains(status)) &&
            await _restorePreparedWorkspace(version)) {
          return;
        }

        ref.read(shopProvider.notifier).clear();
        state = const AuthState(
          error:
              'Chưa thể xác minh phiên làm việc. Vui lòng kết nối mạng và thử lại.',
        );
      }
    } else {
      if (_api.refreshUnavailable && await _restorePreparedWorkspace(version)) {
        return;
      }
      state = const AuthState();
    }
  }

  Future<OfflineSessionStore> _sessionStore() async =>
      OfflineSessionStore(await ref.read(offlineStoreProvider.future));

  Future<void> _forgetPreparedWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_restore_disabled', true);
    try {
      await (await _sessionStore()).clear();
    } catch (_) {
      // A disabled marker prevents reopening even if device storage is broken.
    }
  }

  // Offline access was withdrawn. Keep any device data without reopening it.
  Future<bool> _restorePreparedWorkspace(int version) async => false;

  Future<void> prepareOfflineWorkspace() async {
    throw ApiException(
      'Ứng dụng yêu cầu kết nối mạng; không hỗ trợ ghi chép offline.',
    );
  }

  Future<void> reconnectOfflineSession() {
    final active = _reconnectFuture;
    if (active != null) return active;
    final future = _reconnectPreparedWorkspace();
    _reconnectFuture = future;
    return future.whenComplete(() {
      if (identical(_reconnectFuture, future)) _reconnectFuture = null;
    });
  }

  Future<void> _reconnectPreparedWorkspace() async {
    if (!state.isOfflineSession) return;
    final version = _sessionVersion;
    final userId = state.user!['id'];
    final shopId = ref.read(shopProvider).currentShopId;
    if (!await _api.refreshSession()) {
      if (!_api.refreshUnavailable && version == _sessionVersion) {
        await logout();
      }
      throw ApiException(
        'Chưa xác thực lại được. Ghi chép trên thiết bị được giữ nguyên.',
        _api.refreshUnavailable ? null : 401,
      );
    }
    if (version != _sessionVersion) {
      throw ApiException('Phiên làm việc đã thay đổi.', 409);
    }
    try {
      final values = await Future.wait([
        _api.getSessionIdentity('/profile'),
        _api.getSessionIdentity('/my-shops'),
      ]);
      if (version != _sessionVersion ||
          state.user?['id'] != userId ||
          ref.read(shopProvider).currentShopId != shopId ||
          ref.read(shopProvider).isAllShops) {
        throw ApiException('Phiên làm việc đã thay đổi.', 409);
      }
      final user = Map<String, dynamic>.from(values[0] as Map);
      if (user['id'].toString() != userId.toString()) {
        await logout();
        throw ApiException(
          'Tài khoản trực tuyến khác tài khoản của dữ liệu đang chờ. Chưa gửi dữ liệu.',
          403,
        );
      }
      final shops = (values[1] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      final current = shops
          .where((s) => parseShopRecordId(s['shopId']) == shopId)
          .firstOrNull;
      if (current == null ||
          current['status'] != 'ACTIVE' ||
          current['isActive'] == false) {
        await logout();
        throw ApiException(
          'Quyền cửa hàng đã thay đổi. Chưa gửi dữ liệu.',
          403,
        );
      }
      ref.read(shopProvider.notifier).initFromLogin(shops);
      ref.read(shopProvider.notifier).switchShop(shopId!);
      _api.localOnlyMode = false;
      state = AuthState(
        isLoggedIn: true,
        token: _api.token,
        user: user,
        accountType: user['accountType'] as String?,
        isOnboarded: user['isOnboarded'] as bool? ?? true,
      );
    } catch (_) {
      if (version == _sessionVersion && state.isOfflineSession) {
        _api.localOnlyMode = true;
      }
      rethrow;
    }
  }

  Future<bool> login(String username, String password) async {
    _sessionVersion++;
    _api.localOnlyMode = false;
    state = const AuthState(isLoading: true);
    try {
      await _forgetPreparedWorkspace();
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
      final accountType = user?['accountType'] as String?;
      final isOnboarded = user?['isOnboarded'] as bool? ?? true;

      // Initialize shop provider with shops from login response
      final shops = data['shops'] as List? ?? [];
      ref.read(shopProvider.notifier).initFromLogin(shops);
      await ref.read(shopProvider.notifier).loadUserShops();

      state = AuthState(
        isLoggedIn: true,
        token: token,
        user: user,
        accountType: accountType,
        isOnboarded: isOnboarded,
      );
      _wasManualLogout = false;

      return true;
    } catch (e) {
      String msg = 'Không thể đăng nhập. Vui lòng thử lại';
      if (e is ApiException) {
        msg = e.message;
      } else if (e is DioException && e.error is ApiException) {
        msg = (e.error as ApiException).message;
      }
      final lowerMsg = msg.toLowerCase();
      if (lowerMsg.contains('inactive') ||
          lowerMsg.contains('vô hiệu hóa') ||
          lowerMsg.contains('bị khóa')) {
        msg =
            'Tài khoản của bạn đã bị khóa hoặc vô hiệu hóa. Vui lòng liên hệ quản trị viên.';
      } else if (lowerMsg.contains('sai') ||
          lowerMsg.contains('không đúng') ||
          lowerMsg.contains('invalid') ||
          lowerMsg.contains('incorrect') ||
          lowerMsg.contains('not found') ||
          lowerMsg.contains('không tồn tại') ||
          lowerMsg.contains('unauthorized')) {
        msg = 'Sai Gmail hoặc mật khẩu. Vui lòng kiểm tra lại.';
      } else if (lowerMsg.contains('network') ||
          lowerMsg.contains('connection') ||
          lowerMsg.contains('socket')) {
        msg =
            'Không thể kết nối đến máy chủ. Vui lòng kiểm tra đường truyền mạng.';
      }
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<bool> _acceptAuthResponse(dynamic data) async {
    if (data is! Map) return false;
    final response = Map<String, dynamic>.from(data);
    final token = response['access_token']?.toString() ?? '';
    if (token.isEmpty) return false;
    _sessionVersion++;
    await _forgetPreparedWorkspace();
    _api.localOnlyMode = false;
    await _api.saveToken(token, response['refresh_token']?.toString());
    final user = response['user'] is Map
        ? Map<String, dynamic>.from(response['user'] as Map)
        : null;
    final shops = response['shops'] as List? ?? const [];
    ref.read(shopProvider.notifier).initFromLogin(shops);
    await ref.read(shopProvider.notifier).loadUserShops();
    state = AuthState(
      isLoggedIn: true,
      token: token,
      user: user,
      accountType: user?['accountType'] as String?,
      isOnboarded: user?['isOnboarded'] as bool? ?? true,
    );
    _wasManualLogout = false;
    return true;
  }

  Future<bool> registerWithOtp({
    required String email,
    required String password,
    required String fullName,
    required String accountType,
    required String otpCode,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.post(
        '/auth/register',
        data: {
          'username': email.trim().toLowerCase(),
          'password': password,
          'fullName': fullName.trim(),
          'accountType': accountType,
          'otpCode': otpCode,
        },
      );
      return await _acceptAuthResponse(data);
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'Không thể hoàn tất đăng ký. Vui lòng thử lại.';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  Future<bool> authenticateWithGoogle({
    required String idToken,
    required bool createIfMissing,
    String accountType = 'PERSONAL',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.post(
        '/auth/google',
        data: {
          'idToken': idToken,
          'createIfMissing': createIfMissing,
          'accountType': accountType,
        },
      );
      return await _acceptAuthResponse(data);
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'Không thể xác thực tài khoản Google.';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }
  }

  void updateUser(Map<String, dynamic> updated) {
    state = state.copyWith(user: updated);
  }

  Future<bool> completeOnboarding({
    required String accountType,
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
      final Map<String, dynamic> data = {
        'accountType': accountType,
        'fullName': fullName,
      };
      if (username != null && username.isNotEmpty) {
        data['username'] = username;
      }
      if (phone != null && phone.isNotEmpty) {
        data['phone'] = phone;
      }
      if (shopName != null && shopName.isNotEmpty) {
        data['shopName'] = shopName;
      }
      if (ownerName != null && ownerName.isNotEmpty) {
        data['ownerName'] = ownerName;
      }
      if (address != null && address.isNotEmpty) {
        data['address'] = address;
      }
      if (shopCode != null && shopCode.isNotEmpty) {
        data['shopCode'] = shopCode;
      }
      if (shopId != null && shopId.isNotEmpty) {
        data['shopId'] = shopId;
      }

      final response = await _api.post('/auth/complete-onboarding', data: data);
      final updatedUser = response['user'] is Map
          ? Map<String, dynamic>.from(response['user'])
          : null;
      // Reload shops to get the updated status (ACTIVE / PENDING)
      await ref.read(shopProvider.notifier).loadUserShops();

      if (updatedUser != null) {
        state = state.copyWith(
          user: {...?state.user, ...updatedUser},
          accountType: updatedUser['accountType'] as String?,
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
    _sessionVersion++;
    _wasManualLogout = true;
    state = const AuthState();
    _api.localOnlyMode = false;
    // Clear local reopening permission before waiting for a network logout.
    await _forgetPreparedWorkspace();
    try {
      await _api.revokeSession();
    } catch (_) {
      // Local credentials are cleared even when the server is unreachable.
    }
    await _clearUserWorkspace();
  }

  Future<void> finishEmailChange() async {
    _sessionVersion++;
    _wasManualLogout = true;
    state = const AuthState(isLoading: true);
    _api.localOnlyMode = false;
    String? cleanupError;
    try {
      await _api.discardRevokedSession();
      await _forgetPreparedWorkspace();
    } catch (_) {
      cleanupError =
          'Gmail đã đổi. Vui lòng đăng nhập lại; chưa thể xóa đầy đủ phiên đã lưu trên thiết bị.';
    }
    try {
      await _clearUserWorkspace();
    } finally {
      state = AuthState(error: cleanupError);
    }
  }

  Future<void> _clearUserWorkspace() async {
    await GoogleAuthService.instance.signOut();
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
    ref.invalidate(purchaseOrderQueryProvider);
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
    ref.invalidate(productOptionsProvider);
    ref.invalidate(productDetailProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(supplierListProvider);
    ref.invalidate(supplierOptionsProvider);
    ref.invalidate(supplierDetailProvider);
    ref.invalidate(shopProfileProvider);
    ref.invalidate(activityLogsProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(costingProvider);
    ref.invalidate(taxConfigProvider);
  }

  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _api.get('/shops/search', params: {'q': query});
    if (response is! List) {
      throw ApiException('Dữ liệu tìm kiếm cửa hàng không hợp lệ');
    }
    return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<bool> requestJoinShop(int shopId) async {
    try {
      await _api.post('/shop-members/request-join', data: {'shopId': shopId});
      await ref.read(shopProvider.notifier).loadUserShops();
      return true;
    } catch (e) {
      String msg = 'Không thể gửi yêu cầu gia nhập.';
      if (e is DioException && e.error is ApiException) {
        msg = (e.error as ApiException).message;
      }
      state = state.copyWith(error: msg);
      return false;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
