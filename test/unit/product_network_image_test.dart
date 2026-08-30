import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/widgets/product_network_image.dart';

void main() {
  testWidgets('shows fallback when product image URL is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 80,
          height: 80,
          child: ProductNetworkImage(
            imageUrl: '   ',
            width: 80,
            height: 80,
            fallback: ColoredBox(
              key: Key('product-image-fallback'),
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('product-image-fallback')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('reserves image space while network image is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 80,
          height: 80,
          child: ProductNetworkImage(
            imageUrl: 'https://example.com/product.webp',
            width: 80,
            height: 80,
            fallback: ColoredBox(
              key: Key('product-image-placeholder'),
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('product-image-placeholder')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('keeps its requested size without a constrained parent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ProductNetworkImage(
            imageUrl: 'https://example.com/product.webp',
            width: 44,
            height: 44,
            fallback: ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ProductNetworkImage)),
      const Size(44, 44),
    );
  });
}
