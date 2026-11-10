import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/quick_tag_filter_bar.dart';
import '../../../core/widgets/app_menu_item_content.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/type_parser.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../settings/providers/shop_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../../sales/providers/sales_provider.dart';
import 'widgets/product_collection_view.dart';
import 'widgets/product_quick_view_panel.dart';
import 'widgets/product_selection_toolbar.dart';
import 'product_import_dialog.dart';

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

class _TagFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};
  void toggle(String tag) {
    final next = Set<String>.from(state);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    state = next;
  }

  void setTags(Set<String> tags) => state = Set<String>.from(tags);
  void clear() => state = <String>{};
}

final _productSearchQueryProvider =
    NotifierProvider<_SearchQueryNotifier, String>(_SearchQueryNotifier.new);
final _productTagFilterProvider =
    NotifierProvider<_TagFilterNotifier, Set<String>>(_TagFilterNotifier.new);

bool productListUsesCompactLayout(double width) =>
    width < AppBreakpoints.compactNavigation;

bool productIsLowStock(num stock, num minStock) {
  return minStock > 0 && stock > 0 && stock <= minStock;
}

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({
    super.key,
    this.initialCategoryId,
    this.initialCategoryName,
    this.initialInStockOnly = false,
  });
  final int? initialCategoryId;
  final String? initialCategoryName;
  final bool initialInStockOnly;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  int _page = 1;
  ProductViewMode _viewMode = ProductViewMode.list;
  final Set<int> _selectedProductIds = <int>{};
  bool _isExporting = false;
  int? _categoryId;
  String? _categoryName;
  bool _inStockOnly = false;
  bool _updatingScopeUrl = false;
  bool _allFilteredSelected = false;
  final Set<int> _excludedProductIds = {};
  int _selectionVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(_productSearchQueryProvider);
    _applyInitialCategory();
  }

  void _applyInitialCategory() {
    _categoryId = widget.initialCategoryId;
    _categoryName = widget.initialCategoryName;
    _inStockOnly = widget.initialInStockOnly;
    _page = 1;
    _clearSelection();
    if (_categoryId != null || _inStockOnly) {
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(_productSearchQueryProvider.notifier).set('');
        ref.read(_productTagFilterProvider.notifier).clear();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_updatingScopeUrl) {
      _updatingScopeUrl = false;
      return;
    }
    if (oldWidget.initialCategoryId != widget.initialCategoryId ||
        oldWidget.initialCategoryName != widget.initialCategoryName ||
        oldWidget.initialInStockOnly != widget.initialInStockOnly) {
      _applyInitialCategory();
    }
  }

  void _syncCategoryUrl() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _updatingScopeUrl = true;
    router.replace(
      Uri(
        path: '/products',
        queryParameters: {
          if (_categoryId != null) 'categoryId': '$_categoryId',
          if (_categoryId != null && _categoryName != null)
            'categoryName': _categoryName!,
          if (_inStockOnly) 'inStockOnly': 'true',
        },
      ).toString(),
    );
  }

  void _removeCategoryScope({bool category = false, bool stock = false}) {
    setState(() {
      if (category) {
        _categoryId = null;
        _categoryName = null;
      }
      if (stock) _inStockOnly = false;
      _page = 1;
      _clearSelection();
    });
    _syncCategoryUrl();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    if (_listScrollController.hasClients) {
      _listScrollController.jumpTo(0);
    }
    setState(() {
      _page = page;
    });
  }

  void _onSearchChanged(String query) {
    setState(_clearSelection);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(_productSearchQueryProvider.notifier).set(query);
      setState(() {
        _page = 1;
        _clearSelection();
      });
    });
  }

  void _onTagSelected(String tag) {
    ref.read(_productTagFilterProvider.notifier).toggle(tag);
    setState(() {
      _page = 1;
      _clearSelection();
    });
  }

  void _clearFilters() {
    final hadCategoryScope = _categoryId != null || _inStockOnly;
    _debounce?.cancel();
    _searchController.clear();
    ref.read(_productSearchQueryProvider.notifier).set('');
    ref.read(_productTagFilterProvider.notifier).clear();
    setState(() {
      _categoryId = null;
      _categoryName = null;
      _inStockOnly = false;
      _page = 1;
      _clearSelection();
    });
    if (hadCategoryScope) _syncCategoryUrl();
  }

  void _clearSelection() {
    _selectedProductIds.clear();
    _excludedProductIds.clear();
    _allFilteredSelected = false;
    _selectionVersion++;
  }

  void _toggleProductSelection(int id) {
    setState(() {
      final ids = _allFilteredSelected
          ? _excludedProductIds
          : _selectedProductIds;
      if (!ids.remove(id)) ids.add(id);
      _selectionVersion++;
    });
  }

  void _toggleSelectAll(bool allSelected) {
    setState(() {
      _clearSelection();
      _allFilteredSelected = !allSelected;
    });
  }

  Future<void> _exportSelectedProducts({required bool canExport}) async {
    if (_isExporting) return;
    if (!canExport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền xuất dữ liệu sản phẩm.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final version = _selectionVersion;
    final search = ref.read(_productSearchQueryProvider);
    final tags = ref.read(_productTagFilterProvider);
    final tagParam = tags.isEmpty ? null : tags.join(',');
    final shop = ref.read(shopProvider);
    final shopId = shop.currentShopId;
    final actor = ref.read(authProvider).user?['id']?.toString();
    final categoryId = _categoryId, inStockOnly = _inStockOnly;
    final selectedIds = {..._selectedProductIds};
    final excludedIds = {..._excludedProductIds};
    final allFiltered = _allFilteredSelected;
    bool scopeIsCurrent() {
      if (!mounted || version != _selectionVersion) return false;
      final current = ref.read(shopProvider), auth = ref.read(authProvider);
      return shopId != null &&
          !current.isAllShops &&
          current.currentShopId == shopId &&
          current.hasPermission('products') &&
          auth.isLoggedIn &&
          !auth.isOfflineSession &&
          actor != null &&
          auth.user?['id']?.toString() == actor &&
          ref.read(_productSearchQueryProvider) == search &&
          setEquals(ref.read(_productTagFilterProvider), tags) &&
          _categoryId == categoryId &&
          _inStockOnly == inStockOnly;
    }

    if (!scopeIsCurrent()) return;
    setState(() => _isExporting = true);
    try {
      final snapshot = await ref
          .read(productRepoProvider)
          .exportInventoryInShop(
            shopId!,
            search: search.isEmpty ? null : search,
            tag: tagParam,
            categoryId: categoryId,
            inStockOnly: inStockOnly,
            isCurrentScope: scopeIsCurrent,
          );
      if (!scopeIsCurrent()) return;
      final selected = snapshot.select(
        allFiltered: allFiltered,
        selectedIds: selectedIds,
        excludedIds: excludedIds,
      );
      if (selected.items.isEmpty) return;
      final success = await ExcelExportService.exportInventoryToExcel(
        selected,
        shopName: shop.currentShopName ?? 'Cửa hàng $shopId',
      );
      if (!mounted || !scopeIsCurrent()) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã tạo Excel gồm ${selected.items.length} sản phẩm. Kiểm tra mục tải xuống.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải file Excel. Vui lòng thử lại.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted || !scopeIsCurrent()) return;
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

  Future<void> _importProducts() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProductImportDialog(),
    );
    if (mounted && changed == true) {
      ref.invalidate(productListProvider);
      ref.invalidate(productOptionsProvider);
      ref.invalidate(productDetailProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final searchQuery = ref.watch(_productSearchQueryProvider);
    final selectedTags = ref.watch(_productTagFilterProvider);
    final tagParam = selectedTags.isEmpty ? null : selectedTags.join(',');
    final shopState = ref.watch(shopProvider);
    final authState = ref.watch(authProvider);
    final canExportProducts =
        shopState.currentShopId != null &&
        !shopState.isAllShops &&
        shopState.hasPermission('products') &&
        authState.isLoggedIn &&
        !authState.isOfflineSession &&
        authState.user?['id'] != null;
    ref.listen(authProvider, (previous, next) {
      if (previous?.user?['id'] != next.user?['id'] ||
          previous?.isLoggedIn != next.isLoggedIn ||
          previous?.isOfflineSession != next.isOfflineSession) {
        setState(_clearSelection);
      }
    });

    // Clear selection on shop scope change
    ref.listen(shopProvider, (prev, next) {
      if (prev?.currentShopId != next.currentShopId ||
          prev?.isAllShops != next.isAllShops) {
        final realShopChange =
            prev != null &&
            !prev.isLoading &&
            (prev.currentShopId != null || prev.isAllShops);
        setState(() {
          _clearSelection();
          if (realShopChange) {
            _categoryId = null;
            _categoryName = null;
            _inStockOnly = false;
          }
          _page = 1;
        });
        if (realShopChange) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncCategoryUrl();
          });
        }
      } else if (prev?.hasPermission('products') !=
              next.hasPermission('products') ||
          prev?.memberType != next.memberType) {
        setState(_clearSelection);
      }
    });

    final compactLayout = productListUsesCompactLayout(
      MediaQuery.sizeOf(context).width,
    );
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
        categoryId: _categoryId,
        inStockOnly: _inStockOnly,
        search: searchQuery.isEmpty ? null : searchQuery,
        tag: tagParam,
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
            icon: const AppIcon(Icons.more_horiz_rounded),
            onSelected: (value) {
              if (value == 'guide') {
                showFeatureGuide(context, 'product_list');
              } else if (value == 'tags') {
                context.push('/products/tags');
              } else if (value == 'import') {
                _importProducts();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'guide',
                child: AppMenuItemContent(
                  assetPath: AppAssets.help,
                  label: 'Hướng dẫn',
                ),
              ),
              if (canManageTags)
                const PopupMenuItem(
                  value: 'tags',
                  child: AppMenuItemContent(
                    assetPath: AppAssets.category,
                    label: 'Cấu hình bộ lọc và nhãn',
                  ),
                ),
              if (canCreateProduct)
                const PopupMenuItem(
                  value: 'import',
                  child: AppMenuItemContent(
                    assetPath: AppAssets.upload,
                    label: 'Nhập danh mục từ Excel',
                  ),
                ),
            ],
          )
        else ...[
          featureGuideButton(context, 'product_list'),
          if (canCreateProduct)
            OutlinedButton.icon(
              onPressed: _importProducts,
              icon: const AppIcon(Icons.upload_file_outlined, size: 18),
              label: const Text('Nhập Excel'),
            ),
          if (canManageTags)
            TextButton.icon(
              onPressed: () => context.push('/products/tags'),
              icon: const AppAssetIcon(
                assetPath: AppAssets.settings,
                size: 20,
                semanticLabel: 'Cấu hình bộ lọc và nhãn',
              ),
              label: const Text('Quản lý nhãn'),
            ),
        ],
        if (canCreateProduct)
          FilledButton.icon(
            onPressed: () => context.push('/products/form'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const AppAssetIcon(
              assetPath: AppAssets.add,
              size: 18,
              color: Colors.white,
            ),
            label: const Text('Thêm sản phẩm'),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(productListProvider),
          child: SingleChildScrollView(
            key: const Key('product-page-scroll'),
            controller: _listScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: AppResponsiveContent(
              maxWidth: 1440,
              verticalPadding: compactLayout ? AppSpacing.md : AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, headerConstraints) => AppPageHeader(
                      title: 'Danh mục sản phẩm',
                      dense: true,
                      titleStyle: theme.textTheme.headlineSmall?.copyWith(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.35,
                        height: 1.15,
                      ),
                      action: headerActions(
                        compact: headerConstraints.maxWidth < 900,
                      ),
                    ),
                  ),
                  Container(
                    key: const Key('product-workspace'),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: c.card,
                      border: Border.all(color: c.divider),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: LayoutBuilder(
                            builder: (context, constraints) => Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Tìm theo tên sản phẩm hoặc SKU',
                                      prefixIcon: const AppIcon(
                                        Icons.search_rounded,
                                        size: 19,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                      suffixIcon: searchQuery.isNotEmpty
                                          ? IconButton(
                                              tooltip: 'Xóa tìm kiếm',
                                              onPressed: () {
                                                _debounce?.cancel();
                                                _searchController.clear();
                                                ref
                                                    .read(
                                                      _productSearchQueryProvider
                                                          .notifier,
                                                    )
                                                    .set('');
                                                setState(() {
                                                  _page = 1;
                                                  _clearSelection();
                                                });
                                              },
                                              icon: const AppIcon(
                                                Icons.close_rounded,
                                                size: 18,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _ProductViewModeControl(
                                  mode: _viewMode,
                                  showLabels:
                                      constraints.maxWidth >= 700 &&
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(14) <=
                                          18,
                                  onChanged: (mode) =>
                                      setState(() => _viewMode = mode),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_categoryId != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                InputChip(
                                  key: const Key('product-category-filter'),
                                  label: Text(
                                    'Danh mục: ${_categoryName ?? (_categoryId == 0 ? 'Chưa phân loại' : '#$_categoryId')}',
                                  ),
                                  onDeleted: () =>
                                      _removeCategoryScope(category: true),
                                ),
                              ],
                            ),
                          ),
                        // Filters stay with their results in a single collection surface.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Consumer(
                            builder: (ctx, ref, child) {
                              final tagsAsync = ref.watch(
                                availableTagsProvider,
                              );
                              final visibleTags = (tagsAsync.value ?? [])
                                  .where((tag) => !_isInternalTag(tag.name))
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  QuickTagFilterBar(
                                    tagColors: {
                                      for (final tag in visibleTags)
                                        tag.name: tag.uiColor,
                                    },
                                    tags: visibleTags
                                        .map((t) => t.name)
                                        .toList(),
                                    selectedTags: selectedTags,
                                    onToggleTag: _onTagSelected,
                                    inStockOnly: _inStockOnly,
                                    onToggleInStock: () {
                                      setState(() {
                                        _inStockOnly = !_inStockOnly;
                                        _page = 1;
                                        _clearSelection();
                                      });
                                      _syncCategoryUrl();
                                    },
                                    onClear: _clearFilters,
                                    hasFilters:
                                        selectedTags.isNotEmpty ||
                                        searchQuery.isNotEmpty ||
                                        _categoryId != null ||
                                        _inStockOnly,
                                  ),
                                  if (tagsAsync.isLoading)
                                    const LinearProgressIndicator(),
                                  if (tagsAsync.hasError)
                                    TextButton.icon(
                                      onPressed: () =>
                                          ref.invalidate(availableTagsProvider),
                                      icon: const AppAssetIcon(
                                        assetPath: AppAssets.refresh,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Không tải được nhãn · Thử lại',
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Main Content Area
                        listAsync.when(
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
                                  searchQuery.isNotEmpty ||
                                  selectedTags.isNotEmpty ||
                                  _categoryId != null ||
                                  _inStockOnly;
                              if (hasActiveFilter) {
                                return RefreshIndicator(
                                  onRefresh: () async =>
                                      ref.invalidate(productListProvider),
                                  child: ListView(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(
                                      AppSpacing.xl,
                                    ),
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
                                            onPressed: _clearFilters,
                                            icon: const AppIcon(
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
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
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
                                            key: const Key(
                                              'product-empty-add-button',
                                            ),
                                            onPressed: () =>
                                                context.push('/products/form'),
                                            icon: const AppIcon(
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

                            final selectedCount = _allFilteredSelected
                                ? math.max(
                                    0,
                                    totalItems - _excludedProductIds.length,
                                  )
                                : _selectedProductIds.length;
                            final bool? selectAllState =
                                totalItems > 0 && selectedCount == totalItems
                                ? true
                                : selectedCount > 0
                                ? null
                                : false;
                            final visibleSelectedIds = _allFilteredSelected
                                ? items
                                      .map((p) => TypeParser.asInt(p['id']))
                                      .where(
                                        (id) =>
                                            !_excludedProductIds.contains(id),
                                      )
                                      .toSet()
                                : _selectedProductIds;
                            final collectionWidget = ProductCollectionView(
                              tagColors: {
                                for (final tag
                                    in ref.watch(availableTagsProvider).value ??
                                        [])
                                  tag.name: tag.uiColor,
                              },
                              items: items,
                              viewMode: _viewMode,
                              selectedProductIds: visibleSelectedIds,
                              selectAllState: selectAllState,
                              onSelectAll: () =>
                                  _toggleSelectAll(selectAllState == true),
                              onToggleSelect: _toggleProductSelection,
                              onProductTap: (product) {
                                if (compactLayout) {
                                  final rawId = product['id'];
                                  final id = rawId is int
                                      ? rawId
                                      : int.tryParse('${rawId ?? ''}');
                                  if (id != null) {
                                    context.push('/products/$id?from=products');
                                  }
                                } else {
                                  _openQuickView(product);
                                }
                              },
                              topProductNames: topProductNames,
                              scrollController: _listScrollController,
                              embedded: true,
                              onRefresh: () async =>
                                  ref.invalidate(productListProvider),
                            );

                            return Column(
                              children: [
                                // Bulk selection toolbar
                                ProductSelectionToolbar(
                                  selectedCount: selectedCount,
                                  isExporting: _isExporting,
                                  canExport: canExportProducts,
                                  onClearSelection: () =>
                                      setState(() => _clearSelection()),
                                  onExport: () => _exportSelectedProducts(
                                    canExport: canExportProducts,
                                  ),
                                ),

                                // Main collection list / grid
                                collectionWidget,

                                AppPaginationBar(
                                  currentPage: currentPage,
                                  totalPages: totalPages,
                                  totalItems: totalItems,
                                  itemLabel: 'sản phẩm',
                                  compactNavigation: true,
                                  onPageChanged: _changePage,
                                  trailingSafeSpace: 0,
                                ),
                              ],
                            );
                          },
                          loading: () => ShimmerList(
                            scrollable: false,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
      barrierColor: Colors.black.withValues(alpha: 0.24),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(dialogContext).pop(),
          },
          child: FocusScope(
            autofocus: true,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: math.min(
                  MediaQuery.sizeOf(dialogContext).width * 0.92,
                  500,
                ),
                height: double.infinity,
                child: ProductQuickViewPanel(
                  product: product,
                  onClose: () => Navigator.of(dialogContext).pop(),
                  onViewFullDetail: () {
                    Navigator.of(dialogContext).pop();
                    if (_categoryId != null || _inStockOnly) {
                      context.push('/products/$qId');
                    } else {
                      context.go('/products/$qId?from=products');
                    }
                  },
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

class _ProductViewModeControl extends StatelessWidget {
  const _ProductViewModeControl({
    required this.mode,
    required this.showLabels,
    required this.onChanged,
  });

  final ProductViewMode mode;
  final bool showLabels;
  final ValueChanged<ProductViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in ProductViewMode.values)
            Tooltip(
              message: value == ProductViewMode.list
                  ? 'Xem danh sách'
                  : 'Xem dạng lưới',
              child: Semantics(
                selected: value == mode,
                child: TextButton(
                  key: Key(
                    value == ProductViewMode.list
                        ? 'product-view-mode-list'
                        : 'product-view-mode-grid',
                  ),
                  onPressed: () => onChanged(value),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.symmetric(
                      horizontal: showLabels ? 12 : 8,
                      vertical: 8,
                    ),
                    foregroundColor: value == mode ? primary : c.textSecondary,
                    backgroundColor: value == mode
                        ? primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        value == ProductViewMode.list
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        size: 18,
                      ),
                      if (showLabels) ...[
                        const SizedBox(width: 6),
                        Text(
                          value == ProductViewMode.list ? 'Danh sách' : 'Lưới',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
