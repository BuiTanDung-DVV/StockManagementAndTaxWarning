import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/finance_provider.dart';

class BudgetPlanScreen extends ConsumerWidget {
  const BudgetPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final budgetAsync = ref.watch(budgetPlansProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Kế Hoạch Ngân Sách'),
        centerTitle: true,
      ),
      body: budgetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmpty(message: 'Chưa có kế hoạch ngân sách nào');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return Card(
                color: c.card,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(item['name'] ?? 'Kế hoạch ${i + 1}'),
                  subtitle: Text(item['description'] ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
