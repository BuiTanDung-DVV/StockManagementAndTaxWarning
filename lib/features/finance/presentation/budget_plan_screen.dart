import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/finance_provider.dart';
import 'budget_plan_section.dart';

class BudgetPlanScreen extends ConsumerWidget {
  const BudgetPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final budgetAsync = ref.watch(budgetPlansProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Kế Hoạch Ngân Sách'),
        centerTitle: true,
      ),
      body: budgetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppInlineError(
              message:
                  'Không thể tải kế hoạch ngân sách. Vui lòng thử lại sau.',
              onRetry: () => ref.invalidate(budgetPlansProvider),
            ),
          ),
        ),
        data: (loadedItems) {
          if (loadedItems.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(budgetPlansProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 420,
                  child: const Center(
                    child: AppEmpty(
                      visual: AppEmptyVisual.finance,
                      message: 'Chưa có kế hoạch ngân sách nào',
                    ),
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: const BudgetPlanSection(embedded: false),
          );
        },
      ),
    );
  }
}
