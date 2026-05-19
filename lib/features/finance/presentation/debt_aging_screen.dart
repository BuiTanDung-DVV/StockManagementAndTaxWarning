import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../customers/providers/customer_provider.dart';

class DebtAgingScreen extends ConsumerWidget {
  const DebtAgingScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOf = DateTime.now().toIso8601String().split('T').first;
    final agingAsync = ref.watch(debtAgingProvider(asOf));
    final overdueAsync = ref.watch(overdueDebtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phân tích Tuổi nợ'), actions: [featureGuideButton(context, 'debt_aging'), IconButton(icon: const Icon(Icons.file_download), onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xuất báo cáo PDF/Excel sẽ sớm khả dụng'), duration: Duration(seconds: 2)));
      })]),
      body: agingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (agingData) {
          final buckets = agingData['buckets'] as Map<String, dynamic>? ?? {};
          final summary = agingData['summary'] as Map<String, dynamic>? ?? {};
          final customers = (agingData['customers'] as List?) ?? const [];
          final totalDebt = asNum(agingData['totalDebt']);
          final current = asNum(buckets['current']);
          final days30 = asNum(buckets['past30'] ?? buckets['days30']);
          final days60 = asNum(buckets['past60'] ?? buckets['days60']);
          final over90 = asNum(buckets['past90'] ?? buckets['over90']);

          if (totalDebt == 0) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
              const SizedBox(height: 12),
              const Text('Không có nợ phải thu', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ]));
          }

          double pct(num v) => totalDebt > 0 ? v / totalDebt * 100 : 0;

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('Tổng nợ phải thu', style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_fmt(totalDebt), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 8),
                Text('Nợ quá hạn: ${(asNum(summary['overdueRatio']) * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppColors.danger)),
              ])),
            const SizedBox(height: 16),
            const Text('Phân loại theo thời hạn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _AgingBar('Chưa đến hạn', current / (totalDebt > 0 ? totalDebt : 1) * 100, _fmt(current), '${pct(current).toStringAsFixed(1)}%', AppColors.success),
            _AgingBar('1-30 ngày', days30 / (totalDebt > 0 ? totalDebt : 1) * 100, _fmt(days30), '${pct(days30).toStringAsFixed(1)}%', AppColors.info),
            _AgingBar('31-60 ngày', days60 / (totalDebt > 0 ? totalDebt : 1) * 100, _fmt(days60), '${pct(days60).toStringAsFixed(1)}%', AppColors.warning),
            _AgingBar('> 60 ngày', over90 / (totalDebt > 0 ? totalDebt : 1) * 100, _fmt(over90), '${pct(over90).toStringAsFixed(1)}%', AppColors.danger),
            if (customers.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Top khách hàng nợ cao', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...customers.take(5).map<Widget>((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['customerName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Quá hạn tối đa: ${item['overdueDays'] ?? 0} ngày', style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary)),
                        ]),
                      ),
                      Text(_fmt(asNum(item['total'])), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),
            const Text('KH nợ quá hạn lâu nhất', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            overdueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi: $e'),
              data: (overdueItems) {
                if (overdueItems.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(16), child: Text('Không có khách hàng nợ quá hạn', style: TextStyle(color: Colors.grey)));
                }
                return Column(children: overdueItems.take(10).map<Widget>((item) {
                  return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
                    child: Row(children: [
                      CircleAvatar(radius: 20, backgroundColor: AppColors.danger.withValues(alpha: 0.15),
                        child: Text((item['customerName'] ?? '?')[0], style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['customerName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${_fmt(asNum(item['remaining']))} • ${item['daysOverdue'] ?? 0} ngày quá hạn', style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                      ])),
                      ElevatedButton.icon(
                        onPressed: () => _showRemindDialog(context, item['customerName'] ?? '', _fmt(asNum(item['remaining']))),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                        icon: const Icon(Icons.message, size: 14), label: const Text('Nhắc nợ', style: TextStyle(fontSize: 11))),
                    ]));
                }).toList());
              },
            ),
          ]));
        },
      ),
    );
  }
}

void _showRemindDialog(BuildContext context, String customerName, String debtAmount) {
  final c = AppThemeColors.of(context);
  showDialog(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: c.surface,
    title: const Text('Gửi tin nhắn nhắc nợ'),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Khách hàng: $customerName', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Số tiền nợ: $debtAmount', style: const TextStyle(color: AppColors.danger)),
      const SizedBox(height: 16),
      const Text('Chọn phương thức gửi:'),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildMethodBtn(context, Icons.sms, 'SMS', Colors.blue),
        _buildMethodBtn(context, Icons.chat, 'Zalo', Colors.lightBlue),
        _buildMethodBtn(context, Icons.email, 'Email', Colors.redAccent),
      ]),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Đóng', style: TextStyle(color: c.textSecondary)))],
  ));
}

Widget _buildMethodBtn(BuildContext context, IconData icon, String label, Color color) {
  return InkWell(
    onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã mở $label để gửi tin nhắn nhắc nợ!'), backgroundColor: AppColors.success)); },
    borderRadius: BorderRadius.circular(8),
    child: Padding(padding: const EdgeInsets.all(8.0), child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(icon, color: color)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ])),
  );
}

class _AgingBar extends StatelessWidget {
  final String label, amount, pct; final double widthPct; final Color color;
  const _AgingBar(this.label, this.widthPct, this.amount, this.pct, this.color);
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))]),
        Text(pct, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: widthPct / 100, backgroundColor: Colors.white.withValues(alpha: 0.05), color: color, minHeight: 6)),
      const SizedBox(height: 4),
      Text(amount, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]));
}
