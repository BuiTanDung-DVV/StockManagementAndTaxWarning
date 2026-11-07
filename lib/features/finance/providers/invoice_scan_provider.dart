import '../../../core/providers/data_freshness_provider.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../settings/providers/shop_provider.dart';

class InvoiceScanRepository {
  InvoiceScanRepository(this._api);
  final ApiClient _api;
  Future<Map<String, dynamic>> list({
    int page = 1,
    String? search,
    String? status,
    String? from,
    String? to,
  }) async => Map<String, dynamic>.from(
    await _api.get(
      '/invoice-scans',
      params: {
        'page': page,
        'limit': 12,
        if (search?.isNotEmpty == true) 'search': search,
        if (status != null) 'status': status,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    ),
  );
  Future<Map<String, dynamic>> get(int id) async =>
      Map<String, dynamic>.from(await _api.get('/invoice-scans/$id'));
  Future<Map<String, dynamic>> upload(
    Uint8List bytes,
    String name,
    String type,
  ) => _api.postImage('/invoice-scans/upload', bytes, name, type);
  Future<Map<String, dynamic>> confirm(
    int id,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _api.post('/invoice-scans/$id/confirm', data: data),
  );
  Future<Map<String, dynamic>> retry(int id) async =>
      Map<String, dynamic>.from(await _api.post('/invoice-scans/$id/retry'));
  Future<Map<String, dynamic>> updateInvoice(
    int id,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await _api.put('/invoice-scans/$id/invoice', data: data),
  );
}

typedef InvoiceScanFilter = ({
  int page,
  String search,
  String? status,
  String? from,
  String? to,
});

final filteredInvoiceScanListProvider =
    FutureProvider.family<Map<String, dynamic>, InvoiceScanFilter>((
      ref,
      query,
    ) {
      watchDataFreshness(ref, DataArea.scans);
      return ref
          .watch(invoiceScanRepositoryProvider)
          .list(
            page: query.page,
            search: query.search,
            status: query.status,
            from: query.from,
            to: query.to,
          );
    });

final invoiceScanRepositoryProvider = Provider<InvoiceScanRepository>((ref) {
  ref.watch(shopProvider);
  return InvoiceScanRepository(ref.read(apiClientProvider));
});
final invoiceScanListProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, page) {
      watchDataFreshness(ref, DataArea.scans);
      return ref.watch(invoiceScanRepositoryProvider).list(page: page);
    });
final invoiceScanDetailProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, id) {
      watchDataFreshness(ref, DataArea.scans);
      return ref.watch(invoiceScanRepositoryProvider).get(id);
    });
