import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'shop_provider.dart';

class SettingsOperationsRepository {
  SettingsOperationsRepository(this._api);
  final ApiClient _api;

  Future<List<dynamic>> categories({String? search}) async =>
      List<dynamic>.from(
        await _api.get(
          '/categories',
          params: {
            'includeInactive': 'true',
            if (search?.trim().isNotEmpty ?? false) 'search': search!.trim(),
          },
        ),
      );
  Future<void> createCategory(Map<String, dynamic> data) =>
      _api.post('/categories', data: data);
  Future<void> updateCategory(int id, Map<String, dynamic> data) =>
      _api.put('/categories/$id', data: data);
  Future<void> deactivateCategory(int id, {int? replacementCategoryId}) {
    final data = <String, dynamic>{'action': 'deactivate'};
    if (replacementCategoryId != null) {
      data['replacementCategoryId'] = replacementCategoryId;
    }
    return _api.delete('/categories/$id', data: data);
  }

  Future<Map<String, dynamic>> shopProfile() async =>
      Map<String, dynamic>.from(await _api.get('/shop-profile'));
  Future<Map<String, dynamic>> saveReceiptConfig(
    Map<String, dynamic> config,
  ) async => Map<String, dynamic>.from(
    await _api.post('/shop-profile', data: {'receiptTemplateConfig': config}),
  );

  Future<List<dynamic>> carriers() async => List<dynamic>.from(
    await _api.get('/shipping-carriers', params: {'includeInactive': 'true'}),
  );
  Future<void> createCarrier(Map<String, dynamic> data) =>
      _api.post('/shipping-carriers', data: data);
  Future<void> updateCarrier(int id, Map<String, dynamic> data) =>
      _api.put('/shipping-carriers/$id', data: data);
  Future<void> deactivateCarrier(int id) =>
      _api.delete('/shipping-carriers/$id');

  Future<Uint8List> exportBackup(String password) =>
      _api.postForBytes('/shop-backups/export', data: {'password': password});
  Future<Map<String, dynamic>> validateBackup(
    Uint8List bytes,
    String password,
  ) => _api.postGzip('/shop-backups/validate', bytes, password);
  Future<Map<String, dynamic>> restoreBackup(
    String backupId,
    String password,
  ) async => Map<String, dynamic>.from(
    await _api.post(
      '/shop-backups/restore',
      data: {'backupId': backupId, 'password': password},
    ),
  );
  Future<Map<String, dynamic>> rollback(
    String rollbackId,
    String password,
  ) async => Map<String, dynamic>.from(
    await _api.post(
      '/shop-backups/$rollbackId/rollback',
      data: {'password': password},
    ),
  );
}

final settingsOperationsRepositoryProvider =
    Provider<SettingsOperationsRepository>((ref) {
      ref.watch(shopProvider);
      return SettingsOperationsRepository(ref.read(apiClientProvider));
    });
