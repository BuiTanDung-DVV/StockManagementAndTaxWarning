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
  Future<List<dynamic>> findEvidence(int customerId) async =>
      await _api.get('/customers/$customerId/evidence');

  Future<Map<String, dynamic>> uploadEvidenceImage({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final signed = Map<String, dynamic>.from(
      await _api.post(
        '/customers/evidence-upload/presign',
        data: {
          'fileName': fileName,
          'contentType': contentType,
          'size': bytes.length,
        },
      ),
    );
    final uploadUrl = signed['uploadUrl']?.toString() ?? '';
    final objectKey = signed['objectKey']?.toString() ?? '';
    final fields = Map<String, dynamic>.from(
      signed['fields'] as Map? ?? const {},
    );
    if (uploadUrl.isEmpty || objectKey.isEmpty || fields.isEmpty) {
      throw ApiException('Máy chủ không tạo được liên kết tải chứng từ');
    }

    final uploaded = await _api.postSignedImageUpload(
      uploadUrl,
      bytes,
      fileName,
      contentType,
      fields,
    );
    if (uploaded['public_id']?.toString() != objectKey) {
      throw ApiException('Cloudinary trả về định danh chứng từ không hợp lệ');
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
  Future<Map<String, dynamic>> getDebtAging({String? asOf}) async {
    final params = <String, dynamic>{};
    if (asOf != null) params['asOf'] = asOf;
    return await _api.get('/customers/debt-aging', params: params);
  }

  Future<List<dynamic>> findOverdueDebts() async =>
      await _api.get('/customers/overdue-debts');
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
