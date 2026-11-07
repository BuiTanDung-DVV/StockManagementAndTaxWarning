import 'offline_store.dart';

class SyncTransportFailure implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? review;
  const SyncTransportFailure(this.message, [this.statusCode, this.review]);
}

typedef OfflineTransport =
    Future<Map<String, dynamic>> Function(
      OfflineScope scope,
      Map<String, dynamic> envelope,
    );

class OfflineSyncEngine {
  final OfflineStore store;
  final OfflineTransport transport;
  final bool Function(OfflineScope scope) isCurrentScope;
  final void Function(OfflineOperation operation)? onConfirmed;
  bool _running = false;
  OfflineSyncEngine({
    required this.store,
    required this.transport,
    required this.isCurrentScope,
    this.onConfirmed,
  });

  Future<void> sync(OfflineScope scope, {bool manual = false}) async {
    if (_running || !isCurrentScope(scope)) return;
    if (!manual && !await store.autoSync(scope)) return;
    _running = true;
    try {
      // Bounded work; subsequent timer/manual calls continue the queue.
      for (var i = 0; i < 20 && isCurrentScope(scope); i++) {
        // Explicit retry should run now; automatic retries keep their backoff.
        // This never overrides a live lease or retries rejected/auth-required rows.
        final item = await store.claim(scope, ignoreRetryDelay: manual);
        if (item == null) break;
        if (!isCurrentScope(scope)) {
          await store.finish(
            scope,
            item,
            'pending',
            message: 'Đã đổi tài khoản hoặc cửa hàng.',
          );
          break;
        }
        try {
          final receipt = await transport(scope, item.envelope);
          if (receipt['operationId'] != item.id ||
              receipt['kind'] != item.kind ||
              receipt['entityId'] is! int ||
              (receipt['entityId'] as int) <= 0) {
            throw const SyncTransportFailure(
              'Máy chủ chưa xác nhận đúng bản ghi.',
            );
          }
          final usedExisting =
              receipt['usedExisting'] == true ||
              (item.value['reviewDecision'] as Map?)?['action'] ==
                  'useExisting';
          await store.finish(
            scope,
            item,
            'confirmed',
            receipt: receipt,
            message: usedExisting
                ? 'Đã liên kết với giao dịch đã có; không ghi thêm tiền, kho hoặc công nợ.'
                : null,
          );
          if (isCurrentScope(scope)) onConfirmed?.call(item);
        } on SyncTransportFailure catch (error) {
          final code = error.statusCode;
          final auth = code == 401 || code == 403;
          final transient =
              code == null || code >= 500 || code == 408 || code == 429;
          final review = error.review;
          final validReview =
              code == 409 &&
              review != null &&
              review['guard'] is String &&
              (review['guard'] as String).isNotEmpty &&
              review['candidates'] is List &&
              (review['candidates'] as List).length <= 20 &&
              (review['candidates'] as List).every(
                (c) => c is Map && c['id'] is int && (c['id'] as int) > 0,
              );
          await store.finish(
            scope,
            item,
            validReview
                ? 'reviewRequired'
                : auth
                ? 'authRequired'
                : transient
                ? 'pending'
                : 'rejected',
            message: error.message,
            review: validReview ? review : null,
          );
          if (auth || transient) break;
        } catch (_) {
          // Unknown errors are NOT proof that the server did not commit.
          await store.finish(
            scope,
            item,
            'pending',
            message: 'Chưa nhận được xác nhận. Bản ghi được giữ để thử lại.',
          );
          break;
        }
      }
    } finally {
      _running = false;
    }
  }
}
