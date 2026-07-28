import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Tập trung toàn bộ tài nguyên hình ảnh dùng trong giao diện.
///
/// Màn hình chỉ tham chiếu các hằng số tại đây để tránh trộn icon hệ thống với
/// bộ nhận diện của ứng dụng.
abstract final class AppAssets {
  static const String appIcon = 'assets/icon/app_icon.png';
  static const String aiMascot = 'assets/icon/ai_mascot.png';
  static const String revenue = 'assets/icon/revenue_icon.svg';
  static const String orders = 'assets/icon/orders_icon.svg';
  static const String inventory = 'assets/icon/inventory_icon.svg';
  static const String profit = 'assets/icon/profit_icon.svg';
  static const String cash = 'assets/icon/cash_icon.svg';
  static const String tax = 'assets/icon/tax_icon.svg';
  static const String home = 'assets/icon/home_icon.svg';
  static const String settings = 'assets/icon/settings_icon.svg';
  static const String notification = 'assets/icon/notification_icon.svg';
  static const String search = 'assets/icon/search_icon.svg';
}

class AppAssetIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color? color;
  final String? semanticLabel;
  final BoxFit fit;

  const AppAssetIcon({
    super.key,
    required this.assetPath,
    this.size = 20,
    this.color,
    this.semanticLabel,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final icon = assetPath.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(
            assetPath,
            width: size,
            height: size,
            fit: fit,
            colorFilter: color == null
                ? null
                : ColorFilter.mode(color!, BlendMode.srcIn),
            semanticsLabel: semanticLabel,
          )
        : Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: fit,
            color: color,
            colorBlendMode: color == null ? null : BlendMode.srcIn,
            semanticLabel: semanticLabel,
          );

    return SizedBox.square(dimension: size, child: icon);
  }
}
