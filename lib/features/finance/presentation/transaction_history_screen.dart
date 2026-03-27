import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _today = DateTime.now();
final _from = DateTime(_today.year, _today.month, 1).toIso8601String().split('T')[0];
final _to = _today.toIso8601String().split('T')[0];

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final txAsync = ref.watch(transactionsProvider((page: 1, type: null, from: _from, to: _to)));

    return Scaffold(
      appBar: AppBar(title: Text('Lịch sử Giao dịch'), actions: [featureGuideButton(context, 'transaction_history')]),
      body: txAsync.when(
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Không có giao dịch nào vớí thời gian này.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tx = items[index];
              final isIncome = tx['type'] == 'INCOME' || tx['type'] == 'income';
              final amount = (tx['amount'] ?? 0).toDouble();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, size: 18, color: isIncome ? AppColors.success : AppColors.danger),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx['description'] ?? tx['note'] ?? (isIncome ? 'Thu' : 'Chi'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(tx['paymentMethod'] ?? 'Tiền mặt', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ],
                    ),
                  ),
                  Text('${isIncome ? '+' : '-'}${_currFmt.format(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? AppColors.success : AppColors.danger)),
                ]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}
