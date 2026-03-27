import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

/// Salary Ledger — shows SALARY-category cash transactions.
/// Employee management was removed; this screen now tracks salary payments
/// through the cash transaction system.
class SalaryLedgerScreen extends ConsumerWidget {
  const SalaryLedgerScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch SALARY-type expense transactions
    final txAsync = ref.watch(transactionsProvider((page: 1, type: 'EXPENSE', from: null, to: null)));

    return Scaffold(
      appBar: AppBar(title: const Text('Sổ lương'), actions: [featureGuideButton(context, 'salary_ledger')]),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final allItems = (data['items'] as List?) ?? [];
          // Filter only SALARY category
          final items = allItems.where((t) => t['category'] == 'SALARY').toList();

          final totalSalary = items.fold<num>(0, (s, t) => s + ((t['amount'] as num?) ?? 0));

          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có chi lương nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm chi lương'), onPressed: () => _showAddDialog(context, ref)),
            ]));
          }

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Summary header
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('Tháng ${DateTime.now().month}/${DateTime.now().year}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_fmt(totalSalary), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Tổng chi lương', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('${items.length} giao dịch', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
              ])),
            const SizedBox(height: 16),
            // Transaction list
            ...items.map<Widget>((t) {
              return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  CircleAvatar(radius: 20, backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.payments_outlined, color: AppColors.primary, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['counterparty'] ?? 'Nhân viên', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(t['notes'] ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)),
                    Text(t['transactionDate']?.toString().split('T').first ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                  ])),
                  Text(_fmt((t['amount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger)),
                ]));
            }),
          ]));
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context, ref), child: const Icon(Icons.add)),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final amountC = TextEditingController();
    final notesC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm chi lương'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Tên nhân viên')),
        TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Số tiền'), keyboardType: TextInputType.number),
        TextField(controller: notesC, decoration: const InputDecoration(labelText: 'Ghi chú')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          await ref.read(financeRepoProvider).createTransaction({
            'type': 'EXPENSE', 'category': 'SALARY',
            'counterparty': nameC.text,
            'amount': double.tryParse(amountC.text) ?? 0,
            'notes': notesC.text.isEmpty ? 'Chi lương' : notesC.text,
            'transactionDate': DateTime.now().toIso8601String().split('T').first,
          });
          ref.invalidate(transactionsProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}
