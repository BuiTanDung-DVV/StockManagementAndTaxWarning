import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/inventory_provider.dart';
import 'stock_take_form_screen.dart';
import 'stock_take_history_screen.dart';

enum StockTakeFilter { all, lowStock, safeStock }

class StockTakeScreen extends ConsumerStatefulWidget {
  const StockTakeScreen({super.key});

  @override
  ConsumerState<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends ConsumerState<StockTakeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StockTakeFilter _filter = StockTakeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final stockAsync = ref.watch(stockProvider(null));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    Future<void> openForm() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StockTakeFormScreen()),
      );
      ref.invalidate(stockProvider);
      ref.invalidate(stockPageProvider);
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Kiểm kê Kho',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'Lịch sử kiểm kê',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StockTakeHistoryScreen(),
                ),
              );
              ref.invalidate(stockProvider);
              ref.invalidate(stockPageProvider);
            },
          ),
          featureGuideButton(context, 'stock_take'),
          if (!compactLayout)
            AppPrimaryPageAction(
              label: 'Tạo phiếu kiểm',
              assetPath: AppAssets.add,
              onPressed: openForm,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: compactLayout
          ? FloatingActionButton.extended(
              heroTag: 'stock-take-add-fab',
              onPressed: openForm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              icon: const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Tạo Phiếu Kiểm',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppInlineError(
              message: 'Không tải được dữ liệu tồn kho. Vui lòng thử lại sau.',
              onRetry: () => ref.invalidate(stockProvider),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(stockProvider(null).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  AppEmpty(
                    visual: AppEmptyVisual.inventory,
                    message: 'Chưa có dữ liệu tồn kho',
                  ),
                ],
              ),
            );
          }

          final query = _searchQuery.trim().toLowerCase();
          final lowStockCount = items.where((raw) {
            if (raw is! Map) return false;
            final qty = parseQuantity(
              raw['currentQuantity'] ?? raw['quantity'],
            );
            final minStock = parseQuantity(
              raw['product']?['minStock'] ?? raw['minStock'],
            );
            return qty <= minStock;
          }).length;
          final safeStockCount = items.length - lowStockCount;

          final filteredItems = items.where((raw) {
            if (raw is! Map) return false;
            final name =
                (raw['product']?['name'] ?? raw['productName'] ?? '')
                    .toString()
                    .toLowerCase();
            final sku = (raw['product']?['sku'] ?? raw['sku'] ?? '')
                .toString()
                .toLowerCase();
            final matchesSearch =
                query.isEmpty || name.contains(query) || sku.contains(query);
            if (!matchesSearch) return false;

            final qty = parseQuantity(
              raw['currentQuantity'] ?? raw['quantity'],
            );
            final minStock = parseQuantity(
              raw['product']?['minStock'] ?? raw['minStock'],
            );
            final isLow = qty <= minStock;

            return switch (_filter) {
              StockTakeFilter.all => true,
              StockTakeFilter.lowStock => isLow,
              StockTakeFilter.safeStock => !isLow,
            };
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 720;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 16 : 12,
                          12,
                          isDesktop ? 16 : 12,
                          6,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tên sản phẩm hoặc mã SKU...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 13,
                              color: c.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: c.card,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: c.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: c.divider),
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      // Filter Chips
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 16 : 12,
                          vertical: 4,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                selected: _filter == StockTakeFilter.all,
                                label: Text('Tất cả (${items.length})'),
                                onSelected: (_) => setState(
                                  () => _filter = StockTakeFilter.all,
                                ),
                                avatar: const Icon(
                                  Icons.list_alt_rounded,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                selected: _filter == StockTakeFilter.lowStock,
                                label: Text('Cảnh báo thiếu ($lowStockCount)'),
                                selectedColor: AppColors.danger.withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: AppColors.danger,
                                labelStyle: TextStyle(
                                  color: _filter == StockTakeFilter.lowStock
                                      ? AppColors.danger
                                      : null,
                                  fontWeight:
                                      _filter == StockTakeFilter.lowStock
                                          ? FontWeight.bold
                                          : null,
                                ),
                                onSelected: (_) => setState(
                                  () => _filter = StockTakeFilter.lowStock,
                                ),
                                avatar: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: _filter == StockTakeFilter.lowStock
                                      ? AppColors.danger
                                      : AppColors.danger.withValues(
                                          alpha: 0.8,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                selected: _filter == StockTakeFilter.safeStock,
                                label: Text('Tồn an toàn ($safeStockCount)'),
                                selectedColor: AppColors.success.withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: AppColors.success,
                                labelStyle: TextStyle(
                                  color: _filter == StockTakeFilter.safeStock
                                      ? AppColors.success
                                      : null,
                                  fontWeight:
                                      _filter == StockTakeFilter.safeStock
                                          ? FontWeight.bold
                                          : null,
                                ),
                                onSelected: (_) => setState(
                                  () => _filter = StockTakeFilter.safeStock,
                                ),
                                avatar: Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: _filter == StockTakeFilter.safeStock
                                      ? AppColors.success
                                      : AppColors.success.withValues(
                                          alpha: 0.8,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // List View or Empty Search Result
                      Expanded(
                        child: filteredItems.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: AppEmpty(
                                    visual: AppEmptyVisual.inventory,
                                    message: 'Không tìm thấy sản phẩm',
                                    subtitle:
                                        'Không có sản phẩm nào khớp với "$_searchQuery".',
                                  ),
                                ),
                              )
                            : Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 16 : 0,
                                  vertical: isDesktop ? 8 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: BorderRadius.circular(
                                    isDesktop ? 20 : 0,
                                  ),
                                  border: isDesktop
                                      ? Border.all(
                                          color: c.divider.withValues(
                                            alpha: 0.5,
                                          ),
                                        )
                                      : null,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: RefreshIndicator(
                                  onRefresh: () async =>
                                      ref.refresh(stockProvider(null).future),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                    itemCount: filteredItems.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: c.divider.withValues(alpha: 0.5),
                                    ),
                                    itemBuilder: (_, i) {
                                      final item = filteredItems[i] as Map;
                                      final name =
                                          item['product']?['name'] ??
                                          item['productName'] ??
                                          'Sản phẩm không tên';
                                      final sku =
                                          item['product']?['sku'] ??
                                          item['sku'] ??
                                          '';
                                      final unit =
                                          item['product']?['unit']
                                              ?.toString()
                                              .trim() ??
                                          '';
                                      final warehouseName =
                                          item['warehouse']?['name']
                                              ?.toString()
                                              .trim() ??
                                          '';
                                      final qty = parseQuantity(
                                        item['currentQuantity'] ??
                                            item['quantity'],
                                      );
                                      final minStock = parseQuantity(
                                        item['product']?['minStock'] ??
                                            item['minStock'],
                                      );
                                      final isLow = qty <= minStock;
                                      final qtyStr = (qty % 1 == 0)
                                          ? qty.toInt().toString()
                                          : qty.toString();
                                      final minStockStr = (minStock % 1 == 0)
                                          ? minStock.toInt().toString()
                                          : minStock.toString();

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color:
                                                    (isLow
                                                            ? AppColors.danger
                                                            : AppColors.success)
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                Icons.inventory_2_rounded,
                                                color: isLow
                                                    ? AppColors.danger
                                                    : AppColors.success,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                      color: c.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    [
                                                          if (sku
                                                              .toString()
                                                              .isNotEmpty)
                                                            'SKU: $sku',
                                                          if (warehouseName
                                                              .isNotEmpty)
                                                            warehouseName,
                                                        ].isEmpty
                                                        ? 'Chưa có SKU và kho'
                                                        : [
                                                            if (sku
                                                                .toString()
                                                                .isNotEmpty)
                                                              'SKU: $sku',
                                                            if (warehouseName
                                                                .isNotEmpty)
                                                              warehouseName,
                                                          ].join(' • '),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: c.textSecondary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '$qtyStr${unit.isEmpty ? '' : ' $unit'}',
                                                  style: GoogleFonts.manrope(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 18,
                                                    color: isLow
                                                        ? AppColors.danger
                                                        : AppColors.success,
                                                  ),
                                                ),
                                                if (isLow)
                                                  Text(
                                                    'Min: $minStockStr',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: AppColors.danger,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
