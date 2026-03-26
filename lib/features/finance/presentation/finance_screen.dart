import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _today = DateTime.now();
final _from = DateTime(_today.year, _today.month, 1).toIso8601String().split('T')[0];
final _to = _today.toIso8601String().split('T')[0];

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final summaryAsync = ref.watch(cashSummaryProvider((from: _from, to: _to)));
    final txAsync = ref.watch(transactionsProvider((page: 1, type: null, from: _from, to: _to)));

    return Scaffold(
      appBar: AppBar(title: Text('Tài chính')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashSummaryProvider);
          ref.invalidate(transactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Balance card
            summaryAsync.when(
              data: (data) {
                final balance = (data['balance'] ?? data['currentBalance'] ?? 0).toDouble();
                final income = (data['totalIncome'] ?? data['income'] ?? 0).toDouble();
                final expense = (data['totalExpense'] ?? data['expense'] ?? 0).toDouble();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Text('Số dư quỹ tiền mặt', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(_currFmt.format(balance), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Row(children: [
                        const Icon(Icons.arrow_downward, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Thu', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text(_currFmt.format(income), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                      ])),
                      Expanded(child: Row(children: [
                        const Icon(Icons.arrow_upward, size: 14, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Chi', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text(_currFmt.format(expense), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                      ])),
                    ]),
                  ]),
                );
              },
              loading: () => Container(height: 130, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
                child: const Center(child: CircularProgressIndicator(color: Colors.white))),
              error: (e, _) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12))),
            ),
            const SizedBox(height: 20),
            Text('Báo cáo & Công cụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _NavCard('Báo cáo KQKD (Lãi/Lỗ)', Icons.analytics, () => context.go('/profit-loss')),
            _NavCard('Phân tích Tuổi nợ', Icons.pie_chart, () => context.go('/debt-aging')),
            _NavCard('Quản lý Hóa đơn', Icons.receipt_long, () => context.go('/invoices')),
            _NavCard('Bảng kê mua không HĐ', Icons.description, () => context.go('/purchases-no-invoice')),
            _NavCard('Dự báo dòng tiền', Icons.show_chart, () => context.go('/cashflow-forecast')),
            _NavCard('Chốt sổ cuối ngày', Icons.check_circle, () => context.go('/daily-closing')),
            _NavCard('Tính thuế HKD', Icons.calculate, () => context.go('/tax-calculator')),
            _NavCard('Sổ chi phí SXKD', Icons.account_balance_wallet, () => context.go('/expense-ledger')),
            _NavCard('Theo dõi nghĩa vụ thuế', Icons.gavel, () => context.go('/tax-obligations')),
            _NavCard('Sổ lương nhân viên', Icons.people, () => context.go('/salary-ledger')),
            _NavCard('Kê khai thuế', Icons.file_copy, () => context.go('/tax-declaration')),
            const SizedBox(height: 20),
            // Recent transactions
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Giao dịch gần đây', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton(onPressed: () => context.go('/transactions'), child: Text('Xem tất cả')),
            ]),
            txAsync.when(
              data: (data) {
                final items = (data['items'] as List?) ?? [];
                return Column(children: items.take(5).map((tx) {
                  final isIncome = tx['type'] == 'INCOME' || tx['type'] == 'income';
                  final amount = (tx['amount'] ?? 0).toDouble();
                  return Container(
                    margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: (isIncome ? AppColors.success : AppColors.danger).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, size: 18, color: isIncome ? AppColors.success : AppColors.danger)),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tx['description'] ?? tx['note'] ?? (isIncome ? 'Thu' : 'Chi'), style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        Text(tx['paymentMethod'] ?? '', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ])),
                      Text('${isIncome ? '+' : '-'}${_currFmt.format(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? AppColors.success : AppColors.danger)),
                    ]),
                  );
                }).toList());
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title; final IconData icon; final VoidCallback onTap;
  const _NavCard(this.title, this.icon, this.onTap);
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Icon(Icons.chevron_right, color: AppThemeColors.of(context).textMuted),
      ])));
}
