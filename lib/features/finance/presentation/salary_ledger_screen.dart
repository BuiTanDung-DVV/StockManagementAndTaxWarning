import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../../../core/widgets/app_primary_floating_action.dart';
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

  String _fmt(num v) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(v);

  @override
  Widget build(BuildContext context) {
    final period = currentMonthReportingPeriod(DateTime.now());
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
    final compactLayout = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Sổ lương'),
        actions: [
          featureGuideButton(context, 'salary_ledger'),
          if (compactLayout)
            AppPrimaryHeaderAction(
              label: 'Thêm khoản lương',
              assetPath: AppAssets.add,
              heroTag: 'salary-add-compact',
              onPressed: () => _showAddDialog(context, ref),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          final totalSalary = asNum(data['filteredAmountTotal']);
          final totalTransactions = (data['total'] as num?)?.toInt() ?? 0;
          final currentPage = paginationValue(data, 'page', fallback: _page);
          final totalPages = paginationValue(data, 'totalPages', fallback: 1);

          if (items.isEmpty) {
            return AppEmpty(
              visual: AppEmptyVisual.finance,
              message: 'Chưa có chi lương nào',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text('Thêm chi lương'),
                onPressed: () => _showAddDialog(context, ref),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Tháng ${DateTime.now().month}/${DateTime.now().year}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmt(totalSalary),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Tổng chi lương',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalTransactions giao dịch',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Transaction list
                ...items.map<Widget>((t) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppThemeColors.of(context).card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Icon(
                            Icons.payments_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['counterparty'] ?? 'Nhân viên',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                t['notes'] ?? '',
                                style: TextStyle(
                                  color: AppThemeColors.of(
                                    context,
                                  ).textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                t['transactionDate']
                                        ?.toString()
                                        .split('T')
                                        .first ??
                                    '',
                                style: TextStyle(
                                  color: AppThemeColors.of(
                                    context,
                                  ).textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _fmt(asNum(t['amount'])),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                AppPaginationBar(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  totalItems: totalTransactions,
                  itemLabel: 'giao dịch lương',
                  onPageChanged: (page) => setState(() => _page = page),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: compactLayout
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, ref),
              icon: const Icon(Icons.payments),
              label: const Text('Thêm'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    final notesC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm chi lương'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Tên nhân viên'),
            ),
            TextField(
              controller: amountC,
              decoration: const InputDecoration(labelText: 'Số tiền'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: notesC,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountC.text) ?? 0;
              if (amount <= 0) {
                ToastService.showError('Vui lòng nhập số tiền hợp lệ (> 0)');
                return;
              }
              await ref.read(financeRepoProvider).createTransaction({
                'type': 'EXPENSE',
                'category': 'SALARY',
                'counterparty': nameC.text,
                'amount': amount,
                'notes': notesC.text.isEmpty ? 'Chi lương' : notesC.text,
                'transactionDate': DateTime.now()
                    .toIso8601String()
                    .split('T')
                    .first,
              });
              ref.invalidate(transactionsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
