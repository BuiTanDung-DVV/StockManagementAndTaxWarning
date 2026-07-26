import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/global_search_delegate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/reporting_period.dart';
import '../../sales/providers/sales_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/presentation/widgets/join_shop_dialog.dart';
import 'widgets/dashboard_widgets.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class _DashboardTimeFilter extends Notifier<String> {
  @override
  String build() => 'month';
  void update(String val) => state = val;
}

final _dashboardTimeFilterProvider =
    NotifierProvider<_DashboardTimeFilter, String>(_DashboardTimeFilter.new);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  void _showJoinShopDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const JoinShopDialog());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final shopState = ref.watch(shopProvider);
    final hasFinance = shopState.isOwner || shopState.hasPermission('finance');
    final hasInventory =
        shopState.isOwner || shopState.hasPermission('inventory');

    final filter = ref.watch(_dashboardTimeFilterProvider);
    final today = DateTime.now();

    String from1, to1, from2, to2;
    String label1, label2;

    if (filter == 'week') {
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      from1 = weekStart.toIso8601String().split('T')[0];
      to1 = today.toIso8601String().split('T')[0];
      final lastWeekStart = weekStart.subtract(const Duration(days: 7));
      from2 = lastWeekStart.toIso8601String().split('T')[0];
      to2 = weekStart
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];
      label1 = 'Tuần này';
      label2 = 'Tuần trước';
    } else if (filter == 'month') {
      final period = currentMonthReportingPeriod(today);
      from1 = period.from;
      to1 = period.to;
      from2 = DateTime(
        today.year,
        today.month - 1,
        1,
      ).toIso8601String().split('T')[0];
      to2 = DateTime(
        today.year,
        today.month,
        0,
      ).toIso8601String().split('T')[0];
      label1 = 'Tháng này';
      label2 = 'Tháng trước';
    } else if (filter == '6_months') {
      from1 = DateTime(
        today.year,
        today.month - 5,
        1,
      ).toIso8601String().split('T')[0];
      to1 = today.toIso8601String().split('T')[0];
      from2 = DateTime(
        today.year,
        today.month - 11,
        1,
      ).toIso8601String().split('T')[0];
      to2 = DateTime(
        today.year,
        today.month - 5,
        0,
      ).toIso8601String().split('T')[0];
      label1 = '6 tháng qua';
      label2 = '6 tháng trước';
    } else {
      // year
      from1 = DateTime(today.year, 1, 1).toIso8601String().split('T')[0];
      to1 = today.toIso8601String().split('T')[0];
      from2 = DateTime(today.year - 1, 1, 1).toIso8601String().split('T')[0];
      to2 = DateTime(today.year - 1, 12, 31).toIso8601String().split('T')[0];
      label1 = 'Năm nay';
      label2 = 'Năm trước';
    }

    final salesAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(salesSummaryProvider((from: from1, to: to1)))
        : null;
    final salesAsync2 = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(salesSummaryProvider((from: from2, to: to2)))
        : null;
    final topProductsAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(topProductsProvider((from: from1, to: to1)))
        : null;
    final cashFlowAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(cashSummaryProvider((from: from1, to: to1)))
        : null;
    final paymentSummaryAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(paymentSummaryProvider((from: from1, to: to1)))
        : null;

    final lowStockAsync = hasInventory && shopState.userShops.isNotEmpty
        ? ref.watch(lowStockProvider)
        : null;
    final inventoryCatAsync = hasInventory && shopState.userShops.isNotEmpty
        ? ref.watch(inventoryCategoriesSummaryProvider)
        : null;
    final recentTransactionsAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(recentTransactionsProvider)
        : null;

    final currentYear = today.year;
    final ytdFrom = '$currentYear-01-01';
    final ytdTo = today.toIso8601String().split('T')[0];
    final ytdSalesAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(salesSummaryProvider((from: ytdFrom, to: ytdTo)))
        : null;
    if (shopState.userShops.isEmpty) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedStore02,
                  color: theme.colorScheme.primary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có cửa hàng nào',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn cần tạo cửa hàng hoặc xin gia nhập vào một cửa hàng.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showJoinShopDialog(context),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Tìm kiếm & Xin gia nhập'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(shopProvider),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text('Tải lại trạng thái'),
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
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            if (hasFinance) {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(topProductsProvider);
              ref.invalidate(cashSummaryProvider);
              ref.invalidate(taxObligationsProvider);
            }
            if (hasInventory) {
              ref.invalidate(lowStockProvider);
              ref.invalidate(inventoryCategoriesSummaryProvider);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPageHeader(
                  title:
                      'Tổng quan ${ref.watch(authProvider).user?['fullName'] ?? 'cửa hàng'}',
                  subtitle:
                      '${shopState.memberType == 'OWNER' ? 'Chủ cửa hàng' : (shopState.memberType ?? 'Nhân viên')} • ${shopState.currentShopName ?? 'Tổng quát'} • $label1',
                  action: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      IconButton.filledTonal(
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          size: 20,
                        ),
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: GlobalSearchDelegate(),
                          );
                        },
                        tooltip: 'Tìm kiếm toàn hệ thống',
                      ),
                      if (shopState.isOwner || shopState.hasPermission('sales'))
                        FilledButton.icon(
                          onPressed: () => context.push('/pos'),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedStore01,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text('Bán hàng'),
                        ),
                    ],
                  ),
                ),
                const UrgentBusinessPulseHeader(),
                const SizedBox(height: 18),

                Text(
                  'Thao tác nhanh',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (shopState.isOwner || shopState.hasPermission('sales'))
                      QuickAction(
                        HugeIcons.strokeRoundedStore01,
                        'Bán hàng',
                        () => context.push('/pos'),
                      ),
                    if (shopState.isOwner ||
                        shopState.hasPermission('products'))
                      QuickAction(
                        HugeIcons.strokeRoundedPackage,
                        'Sản phẩm',
                        () => context.push('/products'),
                      ),
                    if (shopState.isOwner ||
                        shopState.hasPermission('customers'))
                      QuickAction(
                        HugeIcons.strokeRoundedUserGroup,
                        'Khách hàng',
                        () => context.push('/customers'),
                      ),
                    if (shopState.isOwner ||
                        shopState.hasPermission('customers'))
                      QuickAction(
                        HugeIcons.strokeRoundedBookOpen01,
                        'Sổ nợ khách',
                        () => context.push('/customer-debts'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('finance'))
                      QuickAction(
                        HugeIcons.strokeRoundedInvoice01,
                        'Đơn hàng',
                        () => context.push('/sales'),
                      ),
                    if (shopState.isOwner ||
                        shopState.hasPermission('inventory'))
                      QuickAction(
                        HugeIcons.strokeRoundedTask01,
                        'Kiểm kê',
                        () => context.push('/stock-take'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('finance'))
                      QuickAction(
                        HugeIcons.strokeRoundedAnalytics01,
                        'Lãi/lỗ',
                        () => context.push('/profit-loss'),
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // Sales summary cards
                if (hasFinance && salesAsync != null) ...[
                  salesAsync.when(
                    data: (data) {
                      final revenue =
                          num.tryParse(
                            data['totalRevenue']?.toString() ?? '0',
                          )?.toDouble() ??
                          0.0;
                      final orders =
                          data['totalOrders'] ?? data['orderCount'] ?? 0;
                      final avgOrder = orders > 0 ? revenue / orders : 0.0;
                      final grossProfit =
                          num.tryParse(
                            data['grossProfit']?.toString() ?? '0',
                          )?.toDouble() ??
                          0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final crossAxisCount = w > 1300
                                  ? 4
                                  : (w > 900 ? 3 : (w < 360 ? 1 : 2));

                              final cardWidth =
                                  (w - (crossAxisCount - 1) * 16) /
                                  crossAxisCount;

                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: SummaryCard(
                                      'Doanh thu • $label1',
                                      _currFmt.format(revenue),
                                      null,
                                      theme.colorScheme.primary,
                                      assetPath: 'assets/icon/revenue_icon.svg',
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: SummaryCard(
                                      'Đơn hàng • $label1',
                                      '$orders',
                                      null,
                                      AppColors.success,
                                      assetPath: 'assets/icon/orders_icon.svg',
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: SummaryCard(
                                      'Lợi nhuận gộp • $label1',
                                      _currFmt.format(grossProfit),
                                      null,
                                      AppColors.warning,
                                      assetPath: 'assets/icon/profit_icon.svg',
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: SummaryCard(
                                      '${AppStrings.dashboardAvgOrder} • $label1',
                                      _currFmt.format(avgOrder),
                                      null,
                                      AppColors.info,
                                      assetPath: 'assets/icon/orders_icon.svg',
                                    ),
                                  ),
                                  if (hasFinance && cashFlowAsync != null)
                                    SizedBox(
                                      width: cardWidth,
                                      child: cashFlowAsync.when(
                                        data: (data) {
                                          final totalCash =
                                              num.tryParse(
                                                data['cashBalance']
                                                        ?.toString() ??
                                                    '0',
                                              )?.toDouble() ??
                                              0.0;
                                          return SummaryCard(
                                            'Sổ quỹ • ${DateFormat('dd/MM/yyyy').format(today)}',
                                            _currFmt.format(totalCash),
                                            null,
                                            Colors.teal,
                                            assetPath:
                                                'assets/icon/cash_icon.svg',
                                          );
                                        },
                                        loading: () => const AppShimmer(
                                          child: ShimmerBox(
                                            width: double.infinity,
                                            height: 75,
                                            radius: 16,
                                          ),
                                        ),
                                        error: (_, _) => const SummaryCard(
                                          'Sổ quỹ tiền mặt',
                                          '?',
                                          null,
                                          Colors.teal,
                                          assetPath:
                                              'assets/icon/cash_icon.svg',
                                        ),
                                      ),
                                    ),
                                  if (hasFinance && ytdSalesAsync != null)
                                    SizedBox(
                                      width: cardWidth,
                                      child: ytdSalesAsync.when(
                                        data: (ytdData) {
                                          final ytdRevenue =
                                              num.tryParse(
                                                ytdData['totalRevenue']
                                                        ?.toString() ??
                                                    '0',
                                              )?.toDouble() ??
                                              0.0;
                                          return SummaryCard(
                                            'Doanh thu lũy kế (YTD)',
                                            _currFmt.format(ytdRevenue),
                                            null,
                                            Colors.blueAccent,
                                            assetPath:
                                                'assets/icon/revenue_icon.svg',
                                            badgeText: 'Lũy kế',
                                          );
                                        },
                                        loading: () => const AppShimmer(
                                          child: ShimmerBox(
                                            width: double.infinity,
                                            height: 75,
                                            radius: 16,
                                          ),
                                        ),
                                        error: (_, _) => const SummaryCard(
                                          'Doanh thu lũy kế (YTD)',
                                          '?',
                                          null,
                                          Colors.blueAccent,
                                          assetPath:
                                              'assets/icon/revenue_icon.svg',
                                        ),
                                      ),
                                    ),
                                  if (hasInventory && lowStockAsync != null)
                                    SizedBox(
                                      width: cardWidth,
                                      child: lowStockAsync.when(
                                        data: (items) => SummaryCard(
                                          AppStrings.dashboardLowStock,
                                          '${items.length}',
                                          null,
                                          items.isEmpty
                                              ? AppColors.success
                                              : AppColors.danger,
                                          assetPath:
                                              'assets/icon/inventory_icon.svg',
                                          badgeText: items.isEmpty
                                              ? 'An toàn'
                                              : 'Cảnh báo',
                                        ),
                                        loading: () => const AppShimmer(
                                          child: ShimmerBox(
                                            width: double.infinity,
                                            height: 75,
                                            radius: 16,
                                          ),
                                        ),
                                        error: (_, _) => SummaryCard(
                                          AppStrings.dashboardLowStock,
                                          '?',
                                          HugeIcons.strokeRoundedAlert02,
                                          AppColors.danger,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          salesAsync2?.whenOrNull(
                                data: (data2) => ComparisonBarChart(
                                  (data['daily'] as List?) ?? [],
                                  (data2['daily'] as List?) ?? [],
                                  label1,
                                  label2,
                                  filterWidget: TimeFilterBar(
                                    filter,
                                    (v) => ref
                                        .read(
                                          _dashboardTimeFilterProvider.notifier,
                                        )
                                        .update(v),
                                  ),
                                ),
                              ) ??
                              const AppShimmer(
                                child: ShimmerBox(
                                  width: double.infinity,
                                  height: 380,
                                  radius: 24,
                                ),
                              ),
                        ],
                      );
                    },
                    loading: () => const ShimmerDashboard(),
                    error: (e, _) => AppError(
                      message: 'Không thể kết nối server\n$e',
                      onRetry: () {
                        ref.invalidate(salesSummaryProvider);
                        if (hasInventory) ref.invalidate(lowStockProvider);
                      },
                    ),
                  ),
                ] else if (hasInventory && lowStockAsync != null) ...[
                  // If no finance permission but has inventory, only show low stock card aligned nicely
                  Row(
                    children: [
                      Expanded(
                        child: lowStockAsync.when(
                          data: (items) => SummaryCard(
                            AppStrings.dashboardLowStock,
                            '${items.length}',
                            HugeIcons.strokeRoundedAlert02,
                            items.isEmpty
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                          loading: () => SummaryCard(
                            AppStrings.dashboardLowStock,
                            '...',
                            HugeIcons.strokeRoundedAlert02,
                            AppColors.warning,
                          ),
                          error: (_, _) => SummaryCard(
                            AppStrings.dashboardLowStock,
                            '?',
                            HugeIcons.strokeRoundedAlert02,
                            AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],

                if ((hasFinance && topProductsAsync != null) ||
                    (hasInventory && inventoryCatAsync != null))
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 800;

                      final topProductsWidget =
                          (hasFinance && topProductsAsync != null)
                          ? topProductsAsync.when(
                              data: (data) => data.isEmpty
                                  ? EmptyChartPlaceholder(
                                      message:
                                          'Tạo đơn bán đầu tiên để thấy Top sản phẩm',
                                      icon: Icons.leaderboard_rounded,
                                      actionLabel: 'Tạo đơn bán',
                                      onAction: () => context.push('/pos'),
                                    )
                                  : TopProductsChart(data),
                              loading: () => const AppShimmer(
                                child: ShimmerBox(
                                  width: double.infinity,
                                  height: 260,
                                  radius: 24,
                                ),
                              ),
                              error: (e, _) => AppError(
                                message: 'Không thể tải Top sản phẩm\n$e',
                                onRetry: () =>
                                    ref.invalidate(topProductsProvider),
                              ),
                            )
                          : null;

                      final inventoryDonutWidget =
                          (hasInventory && inventoryCatAsync != null)
                          ? inventoryCatAsync.when(
                              data: (data) => data.isEmpty
                                  ? EmptyChartPlaceholder(
                                      message:
                                          'Thêm sản phẩm vào kho để thấy biểu đồ tồn kho',
                                      icon: Icons.pie_chart_outline_rounded,
                                      actionLabel: 'Thêm sản phẩm',
                                      onAction: () =>
                                          context.push('/products/form'),
                                    )
                                  : InventoryDonutChart(data),
                              loading: () => const AppShimmer(
                                child: ShimmerBox(
                                  width: double.infinity,
                                  height: 260,
                                  radius: 24,
                                ),
                              ),
                              error: (e, _) => AppError(
                                message: 'Không thể tải phân bổ tồn kho\n$e',
                                onRetry: () => ref.invalidate(
                                  inventoryCategoriesSummaryProvider,
                                ),
                              ),
                            )
                          : null;

                      if (isDesktop) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (topProductsWidget != null)
                                Expanded(child: topProductsWidget),
                              if (topProductsWidget != null &&
                                  inventoryDonutWidget != null)
                                const SizedBox(width: 16),
                              if (inventoryDonutWidget != null)
                                Expanded(child: inventoryDonutWidget),
                            ],
                          ),
                        );
                      } else {
                        return Column(
                          children: [
                            if (topProductsWidget != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: topProductsWidget,
                              ),
                            if (inventoryDonutWidget != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: inventoryDonutWidget,
                              ),
                          ],
                        );
                      }
                    },
                  ),

                if (hasInventory && lowStockAsync != null)
                  lowStockAsync.when(
                    data: (items) => LowStockTableWidget(items),
                    loading: () => const AppShimmer(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: ShimmerBox(
                          width: double.infinity,
                          height: 200,
                          radius: 24,
                        ),
                      ),
                    ),
                    error: (e, _) => AppInlineError(
                      message: 'Không thể tải cảnh báo tồn kho.',
                      onRetry: () => ref.invalidate(lowStockProvider),
                    ),
                  ),

                if (hasFinance && cashFlowAsync != null) ...[
                  const SizedBox(height: 20),
                  cashFlowAsync.when(
                    data: (data) => CashFlowAreaChart(
                      (data['dailyFlow'] as List?) ?? [],
                      label1,
                    ),
                    loading: () => const AppShimmer(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 260,
                        radius: 24,
                      ),
                    ),
                    error: (e, _) => AppError(
                      message: 'Không thể tải biểu đồ dòng tiền\n$e',
                      onRetry: () => ref.invalidate(cashSummaryProvider),
                    ),
                  ),
                ],

                if (hasFinance && paymentSummaryAsync != null) ...[
                  const SizedBox(height: 20),
                  paymentSummaryAsync.when(
                    data: (data) => PaymentMethodDonutChart(data),
                    loading: () => const AppShimmer(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 280,
                        radius: 24,
                      ),
                    ),
                    error: (e, _) => AppError(
                      message: 'Không thể tải phương thức thanh toán\n$e',
                      onRetry: () => ref.invalidate(paymentSummaryProvider),
                    ),
                  ),
                ],

                if (hasFinance && ytdSalesAsync != null) ...[
                  const SizedBox(height: 20),

                  // Revenue threshold warning (Glow progress meter)
                  ytdSalesAsync.whenOrNull(
                        data: (data) {
                          final revenue =
                              num.tryParse(
                                data['totalRevenue']?.toString() ?? '0',
                              )?.toDouble() ??
                              0.0;
                          if (revenue <= 0) return const SizedBox.shrink();
                          final thresholds = ref
                              .watch(taxConfigProvider)
                              .thresholds;
                          final progress = thresholds
                              .getProgress(revenue)
                              .clamp(0.0, 1.0);
                          final color = thresholds.getColor(revenue);
                          final nextThreshold = thresholds.getNextThreshold(
                            revenue,
                          );
                          return GestureDetector(
                            onTap: () => context.push('/tax-calculator'),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.03),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: HugeIcon(
                                          icon: HugeIcons.strokeRoundedFlag01,
                                          size: 16,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ngưỡng DT: ${thresholds.getTierLabel(revenue)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: c.textMuted,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Stack(
                                          children: [
                                            Container(
                                              height: 8,
                                              width: double.infinity,
                                              color: c.surface,
                                            ),
                                            AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 500,
                                              ),
                                              height: 8,
                                              width:
                                                  constraints.maxWidth *
                                                  progress,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    color,
                                                    color.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: color.withValues(
                                                      alpha: 0.35,
                                                    ),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${thresholds.getObligation(revenue)} • Ngưỡng tiếp: ${_currFmt.format(nextThreshold)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ); // closes GestureDetector
                        },
                      ) ??
                      const SizedBox.shrink(),

                  // Real Tax Obligation Reminder
                  const TaxObligationReminder(),
                ],

                if (hasFinance && recentTransactionsAsync != null)
                  recentTransactionsAsync.when(
                    data: (transactions) => RecentOrdersDataTable(transactions),
                    loading: () => const AppShimmer(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 160,
                        radius: 20,
                      ),
                    ),
                    error: (e, _) => AppInlineError(
                      message: 'Không thể tải đơn hàng gần đây.',
                      onRetry: () => ref.invalidate(recentTransactionsProvider),
                    ),
                  ),

                const SizedBox(height: 28),
                if (hasFinance) const RecentDailyClosingsWidget(),
                const SizedBox(height: 88), // UI Breathing Room Padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}
