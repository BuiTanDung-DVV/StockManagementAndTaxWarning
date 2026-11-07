import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../assets/app_icon.dart';
import '../theme/app_theme.dart';
import 'offline_providers.dart';
import '../../features/auth/providers/auth_provider.dart';

final offlinePendingCountProvider = StreamProvider<int>((ref) async* {
  final scope = ref.watch(offlineScopeProvider);
  if (scope == null) {
    yield 0;
    return;
  }
  final store = await ref.watch(offlineStoreProvider.future);
  await for (final operations in store.watch(scope)) {
    yield operations.where((item) => item.status != 'confirmed').length;
  }
});

class OfflineQueueIndicator extends ConsumerWidget {
  const OfflineQueueIndicator({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(offlinePendingCountProvider);
    final reads = ref.watch(offlineReadStatusProvider).value;
    final c = AppThemeColors.of(context);
    final queueLabel = pending.hasError
        ? 'Chưa đọc được ghi chép trên thiết bị'
        : (pending.value ?? 0) > 0
        ? '${pending.value} ghi chép chờ đồng bộ hoặc cần kiểm tra'
        : null;
    final cachedLabel = reads != null && reads.cachedRequests > 0
        ? 'Đang xem dữ liệu đã lưu${reads.oldestSnapshot == null ? '' : ' lúc ${DateFormat('dd/MM HH:mm').format(reads.oldestSnapshot!.toLocal())}'}'
        : null;
    final local = ref.watch(authProvider).isOfflineSession;
    final label = [
      if (local) 'Chế độ cục bộ · Cần xác thực lại trước khi gửi',
      queueLabel,
      cachedLabel,
    ].whereType<String>().join(' · ');
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const AppIcon(Icons.cloud_upload_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(
            onPressed: () => context.push('/offline'),
            child: const Text('Xem'),
          ),
        ],
      ),
    );
  }
}
