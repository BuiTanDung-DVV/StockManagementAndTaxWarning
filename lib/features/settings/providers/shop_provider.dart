import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Shop state ──
class ShopState {
  final int? currentShopId;
  final String? currentShopName;
  final String? memberType; // 'OWNER' | 'EMPLOYEE'
  final Map<String, String> permissions; // { "pos": "full", ... }
  final List<Map<String, dynamic>> userShops;
  final bool isLoading;

  const ShopState({
    this.currentShopId,
    this.currentShopName,
    this.memberType,
    this.permissions = const {},
    this.userShops = const [],
    this.isLoading = false,
  });

  bool get isOwner => memberType == 'OWNER' || userShops.isEmpty;

  /// Check if user has permission. Owners and users with no shop config always return true.
  bool hasPermission(String key, [String level = 'view']) {
    // No RBAC configured yet → full access (legacy/admin mode)
    if (userShops.isEmpty) return true;
    if (memberType == 'OWNER') return true;
    final perm = permissions[key];
    if (perm == null || perm == 'none') return false;
    const hierarchy = ['none', 'view', 'edit', 'full'];
    return hierarchy.indexOf(perm) >= hierarchy.indexOf(level);
  }

  ShopState copyWith({
    int? currentShopId,
    String? currentShopName,
    String? memberType,
    Map<String, String>? permissions,
    List<Map<String, dynamic>>? userShops,
    bool? isLoading,
  }) => ShopState(
    currentShopId: currentShopId ?? this.currentShopId,
    currentShopName: currentShopName ?? this.currentShopName,
    memberType: memberType ?? this.memberType,
    permissions: permissions ?? this.permissions,
    userShops: userShops ?? this.userShops,
    isLoading: isLoading ?? this.isLoading,
  );
}

// ── Shop Notifier ──
class ShopNotifier extends Notifier<ShopState> {
  @override
  ShopState build() => const ShopState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// Initialize from login response shops array
  void initFromLogin(List<dynamic> shops) {
    final parsed = shops.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    if (parsed.isEmpty) return;

    // Default to first shop
    _selectShop(parsed, parsed.first);
  }

  /// Load user shops from API
  Future<void> loadUserShops() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.get('/my-shops');
      final shops = (data as List).map((s) => Map<String, dynamic>.from(s as Map)).toList();
      if (shops.isEmpty) {
        state = state.copyWith(userShops: [], isLoading: false);
        return;
      }
      // Keep current shop if still valid, else default to first
      final currentId = state.currentShopId;
      final current = shops.firstWhere(
        (s) => s['shopId'] == currentId,
        orElse: () => shops.first,
      );
      _selectShop(shops, current);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Switch to a different shop
  void switchShop(int shopId) {
    final shop = state.userShops.firstWhere(
      (s) => s['shopId'] == shopId,
      orElse: () => state.userShops.first,
    );
    _selectShop(state.userShops, shop);
  }

  void _selectShop(List<Map<String, dynamic>> shops, Map<String, dynamic> current) {
    final perms = <String, String>{};
    final rawPerms = current['permissions'];
    if (rawPerms is Map) {
      rawPerms.forEach((k, v) => perms[k.toString()] = v.toString());
    }

    state = ShopState(
      currentShopId: current['shopId'] as int?,
      currentShopName: current['shopName'] as String?,
      memberType: current['memberType'] as String?,
      permissions: perms,
      userShops: shops,
      isLoading: false,
    );
  }

  void clear() {
    state = const ShopState();
  }
}

final shopProvider = NotifierProvider<ShopNotifier, ShopState>(ShopNotifier.new);
