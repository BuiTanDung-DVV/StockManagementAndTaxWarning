import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class NotificationState {
  final int unreadCount;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? errorMessage;

  const NotificationState({
    this.unreadCount = 0,
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });
}

class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() => const NotificationState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadUnreadCount() async {
    try {
      final data = await _api.get('/notifications/unread-count');
      if (data is! Map || data['count'] is! num) {
        throw const FormatException('Số thông báo chưa đọc không hợp lệ');
      }
      state = NotificationState(
        unreadCount: (data['count'] as num).toInt(),
        items: state.items,
      );
    } catch (e) {
      debugPrint('NotificationProvider.loadUnreadCount error: $e');
      state = NotificationState(
        unreadCount: state.unreadCount,
        items: state.items,
        errorMessage: 'Không thể tải số thông báo chưa đọc.',
      );
    }
  }

  Future<void> loadNotifications({int page = 1}) async {
    state = NotificationState(
      unreadCount: state.unreadCount,
      items: state.items,
      isLoading: true,
    );
    try {
      final data = await _api.get('/notifications?page=$page&limit=20');
      if (data is! Map || data['items'] is! List) {
        throw const FormatException('Danh sách thông báo không hợp lệ');
      }
      final items = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      state = NotificationState(unreadCount: state.unreadCount, items: items);
    } catch (e) {
      debugPrint('NotificationProvider.loadNotifications error: $e');
      state = NotificationState(
        unreadCount: state.unreadCount,
        items: state.items,
        errorMessage: 'Không thể tải thông báo từ cơ sở dữ liệu.',
      );
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _api.put('/notifications/$id/read');
      state = NotificationState(
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
        items: state.items
            .map((n) => n['id'] == id ? {...n, 'isRead': true} : n)
            .toList(),
      );
    } catch (e) {
      debugPrint('NotificationProvider.markRead error: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.put('/notifications/read-all');
      state = NotificationState(
        unreadCount: 0,
        items: state.items.map((n) => {...n, 'isRead': true}).toList(),
      );
    } catch (e) {
      debugPrint('NotificationProvider.markAllRead error: $e');
    }
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
