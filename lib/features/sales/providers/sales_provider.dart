import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/providers/shop_provider.dart';
import '../../../core/network/api_client.dart';

class SalesRepository {
  final ApiClient _api;
  SalesRepository(this._api);

  Future<Map<String, dynamic>> findAll({
    int page = 1,
    int limit = 20,
    String? status,
    int? customerId,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (status != null) params['status'] = status;
    if (customerId != null) params['customerId'] = '$customerId';
    return await _api.get('/sales-orders', params: params);
  }

  Future<Map<String, dynamic>> findById(int id) async =>
      await _api.get('/sales-orders/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async =>
      await _api.post('/sales-orders', data: dto);
  Future<Map<String, dynamic>> cancel(int id) async =>
      await _api.post('/sales-orders/$id/cancel');
  Future<Map<String, dynamic>> addPayment(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.post('/sales-orders/$id/payments', data: dto);
  Future<Map<String, dynamic>> createReturn(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.post('/sales-orders/$id/returns', data: dto);

  Future<Map<String, dynamic>> getSummary(String from, String to) async =>
      await _api.get('/sales-orders/summary', params: {'from': from, 'to': to});

  Future<List<dynamic>> getTopProducts(String from, String to) async {
    final res = await _api.get(
      '/sales-orders/top-products',
      params: {'from': from, 'to': to},
    );
    return res as List<dynamic>? ?? [];
  }
}

final salesRepoProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(ref.read(apiClientProvider)),
);

final salesListProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({int page, String? status, int? customerId})
    >((ref, args) {
      return ref
          .read(salesRepoProvider)
          .findAll(
            page: args.page,
            status: args.status,
            customerId: args.customerId,
          );
    });

final salesDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  id,
) {
  return ref.read(salesRepoProvider).findById(id);
});

final salesSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref.read(salesRepoProvider).getSummary(args.from, args.to);
    });

final topProductsProvider =
    FutureProvider.family<List<dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref.read(salesRepoProvider).getTopProducts(args.from, args.to);
    });

final recentTransactionsProvider = FutureProvider<List<dynamic>>((ref) async {
  final shopState = ref.watch(shopProvider);
  if (shopState.userShops.isEmpty) return [];
  final res = await ref.read(salesRepoProvider).findAll(page: 1, limit: 5);
  return res['items'] as List<dynamic>? ?? [];
});
