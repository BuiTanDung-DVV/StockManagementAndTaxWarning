import 'package:go_router/go_router.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
import '../../../core/widgets/business_date_field.dart';
import '../../../core/network/api_client.dart';
import '../providers/finance_provider.dart';

/// Salary Ledger — shows SALARY-category cash transactions.
/// Employee management was removed; this screen now tracks salary payments
/// through the cash transaction system.
class SalaryLedgerScreen extends ConsumerStatefulWidget {
  const SalaryLedgerScreen({super.key});

  @override
  ConsumerState<SalaryLedgerScreen> createState() => _SalaryLedgerScreenState();
}

class _SalaryLedgerScreenState extends ConsumerState<SalaryLedgerScreen> {
  int _page = 1;
  DateTime _displayMonth = DateTime.now();

  String _fmt(num value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(value);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final now = DateTime.now();
    final isCurrentMonth =
        _displayMonth.year == now.year && _displayMonth.month == now.month;
    final endDate = isCurrentMonth
        ? DateTime(now.year, now.month, now.day)
        : DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final period = currentMonthReportingPeriod(endDate);
    final txAsync = ref.watch(
      transactionsProvider((
        page: _page,
        limit: 20,
        type: 'EXPENSE',
        category: 'SALARY',
        from: period.from,
        to: period.to,
      )),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxWidth < 720;
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compactLayout ? 16 : 24,
                    12,
                    compactLayout ? 16 : 24,
                    0,
                  ),
                  child: AppPageHeader(
                    title: 'Sổ lương',
                    subtitle:
                        'Theo dõi tiền lương và tạm ứng đã chi; không thay thế bảng tính lương hoặc chấm công.',
                    showBackButton: true,
                    dense: true,
                    titleStyle: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    action: Wrap(
                      spacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        featureGuideButton(context, 'salary_ledger'),
                        AppPrimaryPageAction(
                          label: 'Thêm chi lương',
                          assetPath: AppAssets.add,
                          onPressed: () => _showAddDialog(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compactLayout ? 16 : 24,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Tháng trước',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                          ),
                          icon: const AppIcon(Icons.chevron_left, size: 20),
                          onPressed:
                              (_displayMonth.year == 1 &&
                                  _displayMonth.month == 1)
                              ? null
                              : () => _changeMonth(-1),
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Tháng ${_displayMonth.month}/${_displayMonth.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tháng sau',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                          ),
                          icon: const AppIcon(Icons.chevron_right, size: 20),
                          onPressed: isCurrentMonth
                              ? null
                              : () => _changeMonth(1),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: txAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AppInlineError(
                          message:
                              'Không thể tải sổ theo dõi lương. Vui lòng thử lại sau.',
                          onRetry: () => ref.invalidate(transactionsProvider),
                        ),
                      ),
                    ),
                    data: (data) {
                      final items = (data['items'] as List?) ?? [];
                      if (items.isEmpty) {
                        return AppEmpty(
                          visual: AppEmptyVisual.finance,
                          message:
                              'Chưa có khoản chi lương trong tháng ${DateFormat('MM/yyyy').format(_displayMonth)}',
                          action: ElevatedButton.icon(
                            icon: const AppIcon(Icons.payments),
                            label: const Text('Thêm chi lương'),
                            onPressed: () => _showAddDialog(context, ref),
                          ),
                        );
                      }
                      return _buildLedger(
                        items,
                        asNum(data['filteredAmountTotal']),
                        (data['total'] as num?)?.toInt() ?? 0,
                        paginationValue(data, 'page', fallback: _page),
                        paginationValue(data, 'totalPages', fallback: 1),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + offset,
      );
      _page = 1;
    });
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString().split('T').first ?? '');
    return date == null ? '—' : DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildLedger(
    List items,
    num total,
    int count,
    int page,
    int totalPages,
  ) {
    final c = AppThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableLayout = constraints.maxWidth >= 720;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tableLayout ? 24 : 16,
            8,
            tableLayout ? 24 : 16,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border.all(color: c.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng chi lương',
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fmt(total),
                          style: TextStyle(
                            color: c.primary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$count khoản chi',
                      style: TextStyle(color: c.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border.all(color: c.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (tableLayout)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.labelMedium!
                              .copyWith(
                                color: c.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                          child: _tableColumns(
                            const Text('Ngày chi'),
                            const Text('Người nhận'),
                            const Text('Ghi chú'),
                            const Text('Số tiền', textAlign: TextAlign.right),
                          ),
                        ),
                      ),
                    for (var index = 0; index < items.length; index++) ...[
                      if (tableLayout || index > 0)
                        Divider(height: 1, color: c.divider),
                      InkWell(
                        onTap: () =>
                            context.push('/transactions/${items[index]['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildTransaction(
                            items[index] as Map,
                            tableLayout,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AppPaginationBar(
                currentPage: page,
                totalPages: totalPages,
                totalItems: count,
                itemLabel: 'khoản chi lương',
                onPageChanged: (page) => setState(() => _page = page),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableColumns(Widget date, Widget name, Widget notes, Widget amount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: date),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: name),
        const SizedBox(width: 16),
        Expanded(flex: 4, child: notes),
        const SizedBox(width: 16),
        SizedBox(width: 140, child: amount),
      ],
    );
  }

  Widget _buildTransaction(Map transaction, bool tableLayout) {
    final c = AppThemeColors.of(context);
    final name = transaction['counterparty']?.toString() ?? 'Nhân viên';
    final notes = transaction['notes']?.toString().trim() ?? '';
    final date = _dateLabel(transaction['transactionDate']);
    final money = Text(
      _fmt(asNum(transaction['amount'])),
      textAlign: TextAlign.right,
      style: TextStyle(
        color: c.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
    final employee = Text(
      name,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
    if (tableLayout) {
      return _tableColumns(
        Text(date, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        employee,
        Text(
          notes.isEmpty ? '—' : notes,
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        money,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stacked) ...[
              employee,
              const SizedBox(height: 4),
              money,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: employee),
                  const SizedBox(width: 12),
                  Flexible(flex: 2, child: money),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              '$date${notes.isEmpty ? '' : ' · $notes'}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => const _AddSalaryDialog(),
    );
    if (mounted && result != null) {
      setState(() {
        _displayMonth = result;
        _page = 1;
      });
    }
  }
}

class _AddSalaryDialog extends ConsumerStatefulWidget {
  const _AddSalaryDialog();

  @override
  ConsumerState<_AddSalaryDialog> createState() => _AddSalaryDialogState();
}

class _AddSalaryDialogState extends ConsumerState<_AddSalaryDialog> {
  late final TextEditingController nameC;
  late final TextEditingController amountC;
  late final TextEditingController notesC;
  DateTime _expenseDate = DateTime.now();
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    nameC = TextEditingController();
    amountC = TextEditingController();
    notesC = TextEditingController();
  }

  @override
  void dispose() {
    nameC.dispose();
    amountC.dispose();
    notesC.dispose();
    super.dispose();
  }

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  Future<void> _submit() async {
    if (isSubmitting) return;

    final empName = nameC.text.trim();
    if (empName.isEmpty) {
      ToastService.showError('Vui lòng nhập tên nhân viên');
      return;
    }
    final amount = parseCurrency(amountC.text);
    if (amount <= 0) {
      ToastService.showError('Vui lòng nhập số tiền hợp lệ (> 0)');
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
      setState(() => errorMessage = 'Ngày chi lương không được ở tương lai.');
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    try {
      await ref.read(financeRepoProvider).createTransaction({
        'type': 'EXPENSE',
        'category': 'SALARY',
        'counterparty': empName,
        'amount': amount,
        'notes': notesC.text.trim().isEmpty ? 'Chi lương' : notesC.text.trim(),
        'transactionDate': _expenseDate.toIso8601String().split('T').first,
      });
      if (!mounted) return;
      refreshCashTransactionViews(ref);
      ToastService.showSuccess('Đã ghi nhận chi lương cho $empName');
      Navigator.pop(context, _expenseDate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSubmitting = false;
        if (e is ApiException) {
          errorMessage = 'Không thể thêm chi lương: ${e.message}';
        } else {
          errorMessage = 'Không thể thêm chi lương. Vui lòng thử lại sau.';
        }
      });
      ToastService.showError('Không thể thêm chi lương. Vui lòng thử lại sau.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedAmount = parseCurrency(amountC.text);

    return PopScope(
      canPop: !isSubmitting,
      child: AlertDialog(
        title: const Text('Thêm chi lương'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
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
                TextField(
                  controller: nameC,
                  enabled: !isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhân viên *',
                    hintText: 'Nhập họ tên nhân viên',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountC,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Số tiền *',
                    hintText: 'Ví dụ: 10.000.000',
                    suffixText: '₫',
                    helperText: parsedAmount > 0 ? _fmt(parsedAmount) : null,
                    helperStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                BusinessDateField(
                  label: 'Ngày chi lương',
                  selectedDate: _expenseDate,
                  enabled: !isSubmitting,
                  onChanged: (date) {
                    setState(() {
                      _expenseDate = date;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesC,
                  enabled: !isSubmitting,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Lương tháng hoặc tạm ứng...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: isSubmitting ? null : _submit,
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
