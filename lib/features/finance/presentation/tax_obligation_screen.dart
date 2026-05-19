import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
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
          final totalOwed = asNum(data['totalOwed']);

          if (items.isEmpty) {
            return AppEmpty(
              message: 'Chưa có dữ liệu nghĩa vụ thuế',
              action: ElevatedButton.icon(icon: const Icon(Icons.account_balance), label: const Text('Thêm kỳ thuế'), onPressed: () => _showAddDialog(context, ref)),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F172A)]), borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  const Text('Tổng còn phải nộp', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_fmt(totalOwed), style: TextStyle(color: totalOwed > 0 ? const Color(0xFFFF6B6B) : AppColors.success, fontSize: 24, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 16),
              ...items.map<Widget>((t) {
                final id = t['id'] as int?;
                final status = t['status'] ?? 'pending';
                final statusColor = status == 'done' ? AppColors.success : status == 'overdue' ? AppColors.danger : AppColors.warning;
                final statusLabel = status == 'done' ? 'Hoàn thành' : status == 'overdue' ? 'Quá hạn' : status == 'partial' ? 'Một phần' : 'Chờ nộp';
                final vatDeclared = asNum(t['vatDeclared']);
                final pitDeclared = asNum(t['pitDeclared']);
                final vatPaid = asNum(t['vatPaid']);
                final pitPaid = asNum(t['pitPaid']);
                final remaining = (vatDeclared + pitDeclared) - (vatPaid + pitPaid);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(t['period'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          color: AppColors.primary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Sửa',
                          onPressed: () => _showEditDialog(context, ref, t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          color: AppColors.danger,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Xóa',
                          onPressed: id == null ? null : () => _confirmDelete(context, ref, id),
                        ),
                      ]),
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
                    if (remaining > 0)
                      Text('Còn lại: ${_fmt(remaining)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
                  ]),
                );
              }),
            ]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.account_balance),
        label: const Text('Thêm'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final periodC = TextEditingController(text: 'Q${((DateTime.now().month - 1) ~/ 3) + 1}/${DateTime.now().year}');
    final vatC = TextEditingController();
    final pitC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm kỳ thuế'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: periodC, decoration: const InputDecoration(labelText: 'Kỳ (VD: Q1/2026)')),
          TextField(controller: vatC, decoration: const InputDecoration(labelText: 'VAT phải nộp'), keyboardType: TextInputType.number),
          TextField(controller: pitC, decoration: const InputDecoration(labelText: 'TNCN phải nộp'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(financeRepoProvider).createTaxObligation({
                'period': periodC.text,
                'vatDeclared': double.tryParse(vatC.text) ?? 0,
                'pitDeclared': double.tryParse(pitC.text) ?? 0,
              });
              ref.invalidate(taxObligationsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    final id = t['id'] as int?;
    if (id == null) return;
    final periodC = TextEditingController(text: t['period']?.toString() ?? '');
    final vatC = TextEditingController(text: asNum(t['vatDeclared']).toString());
    final pitC = TextEditingController(text: asNum(t['pitDeclared']).toString());
    final vatPaidC = TextEditingController(text: asNum(t['vatPaid']).toString());
    final pitPaidC = TextEditingController(text: asNum(t['pitPaid']).toString());

    const statuses = ['pending', 'partial', 'done', 'overdue'];
    const statusLabels = {'pending': 'Chờ nộp', 'partial': 'Một phần', 'done': 'Hoàn thành', 'overdue': 'Quá hạn'};
    String selectedStatus = t['status']?.toString() ?? 'pending';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Sửa kỳ thuế'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: periodC, decoration: const InputDecoration(labelText: 'Kỳ (VD: Q1/2026)')),
              const SizedBox(height: 8),
              TextField(controller: vatC, decoration: const InputDecoration(labelText: 'VAT phải nộp'), keyboardType: TextInputType.number),
              TextField(controller: pitC, decoration: const InputDecoration(labelText: 'TNCN phải nộp'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: vatPaidC, decoration: const InputDecoration(labelText: 'VAT đã nộp'), keyboardType: TextInputType.number),
              TextField(controller: pitPaidC, decoration: const InputDecoration(labelText: 'TNCN đã nộp'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(statusLabels[s] ?? s))).toList(),
                onChanged: (v) => setDlg(() => selectedStatus = v ?? selectedStatus),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(financeRepoProvider).updateTaxObligation(id, {
                  'period': periodC.text,
                  'vatDeclared': double.tryParse(vatC.text) ?? 0,
                  'pitDeclared': double.tryParse(pitC.text) ?? 0,
                  'vatPaid': double.tryParse(vatPaidC.text) ?? 0,
                  'pitPaid': double.tryParse(pitPaidC.text) ?? 0,
                  'status': selectedStatus,
                });
                ref.invalidate(taxObligationsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa kỳ thuế'),
        content: const Text('Bạn có chắc chắn muốn xóa kỳ thuế này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(financeRepoProvider).deleteTaxObligation(id);
      ref.invalidate(taxObligationsProvider);
    }
  }
}
