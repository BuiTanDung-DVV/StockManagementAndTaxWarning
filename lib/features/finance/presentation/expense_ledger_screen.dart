import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class ExpenseLedgerScreen extends ConsumerWidget {
  const ExpenseLedgerScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expAsync = ref.watch(expensesByCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sổ chi phí')),
      body: expAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final categories = (data['categories'] as List?) ?? [];
          final total = (data['total'] as num?) ?? 0;
          final recentItems = (data['recentItems'] as List?) ?? [];

          if (categories.isEmpty && recentItems.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.money_off_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có chi phí nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm chi phí'), onPressed: () => _showAddExpenseDialog(context, ref)),
            ]));
          }

          final catColors = [AppColors.primary, AppColors.danger, AppColors.warning, AppColors.success, const Color(0xFF8B5CF6), const Color(0xFFEC4899)];

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                const Text('Tổng chi phí tháng này', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_fmt(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ])),
            const SizedBox(height: 16),
            const Text('Theo danh mục', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...categories.asMap().entries.map<Widget>((entry) {
              final c = entry.value;
              final color = catColors[entry.key % catColors.length];
              final pct = total > 0 ? ((c['amount'] as num) / total * 100).toStringAsFixed(1) : '0';
              return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Container(width: 4, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_categoryLabel(c['category']), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text('${c['count']} giao dịch', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_fmt((c['amount'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                    Text('$pct%', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                  ]),
                ]));
            }),
            if (recentItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Giao dịch gần đây', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...recentItems.map<Widget>((t) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['counterparty'] ?? _categoryLabel(t['category']), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(t['transactionDate']?.toString().split('T').first ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                  ]),
                  Text(_fmt((t['amount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
                ]))),
            ],
          ]));
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddExpenseDialog(context, ref), child: const Icon(Icons.add)),
    );
  }

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'SALARY': return 'Lương nhân viên';
      case 'RENT': return 'Tiền thuê';
      case 'UTILITIES': return 'Tiện ích';
      case 'PURCHASE': return 'Mua hàng';
      case 'OTHER': return 'Khác';
      default: return cat ?? 'Khác';
    }
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String category = 'OTHER';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm chi phí'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: category, items: const [
          DropdownMenuItem(value: 'SALARY', child: Text('Lương')),
          DropdownMenuItem(value: 'RENT', child: Text('Tiền thuê')),
          DropdownMenuItem(value: 'UTILITIES', child: Text('Tiện ích')),
          DropdownMenuItem(value: 'PURCHASE', child: Text('Mua hàng')),
          DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
        ], onChanged: (v) => category = v ?? 'OTHER', decoration: const InputDecoration(labelText: 'Danh mục')),
        TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Số tiền'), keyboardType: TextInputType.number),
        TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Ghi chú')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          await ref.read(financeRepoProvider).createTransaction({
            'type': 'EXPENSE', 'category': category, 'amount': double.tryParse(amountC.text) ?? 0,
            'transactionDate': DateTime.now().toIso8601String().split('T').first, 'notes': noteC.text,
          });
          ref.invalidate(expensesByCategoryProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}
