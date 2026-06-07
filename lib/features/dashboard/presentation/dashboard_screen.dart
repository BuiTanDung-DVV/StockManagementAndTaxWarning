import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/chart_widgets.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/global_search_delegate.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/providers/sales_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'widgets/dashboard_widgets.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'â‚«',
  decimalDigits: 0,
);

class _DashboardTimeFilter extends Notifier<String> {
  @override
  String build() => 'month';
  void update(String val) => state = val;
}

final _dashboardTimeFilterProvider =
    NotifierProvider<_DashboardTimeFilter, String>(_DashboardTimeFilter.new);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      label1 = 'Tuáº§n nÃ y';
      label2 = 'Tuáº§n trÆ°á»›c';
    } else {
      // month
      from1 = DateTime(
        today.year,
        today.month,
        1,
      ).toIso8601String().split('T')[0];
      to1 = today.toIso8601String().split('T')[0];
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
      label1 = 'ThÃ¡ng nÃ y';
      label2 = 'ThÃ¡ng trÆ°á»›c';
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

    final lowStockAsync = hasInventory && shopState.userShops.isNotEmpty
        ? ref.watch(lowStockProvider)
        : null;
    final inventoryCatAsync = hasInventory && shopState.userShops.isNotEmpty
        ? ref.watch(inventoryCategoriesSummaryProvider)
        : null;
    final recentTransactionsAsync = hasFinance && shopState.userShops.isNotEmpty
        ? ref.watch(recentTransactionsProvider)
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
                  'ChÆ°a cÃ³ cá»­a hÃ ng nÃ o',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Báº¡n cáº§n táº¡o cá»­a hÃ ng hoáº·c chá» chá»§ shop duyá»‡t yÃªu cáº§u tham gia.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: c.textSecondary,
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
                  label: const Text('Táº£i láº¡i tráº¡ng thÃ¡i'),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 32, top: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chÃ o, ${ref.watch(authProvider).user?['fullName'] ?? 'Chá»§ shop'}',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: c.textPrimary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tá»•ng quan hÃ´m nay',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      featureGuideButton(context, 'dashboard'),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.divider, width: 1),
                        ),
                        child: IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedSearch01,
                            color: c.textPrimary,
                            size: 22,
                          ),
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: GlobalSearchDelegate(),
                            );
                          },
                          tooltip: 'Tìm kiếm toàn cầu',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.divider, width: 1),
                        ),
                        child: IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedNotification03,
                            color: c.textPrimary,
                            size: 22,
                          ),
                          onPressed: () => context.push('/notifications'),
                          tooltip: 'Thông báo',
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Actions Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      if (shopState.isOwner || shopState.hasPermission('pos'))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: QuickAction(
                            HugeIcons.strokeRoundedStore01,
                            'BÃ¡n hÃ ng',
                            () => context.push('/pos'),
                          ),
                        ),
                      if (shopState.isOwner ||
                          shopState.hasPermission('products'))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: QuickAction(
                            HugeIcons.strokeRoundedPackage,
                            'Sáº£n pháº©m',
                            () => context.push('/products'),
                          ),
                        ),
                      if (shopState.isOwner ||
                          shopState.hasPermission('customers'))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: QuickAction(
                            HugeIcons.strokeRoundedUserGroup,
                            'KhÃ¡ch hÃ ng',
                            () => context.push('/customers'),
                          ),
                        ),
                      if (shopState.isOwner ||
                          shopState.hasPermission('finance'))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: QuickAction(
                            HugeIcons.strokeRoundedInvoice01,
                            'ÄÆ¡n hÃ ng',
                            () => context.push('/sales'),
                          ),
                        ),
                      if (shopState.isOwner ||
                          shopState.hasPermission('inventory'))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: QuickAction(
                            HugeIcons.strokeRoundedTask01,
                            'Kiá»ƒm kÃª',
                            () => context.push('/stock-take'),
                          ),
                        ),
                      if (shopState.isOwner ||
                          shopState.hasPermission('finance'))
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: QuickAction(
                            HugeIcons.strokeRoundedAnalytics01,
                            'LÃ£i/Lá»—',
                            () => context.push('/profit-loss'),
                          ),
                        ),
                    ],
                  ),
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
                          Row(
                            children: [
                              Expanded(
                                child: SummaryCard(
                                  'Doanh thu',
                                  _currFmt.format(revenue),
                                  HugeIcons.strokeRoundedChartIncrease,
                                  theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SummaryCard(
                                  'ÄÆ¡n hÃ ng',
                                  '$orders',
                                  HugeIcons.strokeRoundedInvoice03,
                                  AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SummaryCard(
                                  'Lá»£i nhuáº­n gá»™p',
                                  _currFmt.format(grossProfit),
                                  HugeIcons.strokeRoundedMoney04,
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SummaryCard(
                                  AppStrings.dashboardAvgOrder,
                                  _currFmt.format(avgOrder),
                                  HugeIcons.strokeRoundedAnalytics01,
                                  AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          if (hasInventory && lowStockAsync != null) ...[
                            const SizedBox(height: 12),
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
                          const SizedBox(height: 16),
                          TimeFilterBar(
                            filter,
                            (v) => ref
                                .read(_dashboardTimeFilterProvider.notifier)
                                .update(v),
                          ),
                          salesAsync2?.whenOrNull(
                                data: (data2) => ComparisonBarChart(
                                  (data['daily'] as List?) ?? [],
                                  (data2['daily'] as List?) ?? [],
                                  label1,
                                  label2,
                                ),
                              ) ??
                              const ShimmerDashboard(),
                        ],
                      );
                    },
                    loading: () => const ShimmerDashboard(),
                    error: (e, _) => AppError(
                      message: 'KhÃ´ng thá»ƒ káº¿t ná»‘i server\n$e',
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

                if (hasFinance && topProductsAsync != null) ...[
                  const SizedBox(height: 20),
                  topProductsAsync.when(
                    data: (data) => data.isEmpty
                        ? EmptyChartPlaceholder(
                            message:
                                'Táº¡o Ä‘Æ¡n bÃ¡n Ä‘áº§u tiÃªn Ä‘á»ƒ tháº¥y Top sáº£n pháº©m',
                            icon: Icons.leaderboard_rounded,
                            actionLabel: 'Táº¡o Ä‘Æ¡n bÃ¡n',
                            onAction: () => context.push('/pos'),
                          )
                        : TopProductsChart(data),
                    loading: () => const ShimmerDashboard(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],

                if (hasInventory && inventoryCatAsync != null) ...[
                  const SizedBox(height: 20),
                  inventoryCatAsync.when(
                    data: (data) => data.isEmpty
                        ? EmptyChartPlaceholder(
                            message:
                                'ThÃªm sáº£n pháº©m vÃ o kho Ä‘á»ƒ tháº¥y biá»ƒu Ä‘á»“ tá»“n kho',
                            icon: Icons.pie_chart_outline_rounded,
                            actionLabel: 'ThÃªm sáº£n pháº©m',
                            onAction: () => context.push('/products/form'),
                          )
                        : InventoryDonutChart(data),
                    loading: () => const ShimmerDashboard(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],

                if (hasFinance && cashFlowAsync != null) ...[
                  const SizedBox(height: 20),
                  cashFlowAsync.when(
                    data: (data) => CashFlowAreaChart(
                      (data['dailyFlow'] as List?) ?? [],
                      label1,
                    ),
                    loading: () => const ShimmerDashboard(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],

                if (hasFinance && salesAsync != null) ...[
                  const SizedBox(height: 20),

                  // Revenue threshold warning (Glow progress meter)
                  salesAsync.whenOrNull(
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
                                        'NgÆ°á»¡ng DT: ${thresholds.getTierLabel(revenue)}',
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
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Stack(
                                      children: [
                                        Container(height: 8, color: c.surface),
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                          height: 8,
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.8 *
                                              progress,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                color,
                                                color.withValues(alpha: 0.7),
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
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${thresholds.getObligation(revenue)} â€¢ NgÆ°á»¡ng tiáº¿p: ${_currFmt.format(nextThreshold)}',
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

                if (hasFinance && recentTransactionsAsync != null) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Giao dá»‹ch gáº§n Ä‘Ã¢y',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  recentTransactionsAsync.when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return const Center(
                          child: Text('ChÆ°a cÃ³ giao dá»‹ch nÃ o'),
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: c.divider, width: 1),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: c.divider),
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            final id = t['id'];
                            final total =
                                num.tryParse(
                                  t['totalAmount']?.toString() ?? '0',
                                )?.toDouble() ??
                                0.0;
                            final dateStr = t['orderDate'] ?? '';
                            final date = DateTime.tryParse(dateStr);
                            final formattedDate = date != null
                                ? DateFormat('dd/MM HH:mm').format(date)
                                : '';
                            final customerName =
                                t['customer']?['name'] ?? 'KhÃ¡ch láº»';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedInvoice03,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                customerName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                'HD-$id â€¢ $formattedDate',
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                _currFmt.format(total),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                  fontSize: 16,
                                ),
                              ),
                              onTap: () => context.push('/sales/$id'),
                            );
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, trace) => Center(
                      child: Text(
                        'Lá»—i táº£i GD: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                // Low stock warnings
                if (hasInventory && lowStockAsync != null)
                  lowStockAsync.when(
                    data: (items) {
                      if (items.isEmpty) return const SizedBox.shrink();
                      final display = items.take(5).toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'DÆ°á»›i Ä‘á»‹nh má»©c tá»‘i thiá»ƒu',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => context.push('/inventory'),
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Xem táº¥t cáº£',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...display.map(
                            (item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: c.divider.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['product']?['name'] ??
                                          item['productName'] ??
                                          'Sáº£n pháº©m',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Tá»“n: ${item['currentQuantity'] ?? item['quantity'] ?? 0}',
                                      style: const TextStyle(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
