import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class TaxObligationScreen extends ConsumerWidget {
  const TaxObligationScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxAsync = ref.watch(taxObligationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nghĩa vụ thuế'), actions: [featureGuideButton(context, 'tax_obligations')]),
      body: taxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          final totalOwed = (data['totalOwed'] as num?) ?? 0;

          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có dữ liệu nghĩa vụ thuế', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm kỳ thuế'), onPressed: () => _showAddDialog(context, ref)),
            ]));
          }

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                const Text('Tổng còn phải nộp', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_fmt(totalOwed), style: TextStyle(color: totalOwed > 0 ? const Color(0xFFFF6B6B) : AppColors.success, fontSize: 24, fontWeight: FontWeight.bold)),
              ])),
            const SizedBox(height: 16),
            ...items.map<Widget>((t) {
              final status = t['status'] ?? 'pending';
              final statusColor = status == 'done' ? AppColors.success : status == 'overdue' ? AppColors.danger : AppColors.warning;
              final statusLabel = status == 'done' ? 'Hoàn thành' : status == 'overdue' ? 'Quá hạn' : status == 'partial' ? 'Một phần' : 'Chờ nộp';
              final vatDeclared = (t['vatDeclared'] as num?) ?? 0;
              final pitDeclared = (t['pitDeclared'] as num?) ?? 0;
              final vatPaid = (t['vatPaid'] as num?) ?? 0;
              final pitPaid = (t['pitPaid'] as num?) ?? 0;
              final remaining = (vatDeclared + pitDeclared) - (vatPaid + pitPaid);

              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(t['period'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('VAT: ${_fmt(vatDeclared)}', style: const TextStyle(fontSize: 12)),
                    Text('Đã nộp: ${_fmt(vatPaid)}', style: TextStyle(fontSize: 12, color: vatPaid >= vatDeclared ? AppColors.success : AppColors.warning)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('TNCN: ${_fmt(pitDeclared)}', style: const TextStyle(fontSize: 12)),
                    Text('Đã nộp: ${_fmt(pitPaid)}', style: TextStyle(fontSize: 12, color: pitPaid >= pitDeclared ? AppColors.success : AppColors.warning)),
                  ]),
                  const SizedBox(height: 6),
                  if (remaining > 0) Text('Còn lại: ${_fmt(remaining)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
                ]));
            }),
          ]));
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context, ref), child: const Icon(Icons.add)),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final periodC = TextEditingController(text: 'Q${((DateTime.now().month - 1) ~/ 3) + 1}/${DateTime.now().year}');
    final vatC = TextEditingController();
    final pitC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm kỳ thuế'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: periodC, decoration: const InputDecoration(labelText: 'Kỳ (VD: Q1/2026)')),
        TextField(controller: vatC, decoration: const InputDecoration(labelText: 'VAT phải nộp'), keyboardType: TextInputType.number),
        TextField(controller: pitC, decoration: const InputDecoration(labelText: 'TNCN phải nộp'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          await ref.read(financeRepoProvider).createTaxObligation({
            'period': periodC.text, 'vatDeclared': double.tryParse(vatC.text) ?? 0, 'pitDeclared': double.tryParse(pitC.text) ?? 0,
          });
          ref.invalidate(taxObligationsProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}
