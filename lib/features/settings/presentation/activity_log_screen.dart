import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/system_provider.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final logsAsync = ref.watch(activityLogsProvider(1));

    return Scaffold(
      appBar: AppBar(
        title: Text('Nhật ký hoạt động'),
        actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: () {})],
      ),
      body: logsAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text('Chưa có nhật ký hoạt động', style: TextStyle(color: c.textSecondary)),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(activityLogsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final log = items[i] as Map;
                final message = (log['message'] ?? log['action'] ?? 'Hoạt động').toString();
                final actor = (log['actor'] ?? log['user']?['username'] ?? 'Hệ thống').toString();
                final createdAt = (log['createdAt'] ?? log['created_at'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.history, size: 18, color: AppColors.primary),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text('$createdAt • $actor', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger))),
      ),
    );
  }
}
