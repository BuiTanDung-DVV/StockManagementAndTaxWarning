import 'package:flutter/material.dart';

import '../assets/app_icon.dart';
import 'product_network_image.dart';

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, this.imageUrl, this.name, this.size = 48});

  final String? imageUrl;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: const Center(child: AppIcon(Icons.inventory_2_outlined, size: 20)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ProductNetworkImage(
        imageUrl: imageUrl ?? '',
        width: size,
        height: size,
        fit: BoxFit.contain,
        fallback: fallback,
        semanticLabel: name == null ? 'Ảnh sản phẩm' : 'Ảnh $name',
      ),
    );
  }
}
