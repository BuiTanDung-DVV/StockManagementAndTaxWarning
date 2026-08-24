import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/utils/data_freshness.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/data_freshness_banner.dart';
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

bool dashboardUsesCompactLayout(double width) =>
    width < AppBreakpoints.compactNavigation;

bool dashboardCanSell(ShopState shopState) =>
    !shopState.isAllShops &&
    (shopState.isOwner || shopState.hasPermission('sales'));

bool dashboardCanViewSalesInsights(ShopState shopState) =>
    shopState.isOwner ||
    shopState.hasPermission('sales') ||
    shopState.hasPermission('dashboard');

bool dashboardCanViewRecentOrders(ShopState shopState) =>
    !shopState.isAllShops &&
    (shopState.isOwner || shopState.hasPermission('sales'));

({bool sales, bool finance, bool inventory}) dashboardRefreshPlan({
  required bool hasSalesInsights,
  required bool hasFinance,
  required bool hasInventory,
}) => (sales: hasSalesInsights, finance: hasFinance, inventory: hasInventory);

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
    final hasSalesInsights = dashboardCanViewSalesInsights(shopState);
    final hasInventory =
        shopState.isOwner || shopState.hasPermission('inventory');
    final canSell = dashboardCanSell(shopState);
    final compactLayout = dashboardUsesCompactLayout(
      MediaQuery.sizeOf(context).width,
    );
    final filter = ref.watch(_dashboardTimeFilterProvider);
    final today = DateTime.now();
    final periods = _resolvePeriods(filter, today);

    final salesAsync = hasSalesInsights && shopState.userShops.isNotEmpty
        ? ref.watch(
            salesSummaryProvider((
              from: periods.currentFrom,
              to: periods.currentTo,
            )),
          )
        : null;
    final comparisonAsync = hasSalesInsights && shopState.userShops.isNotEmpty
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
    final recentTransactionsAsync =
        dashboardCanViewRecentOrders(shopState) &&
            shopState.userShops.isNotEmpty
        ? ref.watch(recentTransactionsProvider)
        : null;
    final topProductsAsync = hasSalesInsights && shopState.userShops.isNotEmpty
        ? ref.watch(
            topProductsProvider((
              from: periods.currentFrom,
              to: periods.currentTo,
              previousFrom: periods.previousFrom,
              previousTo: periods.previousTo,
            )),
          )
        : null;
    final previousTopProductsAsync = topProductsAsync?.value?.isEmpty == true
        ? ref.watch(
            topProductsProvider((
              from: periods.previousFrom,
              to: periods.previousTo,
              previousFrom: null,
              previousTo: null,
            )),
          )
        : null;

    if (shopState.userShops.isEmpty) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: shopState.errorMessage != null
              ? AppResponsiveContent(
                  maxWidth: 720,
                  verticalPadding: AppSpacing.xl,
                  child: AppInlineError(
                    message: shopState.errorMessage!,
                    onRetry: () =>
                        ref.read(shopProvider.notifier).loadUserShops(),
                  ),
                )
              : _NoShopWorkspace(
                  onJoin: () => _showJoinShopDialog(context),
                  onReload: () =>
                      ref.read(shopProvider.notifier).loadUserShops(),
                ),
        ),
      );
    }

    Widget headerActions({required bool compact}) => Wrap(
      spacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        featureGuideButton(context, 'dashboard'),
        if (compact && canSell)
          Tooltip(
            message: 'Ghi nhận bán hàng',
            child: FloatingActionButton.small(
              heroTag: 'dashboard-sale-action-compact',
              elevation: 0,
              onPressed: () => context.push('/sales/new'),
              child: const AppAssetIcon(
                assetPath: AppAssets.orders,
                size: 18,
                color: Colors.white,
                semanticLabel: 'Ghi nhận bán hàng',
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canSell && !compactLayout
          ? AppPrimaryFloatingAction(
              label: 'Ghi nhận bán hàng',
              assetPath: AppAssets.orders,
              heroTag: 'dashboard-sale-action',
              onPressed: () => context.push('/sales/new'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            final refreshPlan = dashboardRefreshPlan(
              hasSalesInsights: hasSalesInsights,
              hasFinance: hasFinance,
              hasInventory: hasInventory,
            );
            if (refreshPlan.sales) {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(topProductsProvider);
            }
            if (refreshPlan.finance) {
              ref.invalidate(cashSummaryProvider);
              ref.invalidate(recentTransactionsProvider);
            }
            if (refreshPlan.inventory) ref.invalidate(lowStockProvider);
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
                    title: shopState.isAllShops
                        ? 'Tổng quan tất cả cửa hàng'
                        : 'Tình hình cửa hàng',
                    subtitle:
                        '${shopState.currentShopName ?? 'Cửa hàng'} • ${periods.currentLabel} • đối chiếu đến ${DateFormat('dd/MM/yyyy').format(today)}',
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
                    action: headerActions(compact: compactLayout),
                    compactAction: headerActions(compact: true),
                  ),
                  if (shopState.isAllShops) ...[
                    _AllShopsNotice(
                      shopCount: shopState.userShops
                          .where(
                            (shop) =>
                                shop['status'] == 'ACTIVE' &&
                                shop['isActive'] != false,
                          )
                          .length,
                      onChooseShop: () => context.push('/settings'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (salesAsync != null)
                    salesAsync.when(
                      data: (data) {
                        final assessment = assessDataFreshness(
                          latestDate: data['latestOrderDate'],
                          periodFrom: DateTime.parse(periods.currentFrom),
                          periodTo: DateTime.parse(periods.currentTo),
                          recordCount:
                              int.tryParse(
                                (data['orderCount'] ?? 0).toString(),
                              ) ??
                              0,
                        );
                        if (!assessment.requiresAttention) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: DataFreshnessBanner(
                            assessment: assessment,
                            dataLabel: 'bán hàng',
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  if (salesAsync != null)
                    salesAsync.when(
                      data: (salesData) {
                        Widget metricStrip(
                          Map<String, dynamic> cashData, {
                          required bool cashAvailable,
                        }) => _DashboardMetricStrip(
                          metrics: _buildMetrics(
                            salesData: salesData,
                            comparisonSalesData: comparisonAsync?.value,
                            cashData: cashData,
                            periodLabel: periods.currentLabel,
                            previousPeriodLabel: periods.previousLabel,
                            asOf: today,
                            cashAvailable: cashAvailable,
                          ),
                          showAllMobile: _showAllMobileMetrics,
                          onToggleMobile: () => setState(
                            () =>
                                _showAllMobileMetrics = !_showAllMobileMetrics,
                          ),
                        );

                        if (cashAsync == null) {
                          return metricStrip(const {}, cashAvailable: false);
                        }
                        return cashAsync.when(
                          data: (cashData) =>
                              metricStrip(cashData, cashAvailable: true),
                          loading: () => const _MetricStripSkeleton(),
                          error: (_, _) =>
                              metricStrip(const {}, cashAvailable: false),
                        );
                      },
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
                    previousTopProducts: previousTopProductsAsync,
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
    Map<String, dynamic>? comparisonSalesData,
    required Map<String, dynamic> cashData,
    required String periodLabel,
    required String previousPeriodLabel,
    required DateTime asOf,
    bool cashAvailable = true,
  }) {
    final revenue =
        num.tryParse(
          (salesData['netSalesRevenue'] ?? salesData['totalRevenue'])
                  ?.toString() ??
              '0',
        ) ??
        0;
    final profit =
        num.tryParse(salesData['grossProfit']?.toString() ?? '0') ?? 0;
    final orderCount = salesData['totalOrders'] ?? salesData['orderCount'] ?? 0;
    final previousRevenue =
        num.tryParse(
          (comparisonSalesData?['netSalesRevenue'] ??
                      comparisonSalesData?['totalRevenue'])
                  ?.toString() ??
              '0',
        ) ??
        0;
    final previousProfit =
        num.tryParse(comparisonSalesData?['grossProfit']?.toString() ?? '0') ??
        0;
    final previousOrderCount =
        num.tryParse(
          (comparisonSalesData?['totalOrders'] ??
                  comparisonSalesData?['orderCount'] ??
                  0)
              .toString(),
        ) ??
        0;
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
        comparison: _growthLabel(revenue, previousRevenue, previousPeriodLabel),
        comparisonPositive: revenue >= previousRevenue,
      ),
      _DashboardMetric(
        label: 'Lợi nhuận gộp',
        value: _currencyFormat.format(profit),
        context: periodLabel,
        assetPath: AppAssets.profit,
        color: profit < 0 ? AppColors.danger : AppColors.success,
        comparison: _growthLabel(profit, previousProfit, previousPeriodLabel),
        comparisonPositive: profit >= previousProfit,
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
        comparison: _growthLabel(
          num.tryParse(orderCount.toString()) ?? 0,
          previousOrderCount,
          previousPeriodLabel,
        ),
        comparisonPositive:
            (num.tryParse(orderCount.toString()) ?? 0) >= previousOrderCount,
      ),
    ];
  }

  String? _growthLabel(num current, num previous, String previousLabel) {
    if (previous <= 0) return null;
    final change = ((current - previous) / previous) * 100;
    return '${change >= 0 ? '▲' : '▼'} ${NumberFormat('0.0', 'vi_VN').format(change.abs())}% so với $previousLabel';
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
                padding: compact
                    ? const EdgeInsets.all(24)
                    : const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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

class _AllShopsNotice extends StatelessWidget {
  final int shopCount;
  final VoidCallback onChooseShop;

  const _AllShopsNotice({required this.shopCount, required this.onChooseShop});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chế độ tổng hợp • $shopCount cửa hàng',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Các chỉ số bên dưới được cộng gộp. Bán hàng, nhập kho và chỉnh sửa dữ liệu yêu cầu chọn một cửa hàng cụ thể.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );

    final chooseButton = OutlinedButton(
      onPressed: onChooseShop,
      child: const Text('Chọn cửa hàng cụ thể'),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: primary.withValues(alpha: 0.28)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: Alignment.centerLeft, child: chooseButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: AppSpacing.md),
              chooseButton,
            ],
          );
        },
      ),
    );
  }
}

class _DashboardWorkspace extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>>? currentSales;
  final AsyncValue<Map<String, dynamic>>? comparisonSales;
  final AsyncValue<List<dynamic>>? recentTransactions;
  final AsyncValue<List<dynamic>>? topProducts;
  final AsyncValue<List<dynamic>>? previousTopProducts;
  final String currentLabel;
  final String previousLabel;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  const _DashboardWorkspace({
    required this.currentSales,
    required this.comparisonSales,
    required this.recentTransactions,
    required this.topProducts,
    required this.previousTopProducts,
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
    Widget productPanel(List<dynamic> items) {
      if (items.isNotEmpty || previousTopProducts == null) {
        return DashboardTopProductsRevenueChart(
          items: items,
          period: currentLabel,
          comparisonPeriod: previousLabel,
        );
      }
      return previousTopProducts!.when(
        data: (previousItems) => DashboardTopProductsRevenueChart(
          items: previousItems,
          period: previousLabel,
          isPreviousPeriodFallback: previousItems.isNotEmpty,
        ),
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
        error: (_, _) => DashboardTopProductsRevenueChart(
          items: const [],
          period: currentLabel,
        ),
      );
    }

    final products =
        topProducts?.when(
          data: productPanel,
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

class DashboardTopProductsRevenueChart extends StatelessWidget {
  final List<dynamic> items;
  final String period;
  final String? comparisonPeriod;
  final bool isPreviousPeriodFallback;

  const DashboardTopProductsRevenueChart({
    super.key,
    required this.items,
    required this.period,
    this.comparisonPeriod,
    this.isPreviousPeriodFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final products = items.take(10).toList();
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final chartHeight = products.isEmpty
        ? 220.0
        : mobile
        ? (140 + products.length * 78).toDouble()
        : (136 + products.length * 55).clamp(324, 686).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: ChartCard(
        title: isPreviousPeriodFallback
            ? 'Top sản phẩm kỳ trước'
            : 'Top sản phẩm bán chạy',
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
            : _TopProductsHorizontalBars(
                products,
                allowGrowth: !isPreviousPeriodFallback,
                comparisonPeriod: isPreviousPeriodFallback
                    ? null
                    : comparisonPeriod,
              ),
      ),
    );
  }
}

class _TopProductsHorizontalBars extends StatelessWidget {
  final List<dynamic> products;
  final bool allowGrowth;
  final String? comparisonPeriod;

  const _TopProductsHorizontalBars(
    this.products, {
    required this.allowGrowth,
    required this.comparisonPeriod,
  });

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
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final showGrowth = allowGrowth && width >= 700;
    final showMargin = width >= 900;
    final comparisonCaption = allowGrowth && comparisonPeriod != null
        ? 'Tăng trưởng so với $comparisonPeriod'
        : null;

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (comparisonCaption != null) ...[
            Text(
              comparisonCaption,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: colors.divider),
              itemBuilder: (context, index) {
                final product = products[index];
                final revenue = _number(product['value']);
                final quantity = _number(product['quantity']);
                final growth = product['growthPct'] == null
                    ? null
                    : _number(product['growthPct']);
                final growthStatus = allowGrowth
                    ? product['growthStatus']?.toString()
                    : 'NOT_REQUESTED';
                return _TopProductMobileRow(
                  rank: index + 1,
                  name: product['name']?.toString() ?? 'Chưa rõ',
                  quantity: quantity,
                  unit: product['unit']?.toString() ?? 'sản phẩm',
                  revenue: revenue,
                  progress: maxRevenue <= 0 ? 0 : revenue / maxRevenue,
                  growth: growth,
                  growthStatus: growthStatus,
                  color: primary.withValues(alpha: 1 - index * 0.045),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (comparisonCaption != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              comparisonCaption,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const SizedBox(width: 34),
              Expanded(
                child: Text(
                  'Xếp theo doanh thu thuần',
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
              if (showMargin) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  child: Text(
                    'Biên lãi',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (showGrowth) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 88,
                  child: Text(
                    'Tăng trưởng',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
              final marginPct = _number(product['marginPct']);
              final progress = maxRevenue <= 0 ? 0.0 : revenue / maxRevenue;
              final growth = product['growthPct'] == null
                  ? null
                  : _number(product['growthPct']);
              final growthStatus = allowGrowth
                  ? product['growthStatus']?.toString()
                  : 'NOT_REQUESTED';

              return _TopProductRankRow(
                rank: index + 1,
                name: product['name']?.toString() ?? 'Chưa rõ',
                revenue: revenue,
                quantity: quantity,
                marginPct: marginPct,
                unit: product['unit']?.toString() ?? 'sản phẩm',
                progress: progress,
                growth: growth,
                growthStatus: growthStatus,
                showGrowth: showGrowth,
                showMargin: showMargin,
                color: primary.withValues(alpha: 1 - index * 0.045),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopProductMobileRow extends StatelessWidget {
  final int rank;
  final String name;
  final double quantity;
  final String unit;
  final double revenue;
  final double progress;
  final double? growth;
  final String? growthStatus;
  final Color color;

  const _TopProductMobileRow({
    required this.rank,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.revenue,
    required this.progress,
    required this.growth,
    required this.growthStatus,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : NumberFormat('0.##', 'vi_VN').format(quantity);
    final growthLabel = switch (growthStatus) {
      'NEW' => 'Mới',
      'NO_BASE' => 'Chưa có kỳ gốc',
      'COMPARABLE' when growth != null =>
        '${growth! >= 0 ? '▲' : '▼'} ${NumberFormat('0.0', 'vi_VN').format(growth!.abs())}%',
      _ => null,
    };
    final growthColor = growth == null
        ? AppColors.info
        : growth! >= 0
        ? AppColors.success
        : AppColors.danger;

    return SizedBox(
      height: 77,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colors.cardAlt,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Text(
                      '$quantityLabel $unit',
                      style: AppTheme.tabularStyle(
                        context,
                        color: colors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${compactVietnameseAmount(revenue)} ₫',
                      style: AppTheme.tabularStyle(
                        context,
                        color: colors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (growthLabel != null)
                      Text(
                        growthLabel,
                        style: AppTheme.tabularStyle(
                          context,
                          color: growthColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductRankRow extends StatelessWidget {
  final int rank;
  final String name;
  final double revenue;
  final double quantity;
  final double marginPct;
  final String unit;
  final double progress;
  final double? growth;
  final String? growthStatus;
  final bool showGrowth;
  final bool showMargin;
  final Color color;

  const _TopProductRankRow({
    required this.rank,
    required this.name,
    required this.revenue,
    required this.quantity,
    required this.marginPct,
    required this.unit,
    required this.progress,
    required this.growth,
    required this.growthStatus,
    required this.showGrowth,
    required this.showMargin,
    required this.color,
  });

  String get _quantityLabel {
    final value = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : NumberFormat('0.##', 'vi_VN').format(quantity);
    return '$value $unit';
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
          if (showMargin) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: Text(
                '${NumberFormat('0.0', 'vi_VN').format(marginPct)}%',
                maxLines: 1,
                textAlign: TextAlign.right,
                style: AppTheme.tabularStyle(
                  context,
                  color: marginPct >= 20
                      ? AppColors.success
                      : marginPct > 0
                      ? colors.textSecondary
                      : AppColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (showGrowth) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: Text(
                switch (growthStatus) {
                  'NEW' => 'Mới',
                  'NO_BASE' => 'Không có gốc',
                  'COMPARABLE' when growth != null =>
                    '${growth! >= 0 ? '▲' : '▼'} ${NumberFormat('0.0', 'vi_VN').format(growth!.abs())}%',
                  _ => 'Chưa đối chiếu',
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTheme.tabularStyle(
                  context,
                  color: growthStatus == 'NEW'
                      ? AppColors.info
                      : growth == null
                      ? colors.textMuted
                      : growth! >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  fontSize: growth == null ? 9 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
                  _MetricRow(
                    metric: visibleMetrics[index],
                    emphasized: index == 0,
                  ),
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
          height: 116,
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
                Expanded(
                  child: _MetricCell(
                    metric: metrics[index],
                    emphasized: index == 0,
                  ),
                ),
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
  final bool emphasized;

  const _MetricCell({required this.metric, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      color: emphasized ? metric.color.withValues(alpha: 0.055) : null,
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
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
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
                color: emphasized ? metric.color : colors.textPrimary,
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
          if (metric.comparison != null) ...[
            const SizedBox(height: 3),
            Text(
              metric.comparison!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: metric.comparisonPositive
                    ? AppColors.success
                    : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final _DashboardMetric metric;
  final bool emphasized;

  const _MetricRow({required this.metric, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: emphasized ? metric.color.withValues(alpha: 0.055) : null,
        border: emphasized
            ? Border(left: BorderSide(color: metric.color, width: 3))
            : null,
      ),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.context,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                if (metric.comparison != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    metric.comparison!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: metric.comparisonPositive
                          ? AppColors.success
                          : AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
                color: emphasized ? metric.color : colors.textPrimary,
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
  final String? comparison;
  final bool comparisonPositive;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.context,
    required this.assetPath,
    required this.color,
    this.comparison,
    this.comparisonPositive = true,
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
  final dates = comparisonReportingDates(filter, today);
  final currentFrom = DateTime.parse(dates.currentFrom);
  final currentTo = DateTime.parse(dates.currentTo);
  final previousFrom = DateTime.parse(dates.previousFrom);
  final previousTo = DateTime.parse(dates.previousTo);
  if (filter == 'week') {
    return _DashboardPeriods(
      currentFrom: dates.currentFrom,
      currentTo: dates.currentTo,
      previousFrom: dates.previousFrom,
      previousTo: dates.previousTo,
      currentLabel: reportingRangeLabel(currentFrom, currentTo),
      previousLabel: reportingRangeLabel(previousFrom, previousTo),
    );
  }

  if (filter == '6_months') {
    return _DashboardPeriods(
      currentFrom: dates.currentFrom,
      currentTo: dates.currentTo,
      previousFrom: dates.previousFrom,
      previousTo: dates.previousTo,
      currentLabel: reportingRangeLabel(currentFrom, currentTo),
      previousLabel: reportingRangeLabel(previousFrom, previousTo),
    );
  }

  if (filter == 'year') {
    return _DashboardPeriods(
      currentFrom: dates.currentFrom,
      currentTo: dates.currentTo,
      previousFrom: dates.previousFrom,
      previousTo: dates.previousTo,
      currentLabel: reportingRangeLabel(currentFrom, currentTo),
      previousLabel: reportingRangeLabel(previousFrom, previousTo),
    );
  }

  return _DashboardPeriods(
    currentFrom: dates.currentFrom,
    currentTo: dates.currentTo,
    previousFrom: dates.previousFrom,
    previousTo: dates.previousTo,
    currentLabel: reportingRangeLabel(currentFrom, currentTo),
    previousLabel: reportingRangeLabel(previousFrom, previousTo),
  );
}
