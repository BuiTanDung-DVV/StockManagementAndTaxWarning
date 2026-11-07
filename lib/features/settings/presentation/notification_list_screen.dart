import 'dart:async';
import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/notification_provider.dart';
import '../providers/notification_navigation.dart';
import '../providers/shop_provider.dart';
import '../../dashboard/providers/dashboard_action_provider.dart';
import '../../dashboard/presentation/widgets/dashboard_widgets.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;
  const NotificationListScreen({super.key, this.initialFilter});
  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen>
    with WidgetsBindingObserver {
  late bool _actionable;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _actionable = widget.initialFilter != 'account';
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_refresh);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (mounted &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed)) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotificationListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      _actionable = widget.initialFilter != 'account';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final shops = ref.read(shopProvider);
      final tasks = <Future<void>>[
        ref
            .read(notificationProvider.notifier)
            .loadNotifications(refreshLoadedPages: true),
      ];
      if (canViewDashboardActions(shops)) {
        // Refresh the source actually shown in Cần xử lý, not the account inbox.
        tasks.add(
          ref
              .refresh(dashboardActionProvider.future)
              .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
        );
      }
      await Future.wait(tasks);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _selectTab(bool actionable) {
    setState(() => _actionable = actionable);
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final notifier = ref.read(notificationProvider.notifier);
    final id = parseShopRecordId(notification['id']);
    if (id != null && notification['isRead'] != true) {
      await notifier.markRead(id);
    }
    if (!mounted) return;
    final target = notificationDestination(
      notification,
      ref.read(shopProvider),
    );
    if (target == null) return;
    if (target.shopId != null) {
      ref.read(shopProvider.notifier).switchShop(target.shopId!);
    }
    context.push(target.route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);
    final inbox = ref.watch(notificationProvider);
    final shop = ref.watch(shopProvider);
    final allowed = canViewDashboardActions(shop);
    final actionCount = allowed
        ? ref.watch(dashboardActionProvider).asData?.value.items.length
        : null;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        leading: AppNavigationBackLeading(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông báo'),
            Text(
              'Tự cập nhật mỗi 30 giây',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _refreshing ? null : _refresh,
            icon: const AppIcon(Icons.refresh_rounded, size: 18),
            label: Text(_refreshing ? 'Đang cập nhật…' : 'Kiểm tra ngay'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: colors.card,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    'Cần xử lý${actionCount == null ? '' : ' ($actionCount)'}',
                  ),
                  selected: _actionable,
                  onSelected: (_) => _selectTab(true),
                ),
                ChoiceChip(
                  label: Text(
                    'Tài khoản${inbox.unreadCount > 0 ? ' (${inbox.unreadCount} chưa đọc)' : ''}',
                  ),
                  selected: !_actionable,
                  onSelected: (_) => _selectTab(false),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: _actionable
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                shop.currentShopName ?? 'Cửa hàng đang xem',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tự cập nhật mỗi 30 giây khi mở màn hình. Cảnh báo chỉ hết khi nghiệp vụ đã được xử lý.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (allowed)
                                const DashboardPriorityList(showViewAll: false)
                              else
                                const AppEmpty(
                                  message:
                                      'Không có mục nghiệp vụ được cấp quyền',
                                  subtitle:
                                      'Bạn vẫn có thể xem thông báo ở mục Tài khoản.',
                                ),
                            ],
                          )
                        : _buildInbox(inbox, shop, colors),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInbox(
    NotificationState inbox,
    ShopState shop,
    AppThemeColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Thông báo tài khoản',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (inbox.unreadCount > 0 ||
                inbox.items.any((n) => n['isRead'] != true))
              TextButton(
                onPressed: () =>
                    ref.read(notificationProvider.notifier).markAllRead(),
                child: const Text('Đọc tất cả'),
              ),
          ],
        ),
        Text(
          'Thông báo của bạn tại các cửa hàng. Đánh dấu đã đọc không thay đổi trạng thái yêu cầu.',
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (inbox.errorMessage != null) ...[
          AppInlineError(
            message: inbox.errorMessage!,
            onRetry: () => ref
                .read(notificationProvider.notifier)
                .loadNotifications(refreshLoadedPages: true),
          ),
          const SizedBox(height: 12),
        ],
        if (inbox.isLoading && inbox.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (inbox.items.isEmpty && inbox.errorMessage == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: AppEmpty(
              message: 'Chưa có thông báo tài khoản',
              subtitle:
                  'Yêu cầu gia nhập và thay đổi vai trò sẽ xuất hiện tại đây.',
            ),
          ),
        for (final item in inbox.items) ...[
          _buildNotifCard(item, shop, colors),
          const SizedBox(height: 8),
        ],
        if (inbox.hasMore)
          Center(
            child: OutlinedButton(
              onPressed: inbox.isLoading
                  ? null
                  : () => ref
                        .read(notificationProvider.notifier)
                        .loadNotifications(page: inbox.page + 1),
              child: Text(inbox.isLoading ? 'Đang tải…' : 'Tải thêm thông báo'),
            ),
          ),
      ],
    );
  }

  Widget _buildNotifCard(
    Map<String, dynamic> item,
    ShopState shop,
    AppThemeColors colors,
  ) {
    final read = item['isRead'] == true;
    final type = item['type']?.toString() ?? '';
    final target = notificationDestination(item, shop);
    final shopName = notificationShopName(item, shop);
    final icon = switch (type) {
      'SHOP_INVITE' ||
      'REQUEST_APPROVED' => Icons.store_mall_directory_outlined,
      'JOIN_REQUEST' => Icons.person_add_alt_1_outlined,
      'ROLE_CHANGE' => Icons.manage_accounts_outlined,
      'REQUEST_REJECTED' => Icons.person_off_outlined,
      _ => Icons.notifications_outlined,
    };
    return Material(
      color: read ? colors.card : colors.primary.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNotification(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: read
                  ? colors.divider
                  : colors.primary.withValues(alpha: .18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shopName != null) ...[
                      Text(
                        shopName,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      item['title']?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item['message']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          _formatDate(item['createdAt']),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                        if (!read)
                          Text(
                            'Chưa đọc',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.primary,
                            ),
                          ),
                        if (target != null)
                          Text(
                            type == 'JOIN_REQUEST'
                                ? 'Xem yêu cầu →'
                                : 'Xem chi tiết →',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
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
    );
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
