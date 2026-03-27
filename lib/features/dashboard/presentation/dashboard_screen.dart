import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../sales/providers/sales_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../../settings/presentation/staff_management_screen.dart';
import '../../settings/presentation/notification_list_screen.dart';
import '../../auth/providers/auth_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _today = DateTime.now();
final _from = DateTime(_today.year, _today.month, 1).toIso8601String().split('T')[0];
final _to = _today.toIso8601String().split('T')[0];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final salesAsync = ref.watch(salesSummaryProvider((from: _from, to: _to)));
    final lowStockAsync = ref.watch(lowStockProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(salesSummaryProvider);
            ref.invalidate(lowStockProvider);
            ref.invalidate(taxObligationsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Xin chào ${ref.watch(authProvider).user?['fullName'] ?? ''} 👋', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                  Text('Tổng quan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ])),
                featureGuideButton(context, 'dashboard'),
                IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationListScreen()))),
              ]),
              const SizedBox(height: 20),

              // Sales summary cards
              salesAsync.when(
                data: (data) {
                  final revenue = (data['totalRevenue'] ?? 0).toDouble();
                  final orders = data['totalOrders'] ?? data['orderCount'] ?? 0;
                  final avgOrder = orders > 0 ? revenue / orders : 0.0;
                  return Column(children: [
                    Row(children: [
                      Expanded(child: _SummaryCard('Doanh thu', _currFmt.format(revenue), Icons.trending_up, AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _SummaryCard('Đơn hàng', '$orders', Icons.receipt, AppColors.success)),
                    ]),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _SummaryCard('TB / Đơn', _currFmt.format(avgOrder), Icons.analytics, AppColors.info)),
                      SizedBox(width: 12),
                      Expanded(child: lowStockAsync.when(
                        data: (items) => _SummaryCard('Dưới DMức', '${items.length}', Icons.warning, items.isEmpty ? AppColors.success : AppColors.danger),
                        loading: () => _SummaryCard('Dưới DMức', '...', Icons.warning, AppColors.warning),
                        error: (_, _) => _SummaryCard('Dưới DMức', '?', Icons.warning, AppColors.danger),
                      )),
                    ]),
                  ]);
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.cloud_off, color: AppColors.danger),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Không thể kết nối server\n$e', style: const TextStyle(fontSize: 12, color: AppColors.danger))),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // Revenue threshold warning
              salesAsync.whenOrNull(
                data: (data) {
                  final revenue = (data['totalRevenue'] ?? 0).toDouble();
                  if (revenue <= 0) return const SizedBox.shrink();
                  final progress = RevenueThreshold.getProgress(revenue).clamp(0.0, 1.0);
                  final color = RevenueThreshold.getColor(revenue);
                  final nextThreshold = RevenueThreshold.getNextThreshold(revenue);
                  return GestureDetector(
                    onTap: () => context.go('/tax-calculator'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.flag, size: 16, color: color),
                          const SizedBox(width: 6),
                          Text('Ngưỡng DT: ${RevenueThreshold.getTierLabel(revenue)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                          const Spacer(),
                          Icon(Icons.chevron_right, size: 16, color: c.textMuted),
                        ]),
                        SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress, backgroundColor: c.surface, color: color, minHeight: 5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${RevenueThreshold.getObligation(revenue)} • Ngưỡng tiếp: ${_currFmt.format(nextThreshold)}',
                          style: TextStyle(fontSize: 10, color: c.textSecondary),
                        ),
                      ]),
                    ),
                  );
                },
              ) ?? const SizedBox.shrink(),

              // ── Real Tax Obligation Reminder ──
              const _TaxObligationReminder(),

              const SizedBox(height: 24),
              Text('Thao tác nhanh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _QuickAction(Icons.point_of_sale, 'Bán hàng', () => context.go('/pos')),
                  _QuickAction(Icons.receipt_long, 'Đơn hàng', () => context.go('/sales')),
                  _QuickAction(Icons.inventory_2, 'Sản phẩm', () => context.go('/products')),
                  _QuickAction(Icons.people, 'Khách hàng', () => context.go('/customers')),
                  _QuickAction(Icons.warehouse, 'Kho hàng', () => context.go('/inventory')),
                  _QuickAction(Icons.business, 'NCC', () => context.go('/suppliers')),
                  _QuickAction(Icons.account_balance_wallet, 'Tài chính', () => context.go('/finance')),
                  _QuickAction(Icons.settings, 'Cài đặt', () => context.go('/settings')),
                  if (ref.watch(shopProvider).isOwner) ...[                  
                    _QuickAction(Icons.people, 'Nhân viên', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementScreen()))),
                    _QuickAction(Icons.admin_panel_settings, 'Vai trò', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleConfigScreen()))),
                  ],
                ],
              ),

              const SizedBox(height: 24),
              // Low stock warnings
              lowStockAsync.when(
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  final display = items.take(5).toList();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('⚠ Dưới định mức tối thiểu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      TextButton(onPressed: () => context.go('/inventory'), child: Text('Xem tất cả')),
                    ]),
                    ...display.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(child: Text(item['product']?['name'] ?? item['productName'] ?? 'SP', style: const TextStyle(fontSize: 13))),
                        Text('Tồn: ${item['currentQuantity'] ?? item['quantity'] ?? 0}', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    )),
                  ]);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ]),
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
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: pending.map<Widget>((t) {
              final period = t['period'] ?? '';
              final dueDateStr = t['dueDate']?.toString().split('T').first;
              final vatOwed = ((t['vatDeclared'] as num?) ?? 0) - ((t['vatPaid'] as num?) ?? 0);
              final pitOwed = ((t['pitDeclared'] as num?) ?? 0) - ((t['pitPaid'] as num?) ?? 0);
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
                urgencyIcon = Icons.error;
              } else if (daysLeft != null && daysLeft <= 7) {
                urgencyColor = AppColors.danger;
                urgencyLabel = 'Còn $daysLeft ngày';
                urgencyIcon = Icons.warning;
              } else if (daysLeft != null && daysLeft <= 30) {
                urgencyColor = AppColors.warning;
                urgencyLabel = 'Còn $daysLeft ngày';
                urgencyIcon = Icons.schedule;
              } else {
                urgencyColor = AppColors.info;
                urgencyLabel = daysLeft != null ? 'Còn $daysLeft ngày' : 'Chờ nộp';
                urgencyIcon = Icons.info_outline;
              }

              return GestureDetector(
                onTap: () => context.go('/tax-obligations'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: urgencyColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(urgencyIcon, size: 20, color: urgencyColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Thuế $period', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        'Còn phải nộp: ${_currFmt.format(totalOwed)}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                      if (dueDateStr != null)
                        Text('Hạn: $dueDateStr', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(urgencyLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: urgencyColor)),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _SummaryCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(title, style: TextStyle(fontSize: 11, color: c.textSecondary)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.primary, size: 22),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
