import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class DailyClosingScreen extends ConsumerWidget {
  const DailyClosingScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final closingAsync = ref.watch(dailyClosingProvider(today));

    return Scaffold(
      appBar: AppBar(title: const Text('Kết ca hôm nay')),
      body: closingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final totalIncome = (data['totalIncome'] as num?) ?? 0;
          final totalExpense = (data['totalExpense'] as num?) ?? 0;
          final netProfit = totalIncome - totalExpense;
          final orderCount = (data['orderCount'] as num?) ?? 0;
          final closed = data['closed'] == true;
          final transactions = data['transactions'] as List? ?? [];

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(today, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(_fmt(netProfit), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('Lợi nhuận ròng', style: TextStyle(color: Colors.white54, fontSize: 12)),
                if (closed) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Text('Đã kết ca', style: TextStyle(color: AppColors.success, fontSize: 12))),
              ])),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _SummaryTile('Tổng thu', _fmt(totalIncome), AppColors.success, Icons.arrow_downward)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryTile('Tổng chi', _fmt(totalExpense), AppColors.danger, Icons.arrow_upward)),
            ]),
            const SizedBox(height: 10),
            _SummaryTile('Số đơn hàng', '$orderCount', AppColors.primary, Icons.receipt_long),
            const SizedBox(height: 16),
            if (transactions.isNotEmpty) ...[
              const Text('Giao dịch trong ngày', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...transactions.map<Widget>((t) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['category'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(t['counterparty'] ?? '', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)),
                  ]),
                  Text(_fmt((t['amount'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: t['type'] == 'INCOME' ? AppColors.success : AppColors.danger)),
                ]),
              )),
            ],
            if (transactions.isEmpty && !closed) Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [
              const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Chưa có giao dịch hôm nay', style: TextStyle(color: Colors.grey)),
            ]))),
          ]));
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value; final Color color; final IconData icon;
  const _SummaryTile(this.label, this.value, this.color, this.icon);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color))])),
    ]));
}
