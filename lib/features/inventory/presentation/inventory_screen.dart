import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final stockPageAsync = ref.watch(stockPageProvider(null));
    final stockAsync = stockPageAsync.whenData(
      (page) => (page['items'] as List?) ?? const <dynamic>[],
    );
    final lowStockAsync = ref.watch(lowStockProvider);
    final expiringAsync = ref.watch(expiringProductsProvider);
    final slowMovingAsync = ref.watch(slowMovingProvider);
    final categoriesAsync = ref.watch(inventoryCategoriesSummaryProvider);
    final abcPeriod = comparisonReportingDates('year', DateTime.now());
    final abcAsync = ref.watch(
      inventoryAbcProvider((
        from: abcPeriod.currentFrom,
        to: abcPeriod.currentTo,
      )),
    );
    final shopState = ref.watch(shopProvider);
    final warehousesAsync = shopState.isAllShops
        ? null
        : ref.watch(warehousesProvider);
    final canManageProducts =
        shopState.isOwner || shopState.hasPermission('products');
    final canCreateProduct =
        !shopState.isAllShops &&
        (shopState.isOwner || shopState.hasPermission('products', 'edit'));
    final canCreatePurchaseOrder =
        !shopState.isAllShops &&
        (shopState.isOwner || shopState.hasPermission('inventory', 'edit'));
    final compactLayout = MediaQuery.sizeOf(context).width < 720;
    final String? actionLabel = canCreateProduct
        ? 'Thêm sản phẩm'
        : canCreatePurchaseOrder
        ? 'Nhập hàng'
        : null;
    final String? actionAsset = canCreateProduct
        ? AppAssets.add
        : canCreatePurchaseOrder
        ? AppAssets.inventory
        : null;
    final String? actionRoute = canCreateProduct
        ? '/products/form'
        : canCreatePurchaseOrder
        ? '/purchase-orders'
        : null;
    Widget headerActions({required bool compact}) => Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        featureGuideButton(context, 'inventory'),
        if (compact && actionLabel != null)
          Tooltip(
            message: actionLabel,
            child: FloatingActionButton.small(
              heroTag: 'inventory-primary-action-compact',
              elevation: 0,
              onPressed: () => context.push(actionRoute!),
              child: AppAssetIcon(
                assetPath: actionAsset!,
                size: 18,
                color: Colors.white,
                semanticLabel: actionLabel,
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: compactLayout || actionLabel == null
          ? null
          : AppPrimaryFloatingAction(
              label: actionLabel,
              assetPath: actionAsset!,
              heroTag: 'inventory-primary-action',
              onPressed: () => context.push(actionRoute!),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(stockProvider);
            ref.invalidate(stockPageProvider);
            ref.invalidate(lowStockProvider);
            ref.invalidate(expiringProductsProvider);
            ref.invalidate(slowMovingProvider);
            ref.invalidate(inventoryCategoriesSummaryProvider);
            ref.invalidate(inventoryAbcProvider);
            if (!shopState.isAllShops) ref.invalidate(warehousesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: AppResponsiveContent(
              maxWidth: 1440,
              verticalPadding: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: 'Quản lý kho',
                    subtitle:
                        'Ưu tiên sản phẩm cần nhập, sắp hết hạn và tồn chậm luân chuyển.',
                    dense: true,
                    action: headerActions(compact: compactLayout),
                    compactAction: headerActions(compact: true),
                  ),
                  _InventoryMetricStrip(
                    stock: stockAsync,
                    totalProducts: stockPageAsync.when(
                      data: inventoryProductTotal,
                      loading: () => null,
                      error: (_, _) => null,
                    ),
                    lowStock: lowStockAsync,
                    expiring: expiringAsync,
                    warehouses: warehousesAsync,
                    isAllShops: shopState.isAllShops,
                    activeShopCount: shopState.userShops
                        .where(
                          (shop) =>
                              shop['status'] == 'ACTIVE' &&
                              shop['isActive'] != false,
                        )
                        .length,
                  ),
                  if (stockAsync.hasError ||
                      lowStockAsync.hasError ||
                      expiringAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: AppInlineError(
                        message: 'Một phần số liệu tồn kho chưa tải được.',
                        onRetry: () {
                          ref.invalidate(stockProvider);
                          ref.invalidate(lowStockProvider);
                          ref.invalidate(expiringProductsProvider);
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _InventoryQuickActions(canManageProducts: canManageProducts),
                  const SizedBox(height: AppSpacing.lg),
                  _InventoryActionWorkspace(
                    lowStock: lowStockAsync,
                    slowMoving: slowMovingAsync,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _InventoryAbcPanel(
                    asyncValue: abcAsync,
                    periodLabel: reportingCompactRangeLabel(
                      DateTime.parse(abcPeriod.currentFrom),
                      DateTime.parse(abcPeriod.currentTo),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CategoryDistribution(asyncValue: categoriesAsync),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _inventoryAbcNumber(dynamic value) =>
    num.tryParse(value?.toString() ?? '0')?.toDouble() ?? 0;

Color _inventoryAbcGradeColor(String grade, BuildContext context) {
  switch (grade) {
    case 'A':
      return Theme.of(context).colorScheme.primary;
    case 'B':
      return AppColors.warning;
    default:
      return AppColors.info;
  }
}

class _InventoryAbcPanel extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> asyncValue;
  final String periodLabel;

  const _InventoryAbcPanel({
    required this.asyncValue,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phân tích ABC theo doanh thu hàng hóa',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Tính trên doanh thu thuần chưa VAT sau chiết khấu và hàng trả; dùng để cân đối tồn và kế hoạch bán.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardAlt,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Text(
                    periodLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          asyncValue.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppShimmer(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 300,
                  radius: AppRadius.control,
                ),
              ),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppInlineError(
                message: 'Không thể tải phân tích ABC tồn kho.',
              ),
            ),
            data: (data) {
              final grades = (data['grades'] as List?) ?? const [];
              final items = ((data['items'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
              final revenueItems = items
                  .where((item) => _inventoryAbcNumber(item['revenue']) > 0)
                  .take(8)
                  .toList();

              if (revenueItems.isEmpty) {
                return const AppEmpty(
                  visual: AppEmptyVisual.inventory,
                  message: 'Chưa có doanh thu sản phẩm trong kỳ',
                  subtitle:
                      'Phân nhóm ABC sẽ xuất hiện khi có đơn bán không bị hủy.',
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 760
                            ? (constraints.maxWidth - AppSpacing.md * 2) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.sm,
                          children: grades.whereType<Map>().map((raw) {
                            final grade = raw['grade']?.toString() ?? 'C';
                            return SizedBox(
                              width: width,
                              child: _InventoryAbcGradeCard(
                                grade: grade,
                                skuCount:
                                    _inventoryAbcNumber(raw['skuCount']).toInt(),
                                revenueShare: _inventoryAbcNumber(
                                  raw['revenueShare'],
                                ),
                                stockValue: _inventoryAbcNumber(
                                  raw['stockValue'],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sản phẩm dẫn đầu',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          'Thuần chưa VAT · tồn hiện tại',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var index = 0; index < revenueItems.length; index++) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.sm),
                      _InventoryAbcProductRow(
                        item: revenueItems[index],
                        maximumRevenue: _inventoryAbcNumber(
                          revenueItems.first['revenue'],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InventoryAbcGradeCard extends StatelessWidget {
  final String grade;
  final int skuCount;
  final double revenueShare;
  final double stockValue;

  const _InventoryAbcGradeCard({
    required this.grade,
    required this.skuCount,
    required this.revenueShare,
    required this.stockValue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final color = _inventoryAbcGradeColor(grade, context);
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(stockValue);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              grade,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$skuCount SKU · ${(revenueShare * 100).toStringAsFixed(1)}% doanh thu',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Giá trị tồn: $money',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
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

class _InventoryAbcProductRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final double maximumRevenue;

  const _InventoryAbcProductRow({
    required this.item,
    required this.maximumRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final grade = item['grade']?.toString() ?? 'C';
    final color = _inventoryAbcGradeColor(grade, context);
    final revenue = _inventoryAbcNumber(item['revenue']);
    final currentStock = _inventoryAbcNumber(item['currentStock']);
    final quantitySold = _inventoryAbcNumber(item['quantitySold']);
    final unit = item['unit']?.toString() ?? 'sản phẩm';
    final progress = maximumRevenue <= 0 ? 0.0 : revenue / maximumRevenue;
    final money = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(revenue);
    final compact = MediaQuery.sizeOf(context).width < 680;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.cardAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              grade,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name']?.toString() ?? 'Sản phẩm chưa có tên',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      money,
                      style: AppTheme.tabularStyle(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 7,
                    backgroundColor: colors.surface,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  compact
                      ? 'Đã bán ${quantitySold.toStringAsFixed(quantitySold % 1 == 0 ? 0 : 1)} $unit · Tồn ${currentStock.toStringAsFixed(currentStock % 1 == 0 ? 0 : 1)} $unit'
                      : '${item['sku'] ?? ''} · ${item['category'] ?? 'Chưa phân loại'} · Đã bán ${quantitySold.toStringAsFixed(quantitySold % 1 == 0 ? 0 : 1)} $unit · Tồn ${currentStock.toStringAsFixed(currentStock % 1 == 0 ? 0 : 1)} $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
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

class _InventoryQuickActions extends StatelessWidget {
  final bool canManageProducts;

  const _InventoryQuickActions({required this.canManageProducts});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (canManageProducts)
        _InventoryQuickAction(
          label: 'Danh mục sản phẩm',
          assetPath: AppAssets.inventory,
          onTap: () => context.push('/products'),
        ),
      _InventoryQuickAction(
        label: 'Kiểm kê kho',
        assetPath: AppAssets.inventory,
        onTap: () => context.push('/stock-take'),
      ),
      _InventoryQuickAction(
        label: 'Đơn nhập hàng',
        assetPath: AppAssets.orders,
        onTap: () => context.push('/purchase-orders'),
      ),
      _InventoryQuickAction(
        label: 'Báo cáo xuất nhập tồn',
        assetPath: AppAssets.emptyDocument,
        onTap: () => context.push('/xnt-report'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = inventoryQuickActionColumnCount(
          constraints.maxWidth,
          actions.length,
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 56,
          ),
          itemBuilder: (context, index) => actions[index],
        );
      },
    );
  }
}

int inventoryQuickActionColumnCount(double width, int actionCount) {
  if (actionCount <= 0) return 1;
  if (width >= 980) return actionCount < 4 ? actionCount : 4;
  if (actionCount == 3 && width >= 600) return 3;
  if (width >= 480) return 2;
  return 1;
}

class _InventoryQuickAction extends StatelessWidget {
  final String label;
  final String assetPath;
  final VoidCallback onTap;

  const _InventoryQuickAction({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              AppAssetIcon(
                assetPath: assetPath,
                size: 18,
                color: primary,
                semanticLabel: label,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryMetricStrip extends StatelessWidget {
  final AsyncValue<List<dynamic>> stock;
  final int? totalProducts;
  final AsyncValue<List<dynamic>> lowStock;
  final AsyncValue<List<dynamic>> expiring;
  final AsyncValue<List<dynamic>>? warehouses;
  final bool isAllShops;
  final int activeShopCount;

  const _InventoryMetricStrip({
    required this.stock,
    required this.totalProducts,
    required this.lowStock,
    required this.expiring,
    required this.warehouses,
    required this.isAllShops,
    required this.activeShopCount,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _InventoryMetric(
        label: 'Tổng sản phẩm',
        value: totalProducts != null
            ? '$totalProducts'
            : stock.when(
                data: (items) => '${items.length}',
                loading: () => 'Đang tải',
                error: (_, _) => 'Chưa tải',
              ),
        context: 'Trong kho hiện tại',
        assetPath: AppAssets.inventory,
      ),
      _InventoryMetric(
        label: 'Dưới định mức',
        value: lowStock.when(
          data: (items) => '${items.length}',
          loading: () => 'Đang tải',
          error: (_, _) => 'Chưa tải',
        ),
        context: 'Cần kiểm tra nhập hàng',
      ),
      _InventoryMetric(
        label: 'Sắp hết hạn',
        value: expiring.when(
          data: (items) => '${items.length}',
          loading: () => 'Đang tải',
          error: (_, _) => 'Chưa tải',
        ),
        context: 'Cần xử lý trước hạn',
      ),
      _InventoryMetric(
        label: isAllShops ? 'Cửa hàng hoạt động' : 'Kho hoạt động',
        value: isAllShops
            ? '$activeShopCount'
            : warehouses!.when(
                data: (items) => '${items.length}',
                loading: () => 'Đang tải',
                error: (_, _) => 'Chưa tải',
              ),
        context: isAllShops ? 'Trong phạm vi tổng hợp' : 'Cửa hàng hiện tại',
      ),
    ];

    return _SimpleMetricStrip(metrics: metrics);
  }
}

int inventoryProductTotal(Map<String, dynamic> page) {
  final total = int.tryParse(page['total']?.toString() ?? '');
  if (total != null && total >= 0) return total;
  return (page['items'] as List?)?.length ?? 0;
}

String inventoryIssueProductName(dynamic item) {
  if (item is! Map) return 'Sản phẩm chưa có tên';
  return item['product']?['name']?.toString() ??
      item['productName']?.toString() ??
      item['name']?.toString() ??
      'Sản phẩm chưa có tên';
}

num inventoryIssueQuantity(dynamic item) {
  if (item is! Map) return 0;
  final value =
      item['currentQuantity'] ?? item['quantity'] ?? item['currentStock'] ?? 0;
  return value is num ? value : num.tryParse(value.toString()) ?? 0;
}

({double totalValue, int totalSkuCount}) inventoryCategoryTotals(
  Iterable<dynamic> items,
) {
  var totalValue = 0.0;
  var totalSkuCount = 0;
  for (final item in items) {
    if (item is! Map) continue;
    totalValue += (item['value'] as num?)?.toDouble() ?? 0;
    totalSkuCount += (item['skuCount'] as num?)?.toInt() ?? 0;
  }
  return (totalValue: totalValue, totalSkuCount: totalSkuCount);
}

class _SimpleMetricStrip extends StatelessWidget {
  final List<_InventoryMetric> metrics;

  const _SimpleMetricStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.divider),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                for (var index = 0; index < metrics.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: colors.divider),
                  _InventoryMetricRow(metric: metrics[index]),
                ],
              ],
            ),
          );
        }

        return Container(
          height: 96,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0) VerticalDivider(width: 1, color: colors.divider),
                Expanded(child: _InventoryMetricCell(metric: metrics[index])),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InventoryMetricCell extends StatelessWidget {
  final _InventoryMetric metric;

  const _InventoryMetricCell({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (metric.assetPath != null) ...[
                AppAssetIcon(
                  assetPath: metric.assetPath!,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: metric.label,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            metric.context,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InventoryMetricRow extends StatelessWidget {
  final _InventoryMetric metric;

  const _InventoryMetricRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (metric.assetPath != null) ...[
            AppAssetIcon(
              assetPath: metric.assetPath!,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: metric.label,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.context,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            metric.value,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryActionWorkspace extends StatelessWidget {
  final AsyncValue<List<dynamic>> lowStock;
  final AsyncValue<List<dynamic>> slowMoving;

  const _InventoryActionWorkspace({
    required this.lowStock,
    required this.slowMoving,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final lowPanel = _InventoryIssuePanel(
          title: 'Dưới định mức tồn',
          emptyMessage: 'Không có sản phẩm dưới định mức.',
          asyncValue: lowStock,
          statusBuilder: (item) {
            final quantity = item['currentQuantity'] ?? item['quantity'] ?? 0;
            final unit =
                item['product']?['unit']?.toString() ??
                item['unit']?.toString() ??
                '';
            return 'Tồn $quantity${unit.isEmpty ? '' : ' $unit'}';
          },
        );
        final slowPanel = _InventoryIssuePanel(
          title: 'Chậm luân chuyển',
          emptyMessage: 'Không có sản phẩm chậm luân chuyển.',
          asyncValue: slowMoving,
          statusBuilder: (item) {
            final quantity = inventoryIssueQuantity(item);
            final unit =
                item['product']?['unit']?.toString() ??
                item['unit']?.toString() ??
                '';
            final days = int.tryParse(
              item['daysSinceLastSale']?.toString() ?? '',
            );
            final age = days == null ? 'Chưa từng bán' : '$days ngày chưa bán';
            return '$age • Tồn $quantity${unit.isEmpty ? '' : ' $unit'}';
          },
        );

        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              lowPanel,
              const SizedBox(height: AppSpacing.md),
              slowPanel,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: lowPanel),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: slowPanel),
          ],
        );
      },
    );
  }
}

class _InventoryIssuePanel extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final AsyncValue<List<dynamic>> asyncValue;
  final String Function(dynamic item) statusBuilder;

  const _InventoryIssuePanel({
    required this.title,
    required this.emptyMessage,
    required this.asyncValue,
    required this.statusBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Divider(height: 1, color: colors.divider),
          asyncValue.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppShimmer(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 120,
                  radius: AppRadius.control,
                ),
              ),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppInlineError(
                message: 'Không thể tải danh sách cần xử lý.',
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (
                    var index = 0;
                    index < items.take(5).length;
                    index++
                  ) ...[
                    if (index > 0) Divider(height: 1, color: colors.divider),
                    _InventoryIssueRow(
                      index: index + 1,
                      item: items[index],
                      status: statusBuilder(items[index]),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InventoryIssueRow extends StatelessWidget {
  final int index;
  final dynamic item;
  final String status;

  const _InventoryIssueRow({
    required this.index,
    required this.item,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final name = inventoryIssueProductName(item);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: AppTheme.tabularStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            status,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDistribution extends StatelessWidget {
  final AsyncValue<List<dynamic>> asyncValue;

  const _CategoryDistribution({required this.asyncValue});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giá trị tồn kho theo danh mục',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Tính theo giá vốn; không cộng trực tiếp các đơn vị Bao, Kg và Bộ.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.divider),
          asyncValue.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppShimmer(
                child: ShimmerBox(
                  width: double.infinity,
                  height: 120,
                  radius: AppRadius.control,
                ),
              ),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppInlineError(message: 'Không thể tải phân bổ tồn kho.'),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const AppEmpty(
                  visual: AppEmptyVisual.inventory,
                  message: 'Chưa có dữ liệu danh mục tồn kho',
                );
              }

              final visibleItems = items.take(8).toList();
              final values = visibleItems
                  .map<double>(
                    (item) =>
                        (item['value'] ??
                                item['quantity'] ??
                                item['count'] ??
                                0)
                            .toDouble(),
                  )
                  .toList();
              final totals = inventoryCategoryTotals(items);
              final maximum = values.fold<double>(
                0,
                (current, value) => value > current ? value : current,
              );

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InventoryValueSummary(
                      totalValue: totals.totalValue,
                      totalSkuCount: totals.totalSkuCount,
                      categoryCount: items.length,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (
                      var index = 0;
                      index < visibleItems.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.md),
                      _DistributionRow(
                        label:
                            visibleItems[index]['name']?.toString() ?? 'Khác',
                        value: values[index],
                        skuCount:
                            (visibleItems[index]['skuCount'] as num?)
                                ?.toInt() ??
                            0,
                        maximum: maximum,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InventoryValueSummary extends StatelessWidget {
  final double totalValue;
  final int totalSkuCount;
  final int categoryCount;

  const _InventoryValueSummary({
    required this.totalValue,
    required this.totalSkuCount,
    required this.categoryCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final valueText = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(totalValue);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.cardAlt,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Giá trị vốn đang tồn',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                valueText,
                style: AppTheme.tabularStyle(
                  context,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            '$totalSkuCount SKU · $categoryCount danh mục',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final double value;
  final int skuCount;
  final double maximum;

  const _DistributionRow({
    required this.label,
    required this.value,
    required this.skuCount,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final progress = maximum <= 0 ? 0.0 : value / maximum;
    final valueText = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (skuCount > 0)
                    Text(
                      '$skuCount SKU',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              valueText,
              style: AppTheme.tabularStyle(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(5),
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: colors.cardAlt,
        ),
      ],
    );
  }
}

class _InventoryMetric {
  final String label;
  final String value;
  final String context;
  final String? assetPath;

  const _InventoryMetric({
    required this.label,
    required this.value,
    required this.context,
    this.assetPath,
  });
}
