import '../../../core/providers/data_freshness_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/xnt_export.dart';
import '../models/purchase_order_suggestion.dart';
import '../models/replenishment_safety.dart';
import '../../settings/providers/shop_provider.dart';

class InventoryRepository {
  final ApiClient _api;
  InventoryRepository(this._api);
  Future<Map<String, dynamic>> createPurchaseFromScan(
    int scanId,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _api.post('/invoice-scans/$scanId/purchase-order', data: data),
  );

  Future<dynamic> getCurrentStock({int? warehouseId, int limit = 500}) async {
    final params = <String, dynamic>{'page': '1', 'limit': '$limit'};
    if (warehouseId != null) params['warehouseId'] = '$warehouseId';
    return await _api.get('/inventory/stock', params: params);
  }

  Future<List<dynamic>> getLowStock({int? threshold}) async => await _api.get(
    '/inventory/low-stock',
    params: threshold == null ? const {} : {'threshold': '$threshold'},
  );

  Future<Map<String, dynamic>> getMovements({
    int? productId,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (productId != null) params['productId'] = '$productId';
    return await _api.get('/inventory/movements', params: params);
  }

  Future<List<dynamic>> findWarehouses() async =>
      await _api.get('/inventory/warehouses');

  Future<List<dynamic>> getCategoriesSummary() async {
    final res = await _api.get('/inventory/categories-summary');
    if (res is! List) {
      throw ApiException('Dữ liệu tổng hợp danh mục kho không hợp lệ');
    }
    return List<dynamic>.from(res);
  }

  Future<Map<String, dynamic>> getAbcAnalysis(String from, String to) async {
    final result = await _api.get(
      '/inventory/abc-analysis',
      params: {'from': from, 'to': to},
    );
    if (result is! Map) {
      throw ApiException('Dữ liệu phân tích ABC không hợp lệ');
    }
    final data = Map<String, dynamic>.from(result);
    const numericKeys = [
      'totalRevenue',
      'classificationRevenue',
      'negativeReturnAdjustment',
      'returnedMoreThanSoldSkuCount',
      'totalStockValue',
      'skuCount',
    ];
    final hasInvalidMetric = numericKeys.any((key) {
      final value = num.tryParse(data[key]?.toString() ?? '');
      return value == null || !value.isFinite;
    });
    final period = data['period'];
    if (hasInvalidMetric ||
        data['grades'] is! List ||
        data['items'] is! List ||
        period is! Map ||
        period['from'] == null ||
        period['to'] == null ||
        data['timezone'] == null) {
      throw ApiException('Dữ liệu phân tích ABC không đầy đủ');
    }
    return data;
  }

  Future<XntExport> exportXntInShop(
    int shopId, {
    required String from,
    required String to,
    int? warehouseId,
    required bool Function() isCurrentScope,
  }) async {
    final response = await _api.getOnlineInShop(
      '/inventory/xnt-export',
      '$shopId',
      params: {
        'from': from,
        'to': to,
        if (warehouseId != null) 'warehouseId': '$warehouseId',
      },
      isCurrentScope: isCurrentScope,
    );
    if (!isCurrentScope() || _api.shopId != '$shopId') {
      throw ApiException('Phạm vi báo cáo đã thay đổi.', 409);
    }
    return XntExport.fromResponse(
      response,
      shopId: shopId,
      from: from,
      to: to,
      warehouseId: warehouseId,
    );
  }

  Future<Map<String, dynamic>> getXNTReport(
    String from,
    String to, {
    int? warehouseId,
  }) async {
    final params = <String, dynamic>{'from': from, 'to': to};
    if (warehouseId != null) params['warehouseId'] = '$warehouseId';
    final result = await _api.get('/inventory/xnt-report', params: params);
    if (result is List) return {'items': result, 'summary': {}};
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<dynamic>> getExpiringProducts({int daysAhead = 30}) async =>
      await _api.get(
        '/inventory/expiring-products',
        params: {'daysAhead': '$daysAhead'},
      );

  Future<List<dynamic>> getSlowMovingProducts({int daysUnsold = 30}) async =>
      await _api.get(
        '/inventory/slow-moving',
        params: {'daysUnsold': '$daysUnsold'},
      );

  Future<Map<String, dynamic>> findPurchaseOrders({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async => await _api.get(
    '/purchase-orders',
    params: {
      'page': '$page',
      'limit': '$limit',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    },
  );

  Future<Map<String, dynamic>> createPurchaseOrder(
    Map<String, dynamic> dto,
  ) async => await _api.post('/purchase-orders', data: dto);

  Future<List<PendingPurchaseMatch>> reviewReplenishmentInShop(
    int shopId,
    List<ReplenishmentLine> selected, {
    required bool Function() isCurrentScope,
  }) => checkReplenishmentSafety(
    shopId: shopId,
    selected: selected,
    isCurrentScope: isCurrentScope,
    loadStock: () async {
      final rows = await _api.getOnlineInShop(
        '/inventory/low-stock',
        '$shopId',
        isCurrentScope: isCurrentScope,
      );
      if (rows is! List) {
        throw ApiException('Dữ liệu tồn kho mới không đầy đủ.');
      }
      return rows;
    },
    loadPendingPage: (page) async {
      final result = await _api.getOnlineInShop(
        '/purchase-orders',
        '$shopId',
        params: {'page': '$page', 'limit': '100', 'status': 'PENDING'},
        isCurrentScope: isCurrentScope,
      );
      if (result is! Map) throw ApiException('Chưa tải được phiếu nhập chờ.');
      return Map<String, dynamic>.from(result);
    },
  );

  Future<Map<String, dynamic>> getPurchaseOrderInShop(
    int id,
    int shopId, {
    required bool Function() isCurrentScope,
  }) async {
    final result = await _api.getOnlineInShop(
      '/purchase-orders/$id',
      '$shopId',
      isCurrentScope: isCurrentScope,
    );
    if (result is! Map ||
        '${result['id']}' != '$id' ||
        '${result['shopId']}' != '$shopId') {
      throw ApiException('Dữ liệu chi tiết đơn nhập không hợp lệ.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<dynamic> updatePurchaseOrderInShop(
    int id,
    int shopId,
    Map<String, dynamic> dto, {
    required bool Function() isCurrentScope,
  }) => _api.putInShop(
    '/purchase-orders/$id',
    '$shopId',
    data: dto,
    isCurrentScope: isCurrentScope,
  );

  Future<dynamic> deletePurchaseOrderInShop(
    int id,
    int shopId, {
    required bool Function() isCurrentScope,
  }) => _api.deleteInShop(
    '/purchase-orders/$id',
    '$shopId',
    isCurrentScope: isCurrentScope,
  );

  Future<Map<String, dynamic>> updatePurchaseOrder(
    int id,
    Map<String, dynamic> dto,
  ) async => await _api.put('/purchase-orders/$id', data: dto);

  Future<void> deletePurchaseOrder(int id) async =>
      await _api.delete('/purchase-orders/$id');

  Future<Map<String, dynamic>> createStockTake(
    Map<String, dynamic> dto,
  ) async => await _api.post('/stock-takes', data: dto);

  Future<Map<String, dynamic>> findStockTakes({
    int page = 1,
    int limit = 20,
  }) async => await _api.get(
    '/stock-takes',
    params: {'page': '$page', 'limit': '$limit'},
  );

  Future<void> deleteStockTake(int id) async =>
      await _api.delete('/stock-takes/$id');

  Future<Map<String, dynamic>> updateStockTakeStatus(
    int id,
    String status,
  ) async => await _api.put('/stock-takes/$id', data: {'status': status});
}

final inventoryRepoProvider = Provider<InventoryRepository>((ref) {
  ref.watch(shopProvider);
  return InventoryRepository(ref.read(apiClientProvider));
});

final stockPageProvider = FutureProvider.family<Map<String, dynamic>, int?>((
  ref,
  warehouseId,
) async {
  watchDataFreshness(ref, DataArea.inventory);
  final result = await ref
      .watch(inventoryRepoProvider)
      .getCurrentStock(warehouseId: warehouseId);
  if (result is Map) {
    final page = Map<String, dynamic>.from(result);
    final items = page['items'];
    final total = num.tryParse(page['total']?.toString() ?? '');
    final productTotal = num.tryParse(page['productTotal']?.toString() ?? '');
    if (items is! List ||
        total == null ||
        !total.isFinite ||
        productTotal == null ||
        !productTotal.isFinite) {
      throw ApiException('Dữ liệu tồn kho không đầy đủ');
    }
    return page;
  }
  if (result is List) {
    return {
      'items': result,
      'total': result.length,
      'productTotal': result.length,
      'page': 1,
      'limit': result.length,
      'totalPages': 1,
    };
  }
  throw ApiException('Dữ liệu tồn kho không hợp lệ');
});

final stockProvider = FutureProvider.family<List<dynamic>, int?>((
  ref,
  warehouseId,
) async {
  watchDataFreshness(ref, DataArea.inventory);
  final result = await ref
      .watch(inventoryRepoProvider)
      .getCurrentStock(warehouseId: warehouseId);
  if (result is List) return result;
  if (result is Map) {
    final items = result['items'];
    if (items is List) return List<dynamic>.from(items);
  }
  throw ApiException('Dữ liệu tồn kho không hợp lệ');
});

final lowStockProvider = FutureProvider<List<dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.inventory);
  return ref.watch(inventoryRepoProvider).getLowStock();
});

final inventoryMovementsProvider =
    FutureProvider.family<Map<String, dynamic>, ({int? productId, int page})>((
      ref,
      args,
    ) {
      watchDataFreshness(ref, DataArea.inventory);
      return ref
          .watch(inventoryRepoProvider)
          .getMovements(productId: args.productId, page: args.page);
    });

final warehousesProvider = FutureProvider<List<dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.inventory);
  return ref.watch(inventoryRepoProvider).findWarehouses();
});

final xntReportProvider =
    FutureProvider.family<
      Map<String, dynamic>,
      ({String from, String to, int? warehouseId})
    >((ref, args) {
      watchDataFreshness(ref, DataArea.inventory);
      return ref
          .watch(inventoryRepoProvider)
          .getXNTReport(args.from, args.to, warehouseId: args.warehouseId);
    });

final expiringProductsProvider = FutureProvider<List<dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.inventory);
  return ref.watch(inventoryRepoProvider).getExpiringProducts();
});

final slowMovingProvider = FutureProvider<List<dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.inventory);
  return ref.watch(inventoryRepoProvider).getSlowMovingProducts();
});

final purchaseOrdersProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, page) {
    watchDataFreshness(ref, DataArea.inventory);
    return ref.watch(inventoryRepoProvider).findPurchaseOrders(page: page);
  },
);

final purchaseOrderQueryProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int page, String search, String status})>((
      ref,
      query,
    ) {
      watchDataFreshness(ref, DataArea.inventory);
      if (query.search.isEmpty && query.status.isEmpty) {
        return ref.watch(purchaseOrdersProvider(query.page).future);
      }
      return ref
          .watch(inventoryRepoProvider)
          .findPurchaseOrders(
            page: query.page,
            search: query.search,
            status: query.status,
          );
    });

final inventoryCategoriesSummaryProvider = FutureProvider<List<dynamic>>((ref) {
  watchDataFreshness(ref, DataArea.inventory);
  return ref.watch(inventoryRepoProvider).getCategoriesSummary();
});

final inventoryAbcProvider =
    FutureProvider.family<Map<String, dynamic>, ({String from, String to})>((
      ref,
      args,
    ) {
      watchDataFreshness(ref, DataArea.inventory);
      return ref
          .watch(inventoryRepoProvider)
          .getAbcAnalysis(args.from, args.to);
    });

final stockTakesProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  page,
) {
  watchDataFreshness(ref, DataArea.inventory);
  return ref.watch(inventoryRepoProvider).findStockTakes(page: page);
});
