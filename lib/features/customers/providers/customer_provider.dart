import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

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
    final data = await _api.get('/customers', params: params);
    return _requirePagedResponse(data, 'Dữ liệu khách hàng không hợp lệ');
  }

  Future<Map<String, dynamic>> findById(int id) async =>
      await _api.get('/customers/$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> dto) async =>
      await _api.post('/customers', data: dto);
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> dto) async =>
      await _api.put('/customers/$id', data: dto);
  Future<void> delete(int id) async => await _api.delete('/customers/$id');
  Future<List<dynamic>> findReceivables(int id) async => _requireListResponse(
    await _api.get('/customers/$id/receivables'),
    'Dữ liệu công nợ khách hàng không hợp lệ',
  );
  Future<List<dynamic>> findEvidence(int customerId) async =>
      _requireListResponse(
        await _api.get('/customers/$customerId/evidence'),
        'Dữ liệu chứng từ công nợ không hợp lệ',
      );

  Future<Map<String, dynamic>> uploadEvidenceImage({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final uploaded = await _api.postImage(
      '/customers/evidence-upload',
      bytes,
      fileName,
      contentType,
    );
    final objectKey = uploaded['objectKey']?.toString() ?? '';
    if (objectKey.isEmpty) {
      throw ApiException('Máy chủ không trả về định danh chứng từ');
    }
    return Map<String, dynamic>.from(
      await _api.post(
        '/customers/evidence-upload/confirm',
        data: {'objectKey': objectKey},
      ),
    );
  }

  Future<void> deletePendingEvidenceImage(String objectKey) async {
    await _api.post(
      '/customers/evidence-upload/delete',
      data: {'objectKey': objectKey},
    );
  }

  Future<Map<String, dynamic>> addEvidence(
    int receivableId,
    Map<String, dynamic> dto,
  ) async => await _api.post(
    '/customers/receivables/$receivableId/evidence',
    data: dto,
  );

  Future<void> deleteEvidence(int evidenceId) async =>
      await _api.delete('/customers/evidence/$evidenceId');
  Future<Map<String, dynamic>> collectReceivablePayment(
    int receivableId,
    Map<String, dynamic> dto,
  ) async => await _api.post(
    '/customers/receivables/$receivableId/payments',
    data: dto,
  );
  Future<Map<String, dynamic>> getDebtAging({String? asOf}) async {
    final params = <String, dynamic>{};
    if (asOf != null) params['asOf'] = asOf;
    final data = await _api.get('/customers/debt-aging', params: params);
    if (data is! Map ||
        data['asOf'] == null ||
        data['buckets'] is! Map ||
        data['summary'] is! Map ||
        data['customers'] is! List) {
      throw ApiException('Dữ liệu tuổi nợ phải thu không đầy đủ');
    }
    final summary = data['summary'] as Map;
    final buckets = data['buckets'] as Map;
    _requireNumericFields(summary, const [
      'totalDebt',
      'overdueDebt',
      'receivableCount',
      'customerCount',
      'currentRatio',
      'overdueRatio',
    ], 'Dữ liệu tuổi nợ phải thu không đầy đủ');
    _requireNumericFields(buckets, const [
      'current',
      'past30',
      'past60',
      'past90',
    ], 'Dữ liệu tuổi nợ phải thu không đầy đủ');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getOpenReceivablesPage({
    required Map<String, dynamic> params,
  }) async => _requirePagedResponse(
    await _api.get('/customer-receivables/paged', params: params),
    'Dữ liệu danh sách công nợ không hợp lệ',
  );

  Future<List<dynamic>> exportOpenReceivables({
    required Map<String, dynamic> params,
  }) async => _requireListResponse(
    await _api.get('/customer-receivables/export', params: params),
    'Dữ liệu xuất công nợ không hợp lệ',
  );

  Future<List<dynamic>> findOverdueDebts() async => _requireListResponse(
    await _api.get('/customers/overdue-debts'),
    'Dữ liệu nợ quá hạn không hợp lệ',
  );
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

List<dynamic> _requireListResponse(dynamic data, String message) {
  if (data is! List) throw ApiException(message);
  return List<dynamic>.from(data);
}

void _requireNumericFields(
  Map<dynamic, dynamic> data,
  List<String> fields,
  String message,
) {
  if (fields.any((field) => data[field] is! num)) {
    throw ApiException(message);
  }
}

final customerRepoProvider = Provider<CustomerRepository>((ref) {
  ref.watch(shopProvider);
  return CustomerRepository(ref.read(apiClientProvider));
});

final customerListProvider =
    FutureProvider.family<Map<String, dynamic>, ({int page, String? search})>((
      ref,
      args,
    ) {
      return ref
          .watch(customerRepoProvider)
          .findAll(page: args.page, search: args.search);
    });

/// Complete option set for POS pickers. The customer management screen remains
/// paginated, while a sales flow must be able to select beyond page one.
final customerOptionsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(customerRepoProvider).findAll(page: 1, limit: 500);
});

final customerDetailProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) {
    return ref.watch(customerRepoProvider).findById(id);
  },
);

final customerReceivablesProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  customerId,
) {
  return ref.watch(customerRepoProvider).findReceivables(customerId);
});

final customerEvidenceProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  customerId,
) {
  return ref.watch(customerRepoProvider).findEvidence(customerId);
});

final debtAgingProvider = FutureProvider.family<Map<String, dynamic>, String?>((
  ref,
  asOf,
) {
  return ref.watch(customerRepoProvider).getDebtAging(asOf: asOf);
});

final overdueDebtsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(customerRepoProvider).findOverdueDebts();
});
