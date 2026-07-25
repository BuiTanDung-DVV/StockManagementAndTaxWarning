import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

bool _isUsableShopRecord(Map<String, dynamic> shop) =>
    shop['status'] == 'ACTIVE' && shop['isActive'] != false;

// ── Shop state ──
class ShopState {
  final int? currentShopId;
  final String? currentShopName;
  final String? shopCode;
  final String? memberType; // 'OWNER' | 'EMPLOYEE'
  final String? status; // 'ACTIVE' | 'PENDING' | 'REJECTED'
  final bool membershipEnabled;
  final Map<String, String> permissions; // { "pos": "full", ... }
  final List<Map<String, dynamic>> userShops;
  final bool isLoading;
  final bool isAllShops;

  const ShopState({
    this.currentShopId,
    this.currentShopName,
    this.shopCode,
    this.memberType,
    this.status,
    this.membershipEnabled = true,
    this.permissions = const {},
    this.userShops = const [],
    this.isLoading = true,
    this.isAllShops = false,
  });

  bool get isOwner =>
      !isAllShops &&
      memberType == 'OWNER' &&
      status == 'ACTIVE' &&
      membershipEnabled;
  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
  bool get isActive =>
      membershipEnabled &&
      (status == 'ACTIVE' || status == null); // legacy compatibility

  /// Check if user has permission. Owners and users with no shop config always return true.
  bool hasPermission(String key, [String level = 'view']) {
    if (!isActive) return false;
    if (isAllShops) {
      if (level != 'view' ||
          !const {'sales', 'inventory', 'finance'}.contains(key)) {
        return false;
      }
      return userShops
          .where(_isUsableShopRecord)
          .any((shop) => _shopHasPermission(shop, key, level));
    }
    // No RBAC configured yet → full access (legacy/admin mode)
    if (userShops.isEmpty) return false;
    if (memberType == 'OWNER') return true;
    final perm = _permissionLevel(permissions, key);
    if (perm == null || perm == 'none') return false;
    const hierarchy = ['none', 'view', 'edit', 'full'];
    return hierarchy.indexOf(perm) >= hierarchy.indexOf(level);
  }

  bool _shopHasPermission(Map<String, dynamic> shop, String key, String level) {
    if (shop['memberType'] == 'OWNER') return true;
    final raw = shop['permissions'];
    final shopPermissions = <String, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        shopPermissions[k.toString()] = v.toString();
      });
    }
    final permission = _permissionLevel(shopPermissions, key);
    if (permission == null) return false;
    const hierarchy = ['none', 'view', 'edit', 'full'];
    return hierarchy.indexOf(permission) >= hierarchy.indexOf(level);
  }

  String? _permissionLevel(Map<String, String> source, String key) {
    final direct = source[key];
    if (direct != null && direct != 'none') return direct;
    if (key != 'sales') return direct;

    const hierarchy = ['none', 'view', 'edit', 'full'];
    final pos = source['pos'] ?? 'none';
    final salesView = source['sales_view'] == null ? 'none' : 'view';
    return hierarchy.indexOf(pos) >= hierarchy.indexOf(salesView)
        ? pos
        : salesView;
  }

  ShopState copyWith({
    int? currentShopId,
    String? currentShopName,
    String? shopCode,
    String? memberType,
    String? status,
    bool? membershipEnabled,
    Map<String, String>? permissions,
    List<Map<String, dynamic>>? userShops,
    bool? isLoading,
    bool? isAllShops,
  }) => ShopState(
    currentShopId: currentShopId ?? this.currentShopId,
    currentShopName: currentShopName ?? this.currentShopName,
    shopCode: shopCode ?? this.shopCode,
    memberType: memberType ?? this.memberType,
    status: status ?? this.status,
    membershipEnabled: membershipEnabled ?? this.membershipEnabled,
    permissions: permissions ?? this.permissions,
    userShops: userShops ?? this.userShops,
    isLoading: isLoading ?? this.isLoading,
    isAllShops: isAllShops ?? this.isAllShops,
  );
}

// ── Shop Notifier ──
class ShopNotifier extends Notifier<ShopState> {
  @override
  ShopState build() => const ShopState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// Initialize from login response shops array
  void initFromLogin(List<dynamic> shops) {
    final parsed = shops
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
    if (parsed.isEmpty) return;

    // Prefer a usable membership when stale pending/inactive rows also exist.
    final current = parsed.firstWhere(
      _isUsableShop,
      orElse: () => parsed.first,
    );
    _selectShop(parsed, current);
  }

  /// Load user shops from API
  Future<void> loadUserShops() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.get('/my-shops');
      final shops = (data as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
      if (shops.isEmpty) {
        state = state.copyWith(userShops: [], isLoading: false);
        return;
      }
      if (_api.shopId == 'all') {
        _selectAllShops(shops);
        return;
      }
      // Keep current shop if still valid, else default to first
      final savedShopId = _api.shopId != null
          ? int.tryParse(_api.shopId!)
          : null;
      final currentId = state.currentShopId ?? savedShopId;
      final activeShops = shops.where(_isUsableShop).toList();
      final fallback = activeShops.isNotEmpty ? activeShops.first : shops.first;
      final current = shops.firstWhere(
        (s) => s['shopId'] == currentId && _isUsableShop(s),
        orElse: () => fallback,
      );
      _selectShop(shops, current);
    } catch (e) {
      debugPrint('ShopProvider.loadUserShops error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Switch to a different shop
  void switchShop(int shopId) {
    if (shopId == -1) {
      final activeShops = state.userShops.where(_isUsableShop).toList();
      if (activeShops.isNotEmpty) {
        _selectAllShops(state.userShops);
      }
      return;
    }
    final activeShops = state.userShops.where(_isUsableShop).toList();
    if (activeShops.isEmpty) return;
    final shop = activeShops.firstWhere(
      (s) => s['shopId'] == shopId,
      orElse: () => activeShops.first,
    );
    _selectShop(state.userShops, shop);
  }

  bool _isUsableShop(Map<String, dynamic> shop) =>
      _isUsableShopRecord(shop);

  void _selectAllShops(List<Map<String, dynamic>> shops) {
    final usableShops = shops.where(_isUsableShop).toList();
    if (usableShops.isEmpty) {
      _api.setShopId(null);
      state = ShopState(userShops: shops, isLoading: false);
      return;
    }
    _api.setShopId('all');
    state = ShopState(
      currentShopId: null,
      currentShopName: 'Tất cả cửa hàng (Tổng quát)',
      shopCode: null,
      memberType: null,
      status: 'ACTIVE',
      membershipEnabled: true,
      permissions: const {},
      userShops: shops,
      isLoading: false,
      isAllShops: true,
    );
  }

  void _selectShop(
    List<Map<String, dynamic>> shops,
    Map<String, dynamic> current,
  ) {
    final perms = <String, String>{};
    final rawPerms = current['permissions'];
    if (rawPerms is Map) {
      rawPerms.forEach((k, v) => perms[k.toString()] = v.toString());
    }

    final usable = _isUsableShop(current);
    _api.setShopId(usable ? current['shopId']?.toString() : null);

    state = ShopState(
      currentShopId: current['shopId'] as int?,
      currentShopName: current['shopName'] as String?,
      shopCode: current['shopCode'] as String?,
      memberType: current['memberType'] as String?,
      status: current['status'] as String?,
      membershipEnabled: current['isActive'] != false,
      permissions: perms,
      userShops: shops,
      isLoading: false,
      isAllShops: false,
    );
  }

  void clear() {
    _api.setShopId(null);
    state = const ShopState();
  }
}

final shopProvider = NotifierProvider<ShopNotifier, ShopState>(
  ShopNotifier.new,
);
