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

  const AuthState({this.isLoading = false, this.isLoggedIn = false, this.token, this.user, this.error, this.accountType});
  AuthState copyWith({bool? isLoading, bool? isLoggedIn, String? token, Map<String, dynamic>? user, String? error, String? accountType}) =>
      AuthState(isLoading: isLoading ?? this.isLoading, isLoggedIn: isLoggedIn ?? this.isLoggedIn, token: token ?? this.token, user: user ?? this.user, error: error, accountType: accountType ?? this.accountType);

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

      state = AuthState(isLoggedIn: true, token: token, user: user, accountType: accountType);

      // Initialize shop provider with shops from login response
      final shops = data['shops'] as List? ?? [];
      ref.read(shopProvider.notifier).initFromLogin(shops);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sai tên đăng nhập hoặc mật khẩu');
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    ref.read(shopProvider.notifier).clear();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
