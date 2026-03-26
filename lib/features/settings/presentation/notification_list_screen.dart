import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});
  @override
  ConsumerState<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationProvider.notifier).loadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final notif = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (notif.items.any((n) => n['isRead'] != true))
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Đọc tất cả'),
            ),
        ],
      ),
      body: notif.items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none, size: 64, color: c.textMuted),
              const SizedBox(height: 12),
              Text('Không có thông báo', style: TextStyle(color: c.textSecondary, fontSize: 16)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notif.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildNotifCard(notif.items[i], c),
            ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> n, AppThemeColors c) {
    final isRead = n['isRead'] == true;
    final type = n['type'] as String? ?? '';
    IconData icon;
    Color iconColor;
    switch (type) {
      case 'SHOP_INVITE':
        icon = Icons.store_mall_directory;
        iconColor = AppColors.primary;
      case 'ROLE_CHANGE':
        icon = Icons.swap_horiz;
        iconColor = AppColors.info;
      default:
        icon = Icons.notifications;
        iconColor = AppColors.warning;
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
          border: isRead ? null : Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.w600, fontSize: 13))),
              if (!isRead)
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 4),
            Text(n['message'] ?? '', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 4),
            Text(_formatDate(n['createdAt']), style: TextStyle(fontSize: 10, color: c.textMuted)),
          ])),
        ]),
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
