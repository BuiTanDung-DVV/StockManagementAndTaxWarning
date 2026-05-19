import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../providers/finance_provider.dart';

class DailyClosingScreen extends ConsumerWidget {
  const DailyClosingScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final closingAsync = ref.watch(dailyClosingProvider(today));

    return Scaffold(
      appBar: AppBar(title: const Text('Kết ca hôm nay'), actions: [featureGuideButton(context, 'daily_closing')]),
      body: closingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final totalIncome = asNum(data['totalIncome']);
          final totalExpense = asNum(data['totalExpense']);
          final netProfit = totalIncome - totalExpense;
          final orderCount = (data['orderCount'] as num?) ?? 0;
          final closed = data['closed'] == true;
          final transactions = data['transactions'] as List? ?? [];

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24), 
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient, 
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(children: [
                Text(today, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(_fmt(netProfit), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('Lợi nhuận ròng', style: TextStyle(color: Colors.white70, fontSize: 14)),
                if (closed) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Text('Đã kết ca', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
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
                  Text(_fmt(asNum(t['amount'])), style: TextStyle(fontWeight: FontWeight.bold, color: t['type'] == 'INCOME' ? AppColors.success : AppColors.danger)),
                ]),
              )),
            ],
            if (transactions.isEmpty && !closed) const AppEmpty(message: 'Chưa có giao dịch hôm nay', size: 120),
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
