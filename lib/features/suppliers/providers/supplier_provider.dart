import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

class SupplierRepository {
  final ApiClient _api;
  SupplierRepository(this._api);

  Future<Map<String, dynamic>> findAll({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (search != null) params['search'] = search;
    final data = await _api.get('/suppliers', params: params);
    return _requirePagedResponse(data, 'Dữ liệu nhà cung cấp không hợp lệ');
  }

  Future<Map<String, dynamic>> findById(int id) async =>
      await _api.get('/suppliers/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async =>
      await _api.post('/suppliers', data: dto);
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async =>
      await _api.put('/suppliers/$id', data: dto);
  Future<void> delete(int id) async => await _api.delete('/suppliers/$id');
  Future<List<dynamic>> findPayables(int id) async {
    final data = await _api.get('/suppliers/$id/payables');
    if (data is! List) {
      throw ApiException('Dữ liệu công nợ nhà cung cấp không hợp lệ');
    }
    return List<dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getPayablesAging(String asOf) async {
    final data = await _api.get(
      '/suppliers/payables-aging',
      params: {'asOf': asOf},
    );
    if (data is! Map ||
        data['asOf'] == null ||
        data['buckets'] is! Map ||
        data['summary'] is! Map ||
        data['suppliers'] is! List ||
        data['items'] is! List) {
      throw ApiException('Dữ liệu tuổi nợ phải trả không đầy đủ');
    }
    final summary = data['summary'] as Map;
    final buckets = data['buckets'] as Map;
    _requireNumericFields(summary, const [
      'totalOutstanding',
      'overdueOutstanding',
      'overdueRatio',
      'payableCount',
      'supplierCount',
    ]);
    _requireNumericFields(buckets, const [
      'current',
      'past30',
      'past60',
      'past90',
    ]);
    return Map<String, dynamic>.from(data);
  }
}

Map<String, dynamic> _requirePagedResponse(dynamic data, String message) {
  if (data is! Map ||
      data['items'] is! List ||
      data['total'] is! num ||
      data['page'] is! num ||
      data['totalPages'] is! num) {
    throw ApiException(message);
  }
  return Map<String, dynamic>.from(data);
}

void _requireNumericFields(Map<dynamic, dynamic> data, List<String> fields) {
  if (fields.any((field) => data[field] is! num)) {
    throw ApiException('Dữ liệu tuổi nợ phải trả không đầy đủ');
  }
}

final supplierRepoProvider = Provider<SupplierRepository>((ref) {
  ref.watch(shopProvider);
  return SupplierRepository(ref.read(apiClientProvider));
});

final supplierListProvider =
    FutureProvider.family<Map<String, dynamic>, ({int page, String? search})>((
      ref,
      args,
    ) {
      return ref
          .watch(supplierRepoProvider)
          .findAll(page: args.page, search: args.search);
    });

/// Complete option set for purchase forms so suppliers beyond page one are not
/// omitted from the selector.
final supplierOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(supplierRepoProvider).findAll(page: 1, limit: 500);
});

final supplierDetailProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) {
    return ref.watch(supplierRepoProvider).findById(id);
  },
);

final supplierPayablesAgingProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, asOf) {
      return ref.watch(supplierRepoProvider).getPayablesAging(asOf);
    });
