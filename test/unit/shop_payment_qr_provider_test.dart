import 'dart:typed_data';

import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/features/settings/providers/system_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQrApiClient extends ApiClient {
  final List<String> calls = [];
  Uint8List? uploadedBytes;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    calls.add(path);
    return {
      'imageUrl':
          'https://res.cloudinary.com/demo/image/upload/'
          'v1/smartstock/shops/4/payment-qr/qr.webp',
    };
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add(path);
    return {
      'imageUrl':
          'https://res.cloudinary.com/demo/image/upload/'
          'v1/smartstock/shops/4/payment-qr/qr.webp',
    };
  }

  @override
  Future<Map<String, dynamic>> postImage(
    String path,
    Uint8List bytes,
    String fileName,
    String contentType,
  ) async {
    calls.add('$path $contentType');
    uploadedBytes = bytes;
    return {'objectKey': 'smartstock/shops/4/payment-qr/qr'};
  }
}

void main() {
  test('loads and uploads the QR assigned to the active shop', () async {
    final api = _FakeQrApiClient();
    final repository = SystemRepository(api);

    expect(
      await repository.getShopPaymentQr(),
      'https://res.cloudinary.com/demo/image/upload/'
      'v1/smartstock/shops/4/payment-qr/qr.webp',
    );

    final bytes = Uint8List.fromList([1, 2, 3]);
    final imageUrl = await repository.uploadShopPaymentQr(
      fileName: 'qr.webp',
      contentType: 'image/webp',
      bytes: bytes,
    );

    expect(
      imageUrl,
      'https://res.cloudinary.com/demo/image/upload/'
      'v1/smartstock/shops/4/payment-qr/qr.webp',
    );
    expect(api.uploadedBytes, bytes);
    expect(api.calls, [
      '/shop-payment-qr',
      '/shop-payment-qr/upload image/webp',
      '/shop-payment-qr/confirm',
    ]);
  });
}
