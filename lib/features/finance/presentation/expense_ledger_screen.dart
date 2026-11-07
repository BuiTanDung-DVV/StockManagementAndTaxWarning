import '../../../core/widgets/app_page_header.dart';
import 'expense_ledger_content.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/widgets/business_date_field.dart';
import '../../../core/assets/app_assets.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../providers/finance_provider.dart';

class ExpenseLedgerScreen extends ConsumerWidget {
  const ExpenseLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expAsync = ref.watch(expensesByCategoryProvider);
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    final c = AppThemeColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        leading: AppNavigationBackLeading(onPressed: () => navigatePageBack(context)),
        title: const Text('Sổ chi phí'),
        actions: [
          featureGuideButton(context, 'expense_ledger'),
          if (compactLayout)
            AppPrimaryHeaderAction(
              label: 'Thêm chi phí',
              assetPath: AppAssets.add,
              heroTag: 'expense-add-compact',
              onPressed: () => _showAddExpenseDialog(context, ref),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: expAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppInlineError(
              message:
                  'Không thể tải sổ theo dõi chi phí. Vui lòng thử lại sau.',
              onRetry: () => ref.invalidate(expensesByCategoryProvider),
            ),
          ),
        ),
        data: (data) {
          final categories = (data['categories'] as List?) ?? [];
          final total = asNum(data['total']);
          final recentItems = (data['recentItems'] as List?) ?? [];

          if (categories.isEmpty && recentItems.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(expensesByCategoryProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 420,
                  child: Center(
                    child: AppEmpty(
                      visual: AppEmptyVisual.finance,
                      message: 'Chưa có chi phí nào',
                      action: ElevatedButton.icon(
                        icon: const AppIcon(Icons.money_off),
                        label: const Text('Thêm chi phí'),
                        onPressed: () => _showAddExpenseDialog(context, ref),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesByCategoryProvider);
            },
            child: ExpenseLedgerContent(
              total: total,
              categories: categories,
              recentItems: recentItems,
            ),
          );
        },
      ),
      floatingActionButton: compactLayout
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddExpenseDialog(context, ref),
              icon: const AppIcon(Icons.money_off),
              label: const Text('Thêm'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) => const _AddExpenseDialog());
  }
}

class _AddExpenseDialog extends ConsumerStatefulWidget {
  const _AddExpenseDialog();

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  late final TextEditingController amountC;
  late final TextEditingController noteC;
  String category = 'OTHER';
  DateTime _expenseDate = DateTime.now();
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    amountC = TextEditingController();
    noteC = TextEditingController();
  }

  @override
  void dispose() {
    amountC.dispose();
    noteC.dispose();
    super.dispose();
  }

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  Future<void> _submit() async {
    if (isSaving) return;
    final amount = parseCurrency(amountC.text);
    if (amount <= 0) {
      ToastService.showError('Số tiền chi phí phải lớn hơn 0');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(
      _expenseDate.year,
      _expenseDate.month,
      _expenseDate.day,
    );
    if (selectedDateOnly.isAfter(today)) {
      setState(() => errorMessage = 'Ngày chi không được ở tương lai.');
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await ref.read(financeRepoProvider).createTransaction({
        'type': 'EXPENSE',
        'category': category,
        'amount': amount,
        'transactionDate': _expenseDate.toIso8601String().split('T').first,
        'notes': noteC.text.trim(),
      });
      if (!mounted) return;
      refreshCashTransactionViews(ref);
      Navigator.pop(context);
      ToastService.showSuccess('Đã thêm khoản chi phí thành công');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        if (e is ApiException) {
          errorMessage = 'Không thể thêm khoản chi phí: ${e.message}';
        } else {
          errorMessage = 'Không thể thêm khoản chi phí. Vui lòng thử lại sau.';
        }
      });
      ToastService.showError(
        'Không thể thêm khoản chi phí. Vui lòng thử lại sau.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseCurrency(amountC.text);
    return PopScope(
      canPop: !isSaving,
      child: AlertDialog(
        title: const Text('Thêm chi phí'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(value: 'SALARY', child: Text('Lương')),
                  DropdownMenuItem(value: 'RENT', child: Text('Tiền thuê')),
                  DropdownMenuItem(value: 'UTILITIES', child: Text('Tiện ích')),
                  DropdownMenuItem(value: 'PURCHASE', child: Text('Mua hàng')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                ],
                onChanged: isSaving
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() => category = v);
                        }
                      },
                decoration: const InputDecoration(labelText: 'Danh mục'),
              ),
              const SizedBox(height: 8),
              BusinessDateField(
                label: 'Ngày chi',
                selectedDate: _expenseDate,
                enabled: !isSaving,
                onChanged: (date) {
                  setState(() {
                    _expenseDate = date;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountC,
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Số tiền *',
                  hintText: 'Nhập số tiền chi...',
                  suffixText: '₫',
                  helperText: parsed > 0 ? _fmt(parsed) : null,
                  helperStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteC,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  hintText: 'Nhập nội dung chi phí...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: isSaving ? null : _submit,
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
