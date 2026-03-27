import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class ProfitLossScreen extends ConsumerWidget {
  const ProfitLossScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final to = now.toIso8601String().split('T').first;
    final plAsync = ref.watch(profitLossProvider((from: from, to: to)));

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo KQKD'), actions: [featureGuideButton(context, 'profit_loss'), IconButton(icon: const Icon(Icons.date_range), onPressed: () {})]),
      body: plAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final revenue = (data['revenue'] as num?) ?? 0;
          final cogs = (data['cogs'] as num?) ?? 0;
          final grossProfit = (data['grossProfit'] as num?) ?? 0;
          final expenses = (data['expenses'] as num?) ?? 0;
          final netProfit = (data['netProfit'] as num?) ?? 0;
          final grossPct = revenue > 0 ? (grossProfit / revenue * 100).toStringAsFixed(1) : '0.0';
          final netPct = revenue > 0 ? (netProfit / revenue * 100).toStringAsFixed(1) : '0.0';

          if (revenue == 0 && cogs == 0 && expenses == 0) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.assessment_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Chưa có dữ liệu giao dịch', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Thêm giao dịch thu/chi để xem báo cáo KQKD', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ]));
          }

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.calendar_today, size: 16, color: AppColors.primary), const SizedBox(width: 8), Text('$from → $to', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500))])),
            const SizedBox(height: 16),
            _MetricCard('Tổng doanh thu', _fmt(revenue), AppColors.primary, Icons.trending_up),
            _MetricCard('Giá vốn hàng bán', _fmt(cogs), AppColors.danger, Icons.shopping_cart),
            Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_graph, color: AppColors.success, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Lãi gộp', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)), Text(_fmt(grossProfit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text('$grossPct%', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13))),
              ])),
            _MetricCard('Chi phí vận hành', _fmt(expenses), AppColors.warning, Icons.settings),
            Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.stars, color: AppColors.primaryLight, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Lợi nhuận ròng', style: TextStyle(color: Colors.white70, fontSize: 12)), Text(_fmt(netProfit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white))])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: Text('$netPct%', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13))),
              ])),
            const SizedBox(height: 16),
            const Text('Chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _DetailRow('Thu nhập bán hàng', _fmt(revenue), true),
            _DetailRow('Chi phí nhập hàng', _fmt(cogs), false),
            _DetailRow('Chi phí vận hành', _fmt(expenses), false),
          ]));
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value; final Color color; final IconData icon;
  const _MetricCard(this.label, this.value, this.color, this.icon);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 12)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color))])),
    ]));
}

class _DetailRow extends StatelessWidget {
  final String label, amount; final bool isIncome;
  const _DetailRow(this.label, this.amount, this.isIncome);
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 13)), Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? AppColors.success : AppColors.danger))]));
}
