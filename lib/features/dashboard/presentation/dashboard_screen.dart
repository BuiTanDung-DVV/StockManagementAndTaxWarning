import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../sales/providers/sales_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../../auth/providers/auth_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
final _today = DateTime.now();
final _from = DateTime(
  _today.year,
  _today.month,
  1,
).toIso8601String().split('T')[0];
final _to = _today.toIso8601String().split('T')[0];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final shopState = ref.watch(shopProvider);
    final hasFinance = shopState.isOwner || shopState.hasPermission('finance');
    final hasInventory = shopState.isOwner || shopState.hasPermission('inventory');

    final salesAsync = hasFinance ? ref.watch(salesSummaryProvider((from: _from, to: _to))) : null;
    final lowStockAsync = hasInventory ? ref.watch(lowStockProvider) : null;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            if (hasFinance) {
              ref.invalidate(salesSummaryProvider);
              ref.invalidate(taxObligationsProvider);
            }
            if (hasInventory) {
              ref.invalidate(lowStockProvider);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner Profile with Glassmorphism
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Background Banner Image with sophisticated dark blend
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: 'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?q=80&w=1000&auto=format&fit=crop',
                            fit: BoxFit.cover,
                            color: Colors.black.withValues(alpha: 0.55),
                            colorBlendMode: BlendMode.darken,
                            placeholder: (context, url) => Container(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        // Glassy gradient glow overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                        // Text Content overlay
                        Positioned(
                          left: 20,
                          bottom: 20,
                          right: 20,
                          top: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Xin chào, ${ref.watch(authProvider).user?['fullName'] ?? 'Chủ shop'} 👋',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.85),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Tổng quan hôm nay',
                                          style: GoogleFonts.outfit(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  featureGuideButton(context, 'dashboard'),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: const HugeIcon(
                                        icon: HugeIcons.strokeRoundedNotification03,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      onPressed: () => context.push('/notifications'),
                                      tooltip: 'Thông báo',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sales summary cards
                if (hasFinance && salesAsync != null) ...[
                  salesAsync.when(
                    data: (data) {
                      final revenue = num.tryParse(data['totalRevenue']?.toString() ?? '0')?.toDouble() ?? 0.0;
                      final orders = data['totalOrders'] ?? data['orderCount'] ?? 0;
                      final avgOrder = orders > 0 ? revenue / orders : 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  'Doanh thu',
                                  _currFmt.format(revenue),
                                  HugeIcons.strokeRoundedChartIncrease,
                                  theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  'Đơn hàng',
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
                                child: _SummaryCard(
                                  AppStrings.dashboardAvgOrder,
                                  _currFmt.format(avgOrder),
                                  HugeIcons.strokeRoundedAnalytics01,
                                  AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: hasInventory && lowStockAsync != null
                                    ? lowStockAsync.when(
                                        data: (items) => _SummaryCard(
                                          AppStrings.dashboardLowStock,
                                          '${items.length}',
                                          HugeIcons.strokeRoundedAlert02,
                                          items.isEmpty ? AppColors.success : AppColors.danger,
                                        ),
                                        loading: () => _SummaryCard(
                                          AppStrings.dashboardLowStock,
                                          '...',
                                          HugeIcons.strokeRoundedAlert02,
                                          AppColors.warning,
                                        ),
                                        error: (_, _) => _SummaryCard(
                                          AppStrings.dashboardLowStock,
                                          '?',
                                          HugeIcons.strokeRoundedAlert02,
                                          AppColors.danger,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
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
                          data: (items) => _SummaryCard(
                            AppStrings.dashboardLowStock,
                            '${items.length}',
                            HugeIcons.strokeRoundedAlert02,
                            items.isEmpty ? AppColors.success : AppColors.danger,
                          ),
                          loading: () => _SummaryCard(
                            AppStrings.dashboardLowStock,
                            '...',
                            HugeIcons.strokeRoundedAlert02,
                            AppColors.warning,
                          ),
                          error: (_, _) => _SummaryCard(
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

                if (hasFinance && salesAsync != null) ...[
                  const SizedBox(height: 20),

                  // Revenue threshold warning (Glow progress meter)
                  salesAsync.whenOrNull(
                    data: (data) {
                      final revenue = num.tryParse(data['totalRevenue']?.toString() ?? '0')?.toDouble() ?? 0.0;
                      if (revenue <= 0) return const SizedBox.shrink();
                      final progress = RevenueThreshold.getProgress(revenue).clamp(0.0, 1.0);
                      final color = RevenueThreshold.getColor(revenue);
                      final nextThreshold = RevenueThreshold.getNextThreshold(revenue);
                      return Semantics(
                        label: 'Ngưỡng doanh thu: ${RevenueThreshold.getTierLabel(revenue)}. ${RevenueThreshold.getObligation(revenue)}',
                        button: true,
                        child: GestureDetector(
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
                                    'Ngưỡng DT: ${RevenueThreshold.getTierLabel(revenue)}',
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
                                    Container(
                                      height: 8,
                                      color: c.surface,
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 500),
                                      height: 8,
                                      width: MediaQuery.of(context).size.width * 0.8 * progress,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: LinearGradient(
                                          colors: [
                                            color,
                                            color.withValues(alpha: 0.7),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withValues(alpha: 0.35),
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
                                '${RevenueThreshold.getObligation(revenue)} • Ngưỡng tiếp: ${_currFmt.format(nextThreshold)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ), // closes GestureDetector
                    ); // closes Semantics
                  },
                  ) ?? const SizedBox.shrink(),

                  // Real Tax Obligation Reminder
                  const _TaxObligationReminder(),
                ],

                const SizedBox(height: 28),
                Text(
                  AppStrings.dashboardQuickActions,
                  style: GoogleFonts.outfit(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.extent(
                  maxCrossAxisExtent: 100,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (shopState.isOwner || shopState.hasPermission('pos'))
                      _QuickAction(
                        HugeIcons.strokeRoundedStore01,
                        'Tạo đơn',
                        () => context.push('/pos'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('products'))
                      _QuickAction(
                        HugeIcons.strokeRoundedPackage,
                        'Sản phẩm',
                        () => context.push('/products'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('customers'))
                      _QuickAction(
                        HugeIcons.strokeRoundedUserGroup,
                        'Khách hàng',
                        () => context.push('/customers'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('suppliers'))
                      _QuickAction(
                        HugeIcons.strokeRoundedTruck,
                        'NCC',
                        () => context.push('/suppliers'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('inventory'))
                      _QuickAction(
                        HugeIcons.strokeRoundedTask01,
                        'Kiểm kê',
                        () => context.push('/stock-take'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('finance'))
                      _QuickAction(
                        HugeIcons.strokeRoundedCheckmarkCircle02,
                        'Chốt sổ',
                        () => context.push('/daily-closing'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('finance'))
                      _QuickAction(
                        HugeIcons.strokeRoundedAnalytics01,
                        'Lãi/Lỗ',
                        () => context.push('/profit-loss'),
                      ),
                    if (shopState.isOwner || shopState.hasPermission('finance'))
                      _QuickAction(
                        HugeIcons.strokeRoundedInvoice01,
                        'Chứng từ',
                        () => context.push('/invoices'),
                      ),
                    if (shopState.isOwner) ...[
                      _QuickAction(
                        HugeIcons.strokeRoundedUserMultiple,
                        'Nhân viên',
                        () => context.push('/staff'),
                      ),
                      _QuickAction(
                        HugeIcons.strokeRoundedUserStar02,
                        'Vai trò',
                        () => context.push('/roles'),
                      ),
                    ],
                  ],
                ),

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
                                  'Dưới định mức tối thiểu',
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
                              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                              label: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...display.map(
                          (item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                    item['product']?['name'] ?? item['productName'] ?? 'Sản phẩm',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Tồn: ${item['currentQuantity'] ?? item['quantity'] ?? 0}',
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

/// Shows pending/overdue tax obligations with deadline countdown from API
class _TaxObligationReminder extends ConsumerWidget {
  const _TaxObligationReminder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final taxAsync = ref.watch(taxObligationsProvider);

    return taxAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final all = ((data['items'] as List?) ?? []);
        final pending = all.where((t) => t['status'] != 'done').toList();
        if (pending.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            children: pending.map<Widget>((t) {
              final period = t['period'] ?? '';
              final dueDateStr = t['dueDate']?.toString().split('T').first;
              final vatDeclared = num.tryParse(t['vatDeclared']?.toString() ?? '0') ?? 0;
              final vatPaid = num.tryParse(t['vatPaid']?.toString() ?? '0') ?? 0;
              final pitDeclared = num.tryParse(t['pitDeclared']?.toString() ?? '0') ?? 0;
              final pitPaid = num.tryParse(t['pitPaid']?.toString() ?? '0') ?? 0;
              final vatOwed = vatDeclared - vatPaid;
              final pitOwed = pitDeclared - pitPaid;
              final totalOwed = vatOwed + pitOwed;
              final status = t['status'] ?? 'pending';

              // Calculate days remaining
              int? daysLeft;
              if (dueDateStr != null) {
                final dueDate = DateTime.tryParse(dueDateStr);
                if (dueDate != null) {
                  daysLeft = dueDate.difference(DateTime.now()).inDays;
                }
              }

              // Urgency color + label
              Color urgencyColor;
              String urgencyLabel;
              IconData urgencyIcon;
              if (status == 'overdue' || (daysLeft != null && daysLeft < 0)) {
                urgencyColor = AppColors.danger;
                urgencyLabel = 'Quá hạn${daysLeft != null ? " ${(-daysLeft)} ngày" : ""}';
                urgencyIcon = Icons.error_rounded;
              } else if (daysLeft != null && daysLeft <= 7) {
                urgencyColor = AppColors.danger;
                urgencyLabel = 'Còn $daysLeft ngày';
                urgencyIcon = Icons.warning_rounded;
              } else if (daysLeft != null && daysLeft <= 30) {
                urgencyColor = AppColors.warning;
                urgencyLabel = 'Còn $daysLeft ngày';
                urgencyIcon = Icons.schedule_rounded;
              } else {
                urgencyColor = AppColors.info;
                urgencyLabel = daysLeft != null ? 'Còn $daysLeft ngày' : 'Chờ nộp';
                urgencyIcon = Icons.info_outline_rounded;
              }

              return Semantics(
                label: 'Cảnh báo thuế $period, còn phải nộp ${_currFmt.format(totalOwed)}, $urgencyLabel',
                button: true,
                child: GestureDetector(
                  onTap: () => context.push('/tax-obligations'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(urgencyIcon, size: 22, color: urgencyColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thuế $period',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Còn phải nộp: ${_currFmt.format(totalOwed)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (dueDateStr != null)
                              Text(
                                'Hạn: $dueDateStr',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          urgencyLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ), // closes GestureDetector
            ); // closes Semantics
          }).toList(),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value;
  final dynamic icon;
  final Color color;
  const _SummaryCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(icon: icon, size: 20, color: color),
              ),
              // Tiny graphic dot/glow matching the color
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22, 
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: TextStyle(
              fontSize: 12, 
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: c.divider.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF232C51).withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: HugeIcon(icon: icon, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
