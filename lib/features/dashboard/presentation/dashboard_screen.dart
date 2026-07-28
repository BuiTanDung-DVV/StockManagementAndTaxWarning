import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/presentation/widgets/join_shop_dialog.dart';
import '../../finance/providers/finance_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../sales/providers/sales_provider.dart';
import '../../settings/providers/shop_provider.dart';
import 'widgets/dashboard_widgets.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class _DashboardTimeFilter extends Notifier<String> {
  @override
  String build() => 'month';

  void update(String value) => state = value;
}

final _dashboardTimeFilterProvider =
    NotifierProvider<_DashboardTimeFilter, String>(_DashboardTimeFilter.new);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showAllMobileMetrics = false;

  void _showJoinShopDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const JoinShopDialog());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final shopState = ref.watch(shopProvider);
    final hasFinance = shopState.isOwner || shopState.hasPermission('finance');
    final hasInventory =
        shopState.isOwner || shopState.hasPermission('inventory');
    final filter = ref.watch(_dashboardTimeFilterProvider);
    final today = DateTime.now();
    final periods = _resolvePeriods(filter, today);

    final salesAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(
            salesSummaryProvider((
              from: periods.currentFrom,
              to: periods.currentTo,
            )),
          )
        : null;
    final comparisonAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(
            salesSummaryProvider((
              from: periods.previousFrom,
              to: periods.previousTo,
            )),
          )
        : null;
    final cashAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(
            cashSummaryProvider((
              from: periods.currentFrom,
              to: periods.currentTo,
            )),
          )
        : null;
    final recentTransactionsAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(recentTransactionsProvider)
        : null;

    if (shopState.userShops.isEmpty) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: AppEmpty(
            message: 'Chưa có cửa hàng',
            subtitle:
                'Tạo cửa hàng mới hoặc gửi yêu cầu gia nhập để bắt đầu quản lý.',
            action: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => _showJoinShopDialog(context),
                  child: const Text('Tìm và xin gia nhập'),
                ),
                OutlinedButton(
                  onPressed: () => ref.invalidate(shopProvider),
                  child: const Text('Tải lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            if (hasFinance) {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(cashSummaryProvider);
              ref.invalidate(recentTransactionsProvider);
            }
            if (hasInventory) ref.invalidate(lowStockProvider);
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
                    title: 'Tình hình cửa hàng',
                    subtitle:
                        '${shopState.currentShopName ?? 'Cửa hàng'} • ${periods.currentLabel} • cập nhật ${DateFormat('dd/MM/yyyy').format(today)}',
                    action:
                        shopState.isOwner || shopState.hasPermission('sales')
                        ? FilledButton(
                            onPressed: () => context.push('/pos'),
                            child: const Text('Bán hàng'),
                          )
                        : null,
                  ),
                  if (salesAsync != null && cashAsync != null)
                    salesAsync.when(
                      data: (salesData) => cashAsync.when(
                        data: (cashData) => _DashboardMetricStrip(
                          metrics: _buildMetrics(
                            salesData: salesData,
                            cashData: cashData,
                            periodLabel: periods.currentLabel,
                            asOf: today,
                          ),
                          showAllMobile: _showAllMobileMetrics,
                          onToggleMobile: () => setState(
                            () =>
                                _showAllMobileMetrics = !_showAllMobileMetrics,
                          ),
                        ),
                        loading: () => const _MetricStripSkeleton(),
                        error: (_, _) => _DashboardMetricStrip(
                          metrics: _buildMetrics(
                            salesData: salesData,
                            cashData: const {},
                            periodLabel: periods.currentLabel,
                            asOf: today,
                            cashAvailable: false,
                          ),
                          showAllMobile: _showAllMobileMetrics,
                          onToggleMobile: () => setState(
                            () =>
                                _showAllMobileMetrics = !_showAllMobileMetrics,
                          ),
                        ),
                      ),
                      loading: () => const _MetricStripSkeleton(),
                      error: (_, _) => AppInlineError(
                        message: 'Không thể tải số liệu tổng quan.',
                        onRetry: () => ref.invalidate(salesSummaryProvider),
                      ),
                    )
                  else
                    _PermissionSummary(
                      hasInventory: hasInventory,
                      periodLabel: periods.currentLabel,
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  _DashboardWorkspace(
                    currentSales: salesAsync,
                    comparisonSales: comparisonAsync,
                    recentTransactions: recentTransactionsAsync,
                    currentLabel: periods.currentLabel,
                    previousLabel: periods.previousLabel,
                    filter: filter,
                    onFilterChanged: (value) => ref
                        .read(_dashboardTimeFilterProvider.notifier)
                        .update(value),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_DashboardMetric> _buildMetrics({
    required Map<String, dynamic> salesData,
    required Map<String, dynamic> cashData,
    required String periodLabel,
    required DateTime asOf,
    bool cashAvailable = true,
  }) {
    final revenue =
        num.tryParse(salesData['totalRevenue']?.toString() ?? '0') ?? 0;
    final profit =
        num.tryParse(salesData['grossProfit']?.toString() ?? '0') ?? 0;
    final orderCount = salesData['totalOrders'] ?? salesData['orderCount'] ?? 0;
    final cashBalance = cashAvailable
        ? num.tryParse(cashData['cashBalance']?.toString() ?? '0')
        : null;

    return [
      _DashboardMetric(
        label: 'Doanh thu thuần',
        value: _currencyFormat.format(revenue),
        context: periodLabel,
        assetPath: AppAssets.revenue,
        color: AppColors.success,
      ),
      _DashboardMetric(
        label: 'Lợi nhuận gộp',
        value: _currencyFormat.format(profit),
        context: periodLabel,
        assetPath: AppAssets.profit,
        color: profit < 0 ? AppColors.danger : AppColors.success,
      ),
      _DashboardMetric(
        label: 'Số dư quỹ',
        value: cashBalance == null
            ? 'Chưa tải được'
            : _currencyFormat.format(cashBalance),
        context: 'Tại ${DateFormat('dd/MM/yyyy').format(asOf)}',
        assetPath: AppAssets.cash,
        color: Theme.of(context).colorScheme.primary,
      ),
      _DashboardMetric(
        label: 'Đơn hàng',
        value: '$orderCount',
        context: periodLabel,
        assetPath: AppAssets.orders,
        color: Theme.of(context).colorScheme.primary,
      ),
    ];
  }
}

class _DashboardWorkspace extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? currentSales;
  final AsyncValue<Map<String, dynamic>>? comparisonSales;
  final AsyncValue<List<dynamic>>? recentTransactions;
  final String currentLabel;
  final String previousLabel;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _DashboardWorkspace({
    required this.currentSales,
    required this.comparisonSales,
    required this.recentTransactions,
    required this.currentLabel,
    required this.previousLabel,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chart = _DashboardChart(
      currentSales: currentSales,
      comparisonSales: comparisonSales,
      currentLabel: currentLabel,
      previousLabel: previousLabel,
      filter: filter,
      onFilterChanged: onFilterChanged,
    );
    final priorities = const DashboardPriorityList();
    final orders =
        recentTransactions?.when(
          data: (items) => DashboardRecentOrdersList(items),
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: AppShimmer(
              child: ShimmerBox(
                width: double.infinity,
                height: 220,
                radius: AppRadius.card,
              ),
            ),
          ),
          error: (_, _) =>
              const AppInlineError(message: 'Không thể tải đơn hàng gần đây.'),
        ) ??
        const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              priorities,
              const SizedBox(height: AppSpacing.lg),
              chart,
              orders,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: chart),
                const SizedBox(width: AppSpacing.lg),
                const SizedBox(width: 390, child: DashboardPriorityList()),
              ],
            ),
            orders,
          ],
        );
      },
    );
  }
}

class _DashboardChart extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? currentSales;
  final AsyncValue<Map<String, dynamic>>? comparisonSales;
  final String currentLabel;
  final String previousLabel;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _DashboardChart({
    required this.currentSales,
    required this.comparisonSales,
    required this.currentLabel,
    required this.previousLabel,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (currentSales == null || comparisonSales == null) {
      return const AppEmpty(
        message: 'Không có quyền xem doanh thu',
        subtitle: 'Các ưu tiên kho và công nợ vẫn được hiển thị theo quyền.',
      );
    }

    return currentSales!.when(
      data: (current) => comparisonSales!.when(
        data: (previous) => ComparisonBarChart(
          (current['daily'] as List?) ?? const [],
          (previous['daily'] as List?) ?? const [],
          currentLabel,
          previousLabel,
          filterWidget: TimeFilterBar(filter, onFilterChanged),
        ),
        loading: () => const _ChartSkeleton(),
        error: (_, _) =>
            const AppInlineError(message: 'Không thể tải dữ liệu so sánh.'),
      ),
      loading: () => const _ChartSkeleton(),
      error: (_, _) =>
          const AppInlineError(message: 'Không thể tải biểu đồ doanh thu.'),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: 360,
        radius: AppRadius.card,
      ),
    );
  }
}

class _DashboardMetricStrip extends StatelessWidget {
  final List<_DashboardMetric> metrics;
  final bool showAllMobile;
  final VoidCallback onToggleMobile;

  const _DashboardMetricStrip({
    required this.metrics,
    required this.showAllMobile,
    required this.onToggleMobile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        if (isCompact) {
          final primaryMetrics = [metrics[0], metrics[2]];
          final secondaryMetrics = [metrics[1], metrics[3]];
          final visibleMetrics = [
            ...primaryMetrics,
            if (showAllMobile) ...secondaryMetrics,
          ];

          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.divider),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                for (var index = 0; index < visibleMetrics.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: colors.divider),
                  _MetricRow(metric: visibleMetrics[index]),
                ],
                Divider(height: 1, color: colors.divider),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onToggleMobile,
                    child: Text(
                      showAllMobile ? 'Thu gọn chỉ số' : 'Xem thêm 2 chỉ số',
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          height: 120,
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
                Expanded(child: _MetricCell(metric: metrics[index])),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MetricCell extends StatelessWidget {
  final _DashboardMetric metric;

  const _MetricCell({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAssetIcon(
                assetPath: metric.assetPath,
                size: 18,
                color: metric.color,
                semanticLabel: metric.label,
              ),
              const SizedBox(width: AppSpacing.xs),
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
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: AppTheme.tabularStyle(
                context,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            metric.context,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final _DashboardMetric metric;

  const _MetricRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAssetIcon(
            assetPath: metric.assetPath,
            size: 22,
            color: metric.color,
            semanticLabel: metric.label,
          ),
          const SizedBox(width: AppSpacing.sm),
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
          Flexible(
            child: Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.tabularStyle(
                context,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionSummary extends StatelessWidget {
  final bool hasInventory;
  final String periodLabel;

  const _PermissionSummary({
    required this.hasInventory,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppInlineError(
      message: hasInventory
          ? 'Tài khoản chỉ có quyền kho. Số liệu tài chính của $periodLabel không được hiển thị.'
          : 'Tài khoản chưa có quyền xem số liệu tổng hợp.',
    );
  }
}

class _MetricStripSkeleton extends StatelessWidget {
  const _MetricStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: 116,
        radius: AppRadius.card,
      ),
    );
  }
}

class _DashboardMetric {
  final String label;
  final String value;
  final String context;
  final String assetPath;
  final Color color;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.context,
    required this.assetPath,
    required this.color,
  });
}

class _DashboardPeriods {
  final String currentFrom;
  final String currentTo;
  final String previousFrom;
  final String previousTo;
  final String currentLabel;
  final String previousLabel;

  const _DashboardPeriods({
    required this.currentFrom,
    required this.currentTo,
    required this.previousFrom,
    required this.previousTo,
    required this.currentLabel,
    required this.previousLabel,
  });
}

_DashboardPeriods _resolvePeriods(String filter, DateTime today) {
  if (filter == 'week') {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final previousStart = weekStart.subtract(const Duration(days: 7));
    return _DashboardPeriods(
      currentFrom: _dateOnly(weekStart),
      currentTo: _dateOnly(today),
      previousFrom: _dateOnly(previousStart),
      previousTo: _dateOnly(weekStart.subtract(const Duration(days: 1))),
      currentLabel: 'Tuần này',
      previousLabel: 'Tuần trước',
    );
  }

  if (filter == '6_months') {
    return _DashboardPeriods(
      currentFrom: _dateOnly(DateTime(today.year, today.month - 5, 1)),
      currentTo: _dateOnly(today),
      previousFrom: _dateOnly(DateTime(today.year, today.month - 11, 1)),
      previousTo: _dateOnly(DateTime(today.year, today.month - 5, 0)),
      currentLabel: '6 tháng qua',
      previousLabel: '6 tháng trước',
    );
  }

  if (filter == 'year') {
    return _DashboardPeriods(
      currentFrom: _dateOnly(DateTime(today.year, 1, 1)),
      currentTo: _dateOnly(today),
      previousFrom: _dateOnly(DateTime(today.year - 1, 1, 1)),
      previousTo: _dateOnly(DateTime(today.year - 1, 12, 31)),
      currentLabel: 'Năm nay',
      previousLabel: 'Năm trước',
    );
  }

  final current = currentMonthReportingPeriod(today);
  return _DashboardPeriods(
    currentFrom: current.from,
    currentTo: current.to,
    previousFrom: _dateOnly(DateTime(today.year, today.month - 1, 1)),
    previousTo: _dateOnly(DateTime(today.year, today.month, 0)),
    currentLabel: 'Tháng này',
    previousLabel: 'Tháng trước',
  );
}

String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;
