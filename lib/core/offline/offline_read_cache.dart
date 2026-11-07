import 'dart:async';
import 'dart:convert';
import 'offline_store.dart';
import 'offline_catalog.dart';

class OfflineCacheAccess {
  final OfflineScope scope;
  final String key;
  const OfflineCacheAccess(this.scope, this.key);
}

class OfflineReadStatus {
  final int cachedRequests;
  final DateTime? oldestSnapshot;
  const OfflineReadStatus(this.cachedRequests, this.oldestSnapshot);
}

/// Cache exact authorized reads, including filters/pagination. A missing cached
/// page is an error, never an invented empty list or a partly filtered result.
class OfflineReadCache {
  final OfflineStore store;
  final OfflineScope? Function() currentScope;
  final OfflineCatalog catalog;
  final _changes = StreamController<OfflineReadStatus>.broadcast();
  final Map<String, DateTime> _stale = {};
  OfflineReadCache({
    required this.store,
    required this.currentScope,
    OfflineCatalog? catalog,
  }) : catalog =
           catalog ?? OfflineCatalog(store: store, currentScope: currentScope);
  Stream<OfflineReadStatus> get changes => _changes.stream;
  OfflineReadStatus get status {
    final scope = currentScope();
    final dates =
        _stale.entries
            .where((e) => e.key.startsWith('${scope?.key}:'))
            .map((e) => e.value)
            .toList()
          ..sort();
    return OfflineReadStatus(dates.length, dates.isEmpty ? null : dates.first);
  }

  OfflineCacheAccess? access(String path, Map<String, dynamic>? params) {
    final scope = currentScope();
    if (scope == null) return null;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    if (!RegExp(
      r'^(products|categories|tags|customers|suppliers|inventory|purchase-orders|stock-takes|sales-orders|cash-transactions|dashboard|customer-receivables|tax-obligations|cashflow-projection)(/|$)',
    ).hasMatch(clean)) {
      return null;
    }
    final sorted = <String, dynamic>{};
    for (final key in (params?.keys.toList() ?? [])..sort()) {
      final value = params![key];
      if (value != null) {
        sorted[key] = value is List
            ? value.map((e) => '$e').toList()
            : '$value';
      }
    }
    return OfflineCacheAccess(scope, 'GET:$clean:${jsonEncode(sorted)}');
  }

  bool current(OfflineCacheAccess access) =>
      currentScope()?.key == access.scope.key;
  void _emit() {
    if (!_changes.isClosed) _changes.add(status);
  }

  void scopeChanged() => _emit();
  Future<void> remember(OfflineCacheAccess access, dynamic data) async {
    if (!current(access)) return;
    await store.cache(access.scope, access.key, data);
    _stale.remove('${access.scope.key}:${access.key}');
    _emit();
  }

  Future<Map<String, Object?>?> fallback(OfflineCacheAccess access) async {
    if (!current(access)) return null;
    var cached = await store.cached(access.scope, access.key);
    final downloaded = await catalog.query(access.scope, access.key);
    if (downloaded != null &&
        (cached == null ||
            DateTime.parse(
              '${downloaded['updatedAt']}',
            ).isAfter(DateTime.parse('${cached['updatedAt']}')))) {
      cached = downloaded;
    }
    if (cached == null || !current(access)) return null;
    final date = DateTime.tryParse(cached['updatedAt']?.toString() ?? '');
    if (date == null) return null;
    _stale['${access.scope.key}:${access.key}'] = date;
    _emit();
    return cached;
  }

  Future<void> invalidate(OfflineCacheAccess access) async {
    await store.evictCache(access.scope, access.key);
    await catalog.invalidate(access.scope);
    _stale.remove('${access.scope.key}:${access.key}');
    _emit();
  }

  Future<void> close() => _changes.close();
}
