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
    String? search,
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (status != null) params['status'] = status;
    if (customerId != null) params['customerId'] = '$customerId';
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (from != null && to != null) {
      params['from'] = from;
      params['to'] = to;
    }
    return await _api.get('/sales-orders', params: params);
  }

  Future<Map<String, dynamic>> findById(int id) async =>
      await _api.get('/sales-orders/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async =>
      await _api.post('/sales-orders', data: dto);
  Future<Map<String, dynamic>> cancel(int id) async =>
      await _api.post('/sales-orders/$id/cancel');
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async =>
      await _api.put('/sales-orders/$id', data: dto);
  Future<Map<String, dynamic>> addPayment(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.post('/sales-orders/$id/payments', data: dto);
  Future<Map<String, dynamic>> createReturn(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.post('/sales-orders/$id/returns', data: dto);

  Future<Map<String, dynamic>> getSummary(String from, String to) async {
    final data = Map<String, dynamic>.from(
      await _api.get('/sales-orders/summary', params: {'from': from, 'to': to}),
    );
    const numericKeys = [
      'orderCount',
      'netSalesRevenue',
      'grossProfit',
      'returnNetSalesRevenue',
      'returnRatePct',
      'totalCogs',
    ];
    final hasInvalidMetric = numericKeys.any((key) {
      final value = num.tryParse(data[key]?.toString() ?? '');
      return value == null || !value.isFinite;
    });
    final daily = data['daily'];
    final period = data['period'];
    final hasInvalidDaily =
        daily is List &&
        daily.any((item) {
          if (item is! Map || item['date'] == null) return true;
          return const [
            'revenue',
            'cogs',
            'grossProfit',
            'marginPct',
            'orderCount',
          ].any((key) {
            final value = num.tryParse(item[key]?.toString() ?? '');
            return value == null || !value.isFinite;
          });
        });
    if (hasInvalidMetric ||
        daily is! List ||
        hasInvalidDaily ||
        period is! Map ||
        period['from'] == null ||
        period['to'] == null ||
        data['timezone'] == null) {
      throw ApiException('Dữ liệu tổng quan bán hàng không đầy đủ');
    }
    return data;
  }

  Future<List<dynamic>> getTopProducts(
    String from,
    String to, {
    String? previousFrom,
    String? previousTo,
  }) async {
    final params = <String, dynamic>{'from': from, 'to': to};
    if (previousFrom != null && previousTo != null) {
      params['previousFrom'] = previousFrom;
      params['previousTo'] = previousTo;
    }
    final res = await _api.get('/sales-orders/top-products', params: params);
    if (res is! List) {
      throw ApiException('Dữ liệu sản phẩm bán chạy không hợp lệ');
    }
    return List<dynamic>.from(res);
  }

  Future<List<dynamic>> getPaymentSummary(String from, String to) async {
    final res = await _api.get(
      '/sales-orders/payment-summary',
      params: {'from': from, 'to': to},
    );
    if (res is! List) {
      throw ApiException('Dữ liệu phương thức thanh toán không hợp lệ');
    }
    return List<dynamic>.from(res);
  }

  Future<List<dynamic>> getTopReturnedProducts(String from, String to) async {
    final res = await _api.get(
      '/sales-orders/top-returns',
      params: {'from': from, 'to': to},
    );
    if (res is! List) {
      throw ApiException('Dữ liệu sản phẩm hoàn trả không hợp lệ');
    }
    return List<dynamic>.from(res);
  }
}

final salesRepoProvider = Provider<SalesRepository>((ref) {
  ref.watch(shopProvider);
  return SalesRepository(ref.read(apiClientProvider));
});

final salesListProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({
        int page,
        String? status,
        int? customerId,
        String? search,
        String? from,
        String? to,
      })
    >((ref, args) {
      return ref
          .watch(salesRepoProvider)
          .findAll(
            page: args.page,
            status: args.status,
            customerId: args.customerId,
            search: args.search,
            from: args.from,
            to: args.to,
          );
    });

final salesDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  id,
) {
  return ref.watch(salesRepoProvider).findById(id);
});

final salesSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref.watch(salesRepoProvider).getSummary(args.from, args.to);
    });

final topProductsProvider =
    FutureProvider.family<
      List<dynamic>,
      ({String from, String to, String? previousFrom, String? previousTo})
    >((ref, args) {
      return ref
          .watch(salesRepoProvider)
          .getTopProducts(
            args.from,
            args.to,
            previousFrom: args.previousFrom,
            previousTo: args.previousTo,
          );
    });

final recentTransactionsProvider = FutureProvider<List<dynamic>>((ref) async {
  final shopState = ref.watch(shopProvider);
  if (shopState.userShops.isEmpty) return [];
  final res = await ref.watch(salesRepoProvider).findAll(page: 1, limit: 5);
  final items = res['items'];
  if (items is! List) {
    throw ApiException('Dữ liệu giao dịch gần đây không hợp lệ');
  }
  return List<dynamic>.from(items);
});

final paymentSummaryProvider =
    FutureProvider.family<List<dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref.watch(salesRepoProvider).getPaymentSummary(args.from, args.to);
    });

final topReturnedProductsProvider =
    FutureProvider.family<List<dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      return ref
          .watch(salesRepoProvider)
          .getTopReturnedProducts(args.from, args.to);
    });
