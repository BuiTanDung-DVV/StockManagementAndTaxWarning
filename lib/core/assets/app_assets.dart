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
  static const String qrPayment = 'assets/icon/qr_payment_icon.svg';
  static const String help = 'assets/icon/help_icon.svg';
  static const String add = 'assets/icon/add_icon.svg';
  static const String edit = 'assets/icon/edit_icon.svg';
  static const String search = 'assets/icon/search_icon.svg';
  static const String emptyGeneric = 'assets/icon/empty_generic.svg';
  static const String emptyInventory = 'assets/icon/empty_inventory.svg';
  static const String emptySales = 'assets/icon/empty_sales.svg';
  static const String emptyPeople = 'assets/icon/empty_people.svg';
  static const String emptyFinance = 'assets/icon/empty_finance.svg';
  static const String emptyDocument = 'assets/icon/empty_document.svg';
  static const String emptyTax = 'assets/icon/empty_tax.svg';
  static const String copy = 'assets/icon/copy_icon.svg';
  static const String delete = 'assets/icon/delete_icon.svg';
  static const String eye = 'assets/icon/eye_icon.svg';
  static const String toggleOn = 'assets/icon/toggle_on_icon.svg';
  static const String toggleOff = 'assets/icon/toggle_off_icon.svg';
  static const String storage = 'assets/icon/storage_icon.svg';
  static const String book = 'assets/icon/book_icon.svg';
  static const String externalLink = 'assets/icon/external_link_icon.svg';
  static const String expand = 'assets/icon/expand_icon.svg';
  static const String collapse = 'assets/icon/collapse_icon.svg';
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
            // Không để lỗi tải ảnh biến logo thành một ô trắng. Điều này đặc
            // biệt quan trọng trên Web khi CDN/service worker còn giữ bản
            // asset cũ hoặc ảnh cửa hàng chưa có.
            errorBuilder: (context, error, stackTrace) {
              final fallbackColor =
                  color ?? Theme.of(context).colorScheme.primary;
              final isMascot = assetPath == AppAssets.aiMascot;
              return Icon(
                isMascot ? Icons.smart_toy_rounded : Icons.inventory_2_rounded,
                size: size * 0.78,
                color: fallbackColor,
                semanticLabel: semanticLabel,
              );
            },
          );

    return SizedBox.square(dimension: size, child: icon);
  }
}
