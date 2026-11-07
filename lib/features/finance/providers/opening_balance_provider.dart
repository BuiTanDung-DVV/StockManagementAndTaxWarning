import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/opening_balance.dart';

final openingBalanceRepoProvider = Provider<OpeningBalanceRepository>(
  (ref) => OpeningBalanceRepository(ref.watch(apiClientProvider)),
);

class OpeningBalanceRepository {
  final ApiClient api;
  OpeningBalanceRepository(this.api);

  Future<dynamic> _post(
    String path,
    int shopId,
    Map<String, dynamic> data,
    bool Function() current,
  ) async {
    final raw = await api.postInShop(
      path,
      '$shopId',
      data,
      isCurrentScope: current,
    );
    if (!current() || api.shopId != '$shopId') {
      throw ApiException(
        'Tài khoản hoặc cửa hàng đã thay đổi. Hãy mở lại đối chiếu.',
        409,
      );
    }
    return raw;
  }

  Future<OpeningSnapshot> snapshot(
    int shopId,
    String day,
    List<String> keys,
    bool Function() current, {
    List<Map<String, dynamic>> sourceLinks = const [],
  }) async => OpeningSnapshot.fromResponse(
    await _post('/opening-balances/snapshot', shopId, {
      'asOf': day,
      'keys': keys,
      if (sourceLinks.isNotEmpty) 'sourceLinks': sourceLinks,
    }, current),
    shopId,
    day,
  );

  Future<OpeningPreview> preview(
    int shopId,
    Map<String, dynamic> request,
    bool Function() current,
  ) async => OpeningPreview.fromResponse(
    await _post('/opening-balances/preview', shopId, request, current),
    shopId,
    request['asOf'],
    request['expectedRevision'],
  );

  Future<OpeningReceipt> commit(
    int shopId,
    Map<String, dynamic> request,
    bool Function() current,
  ) async => OpeningReceipt.fromResponse(
    await _post('/opening-balances/commit', shopId, request, current),
    shopId,
    request['operationId'],
  );

  Future<OpeningReceipt?> status(
    int shopId,
    String operationId,
    bool Function() current,
  ) async {
    final raw = await api.getOnlineInShop(
      '/opening-balances/operations/$operationId',
      '$shopId',
      isCurrentScope: current,
    );
    return raw == null
        ? null
        : OpeningReceipt.fromResponse(raw, shopId, operationId);
  }

  Future<Map<String, dynamic>> history(
    int shopId,
    bool Function() current, {
    int? beforeId,
  }) async {
    final raw = openingMap(
      await api.getOnlineInShop(
        '/opening-balances/history',
        '$shopId',
        params: {if (beforeId != null) 'beforeId': '$beforeId'},
        isCurrentScope: current,
      ),
    );
    if (raw['items'] is! List) {
      throw const FormatException('Lịch sử đối chiếu không hợp lệ');
    }
    return raw;
  }

  Future<List<Map<String, dynamic>>> options(
    int shopId,
    String kind,
    String search,
    bool Function() current,
  ) async {
    final path = switch (kind) {
      'STOCK' => '/products',
      'RECEIVABLE' => '/customers',
      'PAYABLE' => '/suppliers',
      _ => throw ArgumentError('Loại đối tượng không hợp lệ'),
    };
    final raw = openingMap(
      await api.getOnlineInShop(
        path,
        '$shopId',
        params: {'page': '1', 'limit': '20', 'search': search.trim()},
        isCurrentScope: current,
      ),
    );
    if (raw['items'] is! List) {
      throw const FormatException('Danh sách đối tượng không hợp lệ');
    }
    return (raw['items'] as List)
        .map(openingMap)
        .where((row) => row['isActive'] != false)
        .toList();
  }

  Future<List<Map<String, dynamic>>> warehouses(
    int shopId,
    bool Function() current,
  ) async {
    final raw = await api.getOnlineInShop(
      '/inventory/warehouses',
      '$shopId',
      isCurrentScope: current,
    );
    if (raw is! List) throw const FormatException('Danh sách kho không hợp lệ');
    return raw
        .map(openingMap)
        .where((row) => row['isActive'] != false)
        .toList();
  }
}
