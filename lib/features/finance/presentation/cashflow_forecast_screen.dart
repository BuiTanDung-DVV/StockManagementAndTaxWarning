import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class CashflowForecastScreen extends ConsumerWidget {
  const CashflowForecastScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastsProvider);
    final budgetAsync = ref.watch(budgetPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dự báo dòng tiền'), actions: [featureGuideButton(context, 'cashflow_forecast')]),
      body: forecastAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (forecasts) {
          return budgetAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi: $e')),
            data: (budgets) {
              if (forecasts.isEmpty && budgets.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timeline_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Chưa có dữ liệu dự báo', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm dự báo'), onPressed: () => _showAddForecastDialog(context, ref)),
                ]));
              }
              return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (forecasts.isNotEmpty) ...[
                  const Text('Dự báo theo ngày', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...forecasts.map<Widget>((f) {
                    final income = (f['expectedIncome'] as num?) ?? 0;
                    final expense = (f['expectedExpense'] as num?) ?? 0;
                    final balance = (f['expectedBalance'] as num?) ?? (income - expense);
                    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(f['forecastDate']?.toString().split('T').first ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(_fmt(balance), style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? AppColors.success : AppColors.danger)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text('Thu: ${_fmt(income)}', style: const TextStyle(fontSize: 12, color: AppColors.success)),
                          const SizedBox(width: 16),
                          Text('Chi: ${_fmt(expense)}', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                        ]),
                      ]));
                  }),
                ],
                if (budgets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Ngân sách', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...budgets.map<Widget>((b) {
                    final plannedIncome = (b['plannedIncome'] as num?) ?? 0;
                    final actualIncome = (b['actualIncome'] as num?) ?? 0;
                    final plannedExpense = (b['plannedExpense'] as num?) ?? 0;
                    final actualExpense = (b['actualExpense'] as num?) ?? 0;
                    final pct = plannedIncome > 0 ? (actualIncome / plannedIncome) : 0.0;
                    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Kế hoạch thu: ${_fmt(plannedIncome)}', style: const TextStyle(fontSize: 12)),
                          Text('Thực tế: ${_fmt(actualIncome)}', style: TextStyle(fontSize: 12, color: actualIncome >= plannedIncome ? AppColors.success : AppColors.warning)),
                        ]),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: pct.clamp(0, 1).toDouble(), backgroundColor: AppColors.primary.withValues(alpha: 0.1), color: pct >= 1 ? AppColors.success : AppColors.primary),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Kế hoạch chi: ${_fmt(plannedExpense)}', style: const TextStyle(fontSize: 12)),
                          Text('Thực tế: ${_fmt(actualExpense)}', style: TextStyle(fontSize: 12, color: actualExpense <= plannedExpense ? AppColors.success : AppColors.danger)),
                        ]),
                      ]));
                  }),
                ],
              ]));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddForecastDialog(context, ref), child: const Icon(Icons.add)),
    );
  }

  void _showAddForecastDialog(BuildContext context, WidgetRef ref) {
    final incomeC = TextEditingController();
    final expenseC = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Thêm dự báo'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(DateFormat('dd/MM/yyyy').format(selectedDate)), trailing: const Icon(Icons.calendar_today), onTap: () async {
          final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
          if (d != null) selectedDate = d;
        }),
        TextField(controller: incomeC, decoration: const InputDecoration(labelText: 'Thu dự kiến'), keyboardType: TextInputType.number),
        TextField(controller: expenseC, decoration: const InputDecoration(labelText: 'Chi dự kiến'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () async {
          final income = double.tryParse(incomeC.text) ?? 0;
          final expense = double.tryParse(expenseC.text) ?? 0;
          await ref.read(financeRepoProvider).createForecast({
            'forecastDate': selectedDate.toIso8601String().split('T').first,
            'expectedIncome': income, 'expectedExpense': expense, 'expectedBalance': income - expense,
          });
          ref.invalidate(forecastsProvider);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Lưu')),
      ],
    ));
  }
}
