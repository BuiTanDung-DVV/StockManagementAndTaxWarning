import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/widgets/product_network_image.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../../sales/providers/sales_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

class _TagFilterNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final _productSearchQueryProvider =
    NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);
final _productTagFilterProvider = NotifierProvider<_TagFilterNotifier, String>(
  _TagFilterNotifier.new,
);

bool productListUsesCompactLayout(double width) =>
    width < AppBreakpoints.compactNavigation;

class _ProductTagBar extends StatelessWidget {
  final bool compact;
  final List<Widget> children;

  const _ProductTagBar({required this.compact, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final spacedChildren = <Widget>[
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: AppSpacing.xs),
        children[index],
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: compact
          ? SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: spacedChildren),
              ),
            )
          : Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: children,
            ),
    );
  }
}

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  Timer? _debounce;
  final ScrollController _listScrollController = ScrollController();
  int _page = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }
    setState(() => _page = page);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(_productSearchQueryProvider.notifier).set(query);
      setState(() => _page = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final searchQuery = ref.watch(_productSearchQueryProvider);
    final tagQuery = ref.watch(_productTagFilterProvider);
    final authState = ref.watch(authProvider);
    final compactLayout = productListUsesCompactLayout(
      MediaQuery.sizeOf(context).width,
    );
    final veryCompactLayout = MediaQuery.sizeOf(context).width < 520;
    final listAsync = ref.watch(
      productListProvider((
        page: _page,
        search: searchQuery.isEmpty ? null : searchQuery,
        tag: tagQuery.isEmpty ? null : tagQuery,
      )),
    );

    // Get Top Products for "Bán chạy" Smart Tag
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final topProductsAsync = ref.watch(
      topProductsProvider((
        from: firstDayOfMonth.toIso8601String(),
        to: now.toIso8601String(),
        previousFrom: null,
        previousTo: null,
      )),
    );
    final topProductNames =
        topProductsAsync.value?.map((e) => e['name'].toString()).toList() ?? [];
    Widget headerActions({required bool compact}) => Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        featureGuideButton(context, 'product_list'),
        if (authState.isShopOwner)
          IconButton(
            tooltip: 'Cấu hình bộ lọc và nhãn',
            onPressed: () => context.push('/products/tags'),
            icon: const AppAssetIcon(
              assetPath: AppAssets.settings,
              size: 20,
              semanticLabel: 'Cấu hình bộ lọc và nhãn',
            ),
          ),
        if (compact)
          Tooltip(
            message: 'Thêm sản phẩm',
            child: FloatingActionButton.small(
              heroTag: 'products-add-action-compact',
              elevation: 0,
              onPressed: () => context.push('/products/form'),
              child: const AppAssetIcon(
                assetPath: AppAssets.add,
                size: 18,
                color: Colors.white,
                semanticLabel: 'Thêm sản phẩm',
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: c.bg,
      floatingActionButton: compactLayout
          ? null
          : AppPrimaryFloatingAction(
              label: 'Thêm sản phẩm',
              assetPath: AppAssets.add,
              heroTag: 'products-add-action',
              onPressed: () => context.push('/products/form'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: AppResponsiveContent(
          maxWidth: 1440,
          verticalPadding: compactLayout ? AppSpacing.md : AppSpacing.lg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Danh mục sản phẩm',
                subtitle: 'Tìm nhanh theo tên, SKU, tồn kho và nhãn nghiệp vụ.',
                dense: true,
                titleStyle: compactLayout
                    ? theme.textTheme.headlineSmall?.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.35,
                        height: 1.15,
                      )
                    : null,
                action: headerActions(compact: compactLayout),
                compactAction: headerActions(compact: true),
              ),
              FilterBar(
                searchHint: 'Tìm sản phẩm theo tên, SKU...',
                onSearchChanged: _onSearchChanged,
                dense: true,
                showSearchIcon: true,
              ),
              // Horizontal Tag Bar
              Consumer(
                builder: (ctx, ref, child) {
                  final tagsAsync = ref.watch(availableTagsProvider);
                  return tagsAsync.when(
                    data: (tags) {
                      final visibleTags = tags
                          .where((tag) => !_isInternalTag(tag.name))
                          .toList();
                      if (visibleTags.isEmpty) return const SizedBox.shrink();
                      return _ProductTagBar(
                        compact: compactLayout,
                        children: [
                          for (final t in visibleTags)
                            Builder(
                              builder: (context) {
                                final isSelected = tagQuery == t.name;
                                return Semantics(
                                  button: true,
                                  label: isSelected
                                      ? 'Bỏ lọc nhãn ${t.name}'
                                      : 'Lọc theo nhãn ${t.name}',
                                  selected: isSelected,
                                  child: ChoiceChip(
                                    label: Text(
                                      t.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? Colors.white
                                            : t.uiColor,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      ref
                                          .read(
                                            _productTagFilterProvider.notifier,
                                          )
                                          .set(selected ? t.name : '');
                                      setState(() => _page = 1);
                                    },
                                    selectedColor: t.uiColor,
                                    backgroundColor: t.uiColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(
                                      color: t.uiColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: listAsync.when(
                  data: (data) {
                    final items = (data['items'] as List?) ?? [];
                    final currentPage = paginationValue(
                      data,
                      'page',
                      fallback: _page,
                    );
                    final totalPages = paginationValue(
                      data,
                      'totalPages',
                      fallback: 1,
                    );
                    final totalItems = paginationValue(
                      data,
                      'total',
                      fallback: items.length,
                    );
                    if (items.isEmpty) {
                      return const AppEmpty(
                        visual: AppEmptyVisual.inventory,
                        message: 'Chưa có sản phẩm',
                        subtitle:
                            'Hãy thêm sản phẩm đầu tiên hoặc thử từ khóa tìm kiếm khác',
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            color: theme.colorScheme.primary,
                            onRefresh: () async =>
                                ref.invalidate(productListProvider),
                            child: ListView.separated(
                              controller: _listScrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                0,
                                AppSpacing.sm,
                                0,
                                compactLayout ? AppSpacing.xl : 112,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (_, i) {
                                final p = items[i];
                                final price = TypeParser.asDouble(
                                  p['sellingPrice'] ??
                                      p['sellPrice'] ??
                                      p['retailPrice'],
                                );
                                final stock =
                                    p['currentStock'] ?? p['stock'] ?? 0;
                                final minStock = TypeParser.asDouble(
                                  p['minStock'] ??
                                      p['minimumStock'] ??
                                      p['min_stock'],
                                );
                                final unit = p['unit']?.toString().trim();
                                final displayUnit = unit == null || unit.isEmpty
                                    ? 'đơn vị'
                                    : unit;
                                final imageUrl =
                                    p['imageUrl']?.toString() ?? '';
                                final isOutOfStock = stock <= 0;
                                final stockBadge = AppBadge(
                                  label: isOutOfStock
                                      ? 'Hết hàng'
                                      : 'Còn tồn: $stock $displayUnit',
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

                                return Container(
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    border: Border.all(color: c.divider),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.card,
                                      ),
                                      onTap: () {
                                        final rawId = p['id'];
                                        final id = rawId is int
                                            ? rawId
                                            : int.tryParse('${rawId ?? ''}');
                                        if (id != null) {
                                          context.push('/products/$id');
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // Product Image Frame with sophisticated outline
                                            Container(
                                              width: 70,
                                              height: 70,
                                              decoration: BoxDecoration(
                                                color: c.surface,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: c.divider.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                child: ProductNetworkImage(
                                                  imageUrl: imageUrl,
                                                  width: 70,
                                                  height: 70,
                                                  semanticLabel:
                                                      'Ảnh sản phẩm ${p['name'] ?? ''}',
                                                  fallback: _buildImageFallback(
                                                    theme,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),

                                            // Info layout
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    p['name'] ?? '',
                                                    style: GoogleFonts.manrope(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: c.textPrimary,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'SKU: ${p['sku'] ?? 'N/A'}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: c.textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (p['description'] !=
                                                          null &&
                                                      p['description']
                                                          .toString()
                                                          .trim()
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      p['description']
                                                          .toString()
                                                          .trim(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: c.textSecondary,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                  const SizedBox(height: 4),
                                                  _buildTagsRow(
                                                    p['tags'],
                                                    stock,
                                                    p,
                                                    topProductNames,
                                                    c,
                                                    theme,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  if (veryCompactLayout)
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
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
                                            if (!veryCompactLayout) ...[
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              priceLabel,
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        AppPaginationBar(
                          currentPage: currentPage,
                          totalPages: totalPages,
                          totalItems: totalItems,
                          itemLabel: 'sản phẩm',
                          onPageChanged: _changePage,
                          trailingSafeSpace: compactLayout ? 0 : 184,
                        ),
                      ],
                    );
                  },
                  loading: () => ShimmerList(
                    scrollable: true,
                    padding: EdgeInsets.only(
                      bottom: compactLayout ? AppSpacing.xl : 112,
                    ),
                  ),
                  error: (e, _) => AppError(
                    message: 'Lỗi tải dữ liệu: $e',
                    onRetry: () => ref.invalidate(productListProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageFallback(ThemeData theme) {
    return Container(
      color: AppThemeColors.of(context).cardAlt,
      alignment: Alignment.center,
      child: AppAssetIcon(
        assetPath: AppAssets.inventory,
        color: theme.colorScheme.primary,
        size: 24,
        semanticLabel: 'Sản phẩm chưa có ảnh',
      ),
    );
  }

  Widget _buildTagsRow(
    dynamic tagsRaw,
    num stock,
    Map<String, dynamic> p,
    List<String> topProductNames,
    AppThemeColors c,
    ThemeData theme,
  ) {
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
      tags = tagsRaw.split(',').where((e) => e.trim().isNotEmpty).toList();
    }

    // Auto Tags Mechanism
    final minStock = TypeParser.asDouble(
      p['minStock'] ?? p['minimumStock'] ?? p['min_stock'],
    );
    if (productIsLowStock(stock, minStock)) {
      if (!tags.contains('Sắp hết')) tags.insert(0, 'Sắp hết');
    }

    // Bán chạy (Dựa vào API Top Products của tháng hiện tại)
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

    tags = tags.where((tag) => !_isInternalTag(tag)).toList();
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.take(3).map((t) {
        // Special colors for auto tags
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
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

  bool _isInternalTag(String tag) =>
      tag.trim().toLowerCase().startsWith('sim_tag_');
}

bool productIsLowStock(num stock, num minStock) {
  return minStock > 0 && stock > 0 && stock <= minStock;
}
