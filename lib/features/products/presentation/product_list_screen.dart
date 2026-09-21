import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/product_provider.dart';
import '../../sales/providers/sales_provider.dart';
import 'widgets/product_collection_view.dart';
import 'widgets/product_details_content.dart';
import 'widgets/product_selection_toolbar.dart';

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

bool productIsLowStock(num stock, num minStock) {
  return minStock > 0 && stock > 0 && stock <= minStock;
}

class _ProductTagBar extends StatelessWidget {
  final List<Widget> children;

  const _ProductTagBar({required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final colors = AppThemeColors.of(context);

    final spacedChildren = <Widget>[
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: AppSpacing.xs),
        children[index],
      ],
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Text(
            'Lọc nhanh',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(width: 1, height: 24, color: colors.divider),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 28),
                  child: Row(children: spacedChildren),
                ),
                IgnorePointer(
                  child: Container(
                    width: 30,
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.surface.withValues(alpha: 0),
                          colors.surface,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  ProductViewMode _viewMode = ProductViewMode.list;
  final Set<int> _selectedProductIds = <int>{};
  bool _isExporting = false;

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
    setState(() {
      _page = page;
      _selectedProductIds.clear();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(_productSearchQueryProvider.notifier).set(query);
      setState(() {
        _page = 1;
        _selectedProductIds.clear();
      });
    });
  }

  void _onTagSelected(String tag) {
    ref.read(_productTagFilterProvider.notifier).set(tag);
    setState(() {
      _page = 1;
      _selectedProductIds.clear();
    });
  }

  void _toggleProductSelection(int id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
      } else {
        _selectedProductIds.add(id);
      }
    });
  }

  void _toggleSelectAll(Set<int> pageProductIds) {
    setState(() {
      final selectedOnPage = pageProductIds.intersection(_selectedProductIds);
      if (selectedOnPage.length == pageProductIds.length) {
        _selectedProductIds.removeAll(pageProductIds);
      } else {
        _selectedProductIds.addAll(pageProductIds);
      }
    });
  }

  Future<void> _exportSelectedProducts(
    List<dynamic> allPageItems, {
    required bool canExport,
  }) async {
    if (!canExport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền xuất dữ liệu sản phẩm.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final selectedProducts = allPageItems
        .where((p) => _selectedProductIds.contains(TypeParser.asInt(p['id'])))
        .toList();
    if (selectedProducts.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final success = await ExcelExportService.exportInventoryToExcel(
        selectedProducts,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã xuất ${selectedProducts.length} sản phẩm ra file CSV.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải file CSV. Vui lòng thử lại.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Không thể xuất file danh sách sản phẩm. Vui lòng thử lại sau.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final searchQuery = ref.watch(_productSearchQueryProvider);
    final tagQuery = ref.watch(_productTagFilterProvider);
    final shopState = ref.watch(shopProvider);

    // Clear selection on shop scope change
    ref.listen(shopProvider, (prev, next) {
      if (prev?.currentShopId != next.currentShopId ||
          prev?.isAllShops != next.isAllShops) {
        setState(() {
          _selectedProductIds.clear();
        });
      }
    });

    final compactLayout = productListUsesCompactLayout(
      MediaQuery.sizeOf(context).width,
    );
    final canManageProducts =
        shopState.userShops.isEmpty ||
        shopState.isOwner ||
        shopState.hasPermission('products');
    final canCreateProduct =
        !shopState.isAllShops &&
        (shopState.userShops.isEmpty ||
            shopState.isOwner ||
            shopState.hasPermission('products', 'edit'));
    final canManageTags =
        !shopState.isAllShops &&
        (shopState.userShops.isEmpty ||
            shopState.isOwner ||
            shopState.hasPermission('products', 'edit'));

    final listAsync = ref.watch(
      productListProvider((
        page: _page,
        search: searchQuery.isEmpty ? null : searchQuery,
        tag: tagQuery.isEmpty ? null : tagQuery,
      )),
    );

    // Get Top Products for "Bán chạy" Smart Tag
    final now = DateTime.now();
    final firstDayOfMonthStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final topProductsAsync = ref.watch(
      topProductsProvider((
        from: firstDayOfMonthStr,
        to: todayStr,
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
        if (compact)
          PopupMenuButton<String>(
            tooltip: 'Tác vụ khác',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              if (value == 'guide') {
                showFeatureGuide(context, 'product_list');
              } else if (value == 'tags') {
                context.push('/products/tags');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'guide', child: Text('Hướng dẫn')),
              if (canManageTags)
                const PopupMenuItem(
                  value: 'tags',
                  child: Text('Cấu hình bộ lọc và nhãn'),
                ),
            ],
          )
        else ...[
          featureGuideButton(context, 'product_list'),
          if (canManageTags)
            IconButton(
              tooltip: 'Cấu hình bộ lọc và nhãn',
              onPressed: () => context.push('/products/tags'),
              icon: const AppAssetIcon(
                assetPath: AppAssets.settings,
                size: 20,
                semanticLabel: 'Cấu hình bộ lọc và nhãn',
              ),
            ),
        ],
        if (canCreateProduct)
          compact
              ? AppPrimaryHeaderAction(
                  label: 'Thêm sản phẩm',
                  assetPath: AppAssets.add,
                  heroTag: 'products-add-action-compact',
                  onPressed: () => context.push('/products/form'),
                )
              : AppPrimaryPageAction(
                  label: 'Thêm sản phẩm',
                  assetPath: AppAssets.add,
                  onPressed: () => context.push('/products/form'),
                ),
      ],
    );

    return Scaffold(
      backgroundColor: c.bg,
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
                                      _onTagSelected(selected ? t.name : '');
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

              // Main Content Area
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
                      final hasActiveFilter =
                          searchQuery.isNotEmpty || tagQuery.isNotEmpty;
                      if (hasActiveFilter) {
                        return RefreshIndicator(
                          onRefresh: () async =>
                              ref.invalidate(productListProvider),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            children: [
                              const SizedBox(height: 60),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const AppEmpty(
                                    visual: AppEmptyVisual.inventory,
                                    message: 'Không tìm thấy sản phẩm',
                                    subtitle:
                                        'Không có sản phẩm nào khớp với bộ lọc hiện tại.',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  OutlinedButton.icon(
                                    key: const Key(
                                      'product-clear-filters-button',
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(
                                            _productSearchQueryProvider
                                                .notifier,
                                          )
                                          .set('');
                                      ref
                                          .read(
                                            _productTagFilterProvider.notifier,
                                          )
                                          .set('');
                                      setState(() {
                                        _page = 1;
                                        _selectedProductIds.clear();
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.filter_alt_off_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Xóa bộ lọc'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(productListProvider),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          children: [
                            const SizedBox(height: 60),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppEmpty(
                                  visual: AppEmptyVisual.inventory,
                                  message: 'Chưa có sản phẩm',
                                  subtitle:
                                      'Hãy thêm sản phẩm đầu tiên để bắt đầu quản lý kho và bán hàng.',
                                ),
                                if (canCreateProduct) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  ElevatedButton.icon(
                                    key: const Key('product-empty-add-button'),
                                    onPressed: () =>
                                        context.push('/products/form'),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Thêm sản phẩm'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    final pageProductIds = items
                        .map((p) => TypeParser.asInt(p['id']))
                        .where((id) => id > 0)
                        .toSet();
                    final selectedOnPage = pageProductIds.intersection(
                      _selectedProductIds,
                    );
                    final bool? selectAllState = pageProductIds.isEmpty
                        ? false
                        : (selectedOnPage.length == pageProductIds.length
                              ? true
                              : (selectedOnPage.isNotEmpty ? null : false));

                    final collectionWidget = ProductCollectionView(
                      items: items,
                      viewMode: _viewMode,
                      selectedProductIds: _selectedProductIds,
                      onToggleSelect: _toggleProductSelection,
                      onProductTap: (product) {
                        if (compactLayout) {
                          final rawId = product['id'];
                          final id = rawId is int
                              ? rawId
                              : int.tryParse('${rawId ?? ''}');
                          if (id != null) {
                            context.go('/products/$id?from=products');
                          }
                        } else {
                          _openQuickView(product);
                        }
                      },
                      topProductNames: topProductNames,
                      scrollController: _listScrollController,
                      onRefresh: () async =>
                          ref.invalidate(productListProvider),
                    );

                    return Column(
                      children: [
                        // Control bar: selection header checkbox & View mode toggle
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxs,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                key: const Key('product-select-all-checkbox'),
                                tristate: true,
                                value: selectAllState,
                                onChanged: (_) =>
                                    _toggleSelectAll(pageProductIds),
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                'Chọn trang này (${selectedOnPage.length}/${pageProductIds.length})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              // List / Grid toggle
                              Container(
                                decoration: BoxDecoration(
                                  color: c.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                  border: Border.all(color: c.divider),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: const Key('product-view-mode-list'),
                                      tooltip: 'Xem danh sách',
                                      icon: Icon(
                                        Icons.view_list_rounded,
                                        size: 18,
                                        color: _viewMode == ProductViewMode.list
                                            ? theme.colorScheme.primary
                                            : c.textMuted,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        if (_viewMode != ProductViewMode.list) {
                                          setState(() {
                                            _viewMode = ProductViewMode.list;
                                          });
                                        }
                                      },
                                    ),
                                    Container(
                                      width: 1,
                                      height: 18,
                                      color: c.divider,
                                    ),
                                    IconButton(
                                      key: const Key('product-view-mode-grid'),
                                      tooltip: 'Xem dạng lưới',
                                      icon: Icon(
                                        Icons.grid_view_rounded,
                                        size: 18,
                                        color: _viewMode == ProductViewMode.grid
                                            ? theme.colorScheme.primary
                                            : c.textMuted,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        if (_viewMode != ProductViewMode.grid) {
                                          setState(() {
                                            _viewMode = ProductViewMode.grid;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bulk selection toolbar
                        ProductSelectionToolbar(
                          selectedCount: _selectedProductIds.length,
                          isExporting: _isExporting,
                          canExport: canManageProducts,
                          onClearSelection: () =>
                              setState(() => _selectedProductIds.clear()),
                          onExportCsv: () => _exportSelectedProducts(
                            items,
                            canExport: canManageProducts,
                          ),
                        ),

                        // Main collection list / grid
                        Expanded(child: collectionWidget),

                        AppPaginationBar(
                          currentPage: currentPage,
                          totalPages: totalPages,
                          totalItems: totalItems,
                          itemLabel: 'sản phẩm',
                          onPageChanged: _changePage,
                          trailingSafeSpace: 0,
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
                    message:
                        'Không thể tải danh sách sản phẩm. Vui lòng thử lại sau.',
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

  Future<void> _openQuickView(Map<String, dynamic> product) async {
    final rawId = product['id'];
    final qId = TypeParser.asInt(rawId);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng xem nhanh',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final c = AppThemeColors.of(dialogContext);
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(dialogContext).pop(),
          },
          child: FocusScope(
            autofocus: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: math.min(
                    MediaQuery.of(dialogContext).size.width * 0.9,
                    420,
                  ),
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: c.card,
                    boxShadow: const [AppTheme.diffusionShadow],
                    border: Border(left: BorderSide(color: c.divider)),
                  ),
                  child: SafeArea(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final detailAsync = ref.watch(
                          productDetailProvider(qId),
                        );

                        return detailAsync.when(
                          data: (detailed) {
                            final merged = {...product, ...detailed};
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: ProductDetailsContent(
                                product: merged,
                                isQuickView: true,
                                onClose: () =>
                                    Navigator.of(dialogContext).pop(),
                                onViewFullDetail: () {
                                  Navigator.of(dialogContext).pop();
                                  context.go('/products/$qId?from=products');
                                },
                              ),
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Xem nhanh sản phẩm',
                                      style: GoogleFonts.manrope(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    IconButton(
                                      key: const Key(
                                        'product-quick-view-close-button',
                                      ),
                                      tooltip: 'Đóng (Esc)',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              const Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          error: (err, _) => SingleChildScrollView(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: ProductDetailsContent(
                              product: product,
                              isQuickView: true,
                              banner: AppInlineError(
                                message:
                                    'Không thể tải chi tiết sản phẩm đầy đủ.',
                                onRetry: () =>
                                    ref.invalidate(productDetailProvider(qId)),
                              ),
                              onClose: () => Navigator.of(dialogContext).pop(),
                              onViewFullDetail: () {
                                Navigator.of(dialogContext).pop();
                                context.go('/products/$qId?from=products');
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    );
  }

  bool _isInternalTag(String tag) =>
      tag.trim().toLowerCase().startsWith('sim_tag_');
}
