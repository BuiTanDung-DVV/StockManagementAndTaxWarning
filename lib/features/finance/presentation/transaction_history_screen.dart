import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/finance_display.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/reporting_period.dart';
import '../../../core/widgets/app_pagination_bar.dart';
import '../providers/finance_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  int _page = 1;
  String? _type;

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final period = currentMonthReportingPeriod(DateTime.now());
    final from = period.from;
    final to = period.to;
    final periodLabel = reportingCompactRangeLabel(
      DateTime.parse(from),
      DateTime.parse(to),
    );
    final txAsync = ref.watch(
      transactionsProvider((
        page: _page,
        limit: 20,
        type: _type,
        category: null,
        from: from,
        to: to,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        actions: [featureGuideButton(context, 'transaction_history')],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: c.card,
              border: Border(bottom: BorderSide(color: c.divider)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Phạm vi: $periodLabel',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final option in const <(String?, String)>[
                  (null, 'Tất cả'),
                  ('INCOME', 'Khoản thu'),
                  ('EXPENSE', 'Khoản chi'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _type == option.$1,
                    onSelected: (_) => setState(() {
                      _type = option.$1;
                      _page = 1;
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: txAsync.when(
              data: (data) {
                final items = (data['items'] as List?) ?? [];
                final currentPage = paginationValue(
                  data,
                  'page',
                  fallback: _page,
                );
                final totalPages = paginationValue(
                  data,
                  'totalPages',
                  fallback: 1,
                );
                final totalItems = paginationValue(
                  data,
                  'total',
                  fallback: items.length,
                );
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Không có giao dịch trong phạm vi đã chọn.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return AppPaginationBar(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        totalItems: totalItems,
                        itemLabel: 'giao dịch',
                        onPageChanged: (page) => setState(() => _page = page),
                      );
                    }
                    final tx = items[index];
                    final isIncome =
                        tx['type'] == 'INCOME' || tx['type'] == 'income';
                    final amount = asDouble(tx['amount']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              context.push('/transactions/detail', extra: tx),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        (isIncome
                                                ? AppColors.success
                                                : AppColors.danger)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    size: 18,
                                    color: isIncome
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        financeTransactionDescription(tx),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        financePaymentMethodLabel(
                                          tx['paymentMethod']?.toString(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isIncome ? '+' : '-'}${_currFmt.format(amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIncome
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
