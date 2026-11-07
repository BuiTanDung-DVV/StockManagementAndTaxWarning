import 'dart:convert';
import 'shop_provider.dart';

Map<String, dynamic> notificationMetadata(Map<String, dynamic> notification) {
  try {
    final raw = notification['data'];
    final value = raw is String ? jsonDecode(raw) : raw;
    return value is Map ? Map<String, dynamic>.from(value) : {};
  } catch (_) {
    return {};
  }
}

String? notificationShopName(
  Map<String, dynamic> notification,
  ShopState shops,
) {
  final data = notificationMetadata(notification);
  final name = data['shopName']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final id = parseShopRecordId(data['shopId']);
  for (final shop in shops.userShops) {
    if (id != null && parseShopRecordId(shop['shopId']) == id) {
      return shop['shopName']?.toString();
    }
  }
  return null;
}

({String route, int? shopId})? notificationDestination(
  Map<String, dynamic> notification,
  ShopState shops,
) {
  final type = notification['type'];
  if (type == 'REQUEST_REJECTED') return (route: '/profile', shopId: null);
  if (!const {
    'JOIN_REQUEST',
    'SHOP_INVITE',
    'REQUEST_APPROVED',
    'ROLE_CHANGE',
  }.contains(type)) {
    return null;
  }
  final id = parseShopRecordId(notificationMetadata(notification)['shopId']);
  if (id == null) return null;
  for (final shop in shops.userShops) {
    if (parseShopRecordId(shop['shopId']) != id ||
        shop['status'] != 'ACTIVE' ||
        shop['isActive'] == false) {
      continue;
    }
    if (type == 'JOIN_REQUEST' && shop['memberType'] != 'OWNER') return null;
    return (route: type == 'JOIN_REQUEST' ? '/staff' : '/settings', shopId: id);
  }
  return null;
}
