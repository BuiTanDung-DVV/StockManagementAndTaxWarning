import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/providers/reporting_period_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/ai_assistant_widget.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/reporting_period_control.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../auth/presentation/widgets/join_shop_dialog.dart';
import '../../finance/providers/finance_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../sales/providers/sales_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../providers/dashboard_action_provider.dart';
import 'widgets/dashboard_insights_widgets.dart';
import 'widgets/dashboard_widgets.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

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

bool dashboardHasSalesActivity({
  required num revenue,
  required num grossProfit,
  required num orderCount,
}) => revenue != 0 || grossProfit != 0 || orderCount != 0;

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
  Future<void> _openPeriodEditor(ReportingPeriodSelection selection) async {
    final launcherWasVisible = ref.read(aiAssistantLauncherVisibleProvider);
    if (launcherWasVisible) {
      ref.read(aiAssistantLauncherVisibleProvider.notifier).hide();
    }
    final updated = await showReportingPeriodEditor(
      context,
      initialSelection: selection,
      today: DateTime.now(),
    );
    if (launcherWasVisible) {
      ref.read(aiAssistantLauncherVisibleProvider.notifier).show();
    }
    if (updated == null || !mounted) return;
    ref
        .read(reportingPeriodNotifierProvider.notifier)
        .setPeriodForTab('dashboard', updated);
  }

  void _showJoinShopDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const JoinShopDialog());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final shopState = ref.watch(shopProvider);
    final hasFinance = shopState.isOwner || shopState.hasPermission('finance');
    final hasSalesInsights = dashboardCanViewSalesInsights(shopState);
    final canViewSales = shopState.isOwner || shopState.hasPermission('sales');
    final hasInventory =
        shopState.isOwner || shopState.hasPermission('inventory');
    final canSell = dashboardCanSell(shopState);
    final compactLayout = dashboardUsesCompactLayout(
      MediaQuery.sizeOf(context).width,
    );
    final periodSelection = ref.watch(tabSelectionProvider('dashboard'));
    final today = DateTime.now();
    final periods = _resolvePeriods(periodSelection, today);

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
    final inventoryCategoriesAsync =
        hasInventory && shopState.userShops.isNotEmpty
        ? ref.watch(inventoryCategoriesSummaryProvider)
        : null;
    final lowStockAsync = hasInventory && shopState.userShops.isNotEmpty
        ? ref.watch(lowStockProvider)
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
        if (canSell)
          compact
              ? AppPrimaryHeaderAction(
                  label: 'Ghi nhận bán hàng',
                  assetPath: AppAssets.orders,
                  heroTag: 'dashboard-sale-action-compact',
                  onPressed: () => context.push('/sales/new'),
                )
              : AppPrimaryPageAction(
                  label: 'Ghi nhận bán hàng',
                  assetPath: AppAssets.orders,
                  onPressed: () => context.push('/sales/new'),
                ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
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
            if (refreshPlan.inventory) {
              ref.invalidate(lowStockProvider);
              ref.invalidate(inventoryCategoriesSummaryProvider);
            }
            ref.invalidate(dashboardActionProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: AppResponsiveContent(
              maxWidth: 1440,
              verticalPadding: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardMasthead(
                    title: shopState.isAllShops
                        ? 'Tổng quan tất cả cửa hàng'
                        : 'Tổng quan cửa hàng',
                    subtitle:
                        'Số liệu đến ${DateFormat('dd/MM/yyyy').format(periods.currentToDate)}',
                    action: headerActions(compact: compactLayout),
                    compactAction: headerActions(compact: true),
                    compact: compactLayout,
                  ),
                  ReportingPeriodControl(
                    selection: periodSelection,
                    currentLabel: periods.currentLabel,
                    comparisonLabel: periods.previousLabel,
                    onQuickPeriodChanged: (value) => ref
                        .read(reportingPeriodNotifierProvider.notifier)
                        .setPeriodForTab(
                          'dashboard',
                          periodSelection.copyWith(
                            periodType: value,
                            anchorDate: DateTime.now(),
                          ),
                        ),
                    onOpenEditor: () => _openPeriodEditor(periodSelection),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                      data: (salesData) {
                        Widget metricStrip(
                          Map<String, dynamic> cashData, {
                          required bool cashAvailable,
                          bool cashHasError = false,
                        }) => _DashboardMetricStrip(
                          metrics: _buildMetrics(
                            salesData: salesData,
                            comparisonSalesData: comparisonAsync?.value,
                            cashData: cashData,
                            periodLabel: periods.currentLabel,
                            previousPeriodLabel: periods.previousLabel,
                            asOf: today,
                            cashAvailable: cashAvailable,
                            hasFinance: hasFinance,
                            canViewSales: canViewSales,
                            cashHasError: cashHasError,
                          ),
                        );

                        if (cashAsync == null) {
                          return metricStrip(
                            const {},
                            cashAvailable: false,
                            cashHasError: false,
                          );
                        }
                        return cashAsync.when(
                          data: (cashData) =>
                              metricStrip(cashData, cashAvailable: true),
                          loading: () => const _MetricStripSkeleton(),
                          error: (_, _) => metricStrip(
                            const {},
                            cashAvailable: false,
                            cashHasError: true,
                          ),
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
                  if (hasFinance && !shopState.isAllShops)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: TaxObligationReminder(),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  _DashboardWorkspace(
                    currentSales: salesAsync,
                    comparisonSales: comparisonAsync,
                    cashSummary: cashAsync,
                    inventoryCategories: inventoryCategoriesAsync,
                    lowStock: lowStockAsync,
                    hasInventory: hasInventory,
                    isAllShops: shopState.isAllShops,
                    recentTransactions: recentTransactionsAsync,
                    topProducts: topProductsAsync,
                    previousTopProducts: previousTopProductsAsync,
                    currentLabel: periods.currentLabel,
                    previousLabel: periods.previousLabel,
                  ),
                  SizedBox(height: compactLayout ? 112 : 96),
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
    bool hasFinance = true,
    bool canViewSales = true,
    bool cashHasError = false,
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
    final numericOrderCount = num.tryParse(orderCount.toString()) ?? 0;
    final hasSalesActivity = dashboardHasSalesActivity(
      revenue: revenue,
      grossProfit: profit,
      orderCount: numericOrderCount,
    );
    final salesContext = hasSalesActivity
        ? periodLabel
        : 'Chưa phát sinh · $periodLabel';

    final rawCash = cashData['cashBalance'];
    final num? parsedCash = rawCash == null
        ? null
        : num.tryParse(rawCash.toString());
    final cashBalance = (hasFinance && cashAvailable && !cashHasError)
        ? parsedCash
        : null;

    final String cashValue;
    final String cashContext;
    final String? cashRoute;

    if (!hasFinance) {
      cashValue = 'Không có quyền';
      cashContext = 'Cần quyền tài chính';
      cashRoute = null;
    } else if (cashHasError) {
      cashValue = 'Chưa tải được';
      cashContext = 'Lỗi tải dữ liệu';
      cashRoute = null;
    } else if (cashBalance != null) {
      cashValue = _currencyFormat.format(cashBalance);
      cashContext = 'Tại ${DateFormat('dd/MM/yyyy').format(asOf)}';
      cashRoute = '/transactions';
    } else {
      cashValue = 'Chưa có số liệu';
      cashContext = 'Chưa có số dư';
      cashRoute = null;
    }

    return [
      _DashboardMetric(
        label: 'Doanh thu thuần',
        value: _currencyFormat.format(revenue),
        context: salesContext,
        assetPath: AppAssets.revenue,
        color: AppColors.primary,
        comparison: hasSalesActivity
            ? _growthComparison(revenue, previousRevenue, previousPeriodLabel)
            : null,
        comparisonPositive: revenue >= previousRevenue,
        route: canViewSales ? '/sales' : null,
      ),
      _DashboardMetric(
        label: 'Lợi nhuận gộp',
        value: _currencyFormat.format(profit),
        context: salesContext,
        assetPath: AppAssets.profit,
        color: profit < 0 ? AppColors.danger : AppColors.success,
        comparison: hasSalesActivity
            ? _growthComparison(profit, previousProfit, previousPeriodLabel)
            : null,
        comparisonPositive: profit >= previousProfit,
        route: hasFinance ? '/profit-loss' : null,
      ),
      _DashboardMetric(
        label: 'Số dư quỹ',
        value: cashValue,
        context: cashContext,
        assetPath: AppAssets.cash,
        color: Theme.of(context).colorScheme.primary,
        route: cashRoute,
      ),
      _DashboardMetric(
        label: 'Đơn hàng',
        value: '$orderCount',
        context: salesContext,
        assetPath: AppAssets.orders,
        color: Theme.of(context).colorScheme.primary,
        comparison: hasSalesActivity
            ? _growthComparison(
                numericOrderCount,
                previousOrderCount,
                previousPeriodLabel,
              )
            : null,
        comparisonPositive: numericOrderCount >= previousOrderCount,
        route: canViewSales ? '/sales' : null,
      ),
    ];
  }

  _MetricComparison? _growthComparison(
    num current,
    num previous,
    String previousLabel,
  ) {
    if (previous <= 0) return null;
    final change = ((current - previous) / previous) * 100;
    if (change.abs() < 0.05) {
      return _MetricComparison(
        label: '— 0,0% so với kỳ trước',
        semanticLabel: 'Không đổi so với kỳ $previousLabel',
        isNeutral: true,
      );
    }
    final direction = change > 0 ? 'Tăng' : 'Giảm';
    final symbol = change > 0 ? '▲' : '▼';
    final formattedChange = NumberFormat('0.0', 'vi_VN').format(change.abs());
    return _MetricComparison(
      label: '$symbol $formattedChange% so với kỳ trước',
      semanticLabel: '$direction $formattedChange% so với kỳ $previousLabel',
      isNeutral: false,
    );
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
                        assetPath: AppAssets.parcelBox,
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

class _DashboardMasthead extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget action;
  final Widget compactAction;
  final bool compact;

  const _DashboardMasthead({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.compactAction,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    final titleWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: compact ? 22 : 26,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: compact ? 12.5 : 13.5,
            height: 1.35,
            fontWeight: FontWeight.w400,
            color: colors.textSecondary,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleWidget,
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: compact ? compactAction : action,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: AppSpacing.md),
              compact ? compactAction : action,
            ],
          );
        },
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

class _DashboardEqualHeightRow extends MultiChildRenderObjectWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final double? rightWidth;
  final Object? layoutRevision;

  _DashboardEqualHeightRow({
    super.key,
    required this.left,
    required this.right,
    this.spacing = AppSpacing.lg,
    this.rightWidth,
    this.layoutRevision,
  }) : super(children: [left, right]);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDashboardEqualHeightRow(
      spacing: spacing,
      rightWidth: rightWidth,
      layoutRevision: layoutRevision,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDashboardEqualHeightRow renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..rightWidth = rightWidth
      ..layoutRevision = layoutRevision;
  }
}

class _EqualHeightParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderDashboardEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualHeightParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualHeightParentData> {
  double _spacing;
  double? _rightWidth;
  Object? _layoutRevision;

  _RenderDashboardEqualHeightRow({
    required double spacing,
    double? rightWidth,
    Object? layoutRevision,
  }) : _spacing = spacing,
       _rightWidth = rightWidth,
       _layoutRevision = layoutRevision;

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  double? get rightWidth => _rightWidth;
  set rightWidth(double? value) {
    if (_rightWidth != value) {
      _rightWidth = value;
      markNeedsLayout();
    }
  }

  Object? get layoutRevision => _layoutRevision;
  set layoutRevision(Object? value) {
    if (_layoutRevision != value) {
      _layoutRevision = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _EqualHeightParentData) {
      child.parentData = _EqualHeightParentData();
    }
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    final leftChild = firstChild!;
    final rightChild = childAfter(leftChild);

    if (rightChild == null) {
      leftChild.layout(constraints, parentUsesSize: true);
      size = leftChild.size;
      return;
    }

    final double totalWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : 1000.0;
    final double availableWidth = math.max(0.0, totalWidth - _spacing);

    final double allocatedRightWidth;
    final double allocatedLeftWidth;

    if (_rightWidth != null) {
      allocatedRightWidth = math.min(_rightWidth!, availableWidth);
      allocatedLeftWidth = math.max(0.0, availableWidth - allocatedRightWidth);
    } else {
      allocatedLeftWidth = (availableWidth / 2).floorToDouble();
      allocatedRightWidth = availableWidth - allocatedLeftWidth;
    }

    // Pass 1: Natural layout at allocated widths, unconstrained height
    leftChild.layout(
      BoxConstraints(
        minWidth: allocatedLeftWidth,
        maxWidth: allocatedLeftWidth,
        minHeight: 0,
        maxHeight: double.infinity,
      ),
      parentUsesSize: true,
    );

    rightChild.layout(
      BoxConstraints(
        minWidth: allocatedRightWidth,
        maxWidth: allocatedRightWidth,
        minHeight: 0,
        maxHeight: double.infinity,
      ),
      parentUsesSize: true,
    );

    final double tallestHeight = math.max(
      leftChild.size.height,
      rightChild.size.height,
    );

    // Pass 2: Relayout both children with tight stretch constraints
    // This forces both children to be exactly the same height
    leftChild.layout(
      BoxConstraints(
        minWidth: allocatedLeftWidth,
        maxWidth: allocatedLeftWidth,
        minHeight: tallestHeight,
        maxHeight: tallestHeight,
      ),
      parentUsesSize: true,
    );

    rightChild.layout(
      BoxConstraints(
        minWidth: allocatedRightWidth,
        maxWidth: allocatedRightWidth,
        minHeight: tallestHeight,
        maxHeight: tallestHeight,
      ),
      parentUsesSize: true,
    );

    final leftParentData = leftChild.parentData! as _EqualHeightParentData;
    leftParentData.offset = Offset.zero;

    final rightParentData = rightChild.parentData! as _EqualHeightParentData;
    rightParentData.offset = Offset(allocatedLeftWidth + _spacing, 0);

    size = constraints.constrain(Size(totalWidth, tallestHeight));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (firstChild == null) return 0;
    final left = firstChild!;
    final right = childAfter(left);
    if (right == null) return left.getMinIntrinsicWidth(height);
    return left.getMinIntrinsicWidth(height) +
        _spacing +
        right.getMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (firstChild == null) return 0;
    final left = firstChild!;
    final right = childAfter(left);
    if (right == null) return left.getMaxIntrinsicWidth(height);
    return left.getMaxIntrinsicWidth(height) +
        _spacing +
        right.getMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (firstChild == null) return 0;
    final left = firstChild!;
    final right = childAfter(left);
    if (right == null) return left.getMinIntrinsicHeight(width);
    final colWidth = math.max(0.0, (width - _spacing) / 2);
    return math.max(
      left.getMinIntrinsicHeight(colWidth),
      right.getMinIntrinsicHeight(colWidth),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (firstChild == null) return 0;
    final left = firstChild!;
    final right = childAfter(left);
    if (right == null) return left.getMaxIntrinsicHeight(width);
    final colWidth = math.max(0.0, (width - _spacing) / 2);
    return math.max(
      left.getMaxIntrinsicHeight(colWidth),
      right.getMaxIntrinsicHeight(colWidth),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

class _DashboardWorkspace extends ConsumerWidget {
  final AsyncValue<Map<String, dynamic>>? currentSales;
  final AsyncValue<Map<String, dynamic>>? comparisonSales;
  final AsyncValue<Map<String, dynamic>>? cashSummary;
  final AsyncValue<List<dynamic>>? inventoryCategories;
  final AsyncValue<List<dynamic>>? lowStock;
  final bool hasInventory;
  final bool isAllShops;
  final AsyncValue<List<dynamic>>? recentTransactions;
  final AsyncValue<List<dynamic>>? topProducts;
  final AsyncValue<List<dynamic>>? previousTopProducts;
  final String currentLabel;
  final String previousLabel;

  const _DashboardWorkspace({
    required this.currentSales,
    required this.comparisonSales,
    required this.cashSummary,
    required this.inventoryCategories,
    required this.lowStock,
    required this.hasInventory,
    required this.isAllShops,
    required this.recentTransactions,
    required this.topProducts,
    required this.previousTopProducts,
    required this.currentLabel,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(dashboardActionProvider);

    final chart = KeyedSubtree(
      key: const Key('dashboard-card-chart'),
      child: _DashboardChart(
        currentSales: currentSales,
        comparisonSales: comparisonSales,
        currentLabel: currentLabel,
        previousLabel: previousLabel,
      ),
    );
    final priorities = const KeyedSubtree(
      key: Key('dashboard-card-priority'),
      child: DashboardPriorityList(),
    );

    final salesPerformance = KeyedSubtree(
      key: const Key('dashboard-card-sales'),
      child: DashboardSalesPerformanceCard(
        currentSales: currentSales,
        comparisonSales: comparisonSales,
        currentLabel: currentLabel,
        previousLabel: previousLabel,
        onRetry: () => ref.invalidate(salesSummaryProvider),
      ),
    );

    final cashFlow = KeyedSubtree(
      key: const Key('dashboard-card-cash'),
      child: DashboardCashFlowCard(
        cashAsync: cashSummary,
        currentLabel: currentLabel,
        onRetry: () => ref.invalidate(cashSummaryProvider),
      ),
    );

    Widget? inventoryCategoriesCard;
    Widget? lowStockCard;
    if (hasInventory) {
      inventoryCategoriesCard = KeyedSubtree(
        key: const Key('dashboard-card-inventory'),
        child: DashboardInventoryCategoryCard(
          categoriesAsync: inventoryCategories,
          onRetry: () => ref.invalidate(inventoryCategoriesSummaryProvider),
        ),
      );
      lowStockCard = KeyedSubtree(
        key: const Key('dashboard-card-low-stock'),
        child: DashboardLowStockCard(
          lowStockAsync: lowStock,
          isAllShops: isAllShops,
          onRetry: () => ref.invalidate(lowStockProvider),
        ),
      );
    }

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
        if (currentSales == null && hasInventory) {
          if (constraints.maxWidth < 960) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                priorities,
                if (lowStockCard != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  lowStockCard,
                ],
                if (inventoryCategoriesCard != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  inventoryCategoriesCard,
                ],
                products,
                orders,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lowStockCard != null)
                _DashboardEqualHeightRow(
                  key: const Key('dashboard-row-warehouse-priority-stock'),
                  spacing: AppSpacing.lg,
                  layoutRevision: actionState,
                  left: const KeyedSubtree(
                    key: Key('dashboard-card-priority'),
                    child: DashboardPriorityList(fixedHeight: false),
                  ),
                  right: lowStockCard,
                )
              else
                priorities,
              if (inventoryCategoriesCard != null) ...[
                const SizedBox(height: AppSpacing.lg),
                inventoryCategoriesCard,
              ],
              products,
              orders,
            ],
          );
        }

        if (constraints.maxWidth < 960) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              chart,
              const SizedBox(height: AppSpacing.lg),
              priorities,
              const SizedBox(height: AppSpacing.lg),
              salesPerformance,
              const SizedBox(height: AppSpacing.lg),
              cashFlow,
              if (hasInventory &&
                  inventoryCategoriesCard != null &&
                  lowStockCard != null) ...[
                const SizedBox(height: AppSpacing.lg),
                inventoryCategoriesCard,
                const SizedBox(height: AppSpacing.lg),
                lowStockCard,
              ],
              products,
              orders,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DashboardEqualHeightRow(
              key: const Key('dashboard-row-chart-priority'),
              spacing: AppSpacing.lg,
              rightWidth: 360,
              layoutRevision: actionState,
              left: chart,
              right: const KeyedSubtree(
                key: Key('dashboard-card-priority'),
                child: DashboardPriorityList(fixedHeight: false),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DashboardEqualHeightRow(
              key: const Key('dashboard-row-sales-cash'),
              spacing: AppSpacing.lg,
              left: salesPerformance,
              right: cashFlow,
            ),
            if (hasInventory &&
                inventoryCategoriesCard != null &&
                lowStockCard != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _DashboardEqualHeightRow(
                key: const Key('dashboard-row-inventory-stock'),
                spacing: AppSpacing.lg,
                left: inventoryCategoriesCard,
                right: lowStockCard,
              ),
            ],
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
    final textScaler = MediaQuery.textScalerOf(context);
    final mobileItemHeight = textScaler.scale(78.0);
    final mobileHeaderBase = textScaler.scale(140.0);
    final chartHeight = products.isEmpty
        ? 220.0
        : mobile
        ? (mobileHeaderBase + products.length * mobileItemHeight).toDouble()
        : (136 + products.length * 55).clamp(324, 686).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: ChartCard(
        title: isPreviousPeriodFallback
            ? 'Top sản phẩm kỳ trước'
            : 'Top sản phẩm bán chạy',
        subtitle: products.isNotEmpty
            ? 'Xếp hạng các sản phẩm có doanh thu cao nhất trong kỳ.'
            : null,
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
              physics: const ClampingScrollPhysics(),
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
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = textScaler.scale(77.0).clamp(77.0, 140.0);

    return SizedBox(
      height: rowHeight,
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

  const _DashboardChart({
    required this.currentSales,
    required this.comparisonSales,
    required this.currentLabel,
    required this.previousLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    Widget cardWrapper(Widget child) {
      return Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: colors.divider),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      );
    }

    if (currentSales == null || comparisonSales == null) {
      return cardWrapper(
        const AppEmpty(
          visual: AppEmptyVisual.finance,
          message: 'Không có quyền xem doanh thu',
          subtitle: 'Các ưu tiên kho và công nợ vẫn được hiển thị theo quyền.',
        ),
      );
    }

    return currentSales!.when(
      data: (current) => comparisonSales!.when(
        data: (previous) => ComparisonBarChart(
          (current['daily'] as List?) ?? const [],
          (previous['daily'] as List?) ?? const [],
          currentLabel,
          previousLabel,
        ),
        loading: () => const _ChartSkeleton(),
        error: (_, _) => cardWrapper(
          const AppInlineError(message: 'Không thể tải dữ liệu so sánh.'),
        ),
      ),
      loading: () => const _ChartSkeleton(),
      error: (_, _) => cardWrapper(
        const AppInlineError(message: 'Không thể tải biểu đồ doanh thu.'),
      ),
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
        height: 440,
        radius: AppRadius.card,
      ),
    );
  }
}

class _MetricSurfaceStyle {
  final Color background;
  final Color border;
  final Color iconBg;
  final Color iconColor;

  const _MetricSurfaceStyle({
    required this.background,
    required this.border,
    required this.iconBg,
    required this.iconColor,
  });
}

_MetricSurfaceStyle _getMetricSurface(String label, AppThemeColors colors) {
  if (label.contains('Doanh thu')) {
    return _MetricSurfaceStyle(
      background: colors.card,
      border: colors.divider,
      iconBg: AppColors.primary.withValues(alpha: 0.1),
      iconColor: AppColors.primary,
    );
  } else if (label.contains('Lợi nhuận')) {
    return _MetricSurfaceStyle(
      background: colors.card,
      border: colors.divider,
      iconBg: AppColors.success.withValues(alpha: 0.1),
      iconColor: AppColors.success,
    );
  } else if (label.contains('quỹ') || label.contains('tiền')) {
    return _MetricSurfaceStyle(
      background: colors.card,
      border: colors.divider,
      iconBg: AppColors.info.withValues(alpha: 0.1),
      iconColor: AppColors.info,
    );
  } else {
    return _MetricSurfaceStyle(
      background: colors.card,
      border: colors.divider,
      iconBg: colors.cardAlt,
      iconColor: colors.textSecondary,
    );
  }
}

class _DashboardMetricStrip extends StatelessWidget {
  final List<_DashboardMetric> metrics;

  const _DashboardMetricStrip({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = AppThemeColors.of(context);
        final isDesktop = constraints.maxWidth >= 960;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 960;

        if (isDesktop) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < metrics.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: i == 0 ? 28 : 24,
                    child: _PastelMetricCard(
                      metric: metrics[i],
                      surface: _getMetricSurface(metrics[i].label, colors),
                      isPrimary: i == 0,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        if (isTablet) {
          final tabletRows = <Widget>[];
          for (var i = 0; i < metrics.length; i += 2) {
            if (i > 0) {
              tabletRows.add(const SizedBox(height: AppSpacing.md));
            }
            final first = metrics[i];
            final hasSecond = i + 1 < metrics.length;
            final second = hasSecond ? metrics[i + 1] : null;

            tabletRows.add(
              _DashboardEqualHeightRow(
                key: Key('dashboard-tablet-kpi-row-${i ~/ 2}'),
                spacing: AppSpacing.md,
                left: _PastelMetricCard(
                  metric: first,
                  surface: _getMetricSurface(first.label, colors),
                  isPrimary: false,
                ),
                right: second != null
                    ? _PastelMetricCard(
                        metric: second,
                        surface: _getMetricSurface(second.label, colors),
                        isPrimary: false,
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: tabletRows,
          );
        }

        // Mobile layout:
        final textScaler = MediaQuery.textScalerOf(context);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isLargeText = textScaler.scale(1.0) > 1.2;
        final isNarrowScreen = screenWidth < 340 || constraints.maxWidth < 300;

        // Fallback: compact full-width row fallback only for textScaler > 1.2 (150% text)
        // or very narrow screens (< 340px); normal 390px is 2x2.
        if (isLargeText || isNarrowScreen || metrics.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _CompactMetricRow(metric: metrics[i]),
              ],
            ],
          );
        }

        // Compact 2x2 grid layout on neutral white surfaces with subtle dividers
        final rows = <Widget>[];
        for (var i = 0; i < metrics.length; i += 2) {
          if (i > 0) {
            rows.add(const SizedBox(height: 8));
          }
          final first = metrics[i];
          final hasSecond = i + 1 < metrics.length;
          final second = hasSecond ? metrics[i + 1] : null;

          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _MobileMetricCard(metric: first)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: second != null
                        ? _MobileMetricCard(metric: second)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

class _PastelMetricCard extends StatelessWidget {
  final _DashboardMetric metric;
  final _MetricSurfaceStyle surface;
  final bool isPrimary;

  const _PastelMetricCard({
    required this.metric,
    required this.surface,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final titleSlotHeight = textScaler.scale(26.0);
    final amountSlotHeight = textScaler.scale(32.0);

    return Container(
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: surface.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: metric.route == null ? null : () => context.go(metric.route!),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: titleSlotHeight),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: surface.iconBg,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: AppAssetIcon(
                          assetPath: metric.assetPath,
                          size: 14,
                          color: surface.iconColor,
                          semanticLabel: metric.label,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          metric.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: amountSlotHeight),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metric.value,
                      maxLines: 1,
                      style: GoogleFonts.manrope(
                        fontSize: isPrimary ? 24 : 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Tooltip(
                  message: metric.context,
                  child: Text(
                    metric.context,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (metric.comparison != null) ...[
                  const SizedBox(height: 4),
                  _ComparisonBadge(
                    comparison: metric.comparison!,
                    isPositive: metric.comparisonPositive,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileMetricCard extends StatelessWidget {
  final _DashboardMetric metric;

  const _MobileMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Semantics(
      label: '${metric.label}: ${metric.value}, ${metric.context}',
      container: true,
      child: Tooltip(
        message:
            '${metric.label}: ${metric.value}${metric.context.isNotEmpty ? ' (${metric.context})' : ''}',
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: metric.route == null
                  ? null
                  : () => context.go(metric.route!),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: AppAssetIcon(
                            assetPath: metric.assetPath,
                            size: 12,
                            color: AppColors.primary,
                            semanticLabel: metric.label,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            metric.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 22),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          metric.value,
                          maxLines: 1,
                          style: AppTheme.tabularStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildFooter(context, colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppThemeColors colors) {
    if (metric.comparison != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: _ComparisonBadge(
          comparison: metric.comparison!,
          isPositive: metric.comparisonPositive,
        ),
      );
    }

    if (metric.context.startsWith('Tại ')) {
      return Tooltip(
        message: metric.context,
        child: Text(
          metric.context,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (metric.context.startsWith('Chưa phát sinh')) {
      return Tooltip(
        message: metric.context,
        child: Text(
          'Chưa phát sinh',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return const SizedBox(height: 16);
  }
}

class _CompactMetricRow extends StatelessWidget {
  final _DashboardMetric metric;

  const _CompactMetricRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Semantics(
      label: '${metric.label}: ${metric.value}, ${metric.context}',
      container: true,
      child: Tooltip(
        message:
            '${metric.label}: ${metric.value}${metric.context.isNotEmpty ? ' (${metric.context})' : ''}',
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: metric.route == null
                  ? null
                  : () => context.go(metric.route!),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: AppAssetIcon(
                            assetPath: metric.assetPath,
                            size: 12,
                            color: AppColors.primary,
                            semanticLabel: metric.label,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            metric.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        if (metric.comparison != null) ...[
                          const SizedBox(width: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _ComparisonBadge(
                              comparison: metric.comparison!,
                              isPositive: metric.comparisonPositive,
                            ),
                          ),
                        ] else if (metric.context.startsWith('Tại ')) ...[
                          const SizedBox(width: 6),
                          Text(
                            metric.context,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        metric.value,
                        maxLines: 1,
                        style: AppTheme.tabularStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonBadge extends StatelessWidget {
  final _MetricComparison comparison;
  final bool isPositive;

  const _ComparisonBadge({required this.comparison, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final Color bg;
    final Color textColor;
    if (comparison.isNeutral) {
      bg = colors.cardAlt;
      textColor = colors.textMuted;
    } else if (isPositive) {
      bg = AppColors.success.withValues(alpha: 0.12);
      textColor = AppColors.success;
    } else {
      bg = AppColors.danger.withValues(alpha: 0.12);
      textColor = AppColors.danger;
    }

    return Tooltip(
      message: comparison.semanticLabel,
      child: Semantics(
        label: comparison.semanticLabel,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            comparison.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ),
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
    final isCompact = MediaQuery.sizeOf(context).width < 700;
    return AppShimmer(
      child: ShimmerBox(
        width: double.infinity,
        height: isCompact ? 210 : 116,
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
  final _MetricComparison? comparison;
  final bool comparisonPositive;
  final String? route;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.context,
    required this.assetPath,
    required this.color,
    this.comparison,
    this.comparisonPositive = true,
    this.route,
  });
}

class _MetricComparison {
  final String label;
  final String semanticLabel;
  final bool isNeutral;

  const _MetricComparison({
    required this.label,
    required this.semanticLabel,
    this.isNeutral = false,
  });
}

class _DashboardPeriods {
  final String currentFrom;
  final String currentTo;
  final String previousFrom;
  final String previousTo;
  final String currentLabel;
  final String previousLabel;
  final DateTime currentToDate;

  const _DashboardPeriods({
    required this.currentFrom,
    required this.currentTo,
    required this.previousFrom,
    required this.previousTo,
    required this.currentLabel,
    required this.previousLabel,
    required this.currentToDate,
  });
}

_DashboardPeriods _resolvePeriods(
  ReportingPeriodSelection selection,
  DateTime today,
) {
  final dates = resolveReportingPeriods(selection, today: today);
  return _DashboardPeriods(
    currentFrom: dates.currentFrom.toIso8601String().split('T').first,
    currentTo: dates.currentTo.toIso8601String().split('T').first,
    previousFrom: dates.comparisonFrom.toIso8601String().split('T').first,
    previousTo: dates.comparisonTo.toIso8601String().split('T').first,
    currentLabel: reportingRangeLabel(dates.currentFrom, dates.currentTo),
    previousLabel: reportingRangeLabel(
      dates.comparisonFrom,
      dates.comparisonTo,
    ),
    currentToDate: dates.currentTo,
  );
}
