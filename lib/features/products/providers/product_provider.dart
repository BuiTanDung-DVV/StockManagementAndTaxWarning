import '../../../core/providers/data_freshness_provider.dart';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';
import 'tag_provider.dart';
import '../../../core/utils/paged_records.dart';
import '../models/inventory_export.dart';

class ProductRepository {
  final ApiClient _api;
  ProductRepository(this._api);

  Future<InventoryExport> exportInventoryInShop(
    int shopId, {
    String? search,
    String? tag,
    int? categoryId,
    bool inStockOnly = false,
    required bool Function() isCurrentScope,
  }) async {
    final params = <String, dynamic>{
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (tag?.trim().isNotEmpty == true) 'tag': tag!.trim(),
      if (categoryId != null) 'categoryId': '$categoryId',
      if (inStockOnly) 'inStockOnly': 'true',
    };
    final raw = await _api.getOnlineInShop(
      '/products/export',
      '$shopId',
      params: params,
      isCurrentScope: isCurrentScope,
    );
    return InventoryExport.fromResponse(
      raw,
      shopId: shopId,
      search: search,
      tag: tag,
      categoryId: categoryId,
      inStockOnly: inStockOnly,
    );
  }

  Future<Map<String, dynamic>> findAll({
    int page = 1,
    int limit = 20,
    String? search,
    String? tag,
    int? categoryId,
    bool inStockOnly = false,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (search != null) params['search'] = search;
    if (tag != null && tag.trim().isNotEmpty) params['tag'] = tag.trim();
    if (categoryId != null) params['categoryId'] = '$categoryId';
    if (inStockOnly) params['inStockOnly'] = 'true';
    return await _api.get('/products', params: params);
  }

  /// Read every matching page; never export a silently truncated first page.
  Future<List<dynamic>> findAllMatching({
    String? search,
    String? tag,
    int? categoryId,
    bool inStockOnly = false,
    required bool Function() isCurrent,
  }) async {
    final products = <int, dynamic>{};
    int? expectedTotal;
    for (var page = 1; ; page++) {
      if (!isCurrent()) throw StateError('Phạm vi lựa chọn đã thay đổi');
      final data = await findAll(
        page: page,
        limit: 100,
        search: search,
        tag: tag,
        categoryId: categoryId,
        inStockOnly: inStockOnly,
      );
      if (!isCurrent()) throw StateError('Phạm vi lựa chọn đã thay đổi');
      final total = (data['total'] as num?)?.toInt();
      final items = data['items'];
      if (total == null ||
          total < 0 ||
          items is! List ||
          (expectedTotal != null && expectedTotal != total)) {
        throw StateError(
          'Danh sách đã thay đổi. Vui lòng tải lại trước khi xuất.',
        );
      }
      expectedTotal = total;
      var added = 0;
      for (final item in items) {
        final id = int.tryParse('${item['id']}');
        if (id == null || id <= 0) throw StateError('Sản phẩm không hợp lệ');
        if (!products.containsKey(id)) added++;
        products[id] = item;
      }
      if (products.length == total) return products.values.toList();
      if (added == 0 || products.length > total) {
        throw StateError('Không tải đủ danh sách sản phẩm');
      }
    }
  }

  Future<Map<String, dynamic>> findById(int id) async =>
      await _api.get('/products/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async =>
      await _api.post('/products', data: dto);
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async =>
      await _api.put('/products/$id', data: dto);
  Future<void> delete(int id) async => await _api.delete('/products/$id');
  Future<List<dynamic>> findCategories() async => await _api.get('/categories');

  Future<Map<String, dynamic>> uploadProductImage({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final uploaded = await _api.postImage(
      '/products/image-upload',
      bytes,
      fileName,
      contentType,
    );
    final objectKey = uploaded['objectKey']?.toString() ?? '';
    if (objectKey.isEmpty) {
      throw ApiException('Máy chủ không trả về định danh ảnh');
    }
    return Map<String, dynamic>.from(
      await _api.post(
        '/products/image-upload/confirm',
        data: {'objectKey': objectKey},
      ),
    );
  }

  Future<void> deleteProductImage(String objectKey) async {
    await _api.post(
      '/products/image-upload/delete',
      data: {'objectKey': objectKey},
    );
  }
}

final productRepoProvider = Provider<ProductRepository>((ref) {
  ref.watch(shopProvider);
  return ProductRepository(ref.read(apiClientProvider));
});

final productListProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({
        int page,
        String? search,
        String? tag,
        int? categoryId,
        bool inStockOnly,
      })
    >((ref, args) {
      watchDataFreshness(ref, DataArea.products);
      return ref
          .watch(productRepoProvider)
          .findAll(
            page: args.page,
            search: args.search,
            tag: args.tag,
            categoryId: args.categoryId,
            inStockOnly: args.inStockOnly,
          );
    });

/// Complete option set for transactional forms.
/// List screens remain paginated; forms must not silently hide products after
/// the first API page.
final productOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.products);
  final repo = ref.watch(productRepoProvider);
  var active = true;
  ref.onDispose(() => active = false);
  return collectPagedRecords(
    (page, limit) => repo.findAll(page: page, limit: limit),
    isCurrent: () => active,
  );
});

final productDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  id,
) {
  watchDataFreshness(ref, DataArea.products);
  return ref.watch(productRepoProvider).findById(id);
});

final categoriesProvider = FutureProvider<List<dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.products);
  return ref.watch(productRepoProvider).findCategories();
});

final availableTagsProvider = FutureProvider<List<TagModel>>((ref) async {
  watchDataFreshness(ref, DataArea.products);
  // Follow the same sources invalidated by inline tag creation and product saves.
  final sources = await Future.wait<dynamic>([
    ref.watch(tagListProvider('product').future),
    ref.watch(productOptionsProvider.future),
  ]);
  final managedTags = sources[0] as List<TagModel>;
  final tagMap = {for (var t in managedTags) t.name: t};

  // Fetch recent products to find used tags not in managed list
  final res = sources[1] as Map<String, dynamic>;
  final items = res['items'];
  if (items is! List) {
    throw ApiException('Dữ liệu sản phẩm không hợp lệ');
  }
  final Set<String> usedTags = {'Hết hàng', 'Sắp hết'};

  for (final item in items) {
    final tagsRaw = item['tags'];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        if (t != null && t.toString().trim().isNotEmpty) {
          usedTags.add(t.toString().trim());
        }
      }
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      final parts = tagsRaw.split(',');
      for (final p in parts) {
        if (p.trim().isNotEmpty) usedTags.add(p.trim());
      }
    }
    final stock =
        num.tryParse(
          (item['currentStock'] ?? item['stock'] ?? '').toString(),
        ) ??
        0;
    final minStock =
        num.tryParse(
          (item['minStock'] ?? item['minimumStock'] ?? item['min_stock'] ?? '')
              .toString(),
        ) ??
        0;
    if (stock <= 0) {
      usedTags.add('Hết hàng');
    } else if (minStock > 0 && stock <= minStock) {
      usedTags.add('Sắp hết');
    }
  }

  for (final t in usedTags) {
    if (!tagMap.containsKey(t)) {
      final defaultColor = switch (t) {
        'Hết hàng' => '#EF4444',
        'Sắp hết' => '#F59E0B',
        _ => '#9CA3AF',
      };
      tagMap[t] = TagModel(id: -1, name: t, color: defaultColor);
    }
  }

  final list = tagMap.values.toList()
    ..sort((a, b) {
      if (a.name == 'Hết hàng') return -1;
      if (b.name == 'Hết hàng') return 1;
      if (a.name == 'Sắp hết') return -1;
      if (b.name == 'Sắp hết') return 1;
      return a.name.compareTo(b.name);
    });
  return list;
});
