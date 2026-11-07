import 'package:sembast/sembast.dart';
import 'offline_store.dart';

/// A personal-device workspace, never proof of current server authorization.
/// Only explicitly listed display fields survive; credentials are not accepted.
class OfflinePreparedSession {
  final Map<String, dynamic> user;
  final Map<String, dynamic> shop;
  final DateTime preparedAt;
  OfflinePreparedSession._(this.user, this.shop, this.preparedAt);
  OfflineScope get scope =>
      OfflineScope(userId: user['id'] as int, shopId: shop['shopId'] as int);

  factory OfflinePreparedSession.prepare(
    Map<String, dynamic> user,
    Map<String, dynamic> shop,
    DateTime preparedAt,
  ) {
    final userId = int.tryParse('${user['id']}');
    final shopId = int.tryParse('${shop['shopId']}');
    if (userId == null ||
        userId <= 0 ||
        shopId == null ||
        shopId <= 0 ||
        shop['status'] != 'ACTIVE' ||
        shop['isActive'] == false ||
        user['isOnboarded'] == false) {
      throw StateError(
        'Cần tài khoản đã thiết lập và cửa hàng đang hoạt động.',
      );
    }
    final permissions = <String, String>{};
    if (shop['permissions'] is Map) {
      (shop['permissions'] as Map).forEach((key, value) {
        if (const ['none', 'view', 'edit', 'full'].contains(value)) {
          permissions[key.toString()] = value.toString();
        }
      });
    }
    return OfflinePreparedSession._(
      {
        'id': userId,
        for (final key in ['fullName', 'username', 'accountType'])
          if (user[key] is String) key: user[key],
        'isOnboarded': true,
      },
      {
        'shopId': shopId,
        for (final key in ['shopName', 'shopCode', 'memberType'])
          if (shop[key] is String) key: shop[key],
        'status': 'ACTIVE',
        'isActive': true,
        'permissions': permissions,
      },
      preparedAt.toUtc(),
    );
  }

  Map<String, Object?> toMap() => {
    'user': user,
    'shop': shop,
    'preparedAt': preparedAt.toIso8601String(),
  };
}

class OfflineSessionStore {
  final OfflineStore store;
  OfflineSessionStore(this.store);
  final _device = stringMapStoreFactory.store('prepared_workspace');

  Future<void> save(
    OfflinePreparedSession session, {
    required bool Function() isCurrent,
  }) => store.database.transaction((tx) async {
    if (!isCurrent()) throw StateError('Tài khoản hoặc cửa hàng đã thay đổi.');
    await _device.record('active').put(tx, session.toMap());
  });

  Future<OfflinePreparedSession?> read() async {
    final row = await _device.record('active').get(store.database);
    if (row == null) return null;
    try {
      return OfflinePreparedSession.prepare(
        Map<String, dynamic>.from(row['user'] as Map),
        Map<String, dynamic>.from(row['shop'] as Map),
        DateTime.parse(row['preparedAt'] as String),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  // Queue/drafts are preserved under their original user/shop scope.
  Future<void> clear() async {
    await _device.record('active').delete(store.database);
  }
}
