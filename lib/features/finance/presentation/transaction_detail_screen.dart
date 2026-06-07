import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../providers/finance_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class TransactionDetailScreen extends ConsumerWidget {
  final Map<dynamic, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    final isIncome =
        transaction['type'] == 'INCOME' || transaction['type'] == 'income';
    final amount = asDouble(transaction['amount']);
    final paymentMethod = transaction['paymentMethod'] ?? 'Tiền mặt';
    final description =
        transaction['description'] ??
        transaction['note'] ??
        (isIncome ? 'Thu' : 'Chi');
    final createdAt =
        transaction['createdAt']?.toString() ??
        transaction['date']?.toString() ??
        '';
    final counterparty = transaction['counterparty'] ?? '';

    // Lấy ngày tháng format đẹp
    String dateLabel = createdAt;
    if (createdAt.isNotEmpty && createdAt.contains('T')) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel = DateFormat('dd/MM/yyyy HH:mm').format(dt);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Giao Dịch',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
            tooltip: 'Sửa giao dịch',
            onPressed: () => _showEditDialog(context, ref, transaction),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Xóa giao dịch',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Amount header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.card,
                shape: BoxShape.circle,
                border: Border.all(color: c.divider.withValues(alpha: 0.5)),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 40,
                color: isIncome ? AppColors.success : AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${isIncome ? '+' : '-'}${_currFmt.format(amount)}',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: isIncome ? AppColors.success : AppColors.danger,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isIncome ? 'Giao dịch thu tiền' : 'Giao dịch chi tiền',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'Loại giao dịch',
                    isIncome ? 'Thu' : 'Chi',
                    c,
                    valueColor: isIncome ? AppColors.success : AppColors.danger,
                  ),
                  _buildInfoRow('Phương thức', paymentMethod, c),
                  if (dateLabel.isNotEmpty)
                    _buildInfoRow('Thời gian', dateLabel, c),
                  if (counterparty.isNotEmpty)
                    _buildInfoRow('Đối tác', counterparty, c),
                  const Divider(height: 24),
                  _buildInfoRow('Ghi chú', description, c, isMultiLine: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    AppThemeColors c, {
    Color? valueColor,
    bool isMultiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: isMultiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: c.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: valueColor ?? c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: isMultiLine ? null : 1,
              overflow: isMultiLine ? null : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Map<dynamic, dynamic> trans,
  ) {
    final transId = trans['id'] is int
        ? trans['id']
        : int.tryParse(trans['id']?.toString() ?? '0') ?? 0;

    final isIncome = trans['type'] == 'INCOME' || trans['type'] == 'income';
    String type = isIncome ? 'INCOME' : 'EXPENSE';
    final amountC = TextEditingController(text: trans['amount']?.toString());
    final cpartyC = TextEditingController(
      text: trans['counterparty']?.toString(),
    );
    final descC = TextEditingController(
      text: (trans['description'] ?? trans['note'])?.toString(),
    );
    String payMethod = trans['paymentMethod']?.toString() ?? 'CASH';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa giao dịch'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'INCOME', child: Text('Thu tiền')),
                  DropdownMenuItem(value: 'EXPENSE', child: Text('Chi tiền')),
                ],
                onChanged: (v) => type = v ?? 'INCOME',
                decoration: const InputDecoration(labelText: 'Loại'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountC,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: payMethod == 'Chuyển khoản'
                    ? 'TRANSFER'
                    : (payMethod == 'Tiền mặt' ? 'CASH' : payMethod),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                  DropdownMenuItem(
                    value: 'TRANSFER',
                    child: Text('Chuyển khoản'),
                  ),
                ],
                onChanged: (v) => payMethod = v ?? 'CASH',
                decoration: const InputDecoration(labelText: 'Phương thức'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cpartyC,
                decoration: const InputDecoration(labelText: 'Đối tác'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descC,
                decoration: const InputDecoration(labelText: 'Ghi chú'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountC.text) ?? 0;
              if (amt <= 0) {
                ToastService.showError('Số tiền phải > 0');
                return;
              }
              await ref.read(financeRepoProvider).updateTransaction(transId, {
                'type': type,
                'amount': amt,
                'paymentMethod': payMethod,
                'counterparty': cpartyC.text.trim(),
                'description': descC.text.trim(),
              });
              ref.invalidate(transactionsProvider);
              ref.invalidate(cashSummaryProvider);
              if (ctx.mounted) {
                Navigator.pop(ctx); // close dialog
                Navigator.pop(context); // close screen
                ToastService.showSuccess('Cập nhật thành công');
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final transId = transaction['id'] is int
        ? transaction['id']
        : int.tryParse(transaction['id']?.toString() ?? '0') ?? 0;

    AppConfirmModal.show(
      context,
      title: 'Xóa giao dịch',
      message:
          'Bạn có chắc chắn muốn xóa giao dịch này? Số dư sẽ được cập nhật lại.',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
    ).then((confirm) async {
      if (confirm == true) {
        try {
          await ref.read(financeRepoProvider).deleteTransaction(transId);
          ToastService.showSuccess('Xóa giao dịch thành công');
          ref.invalidate(transactionsProvider);
          ref.invalidate(cashSummaryProvider);
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          ToastService.showError('Lỗi: $e');
        }
      }
    });
  }
}
