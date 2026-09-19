import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/type_parser.dart';
import '../../../../core/widgets/product_network_image.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class ProductDetailsContent extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onViewFullDetail;
  final VoidCallback? onClose;
  final bool isQuickView;
  final Widget? banner;

  const ProductDetailsContent({
    super.key,
    required this.product,
    this.onViewFullDetail,
    this.onClose,
    this.isQuickView = false,
    this.banner,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    final name = product['name']?.toString() ?? 'Sản phẩm không tên';
    final imageUrl = product['imageUrl']?.toString().trim() ?? '';
    final sku = product['sku']?.toString() ?? '';
    final category =
        product['category']?['name']?.toString() ??
        product['categoryName']?.toString() ??
        '';
    final unit = product['unit']?.toString() ?? '';
    final barcode = product['barcode']?.toString() ?? '';
    final rawDesc = product['description']?.toString().trim() ?? '';
    final description = rawDesc.isEmpty ? 'Không có mô tả' : rawDesc;
    final descIsMissing = rawDesc.isEmpty;
    final rawCost = product['costPrice'];
    final double? costPrice = rawCost != null
        ? TypeParser.asDouble(rawCost)
        : null;
    final rawSelling =
        product['sellingPrice'] ??
        product['sellPrice'] ??
        product['retailPrice'];
    final double? sellingPrice = rawSelling != null
        ? TypeParser.asDouble(rawSelling)
        : null;
    final rawWholesale = product['wholesalePrice'];
    final double? wholesalePrice = rawWholesale != null
        ? TypeParser.asDouble(rawWholesale)
        : null;
    final taxRate = product['taxRate'] ?? product['tax'];
    final rawCurrentStock =
        product['currentStock'] ?? product['quantity'] ?? product['stock'];
    final num? currentStock = rawCurrentStock != null
        ? num.tryParse(rawCurrentStock.toString())
        : null;
    final rawMinStock =
        product['minStock'] ?? product['minimumStock'] ?? product['min_stock'];
    final num? minStock = rawMinStock != null
        ? num.tryParse(rawMinStock.toString())
        : null;

    final String stockStatus;
    final Color statusColor;
    if (currentStock == null) {
      stockStatus = 'Chưa có số liệu';
      statusColor = AppColors.info;
    } else if (currentStock <= 0) {
      stockStatus = 'Hết hàng';
      statusColor = AppColors.danger;
    } else if (minStock != null && minStock > 0 && currentStock <= minStock) {
      stockStatus = 'Sắp hết hàng';
      statusColor = AppColors.warning;
    } else {
      stockStatus = 'Đang an toàn';
      statusColor = AppColors.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isQuickView) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Xem nhanh sản phẩm',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              if (onClose != null)
                IconButton(
                  key: const Key('product-quick-view-close-button'),
                  tooltip: 'Đóng (Esc)',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
            ],
          ),
          const Divider(height: 16),
        ],
        if (banner != null) ...[banner!, const SizedBox(height: 12)],

        // Product Image & Name
        Center(
          child: Container(
            width: isQuickView ? 100 : 132,
            height: isQuickView ? 100 : 132,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(isQuickView ? 16 : 22),
              border: Border.all(color: c.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isQuickView ? 15 : 21),
              child: ProductNetworkImage(
                imageUrl: imageUrl,
                width: isQuickView ? 100 : 132,
                height: isQuickView ? 100 : 132,
                semanticLabel: 'Ảnh sản phẩm $name',
                fallback: Center(
                  child: AppAssetIcon(
                    assetPath: AppAssets.inventory,
                    size: isQuickView ? 32 : 42,
                    color: theme.colorScheme.primary,
                    semanticLabel: 'Ảnh sản phẩm mặc định',
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: isQuickView ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
          ),
        ),

        // Tags
        if (product['tags'] != null) ...[
          const SizedBox(height: 8),
          Center(child: _buildTags(product['tags'], c, theme)),
        ],

        // Description
        if (!descIsMissing) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mô tả sản phẩm',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: c.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Quick Actions for quick-view panel
        if (isQuickView) ...[
          if (onViewFullDetail != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('product-quick-view-full-detail-button'),
                onPressed: onViewFullDetail,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Xem chi tiết đầy đủ'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],

        // General Info Section
        _ProductDetailSection(
          title: 'Thông tin chung',
          children: [
            _ProductDetailTile(
              label: 'Mã SKU',
              value: sku.isNotEmpty ? sku : 'Chưa có',
            ),
            _ProductDetailTile(
              label: 'Danh mục',
              value: category.isNotEmpty ? category : 'Chưa phân loại',
            ),
            _ProductDetailTile(
              label: 'Đơn vị tính',
              value: unit.isNotEmpty ? unit : 'Chưa có',
            ),
            _ProductDetailTile(
              label: 'Mã vạch barcode',
              value: barcode.isNotEmpty ? barcode : 'Chưa có',
            ),
          ],
        ),

        // Pricing Policy
        _ProductDetailSection(
          title: 'Chính sách giá bán',
          children: [
            _ProductDetailTile(
              label: 'Giá vốn nhập',
              value: costPrice != null && costPrice > 0
                  ? _currFmt.format(costPrice)
                  : 'Chưa có số liệu',
            ),
            _ProductDetailTile(
              label: 'Giá bán lẻ',
              value: sellingPrice != null
                  ? _currFmt.format(sellingPrice)
                  : 'Chưa có số liệu',
            ),
            _ProductDetailTile(
              label: 'Giá bán sỉ',
              value: wholesalePrice != null && wholesalePrice > 0
                  ? _currFmt.format(wholesalePrice)
                  : 'Chưa áp dụng',
            ),
            _ProductDetailTile(
              label: 'Thuế suất áp dụng',
              value: (taxRate != null && taxRate.toString().isNotEmpty)
                  ? '$taxRate%'
                  : 'Chưa cấu hình',
            ),
          ],
        ),

        // Stock Section
        _ProductDetailSection(
          title: 'Thông số tồn kho',
          children: [
            _ProductDetailTile(
              label: 'Tổng tồn hiện tại',
              value: currentStock != null
                  ? '$currentStock ${unit.isNotEmpty ? unit : ''}'.trim()
                  : 'Chưa có số liệu',
            ),
            _ProductDetailTile(
              label: 'Ngưỡng tối thiểu (Min)',
              value: minStock != null
                  ? '$minStock ${unit.isNotEmpty ? unit : ''}'.trim()
                  : 'Chưa cấu hình',
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trạng thái kho',
                  style: GoogleFonts.inter(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    stockStatus,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTags(dynamic tagsRaw, AppThemeColors c, ThemeData theme) {
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = List<String>.from(tagsRaw.map((e) => e.toString()));
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    tags = tags.where((t) => !t.toLowerCase().startsWith('sim_tag_')).toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: tags
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                t,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProductDetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProductDetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final c = AppThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.divider.withValues(alpha: 0.5)),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _ProductDetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _ProductDetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
