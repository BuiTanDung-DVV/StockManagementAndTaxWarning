import 'dart:typed_data';

import 'package:flutter_app/core/network/api_client.dart';
import 'package:flutter_app/features/products/providers/product_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient extends ApiClient {
  final List<String> calls = [];
  Uint8List? uploadedBytes;
  String? uploadedContentType;

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add(path);
    if (path.endsWith('/presign')) {
      return {
        'uploadUrl': 'https://api.cloudinary.com/v1_1/demo/image/upload',
        'objectKey': 'smartstock/shops/1/products/test',
        'fields': {
          'api_key': 'public-key',
          'timestamp': '1',
          'signature': 'signature',
          'public_id': 'smartstock/shops/1/products/test',
        },
      };
    }
    if (path.endsWith('/confirm')) {
      return {
        'imageUrl':
            'https://res.cloudinary.com/demo/image/upload/'
            'v1/smartstock/shops/1/products/test.webp',
        'objectKey': data['objectKey'],
      };
    }
    return {'deleted': true};
  }

  @override
  Future<Map<String, dynamic>> postSignedImageUpload(
    String url,
    Uint8List bytes,
    String fileName,
    String contentType,
    Map<String, dynamic> fields,
  ) async {
    calls.add('POST $url');
    uploadedBytes = bytes;
    uploadedContentType = contentType;
    return {'public_id': fields['public_id']};
  }
}

void main() {
  test(
    'uploads product image directly then confirms it with backend',
    () async {
      final api = _FakeApiClient();
      final repository = ProductRepository(api);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final result = await repository.uploadProductImage(
        fileName: 'san-pham.webp',
        contentType: 'image/webp',
        bytes: bytes,
      );

      expect(api.calls, [
        '/products/image-upload/presign',
        'POST https://api.cloudinary.com/v1_1/demo/image/upload',
        '/products/image-upload/confirm',
      ]);
      expect(api.uploadedBytes, bytes);
      expect(api.uploadedContentType, 'image/webp');
      expect(
        result['imageUrl'],
        'https://res.cloudinary.com/demo/image/upload/'
        'v1/smartstock/shops/1/products/test.webp',
      );
    },
  );
}
