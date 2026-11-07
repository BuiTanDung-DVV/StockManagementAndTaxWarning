import '../../../core/providers/data_freshness_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class NotificationState {
  final int unreadCount;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? errorMessage;
  final int page;
  final int total;

  const NotificationState({
    this.unreadCount = 0,
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
    this.page = 0,
    this.total = 0,
  });

  bool get hasMore => items.length < total;

  NotificationState copyWith({
    int? unreadCount,
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    int? page,
    int? total,
  }) => NotificationState(
    unreadCount: unreadCount ?? this.unreadCount,
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    page: page ?? this.page,
    total: total ?? this.total,
  );
}

class NotificationNotifier extends Notifier<NotificationState> {
  int _countRequest = 0;
  int _listRequest = 0;
  final Set<int> _reading = {};
  bool _readingAll = false;

  @override
  NotificationState build() {
    ref.listen(
      dataFreshnessProvider.select((s) => s[DataArea.notifications] ?? 0),
      (_, _) {
        Future.microtask(() {
          if (!ref.mounted) return;
          if (state.page > 0) {
            loadNotifications(refreshLoadedPages: true);
          } else {
            loadUnreadCount();
          }
        });
      },
    );
    return const NotificationState();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadUnreadCount() async {
    final request = ++_countRequest;
    try {
      final data = await _api.get('/notifications/unread-count');
      if (data is! Map ||
          data['count'] is! num ||
          !(data['count'] as num).isFinite ||
          data['count'] < 0) {
        throw const FormatException('Số thông báo chưa đọc không hợp lệ');
      }
      if (!ref.mounted || request != _countRequest) return;
      state = state.copyWith(
        unreadCount: (data['count'] as num).toInt(),
        clearError:
            state.errorMessage == 'Không thể tải số thông báo chưa đọc.',
      );
    } catch (e) {
      debugPrint('NotificationProvider.loadUnreadCount error: $e');
      if (!ref.mounted || request != _countRequest) return;
      state = state.copyWith(
        errorMessage: 'Không thể tải số thông báo chưa đọc.',
      );
    }
  }

  Future<void> loadNotifications({
    int page = 1,
    bool refreshLoadedPages = false,
  }) async {
    if (page < 1 || (page > 1 && state.isLoading)) return;
    final retainedPage = state.page;
    final request = ++_listRequest;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.get('/notifications?page=$page&limit=20');
      if (data is! Map || data['items'] is! List || data['total'] is! num) {
        throw const FormatException('Danh sách thông báo không hợp lệ');
      }
      final incoming = (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      var resultPage = page;
      if (refreshLoadedPages && page == 1 && retainedPage > 1) {
        final totalPages = ((data['total'] as num).toInt() / 20).ceil();
        final lastPage = retainedPage < totalPages ? retainedPage : totalPages;
        for (var next = 2; next <= lastPage; next++) {
          final extra = await _api.get('/notifications?page=$next&limit=20');
          if (extra is! Map || extra['items'] is! List) {
            throw const FormatException('Danh sách thông báo không hợp lệ');
          }
          incoming.addAll(
            (extra['items'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          resultPage = next;
        }
      }
      if (!ref.mounted || request != _listRequest) return;
      final merged = <dynamic, Map<String, dynamic>>{
        if (page > 1)
          for (final item in state.items) item['id']: item,
        for (final item in incoming) item['id']: item,
      };
      state = state.copyWith(
        items: merged.values.toList(),
        page: resultPage,
        total: (data['total'] as num).toInt(),
        isLoading: false,
      );
      await loadUnreadCount();
    } catch (e) {
      debugPrint('NotificationProvider.loadNotifications error: $e');
      if (!ref.mounted || request != _listRequest) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải thông báo từ cơ sở dữ liệu.',
      );
    }
  }

  Future<void> markRead(int id) async {
    if (_readingAll || !_reading.add(id)) return;
    if (state.items.any((n) => n['id'] == id && n['isRead'] == true)) {
      _reading.remove(id);
      return;
    }
    ++_countRequest;
    try {
      await _api.put('/notifications/$id/read');
      if (!ref.mounted) return;
      ++_listRequest;
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        items: state.items
            .map((n) => n['id'] == id ? {...n, 'isRead': true} : n)
            .toList(),
      );
      await loadUnreadCount();
    } catch (e) {
      debugPrint('NotificationProvider.markRead error: $e');
      if (ref.mounted) {
        state = state.copyWith(
          errorMessage: 'Chưa thể đánh dấu thông báo đã đọc. Vui lòng thử lại.',
        );
      }
    } finally {
      _reading.remove(id);
    }
  }

  Future<void> markAllRead() async {
    if (_readingAll) return;
    _readingAll = true;
    ++_countRequest;
    try {
      await _api.put('/notifications/read-all');
      if (!ref.mounted) return;
      ++_listRequest;
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        unreadCount: 0,
        items: state.items.map((n) => {...n, 'isRead': true}).toList(),
      );
      await loadUnreadCount();
    } catch (e) {
      debugPrint('NotificationProvider.markAllRead error: $e');
      if (ref.mounted) {
        state = state.copyWith(
          errorMessage: 'Chưa thể đánh dấu tất cả đã đọc. Vui lòng thử lại.',
        );
      }
    } finally {
      _readingAll = false;
    }
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
