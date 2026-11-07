import '../../../core/widgets/app_page_header.dart';
import 'cashflow_projection_panel.dart';
import '../../../core/assets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/finance_provider.dart';

class CashflowForecastScreen extends ConsumerWidget {
  const CashflowForecastScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final forecastAsync = ref.watch(forecastsProvider);
    final budgetAsync = ref.watch(budgetPlansProvider);
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        leading: AppNavigationBackLeading(
          onPressed: () => navigatePageBack(context),
        ),
        title: Text(
          'Dự Báo Dòng Tiền',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'cashflow_forecast'),
          if (compactLayout)
            AppPrimaryHeaderAction(
              label: 'Thêm mới',
              assetPath: AppAssets.add,
              heroTag: 'cashflow-add-compact',
              onPressed: () => _showCreateMenu(context, ref),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: forecastAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppInlineError(
              message:
                  'Không thể tải dữ liệu dự báo dòng tiền. Vui lòng thử lại sau.',
              onRetry: () => ref.invalidate(forecastsProvider),
            ),
          ),
        ),
        data: (forecasts) {
          return budgetAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppInlineError(
                  message:
                      'Không thể tải dữ liệu ngân sách. Vui lòng thử lại sau.',
                  onRetry: () => ref.invalidate(budgetPlansProvider),
                ),
              ),
            ),
            data: (budgets) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CashflowProjectionPanel(),
                    if (budgets.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Kế hoạch & Ngân sách',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      ...budgets.map<Widget>((b) {
                        final plannedIncome =
                            num.tryParse(
                              b['plannedIncome']?.toString() ?? '0',
                            ) ??
                            0;
                        final actualIncome =
                            num.tryParse(
                              b['actualIncome']?.toString() ?? '0',
                            ) ??
                            0;
                        final plannedExpense =
                            num.tryParse(
                              b['plannedExpense']?.toString() ?? '0',
                            ) ??
                            0;
                        final actualExpense =
                            num.tryParse(
                              b['actualExpense']?.toString() ?? '0',
                            ) ??
                            0;
                        final pct = plannedIncome > 0
                            ? (actualIncome / plannedIncome)
                            : 0.0;
                        final isFullyAchieved = actualIncome >= plannedIncome;
                        final startDate = DateTime.tryParse(
                          b['startDate']?.toString() ?? '',
                        );
                        final endDate = DateTime.tryParse(
                          b['endDate']?.toString() ?? '',
                        );
                        final dateRange = startDate != null && endDate != null
                            ? '${DateFormat('dd/MM/yyyy').format(startDate)} – ${DateFormat('dd/MM/yyyy').format(endDate)}'
                            : 'Chưa xác định khoảng thời gian';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: c.divider.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AppIcon(
                                      Icons.pie_chart_outline_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b['name'] ?? '',
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: c.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateRange,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Kế hoạch thu: ${_fmt(plannedIncome)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Thực tế: ${_fmt(actualIncome)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isFullyAchieved
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  height: 8,
                                  color: c.surface,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: pct.clamp(0, 1).toDouble(),
                                      heightFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              theme.colorScheme.primary,
                                              isFullyAchieved
                                                  ? AppColors.success
                                                  : theme.colorScheme.primary
                                                        .withValues(alpha: 0.7),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Kế hoạch chi: ${_fmt(plannedExpense)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Thực tế chi: ${_fmt(actualExpense)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: actualExpense <= plannedExpense
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: compactLayout
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateMenu(context, ref),
              icon: const AppIcon(Icons.add_rounded),
              label: Text(
                'Thêm mới',
                style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  void _showCreateMenu(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Kế hoạch bổ sung'),
                subtitle: const Text('Khoản dự kiến chưa có trong công nợ'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddForecastDialog(context, ref);
                },
              ),
              ListTile(
                title: const Text('Kế hoạch ngân sách'),
                subtitle: const Text(
                  'Đặt mục tiêu thu, hạn mức chi và khoảng theo dõi',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAddBudgetDialog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final incomeC = TextEditingController();
    final expenseC = TextEditingController();
    var startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    var endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Thêm kế hoạch ngân sách',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Tên kế hoạch',
                    hintText: 'Ví dụ: Ngân sách tháng 8',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BudgetDateField(
                        label: 'Từ ngày',
                        value: startDate,
                        onTap: () async {
                          final value = await showDatePicker(
                            context: dialogContext,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (value != null) {
                            setDialogState(() => startDate = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BudgetDateField(
                        label: 'Đến ngày',
                        value: endDate,
                        onTap: () async {
                          final value = await showDatePicker(
                            context: dialogContext,
                            initialDate: endDate,
                            firstDate: startDate,
                            lastDate: DateTime(2100),
                          );
                          if (value != null) {
                            setDialogState(() => endDate = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: incomeC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mục tiêu thu (đồng)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expenseC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hạn mức chi (đồng)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameC.text.trim();
                if (name.isEmpty) {
                  ToastService.showError('Vui lòng nhập tên kế hoạch');
                  return;
                }
                if (startDate.isAfter(endDate)) {
                  ToastService.showError(
                    'Ngày bắt đầu không được sau ngày kết thúc',
                  );
                  return;
                }
                final plannedIncome = parseCurrency(incomeC.text);
                final plannedExpense = parseCurrency(expenseC.text);
                if (plannedIncome < 0 || plannedExpense < 0) {
                  ToastService.showError('Số tiền kế hoạch không được âm');
                  return;
                }
                try {
                  await ref.read(financeRepoProvider).createBudgetPlan({
                    'name': name,
                    'period': 'CUSTOM',
                    'startDate': startDate.toIso8601String().split('T').first,
                    'endDate': endDate.toIso8601String().split('T').first,
                    'plannedIncome': plannedIncome,
                    'plannedExpense': plannedExpense,
                  });
                  ref.invalidate(budgetPlansProvider);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ToastService.showSuccess('Đã lưu kế hoạch ngân sách');
                  }
                } catch (error) {
                  ToastService.showError(
                    'Không thể lưu kế hoạch ngân sách. Vui lòng thử lại sau.',
                  );
                }
              },
              child: const Text('Lưu kế hoạch'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddForecastDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final incomeC = TextEditingController();
    final expenseC = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isSaving = false;

    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !isSaving,
          child: AlertDialog(
            title: Text(
              'Thêm kế hoạch bổ sung',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: AppIcon(
                          Icons.calendar_month_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          DateFormat('dd/MM/yyyy').format(selectedDate),
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        trailing: const AppIcon(Icons.edit_rounded, size: 18),
                        onTap: isSaving
                            ? null
                            : () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (d != null && ctx.mounted) {
                                  setDialogState(() => selectedDate = d);
                                }
                              },
                      ),
                    ),
                  ),
                  TextField(
                    controller: incomeC,
                    enabled: !isSaving,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Thu dự kiến (VNĐ)',
                      prefixIcon: const AppIcon(
                        Icons.arrow_downward_rounded,
                        color: AppColors.success,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: c.divider.withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expenseC,
                    enabled: !isSaving,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Chi dự kiến (VNĐ)',
                      prefixIcon: const AppIcon(
                        Icons.arrow_upward_rounded,
                        color: AppColors.danger,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: c.divider.withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('Hủy', style: TextStyle(color: c.textSecondary)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (isSaving) return;
                        final income = parseCurrency(incomeC.text);
                        final expense = parseCurrency(expenseC.text);
                        if (income < 0 || expense < 0) {
                          ToastService.showError(
                            'Số tiền dự báo không được âm',
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(financeRepoProvider).createForecast({
                            'forecastDate': selectedDate
                                .toIso8601String()
                                .split('T')
                                .first,
                            'expectedIncome': income,
                            'expectedExpense': expense,
                            'expectedBalance': income - expense,
                          });
                          ref.invalidate(forecastsProvider);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ToastService.showSuccess('Đã lưu dự báo dòng tiền');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                          }
                          ToastService.showError(
                            'Không thể lưu dự báo dòng tiền. Vui lòng thử lại sau.',
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: isSaving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Đang lưu...'),
                        ],
                      )
                    : const Text('Lưu dự báo'),
              ),
            ],
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    incomeC.dispose();
    expenseC.dispose();
  }
}

class _BudgetDateField extends StatelessWidget {
  const _BudgetDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(DateFormat('dd/MM/yyyy').format(value)),
      ),
    );
  }
}
