import 'dart:convert';
import 'dart:math';
import 'package:sembast/sembast.dart';

class OfflineScope {
  final int userId;
  final int shopId;
  const OfflineScope({required this.userId, required this.shopId});
  String get key => '$userId:$shopId';
  void validate() {
    if (userId <= 0 || shopId <= 0) {
      throw ArgumentError('Cần tài khoản và một cửa hàng cụ thể.');
    }
  }
}

String newOperationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

const offlineKinds = {
  'CASH_TRANSACTION_CREATE',
  'SALES_ORDER_CREATE',
  'PURCHASE_ORDER_CREATE',
};

class OfflineOperation {
  final Map<String, Object?> value;
  OfflineOperation(Map<String, Object?> value)
    : value = Map.unmodifiable(value);
  String get id => value['operationId'] as String;
  String get kind => value['kind'] as String;
  String get status => value['status'] as String;
  String? get message => value['message'] as String?;
  Map<String, dynamic> get payload =>
      Map<String, dynamic>.from(value['payload'] as Map);
  Map<String, dynamic> get envelope => {
    'operationId': id,
    'kind': kind,
    'payload': payload,
    if (value['reviewDecision'] is Map)
      'reviewDecision': value['reviewDecision'],
  };
}

/// Persistent business data, never authentication secrets. Every key is scoped
/// by the verified user AND shop. Transactions also protect cross-tab claims.
class OfflineStore {
  final Database database;
  final DateTime Function() now;
  final _operations = stringMapStoreFactory.store('operations');
  final _drafts = stringMapStoreFactory.store('drafts');
  final _cache = stringMapStoreFactory.store('cache');
  final _settings = stringMapStoreFactory.store('settings');

  OfflineStore(this.database, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  String _key(OfflineScope scope, String id) {
    scope.validate();
    return '${scope.key}:$id';
  }

  Map<String, Object?> _jsonMap(Map<String, dynamic> value) {
    final decoded = jsonDecode(jsonEncode(value)) as Map;
    return Map<String, Object?>.from(decoded);
  }

  Future<void> saveDraft(
    OfflineScope scope,
    String id,
    String kind,
    Map<String, dynamic> payload,
  ) async {
    if (!offlineKinds.contains(kind)) {
      throw ArgumentError('Loại ghi chép chưa được hỗ trợ.');
    }
    await _drafts.record(_key(scope, id)).put(database, {
      'scope': scope.key,
      'kind': kind,
      'payload': _jsonMap(payload),
      'updatedAt': now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, Object?>?> draft(OfflineScope scope, String id) =>
      _drafts.record(_key(scope, id)).get(database);

  Future<void> deleteDraft(OfflineScope scope, String id) async {
    await _drafts.record(_key(scope, id)).delete(database);
  }

  /// Saving to the queue is durable before the UI says "saved on device".
  /// Existing IDs are immutable: a timeout/reload must retry the SAME content.
  Future<OfflineOperation> enqueue(
    OfflineScope scope,
    String kind,
    Map<String, dynamic> payload, {
    String? operationId,
    String? draftId,
  }) async {
    if (!offlineKinds.contains(kind)) {
      throw ArgumentError('Loại ghi chép chưa được hỗ trợ.');
    }
    final id = operationId ?? newOperationId();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw ArgumentError('Mã đồng bộ không hợp lệ.');
    }
    final safePayload = _jsonMap(payload);
    return database.transaction((tx) async {
      final record = _operations.record(_key(scope, id));
      final existing = await record.get(tx);
      if (existing != null) {
        if (existing['kind'] != kind ||
            jsonEncode(existing['payload']) != jsonEncode(safePayload)) {
          throw StateError(
            'Không được thay nội dung của bản ghi đã gửi đồng bộ.',
          );
        }
        return OfflineOperation(existing);
      }
      final value = <String, Object?>{
        'scope': scope.key,
        'operationId': id,
        'kind': kind,
        'payload': safePayload,
        'status': 'pending',
        'attempts': 0,
        'createdAt': now().toUtc().toIso8601String(),
      };
      await record.put(tx, value);
      if (draftId != null) {
        await _drafts.record(_key(scope, draftId)).delete(tx);
      }
      return OfflineOperation(value);
    });
  }

  Future<List<OfflineOperation>> list(OfflineScope scope) async {
    scope.validate();
    final records = await _operations.find(
      database,
      finder: Finder(
        filter: Filter.equals('scope', scope.key),
        sortOrders: [SortOrder('createdAt')],
      ),
    );
    return records.map((r) => OfflineOperation(r.value)).toList();
  }

  Future<OfflineOperation?> operation(OfflineScope scope, String id) async {
    final value = await _operations.record(_key(scope, id)).get(database);
    return value == null ? null : OfflineOperation(value);
  }

  Stream<List<OfflineOperation>> watch(OfflineScope scope) {
    scope.validate();
    return _operations
        .query(
          finder: Finder(
            filter: Filter.equals('scope', scope.key),
            sortOrders: [SortOrder('createdAt', false)],
          ),
        )
        .onSnapshots(database)
        .map(
          (records) => records.map((r) => OfflineOperation(r.value)).toList(),
        );
  }

  Future<OfflineOperation?> claim(
    OfflineScope scope, {
    bool ignoreRetryDelay = false,
  }) => database.transaction((tx) async {
    scope.validate();
    final records = await _operations.find(
      tx,
      finder: Finder(
        filter: Filter.equals('scope', scope.key),
        sortOrders: [SortOrder('createdAt')],
      ),
    );
    final stamp = now().millisecondsSinceEpoch;
    for (final record in records) {
      final value = record.value;
      final status = value['status'];
      if (status != 'pending' &&
          !(status == 'sending' &&
              (value['leaseUntil'] as int? ?? 0) <= stamp)) {
        continue;
      }
      if (!ignoreRetryDelay && (value['nextAttemptAt'] as int? ?? 0) > stamp) {
        continue;
      }
      final next = <String, Object?>{
        ...value,
        'status': 'sending',
        'leaseUntil': stamp + 120000,
        'lease': newOperationId(),
        'attempts': (value['attempts'] as int? ?? 0) + 1,
      };
      await record.ref.put(tx, next);
      return OfflineOperation(next);
    }
    return null;
  });

  Future<void> finish(
    OfflineScope scope,
    OfflineOperation claim,
    String status, {
    String? message,
    Map<String, dynamic>? receipt,
    Map<String, dynamic>? review,
  }) => database.transaction((tx) async {
    if (!{
      'pending',
      'confirmed',
      'rejected',
      'authRequired',
      'reviewRequired',
    }.contains(status)) {
      throw ArgumentError.value(status);
    }
    final record = _operations.record(_key(scope, claim.id));
    final current = await record.get(tx);
    if (current == null ||
        current['status'] != 'sending' ||
        current['lease'] != claim.value['lease']) {
      return;
    }
    await record.put(tx, {
      ...current,
      'status': status,
      'message': message,
      if (review != null) 'review': _jsonMap(review),
      if (review != null) 'reviewDecision': null,
      'lease': null,
      'leaseUntil': null,
      'nextAttemptAt': status == 'pending'
          ? now().millisecondsSinceEpoch +
                min(
                  300000,
                  15000 *
                      pow(
                        2,
                        min(5, max(0, (current['attempts'] as int? ?? 1) - 1)),
                      ).toInt(),
                )
          : null,
      if (receipt != null) 'receipt': _jsonMap(receipt),
      if (status == 'confirmed') 'confirmedAt': now().toUtc().toIso8601String(),
    });
  });

  /// Retry keeps the operation ID and payload, including ambiguous timeouts.
  Future<void> retry(OfflineScope scope, String id) =>
      database.transaction((tx) async {
        final record = _operations.record(_key(scope, id));
        final current = await record.get(tx);
        if (current == null ||
            current['status'] == 'confirmed' ||
            current['status'] == 'reviewRequired' ||
            current['status'] == 'sending') {
          return;
        }
        await record.put(tx, {
          ...current,
          'status': 'pending',
          'nextAttemptAt': null,
          'message': null,
        });
      });

  /// Only a deliberate choice from the displayed review can release this row.
  /// Normal retry/background sync cannot silently approve a suspected duplicate.
  Future<void> approveReview(
    OfflineScope scope,
    String id,
    Map<String, dynamic> decision,
  ) => database.transaction((tx) async {
    final record = _operations.record(_key(scope, id));
    final current = await record.get(tx);
    final review = current?['review'];
    if (current == null ||
        current['status'] != 'reviewRequired' ||
        review is! Map ||
        decision['guard'] != review['guard'] ||
        !['createNew', 'useExisting'].contains(decision['action'])) {
      throw StateError(
        'Nội dung cần kiểm tra đã thay đổi. Hãy mở lại bản ghi.',
      );
    }
    if (decision['action'] == 'useExisting' &&
        !(review['candidates'] as List).any(
          (c) => c['id'] == decision['entityId'],
        )) {
      throw StateError(
        'Giao dịch được chọn không thuộc danh sách đã kiểm tra.',
      );
    }
    await record.put(tx, {
      ...current,
      'status': 'pending',
      'nextAttemptAt': null,
      'reviewDecision': _jsonMap(decision),
      'message': null,
    });
  });

  Future<bool> autoSync(OfflineScope scope) async =>
      (await _settings
          .record(_key(scope, 'autoSync'))
          .get(database))?['enabled'] ==
      true;
  Future<void> setAutoSync(OfflineScope scope, bool enabled) => _settings
      .record(_key(scope, 'autoSync'))
      .put(database, {'enabled': enabled});

  Future<void> cache(OfflineScope scope, String key, dynamic data) async {
    await _cache.record(_key(scope, key)).put(database, {
      'data': jsonDecode(jsonEncode(data)),
      'updatedAt': now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, Object?>?> cached(OfflineScope scope, String key) =>
      _cache.record(_key(scope, key)).get(database);
  Future<void> evictCache(OfflineScope scope, String key) =>
      _cache.record(_key(scope, key)).delete(database);
}
