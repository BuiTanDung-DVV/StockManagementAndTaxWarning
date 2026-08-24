import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';
import 'tag_provider.dart';

class ProductRepository {
  final ApiClient _api;
  ProductRepository(this._api);

  Future<Map<String, dynamic>> findAll({
    int page = 1,
    int limit = 20,
    String? search,
    String? tag,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (search != null) params['search'] = search;
    if (tag != null && tag.trim().isNotEmpty) params['tag'] = tag.trim();
    return await _api.get('/products', params: params);
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
      ({int page, String? search, String? tag})
    >((ref, args) {
      return ref
          .watch(productRepoProvider)
          .findAll(page: args.page, search: args.search, tag: args.tag);
    });

/// Complete option set for transactional forms.
/// List screens remain paginated; forms must not silently hide products after
/// the first API page.
final productOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(productRepoProvider).findAll(page: 1, limit: 500);
});

final productDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  id,
) {
  return ref.watch(productRepoProvider).findById(id);
});

final categoriesProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(productRepoProvider).findCategories();
});

final availableTagsProvider = FutureProvider<List<TagModel>>((ref) async {
  // Fetch managed tags
  final managedTags = await ref.read(tagRepoProvider).getAll(type: 'product');
  final tagMap = {for (var t in managedTags) t.name: t};

  // Fetch recent products to find used tags not in managed list
  final res = await ref.watch(productRepoProvider).findAll(limit: 500);
  final items = res['items'];
  if (items is! List) {
    throw ApiException('Dữ liệu sản phẩm không hợp lệ');
  }
  final Set<String> usedTags = {};

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
  }

  for (final t in usedTags) {
    if (!tagMap.containsKey(t)) {
      tagMap[t] = TagModel(
        id: -1,
        name: t,
        color: '#9CA3AF',
      ); // Gray color for unmanaged tags
    }
  }

  final list = tagMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return list;
});
