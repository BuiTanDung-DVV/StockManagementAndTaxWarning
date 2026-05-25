import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/widgets/app_animations.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../providers/finance_provider.dart';

class TaxObligationScreen extends ConsumerWidget {
  const TaxObligationScreen({super.key});

  String _fmt(num v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    final taxAsync = ref.watch(taxObligationsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Theo dõi Nghĩa vụ thuế',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [featureGuideButton(context, 'tax_obligations')],
      ),
      body: taxAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: TextStyle(color: AppColors.danger))),
        data: (data) {
          final items = (data['items'] as List?) ?? [];
          final totalOwed = asNum(data['totalOwed']);

          if (items.isEmpty) {
            return AppEmpty(
              message: 'Chưa phát sinh dữ liệu nghĩa vụ thuế',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_rounded), 
                label: Text('Thêm kỳ thuế mới', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), 
                onPressed: () => _showAddDialog(context, ref)
              ),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Total Owed Header Card
                Container(
                  padding: const EdgeInsets.all(22),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        totalOwed > 0 ? AppColors.danger : AppColors.success,
                        (totalOwed > 0 ? AppColors.danger : AppColors.success).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (totalOwed > 0 ? AppColors.danger : AppColors.success).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TỔNG THUẾ CÒN PHẢI NỘP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), 
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _fmt(totalOwed),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Chi tiết các kỳ thuế',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 12),
                
                ...items.map<Widget>((t) {
                  final id = t['id'] as int?;
                  final status = t['status'] ?? 'pending';
                  final statusColor = status == 'done' 
                      ? AppColors.success 
                      : status == 'overdue' ? AppColors.danger : AppColors.warning;
                  final statusLabel = status == 'done' 
                      ? 'Hoàn thành' 
                      : status == 'overdue' ? 'Quá hạn' : status == 'partial' ? 'Một phần' : 'Chờ nộp';
                  final vatDeclared = asNum(t['vatDeclared']);
                  final pitDeclared = asNum(t['pitDeclared']);
                  final vatPaid = asNum(t['vatPaid']);
                  final pitPaid = asNum(t['pitPaid']);
                  final remaining = (vatDeclared + pitDeclared) - (vatPaid + pitPaid);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: c.divider.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t['period'] ?? 'Kỳ kê khai', 
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary)
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12), 
                                    borderRadius: BorderRadius.circular(30)
                                  ),
                                  child: Text(
                                    statusLabel, 
                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                                  color: theme.colorScheme.primary,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  tooltip: 'Chỉnh sửa',
                                  onPressed: () => _showEditDialog(context, ref, t),
                                  splashRadius: 20,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                                  color: AppColors.danger,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  tooltip: 'Xóa kỳ thuế',
                                  onPressed: id == null ? null : () => _confirmDelete(context, ref, id),
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        _taxRowItem('Thuế GTGT (VAT)', _fmt(vatDeclared), _fmt(vatPaid), vatPaid >= vatDeclared, c),
                        const SizedBox(height: 6),
                        _taxRowItem('Thuế TNCN', _fmt(pitDeclared), _fmt(pitPaid), pitPaid >= pitDeclared, c),
                        
                        if (remaining > 0) ...[
                          Divider(color: c.divider.withValues(alpha: 0.4), height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Còn phải nộp kỳ này:', 
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary)
                              ),
                              Text(
                                _fmt(remaining), 
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 14)
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.account_balance_rounded),
        label: Text('Khai thuế mới', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _taxRowItem(String label, String declared, String paid, bool isPaidComplete, AppThemeColors c) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label, 
            style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Khai: $declared', 
          style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w500)
        ),
        const SizedBox(width: 8),
        Text(
          'Đã nộp: $paid', 
          style: TextStyle(
            fontSize: 11, 
            color: isPaidComplete ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.bold,
          )
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final periodC = TextEditingController(text: 'Q${((DateTime.now().month - 1) ~/ 3) + 1}/${DateTime.now().year}');
    final vatC = TextEditingController();
    final pitC = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Thêm kỳ nghĩa vụ thuế', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(
              controller: periodC, 
              decoration: const InputDecoration(labelText: 'Kỳ kê khai (VD: Q1/2026)')
            ),
            const SizedBox(height: 8),
            TextField(
              controller: vatC, 
              decoration: const InputDecoration(labelText: 'Thuế VAT phải nộp (VNĐ)'), 
              keyboardType: TextInputType.number
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pitC, 
              decoration: const InputDecoration(labelText: 'Thuế TNCN phải nộp (VNĐ)'), 
              keyboardType: TextInputType.number
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text('Hủy', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.bold))
          ),
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
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Lưu lại'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> t) {
    final c = AppThemeColors.of(context);
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
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Cập nhật kỳ thuế', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                TextField(controller: periodC, decoration: const InputDecoration(labelText: 'Kỳ kê khai (VD: Q1/2026)')),
                const SizedBox(height: 8),
                TextField(controller: vatC, decoration: const InputDecoration(labelText: 'VAT khai nộp'), keyboardType: TextInputType.number),
                TextField(controller: pitC, decoration: const InputDecoration(labelText: 'TNCN khai nộp'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: vatPaidC, decoration: const InputDecoration(labelText: 'VAT thực tế đã nộp'), keyboardType: TextInputType.number),
                TextField(controller: pitPaidC, decoration: const InputDecoration(labelText: 'TNCN thực tế đã nộp'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Trạng thái nghĩa vụ'),
                  items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(statusLabels[s] ?? s))).toList(),
                  onChanged: (v) => setDlg(() => selectedStatus = v ?? selectedStatus),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text('Hủy', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.bold))
            ),
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
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, int id) async {
    final confirmed = await AppConfirmModal.show(
      context,
      title: 'Xóa kỳ nghĩa vụ thuế?',
      message: 'Bạn có chắc chắn muốn xóa kỳ thuế này khỏi sổ cái? Dữ liệu không thể phục hồi.',
      confirmText: 'Xóa kỳ thuế',
      cancelText: 'Hủy',
      isDestructive: true,
    );
    if (confirmed == true) {
      await ref.read(financeRepoProvider).deleteTaxObligation(id);
      ref.invalidate(taxObligationsProvider);
    }
  }
}
