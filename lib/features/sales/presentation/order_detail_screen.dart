import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/sales_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class OrderDetailScreen extends ConsumerWidget {
  final int id;
  const OrderDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final orderAsync = ref.watch(salesDetailProvider(id));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Đơn Hàng',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'order_detail'),
          IconButton(
            icon: const Icon(Icons.print_rounded, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang kết nối máy in... Tính năng in hóa đơn sẽ sớm ra mắt!')),
              );
            },
            tooltip: 'In hóa đơn',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          final createdAt = (order['createdAt'] ?? order['created_at'])?.toString();
          final customerName = (order['customer']?['name'] ?? order['customerName'] ?? 'Khách mua lẻ').toString();
          final status = (order['status'] ?? 'PENDING').toString();
          final returnStatus = order['returnStatus']?.toString();
          final orderCode = (order['orderCode'] ?? 'DH-$id').toString();

          final totalAmount = double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
          final paidAmount = double.tryParse(order['paidAmount']?.toString() ?? '0') ?? 0.0;
          final remaining = (totalAmount - paidAmount) < 0 ? 0.0 : (totalAmount - paidAmount);

          final items = (order['items'] as List?) ?? const [];

          // Payment status
          final bool isFullyPaid = remaining <= 0;
          final bool isCancelled = status == 'CANCELLED';
          final bool isReturned = returnStatus == 'RETURNED';

          Color statusColor;
          String statusLabel;
          switch (status) {
            case 'COMPLETED':
            case 'DELIVERED':
              statusColor = AppColors.success;
              statusLabel = 'Hoàn thành';
              break;
            case 'CANCELLED':
              statusColor = AppColors.danger;
              statusLabel = 'Đã hủy';
              break;
            default:
              statusColor = AppColors.warning;
              statusLabel = 'Chờ xử lý';
          }

          // Payment status label
          String paymentLabel;
          Color paymentColor;
          if (isFullyPaid) {
            paymentLabel = 'Đã trả đủ';
            paymentColor = AppColors.success;
          } else if (paidAmount > 0) {
            paymentLabel = 'Trả một phần';
            paymentColor = AppColors.warning;
          } else {
            paymentLabel = 'Chưa trả tiền';
            paymentColor = AppColors.danger;
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order general info bento-style card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            _InfoRow('Mã hóa đơn', orderCode, c),
                            if (createdAt != null && createdAt.isNotEmpty)
                              _InfoRow('Thời gian tạo', _formatDate(createdAt), c),
                            _InfoRow('Khách hàng', customerName, c),
                            
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Trạng thái đơn',
                                  style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Thanh toán',
                                  style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: paymentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: paymentColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    paymentLabel,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: paymentColor,
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        'Danh sách sản phẩm mua',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Không có sản phẩm nào trong đơn hàng.',
                            style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13),
                          ),
                        )
                      else
                        ...items.map((raw) {
                          final it = raw as Map;
                          final name = (it['productName'] ?? it['product']?['name'] ?? 'Sản phẩm không tên').toString();
                          final qty = double.tryParse(it['quantity']?.toString() ?? '0') ?? 0.0;
                          final unitPrice = double.tryParse(it['unitPrice']?.toString() ?? '0') ?? 0.0;
                          final subtotal = double.tryParse(it['subtotal']?.toString() ?? '0') ?? (qty * unitPrice);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: c.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SL: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} x ${_currFmt.format(unitPrice)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _currFmt.format(subtotal),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: c.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 20),

                      // Cost Summary details ledger card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.divider.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            _InfoRow('Tổng tiền hóa đơn', _currFmt.format(totalAmount), c),
                            _InfoRow('Khách đã thanh toán', _currFmt.format(paidAmount), c),
                            Divider(height: 20, color: c.divider),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dư nợ còn lại',
                                  style: GoogleFonts.outfit(
                                    color: remaining > 0 ? AppColors.danger : AppColors.success,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _currFmt.format(remaining),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: remaining > 0 ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Payment history log ledger
                      if ((order['payments'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Lịch sử giao dịch thanh toán',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(order['payments'] as List).map((p) {
                          final pMap = p as Map;
                          final amt = double.tryParse(pMap['amount']?.toString() ?? '0') ?? 0.0;
                          final method = (pMap['method'] ?? 'CASH').toString();
                          final paidAt = (pMap['paidAt'] ?? pMap['paid_at'])?.toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.divider.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '+${_currFmt.format(amt)}',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.success,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${_paymentMethodLabel(method)}${paidAt != null ? ' • ${_formatDate(paidAt)}' : ''}',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: c.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              
              // Bottom floating visual control sheet
              if (!isCancelled)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border(top: BorderSide(color: c.divider.withValues(alpha: 0.4))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFullyPaid)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showPaymentDialog(context, ref, id, remaining),
                              icon: const Icon(Icons.payment_rounded, size: 18, color: Colors.white),
                              label: Text(
                                'Thanh toán ngay (${_currFmt.format(remaining)})',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        if (status == 'DELIVERED' || status == 'COMPLETED' || isFullyPaid) ...[
                          if (!isFullyPaid) const SizedBox(height: 10),
                          if (!isReturned)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showReturnDialog(context, ref, id, items, paidAmount),
                                icon: const Icon(Icons.assignment_return_rounded, size: 18, color: AppColors.danger),
                                label: Text(
                                  'Yêu Cầu Trả Hàng',
                                  style: GoogleFonts.outfit(color: AppColors.danger, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Không tải được chi tiết hóa đơn.\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(salesDetailProvider(id)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showPaymentDialog(BuildContext context, WidgetRef ref, int orderId, double remaining) {
  final c = AppThemeColors.of(context);
  final theme = Theme.of(context);
  final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(0));
  String selectedMethod = 'CASH';
  final notesCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text(
              'Thanh toán đơn hàng',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              'Hạn mức cần thu: ${_currFmt.format(remaining)}',
              style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // Amount field
            Text(
              'Số tiền thanh toán (VNĐ)',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhập số tiền',
                suffixText: '₫',
                filled: true,
                fillColor: c.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // Payment method
            Text(
              'Phương thức giao dịch',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _MethodChip('CASH', 'Tiền mặt', Icons.money_rounded, selectedMethod, (v) => setState(() => selectedMethod = v)),
                _MethodChip('TRANSFER', 'Chuyển khoản', Icons.account_balance_rounded, selectedMethod, (v) => setState(() => selectedMethod = v)),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            Text(
              'Ghi chú bổ sung',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: notesCtrl,
              style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ghi chú (Không bắt buộc)',
                filled: true,
                fillColor: c.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.divider, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Hủy bỏ',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Số tiền thanh toán phải lớn hơn 0!'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }
                      if (amount > remaining) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Không thể thanh toán vượt quá ${_currFmt.format(remaining)}!'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop();
                      try {
                        await ref.read(salesRepoProvider).addPayment(orderId, {
                          'amount': amount,
                          'method': selectedMethod,
                          'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        });
                        ref.invalidate(salesDetailProvider(orderId));
                        ref.invalidate(salesListProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thanh toán ${_currFmt.format(amount)} thành công!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Xác Nhận',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showReturnDialog(BuildContext context, WidgetRef ref, int orderId, List? items, double maxRefund) {
  final c = AppThemeColors.of(context);
  final theme = Theme.of(context);
  final amountCtrl = TextEditingController(text: maxRefund.toStringAsFixed(0));
  String selectedMethod = 'CASH';
  final reasonCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text(
              'Trả hàng & Hoàn tiền sản phẩm',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger),
            ),
            const SizedBox(height: 2),
            Text(
              'Hạn mức hoàn trả tối đa: ${_currFmt.format(maxRefund)}',
              style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // Amount field
            Text(
              'Số tiền hoàn trả cho khách lẻ (VNĐ)',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhập số tiền hoàn',
                suffixText: '₫',
                filled: true,
                fillColor: c.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // Payment method
            Text(
              'Phương thức trả tiền',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _MethodChip('CASH', 'Tiền mặt', Icons.money_rounded, selectedMethod, (v) => setState(() => selectedMethod = v)),
                _MethodChip('TRANSFER', 'Chuyển khoản', Icons.account_balance_rounded, selectedMethod, (v) => setState(() => selectedMethod = v)),
              ],
            ),
            const SizedBox(height: 16),

            // Reason
            Text(
              'Lý do trả lại hàng',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonCtrl,
              style: GoogleFonts.inter(fontSize: 13, color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhập lý do trả hàng...',
                filled: true,
                fillColor: c.inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.divider, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Hủy bỏ',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount < 0 || amount > maxRefund) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Số tiền hoàn phải hợp lệ (0 - ${_currFmt.format(maxRefund)})!'), backgroundColor: AppColors.danger),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop();
                      try {
                        final returnItems = (items ?? []).map((i) {
                          final it = i as Map;
                          return {
                            'productId': it['productId'] ?? it['product']?['id'],
                            'quantity': it['quantity'],
                            'unitPrice': it['unitPrice'],
                            'subtotal': it['subtotal'],
                            'reason': reasonCtrl.text.trim(),
                          };
                        }).where((item) => item['productId'] != null).toList();

                        await ref.read(salesRepoProvider).createReturn(orderId, {
                          'refundAmount': amount,
                          'refundMethod': selectedMethod,
                          'reason': reasonCtrl.text.trim(),
                          'items': returnItems,
                        });
                        ref.invalidate(salesDetailProvider(orderId));
                        ref.invalidate(salesListProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã hoàn tất trả hàng & hoàn trả ${_currFmt.format(amount)} cho khách!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.assignment_return_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Xác Nhận Trả',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _paymentMethodLabel(String method) {
  switch (method) {
    case 'CASH':
      return 'Tiền mặt';
    case 'TRANSFER':
      return 'Chuyển khoản';
    default:
      return method;
  }
}

String _formatDate(String raw) {
  try {
    final dt = DateTime.parse(raw);
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  } catch (_) {
    return raw;
  }
}

class _MethodChip extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final String selected;
  final ValueChanged<String> onTap;
  const _MethodChip(this.value, this.label, this.icon, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : c.divider, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final AppThemeColors c;
  const _InfoRow(this.label, this.value, this.c);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
