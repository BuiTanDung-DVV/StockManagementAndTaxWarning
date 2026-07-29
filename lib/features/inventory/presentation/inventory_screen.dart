import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppThemeColors.of(context);
    final stockAsync = ref.watch(stockProvider(null));
    final lowStockAsync = ref.watch(lowStockProvider);
    final expiringAsync = ref.watch(expiringProductsProvider);
    final slowMovingAsync = ref.watch(slowMovingProvider);
    final categoriesAsync = ref.watch(inventoryCategoriesSummaryProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      floatingActionButton: AppPrimaryFloatingAction(
        label: 'Nhập hàng',
        assetPath: AppAssets.inventory,
        heroTag: 'inventory-purchase-action',
        onPressed: () => context.push('/purchase-orders'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(stockProvider);
            ref.invalidate(lowStockProvider);
            ref.invalidate(expiringProductsProvider);
            ref.invalidate(slowMovingProvider);
            ref.invalidate(inventoryCategoriesSummaryProvider);
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
                    action: featureGuideButton(context, 'inventory'),
                    compactAction: featureGuideButton(context, 'inventory'),
                  ),
                  _InventoryMetricStrip(
                    stock: stockAsync,
                    lowStock: lowStockAsync,
                    expiring: expiringAsync,
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
                  const _InventoryQuickActions(),
                  const SizedBox(height: AppSpacing.lg),
                  _InventoryActionWorkspace(
                    lowStock: lowStockAsync,
                    slowMoving: slowMovingAsync,
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

class _InventoryQuickActions extends StatelessWidget {
  const _InventoryQuickActions();

  @override
  Widget build(BuildContext context) {
    return AppFillGrid(
      minItemWidth: 180,
      maxColumns: 3,
      itemHeight: 56,
      children: [
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
      ],
    );
  }
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
  final AsyncValue<List<dynamic>> lowStock;
  final AsyncValue<List<dynamic>> expiring;

  const _InventoryMetricStrip({
    required this.stock,
    required this.lowStock,
    required this.expiring,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _InventoryMetric(
        label: 'Tổng sản phẩm',
        value: stock.when(
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
      const _InventoryMetric(
        label: 'Kho hoạt động',
        value: '1',
        context: 'Trong phạm vi cửa hàng',
      ),
    ];

    return _SimpleMetricStrip(metrics: metrics);
  }
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
            return 'Tồn $quantity';
          },
        );
        final slowPanel = _InventoryIssuePanel(
          title: 'Chậm luân chuyển',
          emptyMessage: 'Không có sản phẩm chậm luân chuyển.',
          asyncValue: slowMoving,
          statusBuilder: (item) {
            final quantity = item['currentQuantity'] ?? item['quantity'] ?? 0;
            return 'Tồn $quantity';
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
    final name =
        item['product']?['name'] ??
        item['productName'] ??
        'Sản phẩm chưa có tên';

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
            child: Text(
              'Phân bổ tồn kho theo danh mục',
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
              final maximum = values.fold<double>(
                0,
                (current, value) => value > current ? value : current,
              );

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
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

class _DistributionRow extends StatelessWidget {
  final String label;
  final double value;
  final double maximum;

  const _DistributionRow({
    required this.label,
    required this.value,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final progress = maximum <= 0 ? 0.0 : value / maximum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(
              value.toStringAsFixed(0),
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
