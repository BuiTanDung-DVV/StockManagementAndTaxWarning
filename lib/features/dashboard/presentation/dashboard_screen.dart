import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/chart_widgets.dart';
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
    final hasSalesInsights =
        shopState.isOwner ||
        shopState.hasPermission('sales') ||
        shopState.hasPermission('dashboard');
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
    final topProductsAsync = hasSalesInsights && shopState.userShops.isNotEmpty
        ? ref.watch(
            topProductsProvider((
              from: periods.currentFrom,
              to: periods.currentTo,
            )),
          )
        : null;

    if (shopState.userShops.isEmpty) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: _NoShopWorkspace(
            onJoin: () => _showJoinShopDialog(context),
            onReload: () => ref.invalidate(shopProvider),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          shopState.isOwner || shopState.hasPermission('sales')
          ? AppPrimaryFloatingAction(
              label: 'Bán hàng',
              assetPath: AppAssets.orders,
              heroTag: 'dashboard-sale-action',
              onPressed: () => context.push('/pos'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            if (hasSalesInsights) {
              ref.invalidate(topProductsProvider);
            }
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
                    dense: true,
                    titleStyle: GoogleFonts.manrope(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.65,
                      color: colors.textPrimary,
                    ),
                    subtitleStyle: GoogleFonts.manrope(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
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
                    topProducts: topProductsAsync,
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

class _NoShopWorkspace extends StatelessWidget {
  final VoidCallback onJoin;
  final VoidCallback onReload;

  const _NoShopWorkspace({required this.onJoin, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return SingleChildScrollView(
      child: AppResponsiveContent(
        maxWidth: 1080,
        verticalPadding: AppSpacing.xl,
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            border: Border.all(color: colors.divider),
            boxShadow: const [AppTheme.diffusionShadow],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final intro = Padding(
                padding: EdgeInsets.all(compact ? 24 : 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const AppAssetIcon(
                        assetPath: AppAssets.appIcon,
                        size: 40,
                        semanticLabel: 'SmartStock',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Chưa có cửa hàng',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Bắt đầu không gian quản lý',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tài khoản của bạn chưa thuộc cửa hàng nào. Gửi yêu cầu gia nhập để sử dụng bán hàng, kho, công nợ và báo cáo thuế.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton(
                          onPressed: onJoin,
                          child: const Text('Tìm cửa hàng'),
                        ),
                        OutlinedButton(
                          onPressed: onReload,
                          child: const Text('Kiểm tra lại'),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final checklist = Container(
                color: colors.cardAlt,
                padding: EdgeInsets.all(compact ? 24 : 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quy trình kích hoạt',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _ActivationStep(
                      number: '01',
                      title: 'Tìm đúng cửa hàng',
                      description:
                          'Tra cứu theo tên hoặc mã được chủ cửa hàng cung cấp.',
                    ),
                    const _ActivationStep(
                      number: '02',
                      title: 'Gửi yêu cầu gia nhập',
                      description:
                          'Chủ cửa hàng kiểm tra và cấp vai trò phù hợp.',
                    ),
                    const _ActivationStep(
                      number: '03',
                      title: 'Bắt đầu vận hành',
                      description:
                          'Dữ liệu và chức năng hiển thị theo quyền được cấp.',
                      showDivider: false,
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, checklist],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: intro),
                    Expanded(flex: 4, child: checklist),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActivationStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final bool showDivider;

  const _ActivationStep({
    required this.number,
    required this.title,
    required this.description,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: AppTheme.tabularStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              padding: EdgeInsets.only(bottom: showDivider ? AppSpacing.md : 0),
              decoration: BoxDecoration(
                border: showDivider
                    ? Border(bottom: BorderSide(color: colors.divider))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardWorkspace extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? currentSales;
  final AsyncValue<Map<String, dynamic>>? comparisonSales;
  final AsyncValue<List<dynamic>>? recentTransactions;
  final AsyncValue<List<dynamic>>? topProducts;
  final String currentLabel;
  final String previousLabel;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _DashboardWorkspace({
    required this.currentSales,
    required this.comparisonSales,
    required this.recentTransactions,
    required this.topProducts,
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
    final products =
        topProducts?.when(
          data: (items) =>
              _TopProductsRevenueChart(items: items, period: currentLabel),
          loading: () => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: AppShimmer(
              child: ShimmerBox(
                width: double.infinity,
                height: 320,
                radius: AppRadius.card,
              ),
            ),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: AppInlineError(message: 'Không thể tải sản phẩm bán chạy.'),
          ),
        ) ??
        const SizedBox.shrink();
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
              chart,
              const SizedBox(height: AppSpacing.lg),
              priorities,
              products,
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
                Expanded(flex: 3, child: chart),
                const SizedBox(width: AppSpacing.lg),
                const SizedBox(width: 330, child: DashboardPriorityList()),
              ],
            ),
            products,
            orders,
          ],
        );
      },
    );
  }
}

class _TopProductsRevenueChart extends StatelessWidget {
  final List<dynamic> items;
  final String period;

  const _TopProductsRevenueChart({required this.items, required this.period});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final products = items.take(10).toList();
    final chartHeight = products.isEmpty
        ? 300.0
        : (112 + products.length * 55).clamp(300, 662).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: ChartCard(
        title: 'Top sản phẩm bán chạy',
        height: chartHeight,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: colors.cardAlt,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: colors.divider),
          ),
          child: Text(
            period,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child: products.isEmpty
            ? const EmptyChartPlaceholder(
                message: 'Chưa có doanh thu sản phẩm trong kỳ này.',
              )
            : _TopProductsHorizontalBars(products),
      ),
    );
  }
}

class _TopProductsHorizontalBars extends StatelessWidget {
  final List<dynamic> products;

  const _TopProductsHorizontalBars(this.products);

  double _number(dynamic value) =>
      num.tryParse(value?.toString() ?? '0')?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final maxRevenue = products.fold<double>(
      0,
      (current, item) =>
          _number(item['value']) > current ? _number(item['value']) : current,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const SizedBox(width: 34),
              Expanded(
                child: Text(
                  'Xếp theo doanh thu',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 66,
                child: Text(
                  'Đã bán',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: Text(
                  'Doanh thu',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final product = products[index];
              final revenue = _number(product['value']);
              final quantity = _number(product['quantity']);
              final progress = maxRevenue <= 0 ? 0.0 : revenue / maxRevenue;

              return _TopProductRankRow(
                rank: index + 1,
                name: product['name']?.toString() ?? 'Chưa rõ',
                revenue: revenue,
                quantity: quantity,
                progress: progress,
                color: primary.withValues(alpha: 1 - index * 0.045),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopProductRankRow extends StatelessWidget {
  final int rank;
  final String name;
  final double revenue;
  final double quantity;
  final double progress;
  final Color color;

  const _TopProductRankRow({
    required this.rank,
    required this.name,
    required this.revenue,
    required this.quantity,
    required this.progress,
    required this.color,
  });

  String get _quantityLabel {
    final value = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : NumberFormat('0.##', 'vi_VN').format(quantity);
    return '$value sp';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return SizedBox(
      height: 47,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: AppTheme.tabularStyle(
                context,
                color: rank <= 3 ? color : colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: colors.cardAlt,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Text(
              _quantityLabel,
              textAlign: TextAlign.right,
              style: AppTheme.tabularStyle(
                context,
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            child: Text(
              '${compactVietnameseAmount(revenue)} ₫',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.tabularStyle(
                context,
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
        visual: AppEmptyVisual.finance,
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
        height: 420,
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
              boxShadow: const [AppTheme.diffusionShadow],
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
          height: 96,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.divider),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [AppTheme.diffusionShadow],
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAssetIcon(
                assetPath: metric.assetPath,
                size: 16,
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
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: GoogleFonts.manrope(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppAssetIcon(
            assetPath: metric.assetPath,
            size: 19,
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
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
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
        height: 96,
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
