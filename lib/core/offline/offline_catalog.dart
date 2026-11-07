import 'dart:convert';
import 'dart:math';
import 'package:sembast/sembast.dart';
import '../utils/paged_records.dart';
import '../utils/search_text.dart';
import 'offline_store.dart';

const offlineCatalogLabels = {
  'products': 'sản phẩm',
  'customers': 'khách hàng',
  'suppliers': 'nhà cung cấp',
  'categories': 'danh mục hàng',
  'inventory/warehouses': 'kho',
  'tags:product': 'nhãn sản phẩm',
  'tags:customer': 'nhãn khách hàng',
  'tags:supplier': 'nhãn NCC',
};
const _paged = {'products', 'customers', 'suppliers'};

/// A complete downloaded catalog for one actor/shop. It is a cached read, not
/// authoritative current stock, permissions, or proof of business posting.
class OfflineCatalog {
  final OfflineStore store;
  final OfflineScope? Function() currentScope;
  final _catalogs = stringMapStoreFactory.store('complete_catalogs');
  OfflineCatalog({required this.store, required this.currentScope});

  Future<Map<String, Object?>?> summary(OfflineScope scope) async {
    final row = await _catalogs.record(scope.key).get(store.database);
    if (row?['version'] != 1 || row?['data'] is! Map) return null;
    return {
      'downloadedAt': row!['downloadedAt'],
      'counts': {
        for (final entry in (row['data'] as Map).entries)
          entry.key: (entry.value as List).length,
      },
    };
  }

  Future<Map<String, Object?>> prepare({
    required OfflineScope scope,
    required Set<String> resources,
    required Future<dynamic> Function(String path, Map<String, dynamic> params)
    loadOnline,
    required bool Function() isCurrent,
    void Function(String resource, int loaded, int total)? onProgress,
  }) async {
    if (!resources.every(offlineCatalogLabels.containsKey)) {
      throw ArgumentError('Danh mục không được hỗ trợ.');
    }
    bool current() => isCurrent() && currentScope()?.key == scope.key;
    final data = <String, List<dynamic>>{};
    final work = resources.toList()..sort();
    var next = 0;
    var failed = false;
    Future<void> worker() async {
      while (next < work.length && !failed) {
        final resource = work[next++];
        try {
          if (!current()) {
            throw StateError('Tài khoản hoặc cửa hàng đã thay đổi.');
          }
          if (_paged.contains(resource)) {
            final complete = await collectPagedRecords(
              (page, limit) => loadOnline('/$resource', {
                'page': '$page',
                'limit': '$limit',
              }),
              isCurrent: () => !failed && current(),
              onProgress: (done, total) =>
                  onProgress?.call(resource, done, total),
            );
            data[resource] = complete['items'] as List;
          } else {
            final parts = resource.split(':');
            final rows = await loadOnline(
              '/${parts[0]}',
              parts.length == 2 ? {'type': parts[1]} : {},
            );
            if (rows is! List || rows.any((row) => row is! Map)) {
              throw StateError('Danh mục $resource chưa tải đủ.');
            }
            data[resource] = rows;
            onProgress?.call(resource, rows.length, rows.length);
          }
          if (!current()) {
            throw StateError('Tài khoản hoặc cửa hàng đã thay đổi.');
          }
        } catch (_) {
          failed = true;
          rethrow;
        }
      }
    }

    await Future.wait(List.generate(min(3, work.length), (_) => worker()));
    // No partially prepared snapshot replaces the last successful download.
    final safe = jsonDecode(jsonEncode(data)) as Map;
    await store.database.transaction((tx) async {
      if (failed || !current()) {
        throw StateError('Chưa lưu danh mục: phạm vi đã thay đổi.');
      }
      await _catalogs.record(scope.key).put(tx, {
        'version': 1,
        'downloadedAt': store.now().toUtc().toIso8601String(),
        'data': safe,
      });
    });
    return (await summary(scope))!;
  }

  Future<void> invalidate(OfflineScope scope) =>
      _catalogs.record(scope.key).delete(store.database);

  /// Only known list semantics may be evaluated locally. Unknown filters,
  /// detail records and reports still require an exact cached response.
  Future<Map<String, Object?>?> query(
    OfflineScope scope,
    String cacheKey,
  ) async {
    if (currentScope()?.key != scope.key || !cacheKey.startsWith('GET:')) {
      return null;
    }
    final separator = cacheKey.indexOf(':', 4);
    if (separator < 0) return null;
    final path = cacheKey.substring(4, separator);
    final params = jsonDecode(cacheKey.substring(separator + 1)) as Map;
    final row = await _catalogs.record(scope.key).get(store.database);
    if (row?['version'] != 1 ||
        row?['data'] is! Map ||
        currentScope()?.key != scope.key) {
      return null;
    }
    final catalogs = row!['data'] as Map;
    final resource = path == 'tags'
        ? 'tags:${params['type'] ?? 'product'}'
        : path;
    final source = catalogs[resource];
    if (source is! List) return null;
    if (!_paged.contains(path)) {
      if (!params.keys.every((key) => path == 'tags' && key == 'type')) {
        return null;
      }
      return {'data': source, 'updatedAt': row['downloadedAt']};
    }
    final allowed = {
      'page',
      'limit',
      'search',
      if (path == 'products') ...['tag', 'categoryId', 'inStockOnly'],
    };
    if (!params.keys.every(allowed.contains)) return null;
    final page = int.tryParse('${params['page'] ?? 1}'),
        limit = int.tryParse('${params['limit'] ?? 20}');
    if (page == null || limit == null || page < 1 || limit < 1) return null;
    final categoryText = params['categoryId']?.toString();
    final categoryId = categoryText == null ? null : int.tryParse(categoryText);
    if (categoryText != null &&
        (categoryId == null ||
            categoryId < 0 ||
            !RegExp(r'^(0|[1-9]\d*)$').hasMatch(categoryText))) {
      return null;
    }
    final stock = params['inStockOnly']?.toString();
    if (stock != null && !['true', 'false'].contains(stock)) return null;
    if (stock == 'true' && source.any((p) => p['hasPositiveStock'] is! bool)) {
      return null;
    }
    final search = foldSearchText(params['search']);
    final tag = params['tag']?.toString().trim().toLowerCase() ?? '';
    final fields = path == 'products'
        ? ['name', 'sku', 'barcode']
        : ['name', 'phone', 'code', if (path == 'suppliers') 'taxCode'];
    final matches = source.where((raw) {
      final item = raw as Map;
      if (item['isActive'] == false) return false;
      if (search.isNotEmpty &&
          !fields.any((key) => foldSearchText(item[key]).contains(search))) {
        return false;
      }
      if (path != 'products') return true;
      final actualCategory = item['category'] is Map
          ? item['category']['id']
          : item['categoryId'];
      if (categoryId != null &&
          (categoryId == 0
              ? actualCategory != null
              : '$actualCategory' != '$categoryId')) {
        return false;
      }
      if (stock == 'true' && item['hasPositiveStock'] != true) return false;
      final quantity = num.tryParse('${item['currentStock']}') ?? 0;
      final minimum = num.tryParse('${item['minStock']}') ?? 0;
      if (tag == 'hết hàng') return quantity <= 0;
      if (tag == 'sắp hết') {
        return quantity > 0 && minimum > 0 && quantity <= minimum;
      }
      final tags = item['tags'] is List
          ? item['tags'] as List
          : '${item['tags'] ?? ''}'.split(',');
      return tag.isEmpty ||
          tags.any((value) => value.toString().trim().toLowerCase() == tag);
    }).toList();
    final start = min((page - 1) * limit, matches.length),
        end = min(page * limit, matches.length);
    return {
      'data': {
        'items': matches.sublist(start, end),
        'total': matches.length,
        'page': page,
        'limit': limit,
        'totalPages': (matches.length / limit).ceil(),
      },
      'updatedAt': row['downloadedAt'],
    };
  }
}
