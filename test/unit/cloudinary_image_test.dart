import 'package:flutter_app/core/utils/cloudinary_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds bounded automatic Cloudinary delivery optimization', () {
    const original =
        'https://res.cloudinary.com/demo/image/upload/v1/smartstock/product.jpg';

    expect(
      optimizedCloudinaryImageUrl(
        original,
        width: 240,
        height: 240,
        crop: 'fill',
      ),
      'https://res.cloudinary.com/demo/image/upload/'
      'f_auto,q_auto:good,w_240,h_240,c_fill/'
      'v1/smartstock/product.jpg',
    );
  });

  test('leaves non-Cloudinary and QR URLs unchanged when not requested', () {
    const original = 'https://media.example.com/product.jpg';
    expect(optimizedCloudinaryImageUrl(original, width: 240), original);
  });
}
