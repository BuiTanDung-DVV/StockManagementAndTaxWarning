String optimizedCloudinaryImageUrl(
  String imageUrl, {
  required int width,
  int? height,
  String crop = 'limit',
}) {
  final uri = Uri.tryParse(imageUrl);
  if (uri == null ||
      uri.host != 'res.cloudinary.com' ||
      !uri.path.contains('/image/upload/')) {
    return imageUrl;
  }

  final safeWidth = width.clamp(32, 2000);
  final safeHeight = height?.clamp(32, 2000);
  final transformations = <String>[
    // Flutter web's CanvasKit renderer can fail silently when Cloudinary's
    // `f_auto` negotiates a browser-specific format. WebP keeps the CDN
    // payload compact while remaining consistently decodable by Flutter.
    'f_webp',
    'q_auto:good',
    'w_$safeWidth',
    if (safeHeight != null) 'h_$safeHeight',
    'c_$crop',
  ].join(',');

  return imageUrl.replaceFirst(
    '/image/upload/',
    '/image/upload/$transformations/',
  );
}
