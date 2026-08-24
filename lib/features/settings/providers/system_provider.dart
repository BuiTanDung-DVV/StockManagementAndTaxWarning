import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'shop_provider.dart';

class SystemRepository {
  final ApiClient _api;
  SystemRepository(this._api);

  Future<Map<String, dynamic>> getShopProfile() async =>
      await _api.get('/shop-profile');
  Future<Map<String, dynamic>> saveShopProfile(
    Map<String, dynamic> dto,
  ) async => await _api.post('/shop-profile', data: dto);

  Future<List<Map<String, String>>> getPaymentBanks() async {
    final data = await _api.get('/payment-banks');
    if (data is! List) throw ApiException('Danh mục ngân hàng không hợp lệ');
    return data.map<Map<String, String>>((item) {
      final row = Map<String, dynamic>.from(item as Map);
      return {
        'id': row['id']?.toString() ?? '',
        'name': row['name']?.toString() ?? '',
      };
    }).toList();
  }

  Future<Map<String, dynamic>> getLogs({int page = 1, int limit = 50}) async =>
      await _api.get(
        '/activity-logs',
        params: {'page': '$page', 'limit': '$limit'},
      );

  Future<String?> getShopPaymentQr() async {
    final data = Map<String, dynamic>.from(await _api.get('/shop-payment-qr'));
    final imageUrl = data['imageUrl']?.toString().trim();
    return imageUrl == null || imageUrl.isEmpty ? null : imageUrl;
  }

  Future<String> uploadShopPaymentQr({
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final uploaded = await _api.postImage(
      '/shop-payment-qr/upload',
      bytes,
      fileName,
      contentType,
    );
    final objectKey = uploaded['objectKey']?.toString() ?? '';
    if (objectKey.isEmpty) throw ApiException('Máy chủ không trả về định danh QR');
    final confirmed = Map<String, dynamic>.from(
      await _api.post(
        '/shop-payment-qr/confirm',
        data: {'objectKey': objectKey},
      ),
    );
    final imageUrl = confirmed['imageUrl']?.toString() ?? '';
    if (imageUrl.isEmpty) {
      throw ApiException('Không nhận được địa chỉ QR sau khi tải lên');
    }
    return imageUrl;
  }
}

final systemRepoProvider = Provider<SystemRepository>((ref) {
  ref.watch(shopProvider);
  return SystemRepository(ref.read(apiClientProvider));
});

final shopProfileProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(systemRepoProvider).getShopProfile();
});

final paymentBanksProvider = FutureProvider<List<Map<String, String>>>((ref) {
  return ref.watch(systemRepoProvider).getPaymentBanks();
});

final shopPaymentQrProvider = FutureProvider<String?>((ref) {
  return ref.watch(systemRepoProvider).getShopPaymentQr();
});

final activityLogsProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  page,
) {
  return ref.watch(systemRepoProvider).getLogs(page: page);
});
