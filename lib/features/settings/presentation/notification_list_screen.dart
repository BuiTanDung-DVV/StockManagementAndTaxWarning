import 'package:flutter/material.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/notification_provider.dart';
import '../../dashboard/presentation/widgets/dashboard_widgets.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const NotificationListScreen({super.key, this.initialFilter});
  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != 'actionable') {
      Future.microtask(
        () => ref.read(notificationProvider.notifier).loadNotifications(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final notif = ref.watch(notificationProvider);
    final actionable = widget.initialFilter == 'actionable';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(actionable ? 'Trung tâm cần xử lý' : 'Thông báo'),
        actions: [
          if (!actionable && notif.items.any((n) => n['isRead'] != true))
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: actionable
          ? RefreshIndicator(
              onRefresh: () async =>
                  ref.read(notificationProvider.notifier).loadNotifications(),
              child: const SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: DashboardPriorityList(showViewAll: false),
              ),
            )
          : notif.isLoading && notif.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notif.errorMessage != null && notif.items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppInlineError(
                  message: notif.errorMessage!,
                  onRetry: () => ref
                      .read(notificationProvider.notifier)
                      .loadNotifications(),
                ),
              ),
            )
          : notif.items.isEmpty
          ? RefreshIndicator(
              onRefresh: () async =>
                  ref.read(notificationProvider.notifier).loadNotifications(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: const SizedBox(
                  height: 360,
                  child: Center(
                    child: AppEmpty(
                      message: 'Không có thông báo',
                      subtitle: 'Hiện tại bạn không có thông báo mới nào.',
                    ),
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.read(notificationProvider.notifier).loadNotifications(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: notif.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildNotifCard(notif.items[i], c),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> n, AppThemeColors c) {
    final isRead = n['isRead'] == true;
    final type = n['type'] as String? ?? '';
    IconData icon;
    Color iconColor;
    switch (type) {
      case 'INVENTORY_LOW':
      case 'STOCK_LOW':
      case 'OUT_OF_STOCK':
      case 'EXPIRED':
        icon = Icons.inventory_2_outlined;
        iconColor = AppColors.danger;
      case 'DEBT_REMINDER':
      case 'DEBT_OVERDUE':
      case 'PAYMENT_PENDING':
        icon = Icons.account_balance_wallet_outlined;
        iconColor = AppColors.warning;
      case 'SALES_MILESTONE':
      case 'TARGET_REACHED':
      case 'ORDER_COMPLETED':
        icon = Icons.trending_up_rounded;
        iconColor = AppColors.success;
      case 'TAX_ALERT':
      case 'TAX_WARNING':
        icon = Icons.receipt_long_outlined;
        iconColor = AppColors.danger;
      case 'SHOP_INVITE':
        icon = Icons.store_mall_directory_outlined;
        iconColor = AppColors.primary;
      case 'ROLE_CHANGE':
        icon = Icons.swap_horiz_rounded;
        iconColor = AppColors.info;
      default:
        icon = Icons.notifications_outlined;
        iconColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          ref.read(notificationProvider.notifier).markRead(n['id'] as int);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? c.card : AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: isRead
              ? null
              : Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withValues(alpha: 0.12),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n['title'] ?? '',
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['message'] ?? '',
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(n['createdAt']),
                    style: TextStyle(fontSize: 10, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date.toString();
    }
  }
}
