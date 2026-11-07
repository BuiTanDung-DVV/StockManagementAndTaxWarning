import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/product_import.dart';

class ProductImportRepository {
  final ApiClient _api;
  ProductImportRepository(this._api);

  Future<dynamic> _post(
    String action,
    int shopId,
    Map<String, dynamic> body,
    bool Function() current,
  ) async {
    final result = await _api.postInShop(
      '/products/import/$action',
      '$shopId',
      body,
      isCurrentScope: current,
    );
    if (!current() || _api.shopId != '$shopId') {
      throw ApiException('Tài khoản, cửa hàng hoặc quyền đã thay đổi.', 409);
    }
    return result;
  }

  Future<ProductImportInspection> inspect(
    int shopId,
    String csv,
    bool Function() current,
  ) async => ProductImportInspection.fromJson(
    await _post('inspect', shopId, {'csv': csv}, current),
  );

  Future<ProductImportPreview> preview(
    int shopId,
    String csv,
    Map<String, dynamic> options,
    bool Function() current,
  ) async => ProductImportPreview.fromJson(
    await _post('preview', shopId, {'csv': csv, 'options': options}, current),
    shopId,
  );

  Future<ProductImportResult> commit(
    int shopId,
    Map<String, dynamic> request,
    bool Function() current,
  ) async => ProductImportResult.fromJson(
    await _post('commit', shopId, request, current),
    shopId,
    request['operationId'] as String,
  );

  Future<ProductImportResult?> findResult(
    int shopId,
    String operationId,
    bool Function() current,
  ) async {
    final result = Map<String, dynamic>.from(
      await _api.getOnlineInShop(
        '/products/import/operations/$operationId',
        '$shopId',
        isCurrentScope: current,
      ),
    );
    if (!current() || _api.shopId != '$shopId') {
      throw ApiException('Phạm vi đã thay đổi.', 409);
    }
    if (result['state'] == 'UNKNOWN') return null;
    if (result['state'] != 'COMPLETED') {
      throw const FormatException('Chưa xác nhận được trạng thái nhập.');
    }
    return ProductImportResult.fromJson(result['result'], shopId, operationId);
  }
}

final productImportRepoProvider = Provider(
  (ref) => ProductImportRepository(ref.watch(apiClientProvider)),
);
