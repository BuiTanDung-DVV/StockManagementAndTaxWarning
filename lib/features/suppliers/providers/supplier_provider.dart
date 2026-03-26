import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class SupplierRepository {
  final ApiClient _api;
  SupplierRepository(this._api);

  Future<Map<String, dynamic>> findAll({int page = 1, int limit = 20, String? search}) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (search != null) params['search'] = search;
    return await _api.get('/suppliers', params: params);
  }

  Future<Map<String, dynamic>> findById(int id) async => await _api.get('/suppliers/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async => await _api.post('/suppliers', data: dto);
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async => await _api.put('/suppliers/$id', data: dto);
  Future<List<dynamic>> findPayables(int id) async => await _api.get('/suppliers/$id/payables');
}

final supplierRepoProvider = Provider<SupplierRepository>((ref) => SupplierRepository(ref.read(apiClientProvider)));

final supplierListProvider = FutureProvider.family<Map<String, dynamic>, ({int page, String? search})>((ref, args) {
  return ref.read(supplierRepoProvider).findAll(page: args.page, search: args.search);
});

final supplierDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(supplierRepoProvider).findById(id);
});
