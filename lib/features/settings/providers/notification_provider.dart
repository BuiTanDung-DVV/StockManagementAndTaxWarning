import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class NotificationState {
  final int unreadCount;
  final List<Map<String, dynamic>> items;
  final bool isLoading;

  const NotificationState({this.unreadCount = 0, this.items = const [], this.isLoading = false});
}

class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() => const NotificationState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadUnreadCount() async {
    try {
      final data = await _api.get('/notifications/unread-count');
      state = NotificationState(unreadCount: data['count'] ?? 0, items: state.items);
    } catch (_) {}
  }

  Future<void> loadNotifications({int page = 1}) async {
    try {
      final data = await _api.get('/notifications?page=$page&limit=20');
      final items = (data['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      state = NotificationState(unreadCount: state.unreadCount, items: items);
    } catch (_) {}
  }

  Future<void> markRead(int id) async {
    try {
      await _api.put('/notifications/$id/read');
      state = NotificationState(
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
        items: state.items.map((n) => n['id'] == id ? {...n, 'isRead': true} : n).toList(),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.put('/notifications/read-all');
      state = NotificationState(
        unreadCount: 0,
        items: state.items.map((n) => {...n, 'isRead': true}).toList(),
      );
    } catch (_) {}
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
