import 'package:flutter/material.dart';

import '../utils/cloudinary_image.dart';

/// Product image renderer that avoids CanvasKit's intermittent black-frame
/// decoding issue on Flutter web by preferring the browser's native <img>.
class ProductNetworkImage extends StatelessWidget {
  const ProductNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();
    if (normalizedUrl.isEmpty) return fallback;

    final optimizedUrl = optimizedCloudinaryImageUrl(
      normalizedUrl,
      width: (width * 3).round(),
      height: (height * 3).round(),
      crop: 'fill',
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        Image.network(
          optimizedUrl,
          width: width,
          height: height,
          fit: fit,
          semanticLabel: semanticLabel,
          gaplessPlayback: true,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, _, _) => fallback,
        ),
      ],
    );
  }
}
