import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/type_parser.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/product_network_image.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

enum ProductViewMode { list, grid }

bool productIsLowStock(num stock, num minStock) {
  return minStock > 0 && stock > 0 && stock <= minStock;
}

class ProductCollectionView extends StatelessWidget {
  final List<dynamic> items;
  final ProductViewMode viewMode;
  final Set<int> selectedProductIds;
  final ValueChanged<int> onToggleSelect;
  final ValueChanged<Map<String, dynamic>> onProductTap;
  final List<String> topProductNames;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  const ProductCollectionView({
    super.key,
    required this.items,
    required this.viewMode,
    required this.selectedProductIds,
    required this.onToggleSelect,
    required this.onProductTap,
    required this.topProductNames,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: onRefresh,
      child: viewMode == ProductViewMode.list
          ? _buildListView(context)
          : _buildGridView(context),
    );
  }

  Widget _buildListView(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) {
        final p = items[i] as Map<String, dynamic>;
        final id = TypeParser.asInt(p['id']);
        final isSelected = selectedProductIds.contains(id);
        return _ProductListItemCard(
          product: p,
          id: id,
          isSelected: isSelected,
          topProductNames: topProductNames,
          onToggleSelect: () => onToggleSelect(id),
          onTap: () => onProductTap(p),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final cardHeight = textScaler.scale(320.0).clamp(300.0, 480.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : (width >= 860 ? 3 : (width >= 560 ? 2 : 1));

        return GridView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: cardHeight,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final p = items[i] as Map<String, dynamic>;
            final id = TypeParser.asInt(p['id']);
            final isSelected = selectedProductIds.contains(id);
            return _ProductGridItemCard(
              product: p,
              id: id,
              isSelected: isSelected,
              topProductNames: topProductNames,
              onToggleSelect: () => onToggleSelect(id),
              onTap: () => onProductTap(p),
            );
          },
        );
      },
    );
  }
}

class _ProductListItemCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int id;
  final bool isSelected;
  final List<String> topProductNames;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;

  const _ProductListItemCard({
    required this.product,
    required this.id,
    required this.isSelected,
    required this.topProductNames,
    required this.onToggleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final p = product;
    final name = p['name']?.toString() ?? 'Sản phẩm không tên';
    final price = TypeParser.asDouble(
      p['sellingPrice'] ?? p['sellPrice'] ?? p['retailPrice'],
    );
    final stock = p['currentStock'] ?? p['stock'] ?? 0;
    final minStock = TypeParser.asDouble(
      p['minStock'] ?? p['minimumStock'] ?? p['min_stock'],
    );
    final unit = p['unit']?.toString().trim();
    final displayUnit = (unit == null || unit.isEmpty) ? 'đơn vị' : unit;
    final imageUrl = p['imageUrl']?.toString() ?? '';
    final isOutOfStock = stock <= 0;

    final stockBadge = AppBadge(
      label: isOutOfStock ? 'Hết hàng' : 'Còn tồn: $stock $displayUnit',
      color: isOutOfStock
          ? AppColors.danger
          : (productIsLowStock(stock, minStock)
              ? AppColors.warning
              : AppColors.success),
    );

    final priceLabel = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _currFmt.format(price),
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '/ $displayUnit',
          style: TextStyle(
            fontSize: 11,
            color: c.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final veryCompact = MediaQuery.sizeOf(context).width < 520;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : c.divider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                // Selection Checkbox
                Semantics(
                  label: isSelected ? 'Bỏ chọn $name' : 'Chọn $name',
                  child: Checkbox(
                    key: Key('product-select-checkbox-$id'),
                    value: isSelected,
                    onChanged: (_) => onToggleSelect(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),

                // Product Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.divider.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: ProductNetworkImage(
                      imageUrl: imageUrl,
                      width: 64,
                      height: 64,
                      semanticLabel: 'Ảnh sản phẩm $name',
                      fallback: _buildImageFallback(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: c.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${p['sku'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p['description'] != null &&
                          p['description'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          p['description'].toString().trim(),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      _ProductTagsRow(
                        tagsRaw: p['tags'],
                        stock: stock,
                        p: p,
                        topProductNames: topProductNames,
                      ),
                      const SizedBox(height: 6),
                      if (veryCompact)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            stockBadge,
                            const Spacer(),
                            priceLabel,
                          ],
                        )
                      else
                        stockBadge,
                    ],
                  ),
                ),

                if (!veryCompact) ...[
                  const SizedBox(width: AppSpacing.xs),
                  priceLabel,
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: c.textMuted,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppThemeColors.of(context);
    return Container(
      color: c.cardAlt,
      alignment: Alignment.center,
      child: AppAssetIcon(
        assetPath: AppAssets.inventory,
        color: theme.colorScheme.primary,
        size: 22,
        semanticLabel: 'Sản phẩm chưa có ảnh',
      ),
    );
  }
}

class _ProductGridItemCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int id;
  final bool isSelected;
  final List<String> topProductNames;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;

  const _ProductGridItemCard({
    required this.product,
    required this.id,
    required this.isSelected,
    required this.topProductNames,
    required this.onToggleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final p = product;
    final name = p['name']?.toString() ?? 'Sản phẩm không tên';
    final price = TypeParser.asDouble(
      p['sellingPrice'] ?? p['sellPrice'] ?? p['retailPrice'],
    );
    final stock = p['currentStock'] ?? p['stock'] ?? 0;
    final minStock = TypeParser.asDouble(
      p['minStock'] ?? p['minimumStock'] ?? p['min_stock'],
    );
    final unit = p['unit']?.toString().trim();
    final displayUnit = (unit == null || unit.isEmpty) ? 'đơn vị' : unit;
    final imageUrl = p['imageUrl']?.toString() ?? '';
    final isOutOfStock = stock <= 0;

    final stockBadge = AppBadge(
      label: isOutOfStock ? 'Hết hàng' : 'Tồn: $stock',
      color: isOutOfStock
          ? AppColors.danger
          : (productIsLowStock(stock, minStock)
              ? AppColors.warning
              : AppColors.success),
    );

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2)
            : c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : c.divider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with Checkbox and Stock badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      label: isSelected ? 'Bỏ chọn $name' : 'Chọn $name',
                      child: Checkbox(
                        key: Key('product-select-checkbox-$id'),
                        value: isSelected,
                        onChanged: (_) => onToggleSelect(),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    stockBadge,
                  ],
                ),
                const SizedBox(height: 6),

                // Image in center
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: c.divider.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: ProductNetworkImage(
                        imageUrl: imageUrl,
                        width: 80,
                        height: 80,
                        semanticLabel: 'Ảnh sản phẩm $name',
                        fallback: Container(
                          color: c.cardAlt,
                          alignment: Alignment.center,
                          child: AppAssetIcon(
                            assetPath: AppAssets.inventory,
                            color: theme.colorScheme.primary,
                            size: 28,
                            semanticLabel: 'Sản phẩm chưa có ảnh',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Product Name
                Text(
                  name,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: c.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // SKU
                Text(
                  'SKU: ${p['sku'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Tags
                _ProductTagsRow(
                  tagsRaw: p['tags'],
                  stock: stock,
                  p: p,
                  topProductNames: topProductNames,
                  maxTags: 2,
                ),

                const Spacer(),

                // Price and Unit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _currFmt.format(price),
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ $displayUnit',
                      style: TextStyle(
                        fontSize: 10,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTagsRow extends StatelessWidget {
  final dynamic tagsRaw;
  final num stock;
  final Map<String, dynamic> p;
  final List<String> topProductNames;
  final int maxTags;

  const _ProductTagsRow({
    required this.tagsRaw,
    required this.stock,
    required this.p,
    required this.topProductNames,
    this.maxTags = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    final minStock = TypeParser.asDouble(
      p['minStock'] ?? p['minimumStock'] ?? p['min_stock'],
    );
    if (productIsLowStock(stock, minStock)) {
      if (!tags.contains('Sắp hết')) tags.insert(0, 'Sắp hết');
    }

    if (topProductNames.contains(p['name']?.toString())) {
      if (!tags.contains('Bán chạy')) tags.insert(0, 'Bán chạy');
    }

    final createdAtStr = p['createdAt'] ?? p['created_at'];
    if (createdAtStr != null) {
      final createdAt = DateTime.tryParse(createdAtStr.toString());
      if (createdAt != null &&
          DateTime.now().difference(createdAt).inDays <= 7) {
        if (!tags.contains('Mới')) tags.insert(0, 'Mới');
      }
    }

    tags = tags
        .where((tag) => !tag.trim().toLowerCase().startsWith('sim_tag_'))
        .toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.take(maxTags).map((t) {
        Color bgColor = theme.colorScheme.primary.withValues(alpha: 0.1);
        Color textColor = theme.colorScheme.primary;

        if (t == 'Hết hàng') {
          bgColor = AppColors.danger.withValues(alpha: 0.1);
          textColor = AppColors.danger;
        } else if (t == 'Sắp hết') {
          bgColor = AppColors.warning.withValues(alpha: 0.1);
          textColor = AppColors.warning;
        } else if (t == 'Bán chạy') {
          bgColor = Colors.purple.withValues(alpha: 0.1);
          textColor = Colors.purple;
        } else if (t == 'Mới') {
          bgColor = Colors.blue.withValues(alpha: 0.1);
          textColor = Colors.blue;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            t,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }
}
