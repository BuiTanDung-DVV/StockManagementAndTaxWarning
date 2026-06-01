import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class ProductRepository {
  final ApiClient _api;
  ProductRepository(this._api);

  Future<Map<String, dynamic>> findAll({int page = 1, int limit = 20, String? search, String? tag}) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (search != null) params['search'] = search;
    if (tag != null && tag.trim().isNotEmpty) params['tag'] = tag.trim();
    return await _api.get('/products', params: params);
  }

  Future<Map<String, dynamic>> findById(int id) async => await _api.get('/products/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async => await _api.post('/products', data: dto);
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async => await _api.put('/products/$id', data: dto);
  Future<void> delete(int id) async => await _api.delete('/products/$id');
  Future<List<dynamic>> findCategories() async => await _api.get('/categories');
}

final productRepoProvider = Provider<ProductRepository>((ref) => ProductRepository(ref.read(apiClientProvider)));

final productListProvider = FutureProvider.family<Map<String, dynamic>, ({int page, String? search, String? tag})>((ref, args) {
  return ref.read(productRepoProvider).findAll(page: args.page, search: args.search, tag: args.tag);
});

final productDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(productRepoProvider).findById(id);
});

final categoriesProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(productRepoProvider).findCategories();
});

final availableTagsProvider = FutureProvider<List<String>>((ref) async {
  // Fetch a batch of products to extract unique tags (for the Tag Bar)
  final res = await ref.read(productRepoProvider).findAll(limit: 500);
  final items = (res['items'] as List?) ?? [];
  final Set<String> tagSet = {};
  
  for (final item in items) {
    final tagsRaw = item['tags'];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        if (t != null && t.toString().trim().isNotEmpty) {
          tagSet.add(t.toString().trim());
        }
      }
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      final parts = tagsRaw.split(',');
      for (final p in parts) {
        if (p.trim().isNotEmpty) tagSet.add(p.trim());
      }
    }
  }
  
  final list = tagSet.toList()..sort();
  return list;
});
