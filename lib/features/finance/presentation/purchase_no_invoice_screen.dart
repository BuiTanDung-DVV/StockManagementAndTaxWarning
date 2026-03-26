import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class PurchaseNoInvoiceScreen extends ConsumerWidget {
  const PurchaseNoInvoiceScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnAsync = ref.watch(purchasesNoInvoiceProvider(1));

    return Scaffold(
      appBar: AppBar(title: const Text('Mua hàng không hóa đơn')),
      body: pnAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          final totalAmount = (data['totalAmount'] as num?) ?? 0;

          if (items.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có bảng kê nào', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm bảng kê'), onPressed: () => _showAddDialog(context, ref)),
            ]));
          }

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Tổng giá trị', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_fmt(totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              ])),
            const SizedBox(height: 12),
            ...items.map<Widget>((p) {
              return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(p['recordCode'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(_fmt((p['totalAmount'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${p['sellerName'] ?? ''} ${p['sellerIdentityNumber'] != null ? '• CCCD: ${p['sellerIdentityNumber']}' : ''}', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)),
                  Text(p['purchaseDate']?.toString().split('T').first ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 11)),
                ]));
            }),
          ]));
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context, ref), child: const Icon(Icons.add)),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final sellerC = TextEditingController();
    final idC = TextEditingController();
    final amountC = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm bảng kê'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: sellerC, decoration: const InputDecoration(labelText: 'Tên người bán')),
        TextField(controller: idC, decoration: const InputDecoration(labelText: 'CCCD người bán')),
        TextField(controller: amountC, decoration: const InputDecoration(labelText: 'Số tiền'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          await ref.read(financeRepoProvider).createPurchaseNoInvoice({
            'sellerName': sellerC.text, 'sellerIdentityNumber': idC.text,
            'totalAmount': double.tryParse(amountC.text) ?? 0,
            'purchaseDate': DateTime.now().toIso8601String().split('T').first,
          });
          ref.invalidate(purchasesNoInvoiceProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}


