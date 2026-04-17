import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

// ─── Auth State ───
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final String? token;
  final Map<String, dynamic>? user;
  final String? error;
  final String? accountType; // 'SHOP' | 'PERSONAL'
  final bool isOnboarded;

  const AuthState({this.isLoading = false, this.isLoggedIn = false, this.token, this.user, this.error, this.accountType, this.isOnboarded = true});
  AuthState copyWith({bool? isLoading, bool? isLoggedIn, String? token, Map<String, dynamic>? user, String? error, String? accountType, bool? isOnboarded}) =>
      AuthState(isLoading: isLoading ?? this.isLoading, isLoggedIn: isLoggedIn ?? this.isLoggedIn, token: token ?? this.token, user: user ?? this.user, error: error, accountType: accountType ?? this.accountType, isOnboarded: isOnboarded ?? this.isOnboarded);

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
      final data = await _api.post('/auth/login', data: {'username': username, 'password': password});
      final token = data['access_token'] ?? data['token'] ?? '';
      await _api.saveToken(token);

      final user = data['user'] is Map ? Map<String, dynamic>.from(data['user']) : null;
      final accountType = user?['accountType'] as String? ?? 'PERSONAL';
      final isOnboarded = user?['isOnboarded'] as bool? ?? true;

      state = AuthState(isLoggedIn: true, token: token, user: user, accountType: accountType, isOnboarded: isOnboarded);

      // Initialize shop provider with shops from login response
      final shops = data['shops'] as List? ?? [];
      ref.read(shopProvider.notifier).initFromLogin(shops);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sai tên đăng nhập hoặc mật khẩu');
      return false;
    }
  }

  void updateUser(Map<String, dynamic> updated) {
    state = state.copyWith(user: updated);
  }

  Future<bool> completeOnboarding({String? username, String? phone, required String fullName, String? shopName, String? ownerName, String? address, String? shopCode, String? shopId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final Map<String, dynamic> data = {'fullName': fullName};
      if (username != null && username.isNotEmpty) data['username'] = username;
      if (phone != null && phone.isNotEmpty) data['phone'] = phone;
      if (shopName != null && shopName.isNotEmpty) data['shopName'] = shopName;
      if (ownerName != null && ownerName.isNotEmpty) data['ownerName'] = ownerName;
      if (address != null && address.isNotEmpty) data['address'] = address;
      if (shopCode != null && shopCode.isNotEmpty) data['shopCode'] = shopCode;
      if (shopId != null && shopId.isNotEmpty) data['shopId'] = shopId;

      final response = await _api.post('/auth/complete-onboarding', data: data);
      final updatedUser = response['user'] is Map ? Map<String, dynamic>.from(response['user']) : null;
      if (updatedUser != null) {
        state = state.copyWith(user: {...?state.user, ...updatedUser}, isOnboarded: true, isLoading: false);
      } else {
        state = state.copyWith(isOnboarded: true, isLoading: false);
      }
      
      // Reload shops to get the updated status (ACTIVE / PENDING)
      await ref.read(shopProvider.notifier).loadUserShops();
      
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().contains('bắt buộc') || e.toString().contains('Không tìm thấy') ? e.toString() : 'Không thể hoàn tất onboarding. Vui lòng thử lại.');
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    ref.read(shopProvider.notifier).clear();
    state = const AuthState();
  }

  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _api.get('/auth/search-shops', params: {'q': query});
      if (response is List) {
        return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
