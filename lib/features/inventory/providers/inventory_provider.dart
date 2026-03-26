import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class InventoryRepository {
  final ApiClient _api;
  InventoryRepository(this._api);

  Future<List<dynamic>> getCurrentStock({int? warehouseId}) async {
    final params = <String, dynamic>{};
    if (warehouseId != null) params['warehouseId'] = '$warehouseId';
    return await _api.get('/inventory/stock', params: params);
  }

  Future<List<dynamic>> getLowStock({int threshold = 10}) async =>
      await _api.get('/inventory/low-stock', params: {'threshold': '$threshold'});

  Future<Map<String, dynamic>> getMovements({int? productId, int page = 1, int limit = 20}) async {
    final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
    if (productId != null) params['productId'] = '$productId';
    return await _api.get('/inventory/movements', params: params);
  }

  Future<List<dynamic>> findWarehouses() async => await _api.get('/inventory/warehouses');

  Future<Map<String, dynamic>> getXNTReport(String from, String to, {int? warehouseId}) async {
    final params = <String, dynamic>{'from': from, 'to': to};
    if (warehouseId != null) params['warehouseId'] = '$warehouseId';
    return await _api.get('/inventory/xnt-report', params: params);
  }

  Future<List<dynamic>> getExpiringProducts({int daysAhead = 30}) async =>
      await _api.get('/inventory/expiring-products', params: {'daysAhead': '$daysAhead'});

  Future<List<dynamic>> getSlowMovingProducts({int daysUnsold = 30}) async =>
      await _api.get('/inventory/slow-moving', params: {'daysUnsold': '$daysUnsold'});

  Future<Map<String, dynamic>> findPurchaseOrders({int page = 1, int limit = 20}) async =>
      await _api.get('/purchase-orders', params: {'page': '$page', 'limit': '$limit'});

  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> dto) async =>
      await _api.post('/purchase-orders', data: dto);

  Future<Map<String, dynamic>> createStockTake(Map<String, dynamic> dto) async =>
      await _api.post('/stock-takes', data: dto);
}

final inventoryRepoProvider = Provider<InventoryRepository>((ref) => InventoryRepository(ref.read(apiClientProvider)));

final stockProvider = FutureProvider.family<List<dynamic>, int?>((ref, warehouseId) {
  return ref.read(inventoryRepoProvider).getCurrentStock(warehouseId: warehouseId);
});

final lowStockProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(inventoryRepoProvider).getLowStock();
});

final warehousesProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(inventoryRepoProvider).findWarehouses();
});

final xntReportProvider = FutureProvider.family<Map<String, dynamic>, ({String from, String to, int? warehouseId})>((ref, args) {
  return ref.read(inventoryRepoProvider).getXNTReport(args.from, args.to, warehouseId: args.warehouseId);
});

final expiringProductsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(inventoryRepoProvider).getExpiringProducts();
});

final slowMovingProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.read(inventoryRepoProvider).getSlowMovingProducts();
});

final purchaseOrdersProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) {
  return ref.read(inventoryRepoProvider).findPurchaseOrders(page: page);
});
