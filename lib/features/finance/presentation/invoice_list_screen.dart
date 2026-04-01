import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(invoiceListProvider((page: 1, type: null)));
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final to = now.toIso8601String().split('T').first;
    final summaryAsync = ref.watch(invoiceSummaryProvider((from: from, to: to)));

    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn'), actions: [featureGuideButton(context, 'invoices')]),
      body: invAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final items = (data['items'] as List?) ?? [];

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Summary card
            summaryAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, st) => const SizedBox(),
              data: (summary) {
                final vatIn = (summary['vatIn'] as num?) ?? 0;
                final vatOut = (summary['vatOut'] as num?) ?? 0;
                final vatOwed = (summary['vatOwed'] as num?) ?? 0;
                return Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Text('Thuế VAT tháng này', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      Column(children: [const Text('VAT đầu vào', style: TextStyle(fontSize: 11)), Text(_fmt(vatIn), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13))]),
                      Column(children: [const Text('VAT đầu ra', style: TextStyle(fontSize: 11)), Text(_fmt(vatOut), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13))]),
                      Column(children: [const Text('Phải nộp', style: TextStyle(fontSize: 11)), Text(_fmt(vatOwed), style: TextStyle(fontWeight: FontWeight.bold, color: vatOwed > 0 ? AppColors.danger : AppColors.success, fontSize: 13))]),
                    ]),
                  ]));
              },
            ),
            if (items.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [
              const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có hóa đơn nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm hóa đơn'), onPressed: () => _showAddDialog(context, ref)),
            ]))),
            if (items.isNotEmpty) ...[
              const Text('Danh sách hóa đơn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisExtent: 85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 0,
                ),
                itemBuilder: (_, i) {
                  final inv = items[i];
                  final isOut = inv['invoiceType'] == 'OUT';
                  return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (isOut ? AppColors.danger : AppColors.success).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(isOut ? Icons.arrow_upward : Icons.arrow_downward, color: isOut ? AppColors.danger : AppColors.success, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(inv['invoiceNumber'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(inv['partnerName'] ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)),
                        Text(inv['invoiceDate']?.toString().split('T').first ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_fmt((inv['totalAmount'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isOut ? AppColors.danger : AppColors.success)),
                        Text('VAT: ${_fmt((inv['taxAmount'] as num?) ?? 0)}', style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary)),
                      ]),
                    ]));
                },
              ),
            ],
          ]));
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context, ref), child: const Icon(Icons.add)),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final numC = TextEditingController();
    final partnerC = TextEditingController();
    final amountC = TextEditingController();
    final vatC = TextEditingController();
    String type = 'IN';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm hóa đơn'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: type, items: const [
          DropdownMenuItem(value: 'IN', child: Text('Đầu vào')),
          DropdownMenuItem(value: 'OUT', child: Text('Đầu ra')),
        ], onChanged: (v) => type = v ?? 'IN', decoration: const InputDecoration(labelText: 'Loại')),
        TextField(controller: numC, decoration: const InputDecoration(labelText: 'Số hóa đơn')),
        TextField(controller: partnerC, decoration: const InputDecoration(labelText: 'Đối tác')),
        TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Số tiền'), keyboardType: TextInputType.number),
        TextField(controller: vatC, decoration: const InputDecoration(labelText: 'VAT'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          await ref.read(financeRepoProvider).createInvoice({
            'invoiceType': type, 'invoiceNumber': numC.text, 'partnerName': partnerC.text,
            'subtotal': double.tryParse(amountC.text) ?? 0, 'taxAmount': double.tryParse(vatC.text) ?? 0,
            'totalAmount': (double.tryParse(amountC.text) ?? 0) + (double.tryParse(vatC.text) ?? 0),
            'invoiceDate': DateTime.now().toIso8601String().split('T').first,
          });
          ref.invalidate(invoiceListProvider);
          ref.invalidate(invoiceSummaryProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}
