import '../../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tag_colors.dart';
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
  final Map<String, Color> tagColors;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  /// Server-paginated collections can participate in the page's single scroll.
  final bool embedded;
  final bool? selectAllState;
  final VoidCallback? onSelectAll;

  const ProductCollectionView({
    super.key,
    required this.items,
    required this.viewMode,
    required this.selectedProductIds,
    required this.onToggleSelect,
    required this.onProductTap,
    required this.topProductNames,
    this.tagColors = const {},
    required this.scrollController,
    required this.onRefresh,
    this.embedded = false,
    this.selectAllState = false,
    this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableLayout =
            viewMode == ProductViewMode.list &&
            constraints.maxWidth >=
                600 * (MediaQuery.textScalerOf(context).scale(14) / 14);
        final collection = viewMode == ProductViewMode.list
            ? _buildListView(context)
            : _buildGridView(context);
        final content = tableLayout
            ? collection
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (onSelectAll != null)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: viewMode == ProductViewMode.grid ? 8 : 0,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _selectAllCheckbox(),
                          const Expanded(child: Text('Sản phẩm')),
                        ],
                      ),
                    ),
                  if (embedded) collection else Expanded(child: collection),
                ],
              );
        final surface = viewMode == ProductViewMode.grid
            ? DecoratedBox(
                key: const Key('product-grid-surface'),
                decoration: BoxDecoration(
                  color: AppThemeColors.of(context).bg,
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: AppThemeColors.of(context).divider,
                    ),
                  ),
                ),
                child: content,
              )
            : content;
        if (embedded) return surface;
        return RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: onRefresh,
          child: surface,
        );
      },
    );
  }

  Widget _buildListView(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth >= 600 * scale) {
          final table = _buildTable(context, scale);
          if (embedded) return table;
          return SingleChildScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: table,
          );
        }
        return _buildCompactList(context);
      },
    );
  }

  Widget _selectAllCheckbox() => Tooltip(
    message: 'Chọn tất cả sản phẩm khớp bộ lọc, gồm các trang khác',
    child: Checkbox(
      key: const Key('product-select-all-checkbox'),
      tristate: true,
      value: selectAllState,
      onChanged: onSelectAll == null ? null : (_) => onSelectAll!(),
      semanticLabel: 'Chọn tất cả kết quả lọc',
    ),
  );

  Widget _buildTable(BuildContext context, double scale) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final priceWidth = 112 * scale;
    final stockWidth = 96 * scale;

    Widget heading(String text, {bool numeric = false}) => Text(
      text,
      textAlign: numeric ? TextAlign.end : TextAlign.start,
      style: theme.textTheme.bodySmall?.copyWith(
        color: c.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );

    return Container(
      key: const Key('product-desktop-table'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(embedded ? 0 : 12),
        border: embedded ? null : Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          Container(
            color: c.cardAlt,
            padding: const EdgeInsets.fromLTRB(8, 4, 40, 4),
            child: Semantics(
              header: true,
              child: Row(
                children: [
                  _selectAllCheckbox(),
                  const SizedBox(width: 4),
                  Expanded(child: heading('Sản phẩm')),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: priceWidth,
                    child: heading('Giá bán', numeric: true),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: stockWidth,
                    child: heading('Tồn kho', numeric: true),
                  ),
                ],
              ),
            ),
          ),
          for (final raw in items) ...[
            Divider(height: 1, color: c.divider),
            Builder(
              builder: (context) {
                final product = raw as Map<String, dynamic>;
                final id = TypeParser.asInt(product['id']);
                final name =
                    product['name']?.toString() ?? 'Sản phẩm không tên';
                final stock = TypeParser.asDouble(
                  product['currentStock'] ?? product['stock'],
                );
                final minStock = TypeParser.asDouble(
                  product['minStock'] ??
                      product['minimumStock'] ??
                      product['min_stock'],
                );
                final unit = product['unit']?.toString().trim() ?? '';
                final price = TypeParser.asDouble(
                  product['sellingPrice'] ??
                      product['sellPrice'] ??
                      product['retailPrice'],
                );
                final selected = selectedProductIds.contains(id);
                final status = stock <= 0
                    ? 'Hết hàng'
                    : productIsLowStock(stock, minStock)
                    ? 'Sắp hết'
                    : null;
                final stockText = stock == stock.roundToDouble()
                    ? stock.toInt().toString()
                    : stock.toString();
                final numberStyle = theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                );
                return Material(
                  key: ValueKey('product-list-$id'),
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.06)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => onProductTap(product),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
                      child: Row(
                        children: [
                          Semantics(
                            label: selected ? 'Bỏ chọn $name' : 'Chọn $name',
                            child: Checkbox(
                              key: Key('product-select-checkbox-$id'),
                              value: selected,
                              onChanged: (_) => onToggleSelect(id),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ProductNetworkImage(
                                    key: ValueKey('product-table-image-$id'),
                                    imageUrl:
                                        product['imageUrl']?.toString() ?? '',
                                    width: 44,
                                    height: 44,
                                    semanticLabel: 'Ảnh sản phẩm $name',
                                    fallback: ColoredBox(
                                      color: c.surface,
                                      child: SizedBox.square(
                                        dimension: 44,
                                        child: AppAssetIcon(
                                          assetPath: AppAssets.inventory,
                                          size: 20,
                                          color: c.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Tooltip(
                                        message: name,
                                        child: Text(
                                          name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: c.textPrimary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 3,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'SKU: ${product['sku'] ?? 'Chưa có'}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: c.textSecondary,
                                                ),
                                          ),
                                          _ProductTagsRow(
                                            tagsRaw: product['tags'],
                                            stock: stock,
                                            p: product,
                                            topProductNames: topProductNames,
                                            tagColors: tagColors,
                                            maxTags: 2,
                                            includeStockStatus: false,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: priceWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currFmt.format(price),
                                  style: numberStyle,
                                  textAlign: TextAlign.end,
                                ),
                                if (unit.isNotEmpty)
                                  Text(
                                    '/ $unit',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: c.textSecondary,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: stockWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$stockText${unit.isEmpty ? '' : ' $unit'}',
                                  style: numberStyle,
                                  textAlign: TextAlign.end,
                                ),
                                if (status != null)
                                  Text(
                                    status,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: stock <= 0
                                          ? AppColors.danger
                                          : AppColors.warning,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppIcon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: c.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactList(BuildContext context) {
    return ListView.separated(
      controller: embedded ? null : scrollController,
      primary: false,
      shrinkWrap: embedded,
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (context, _) =>
          Divider(height: 1, color: AppThemeColors.of(context).divider),
      itemBuilder: (ctx, i) {
        final p = items[i] as Map<String, dynamic>;
        final id = TypeParser.asInt(p['id']);
        final isSelected = selectedProductIds.contains(id);
        return _ProductListItemCard(
          key: ValueKey('product-list-$id'),
          product: p,
          id: id,
          isSelected: isSelected,
          topProductNames: topProductNames,
          tagColors: tagColors,
          onToggleSelect: () => onToggleSelect(id),
          onTap: () => onProductTap(p),
        );
      },
    );
  }

  Widget _buildGridView(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final cardHeight = 252.0 + (textScaler.scale(130) - 130).clamp(0, 180);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1140
            ? 4
            : (width >= 760 ? 3 : (width >= 500 ? 2 : 1));

        return GridView.builder(
          key: const Key('product-grid-view'),
          controller: embedded ? null : scrollController,
          primary: false,
          shrinkWrap: embedded,
          physics: embedded
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final p = items[i] as Map<String, dynamic>;
            final id = TypeParser.asInt(p['id']);
            final isSelected = selectedProductIds.contains(id);
            return _ProductGridItemCard(
              key: ValueKey('product-grid-$id'),
              product: p,
              id: id,
              isSelected: isSelected,
              topProductNames: topProductNames,
              tagColors: tagColors,
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
  final Map<String, Color> tagColors;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;

  const _ProductListItemCard({
    super.key,
    required this.product,
    required this.id,
    required this.isSelected,
    required this.topProductNames,
    this.tagColors = const {},
    required this.onToggleSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final name = product['name']?.toString() ?? 'Sản phẩm không tên';
    final price = TypeParser.asDouble(
      product['sellingPrice'] ?? product['sellPrice'] ?? product['retailPrice'],
    );
    final stock = TypeParser.asDouble(
      product['currentStock'] ?? product['stock'],
    );
    final min = TypeParser.asDouble(
      product['minStock'] ?? product['minimumStock'] ?? product['min_stock'],
    );
    final unit = product['unit']?.toString().trim() ?? '';
    final stockNumber = stock == stock.roundToDouble()
        ? stock.toInt().toString()
        : stock.toString();
    final stockText = stock <= 0
        ? 'Hết hàng'
        : 'Tồn $stockNumber${unit.isEmpty ? '' : ' $unit'}';
    final attention = stock <= 0 || productIsLowStock(stock, min);

    return Material(
      color: isSelected ? c.primarySubtle : c.card,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: isSelected ? 'Bỏ chọn $name' : 'Chọn $name',
                child: Checkbox(
                  key: Key('product-select-checkbox-$id'),
                  value: isSelected,
                  onChanged: (_) => onToggleSelect(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ProductNetworkImage(
                    imageUrl: product['imageUrl']?.toString() ?? '',
                    width: 48,
                    height: 48,
                    semanticLabel: 'Ảnh sản phẩm $name',
                    fallback: ColoredBox(
                      color: c.cardAlt,
                      child: SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: AppAssetIcon(
                            assetPath: AppAssets.inventory,
                            size: 22,
                            color: c.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product['sku']?.toString() ?? 'Chưa có SKU',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _currFmt.format(price),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            stockText,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: attention
                                  ? (stock <= 0
                                        ? AppColors.danger
                                        : AppColors.warning)
                                  : c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ProductTagsRow(
                      tagsRaw: product['tags'],
                      stock: stock,
                      p: product,
                      topProductNames: topProductNames,
                      tagColors: tagColors,
                      includeStockStatus: false,
                      maxTags: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductGridItemCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int id;
  final bool isSelected;
  final List<String> topProductNames;
  final Map<String, Color> tagColors;
  final VoidCallback onToggleSelect;
  final VoidCallback onTap;

  const _ProductGridItemCard({
    super.key,
    required this.product,
    required this.id,
    required this.isSelected,
    required this.topProductNames,
    this.tagColors = const {},
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

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
          : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : Color.alphaBlend(
                  c.textSecondary.withValues(alpha: 0.12),
                  c.divider,
                ),
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 116,
              child: Stack(
                children: [
                  Center(
                    child: ProductNetworkImage(
                      imageUrl: imageUrl,
                      width: 100,
                      height: 100,
                      semanticLabel: 'Ảnh sản phẩm $name',
                      fallback: AppAssetIcon(
                        assetPath: AppAssets.inventory,
                        size: 32,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Semantics(
                      label: isSelected ? 'Bỏ chọn $name' : 'Chọn $name',
                      child: Checkbox(
                        key: Key('product-select-checkbox-$id'),
                        value: isSelected,
                        onChanged: (_) => onToggleSelect(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  Positioned(right: 10, top: 10, child: stockBadge),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: name,
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${p['sku'] ?? 'N/A'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ProductTagsRow(
                      tagsRaw: p['tags'],
                      stock: stock,
                      p: p,
                      topProductNames: topProductNames,
                      tagColors: tagColors,
                      maxTags: 2,
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            _currFmt.format(price),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '/ $displayUnit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
  final Map<String, Color> tagColors;
  final int maxTags;
  final bool includeStockStatus;

  const _ProductTagsRow({
    required this.tagsRaw,
    required this.stock,
    required this.p,
    required this.topProductNames,
    this.tagColors = const {},
    this.maxTags = 3,
    this.includeStockStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final raw = tagsRaw;
    List<String> tags = [];
    if (raw is Iterable) {
      tags = [
        for (final item in raw)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      ];
    } else if (raw is String && raw.isNotEmpty) {
      tags = raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final minStock = TypeParser.asDouble(
      p['minStock'] ?? p['minimumStock'] ?? p['min_stock'],
    );
    if (includeStockStatus && stock <= 0) {
      if (!tags.contains('Hết hàng')) tags.insert(0, 'Hết hàng');
    } else if (includeStockStatus && productIsLowStock(stock, minStock)) {
      if (!tags.contains('Sắp hết')) tags.insert(0, 'Sắp hết');
    }

    if (topProductNames.contains(p['name']?.toString())) {
      if (!tags.contains('Bán chạy')) tags.insert(0, 'Bán chạy');
    }

    tags = tags
        .where(
          (tag) =>
              !tag.trim().toLowerCase().startsWith('sim_tag_') &&
              (includeStockStatus || (tag != 'Hết hàng' && tag != 'Sắp hết')),
        )
        .toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.take(maxTags).map((t) {
        final c = AppThemeColors.of(context);
        final accent = TagColors.resolve(t, configured: tagColors[t]);
        final bgColor = TagColors.surface(accent, c.card);
        final textColor = TagColors.foreground(accent, bgColor);

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
