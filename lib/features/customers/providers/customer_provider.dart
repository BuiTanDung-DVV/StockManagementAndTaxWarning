import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class CustomerRepository {
  final ApiClient _api;
  CustomerRepository(this._api);

  Future<Map<String, dynamic>> findAll({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (search != null) params['search'] = search;
    return await _api.get('/customers', params: params);
  }

  Future<Map<String, dynamic>> findById(int id) async =>
      await _api.get('/customers/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async =>
      await _api.post('/customers', data: dto);
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async =>
      await _api.put('/customers/$id', data: dto);
  Future<void> delete(int id) async => await _api.delete('/customers/$id');
  Future<List<dynamic>> findReceivables(int id) async =>
      await _api.get('/customers/$id/receivables');
  Future<Map<String, dynamic>> getDebtAging({String? asOf}) async {
    final params = <String, dynamic>{};
    if (asOf != null) params['asOf'] = asOf;
    return await _api.get('/customers/debt-aging', params: params);
  }

  Future<List<dynamic>> findOverdueDebts() async =>
      await _api.get('/customers/overdue-debts');
}

final customerRepoProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.read(apiClientProvider)),
);

final customerListProvider =
    FutureProvider.family<Map<String, dynamic>, ({int page, String? search})>((
      ref,
      args,
    ) {
      return ref
          .read(customerRepoProvider)
          .findAll(page: args.page, search: args.search);
    });

final customerDetailProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) {
    return ref.read(customerRepoProvider).findById(id);
  },
);

final debtAgingProvider = FutureProvider.family<Map<String, dynamic>, String?>((
  ref,
  asOf,
) {
  return ref.read(customerRepoProvider).getDebtAging(asOf: asOf);
});

final overdueDebtsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(customerRepoProvider).findOverdueDebts();
});
