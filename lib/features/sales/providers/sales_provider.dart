import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class SalesRepository {
  final ApiClient _api;
  SalesRepository(this._api);

  Future<Map<String, dynamic>> findAll({int page = 1, int limit = 20, String? status}) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (status != null) params['status'] = status;
    return await _api.get('/sales-orders', params: params);
  }

  Future<Map<String, dynamic>> findById(int id) async => await _api.get('/sales-orders/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async => await _api.post('/sales-orders', data: dto);
  Future<Map<String, dynamic>> cancel(int id) async => await _api.post('/sales-orders/$id/cancel');
  Future<Map<String, dynamic>> addPayment(int id, Map<String, dynamic> dto) async => await _api.post('/sales-orders/$id/payments', data: dto);

  Future<Map<String, dynamic>> getSummary(String from, String to) async =>
      await _api.get('/sales-orders/summary', params: {'from': from, 'to': to});
}

final salesRepoProvider = Provider<SalesRepository>((ref) => SalesRepository(ref.read(apiClientProvider)));

final salesListProvider = FutureProvider.family<Map<String, dynamic>, ({int page, String? status})>((ref, args) {
  return ref.read(salesRepoProvider).findAll(page: args.page, status: args.status);
});

final salesDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
  return ref.read(salesRepoProvider).findById(id);
});

final salesSummaryProvider = FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((ref, args) {
  return ref.read(salesRepoProvider).getSummary(args.from, args.to);
});
