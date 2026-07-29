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
    final signed = Map<String, dynamic>.from(
      await _api.post(
        '/shop-payment-qr/presign',
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
      throw ApiException('Máy chủ không tạo được liên kết tải QR');
    }

    final uploaded = await _api.postSignedImageUpload(
      uploadUrl,
      bytes,
      fileName,
      contentType,
      fields,
    );
    if (uploaded['public_id']?.toString() != objectKey) {
      throw ApiException('Cloudinary trả về định danh QR không hợp lệ');
    }
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

final shopPaymentQrProvider = FutureProvider<String?>((ref) {
  return ref.watch(systemRepoProvider).getShopPaymentQr();
});

final activityLogsProvider = FutureProvider.family<Map<String, dynamic>, int>((
  ref,
  page,
) {
  return ref.watch(systemRepoProvider).getLogs(page: page);
});
