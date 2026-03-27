import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      appBar: AppBar(title: Text('Chi tiết đơn #$id'), actions: [featureGuideButton(context, 'order_detail')]),
      body: orderAsync.when(
        data: (order) {
          final createdAt = (order['createdAt'] ?? order['created_at'])?.toString();
          final customerName = (order['customer']?['name'] ?? order['customerName'] ?? 'Khách lẻ').toString();
          final status = (order['status'] ?? 'PENDING').toString();
          final orderCode = (order['orderCode'] ?? 'DH-$id').toString();

          final totalAmount = (order['totalAmount'] ?? 0).toDouble();
          final paidAmount = (order['paidAmount'] ?? 0).toDouble();
          final remaining = (totalAmount - paidAmount) < 0 ? 0.0 : (totalAmount - paidAmount);

          final items = (order['items'] as List?) ?? const [];

          // Payment status
          final bool isFullyPaid = remaining <= 0;
          final bool isCancelled = status == 'CANCELLED';

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
            paymentLabel = 'Đã thanh toán đủ';
            paymentColor = AppColors.success;
          } else if (paidAmount > 0) {
            paymentLabel = 'Thanh toán một phần';
            paymentColor = AppColors.warning;
          } else {
            paymentLabel = 'Chưa thanh toán';
            paymentColor = AppColors.danger;
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Order info card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        _InfoRow('Mã đơn', orderCode),
                        if (createdAt != null && createdAt.isNotEmpty) _InfoRow('Ngày tạo', _formatDate(createdAt)),
                        _InfoRow('Khách hàng', customerName),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Trạng thái', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                            )
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Thanh toán', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: paymentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text(paymentLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: paymentColor)),
                            )
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text('Chi tiết sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Text('Không có sản phẩm', style: TextStyle(color: c.textSecondary))
                    else
                      ...items.map((raw) {
                        final it = raw as Map;
                        final name = (it['productName'] ?? it['product']?['name'] ?? 'Sản phẩm').toString();
                        final qty = (it['quantity'] ?? 0).toDouble();
                        final unitPrice = (it['unitPrice'] ?? 0).toDouble();
                        final subtotal = (it['subtotal'] ?? (qty * unitPrice)).toDouble();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('SL: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} x ${_currFmt.format(unitPrice)}',
                                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
                              ]),
                            ),
                            Text(_currFmt.format(subtotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ]),
                        );
                      }),
                    const SizedBox(height: 16),
                    // Payment summary card
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        _InfoRow('Tổng tiền', _currFmt.format(totalAmount)),
                        _InfoRow('Đã thanh toán', _currFmt.format(paidAmount)),
                        Divider(height: 16, color: c.surface),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Còn lại', style: TextStyle(
                              color: remaining > 0 ? AppColors.danger : AppColors.success,
                              fontSize: 14, fontWeight: FontWeight.w600,
                            )),
                            Text(_currFmt.format(remaining), style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16,
                              color: remaining > 0 ? AppColors.danger : AppColors.success,
                            )),
                          ],
                        ),
                      ]),
                    ),

                    // Payment history
                    if ((order['payments'] as List?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      Text('Lịch sử thanh toán', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      ...(order['payments'] as List).map((p) {
                        final pMap = p as Map;
                        final amt = (pMap['amount'] ?? 0).toDouble();
                        final method = (pMap['method'] ?? 'CASH').toString();
                        final paidAt = (pMap['paidAt'] ?? pMap['paid_at'])?.toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                            ),
                            SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_currFmt.format(amt), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                              Text('${_paymentMethodLabel(method)}${paidAt != null ? ' • ${_formatDate(paidAt)}' : ''}',
                                style: TextStyle(fontSize: 11, color: c.textSecondary)),
                            ])),
                          ]),
                        );
                      }),
                    ],
                    const SizedBox(height: 80), // space for bottom button
                  ]),
                ),
              ),
              // Bottom payment button
              if (!isFullyPaid && !isCancelled)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -2))],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPaymentDialog(context, ref, id, remaining),
                        icon: const Icon(Icons.payment, size: 20),
                        label: Text('Thanh toán (${_currFmt.format(remaining)})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cloud_off, size: 48, color: c.textMuted),
              const SizedBox(height: 12),
              Text('Không tải được chi tiết đơn hàng.\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => ref.invalidate(salesDetailProvider), child: Text('Thử lại')),
            ]),
          ),
        ),
      ),
    );
  }
}

void _showPaymentDialog(BuildContext context, WidgetRef ref, int orderId, double remaining) {
  final c = AppThemeColors.of(context);
  final amountCtrl = TextEditingController(text: remaining.toStringAsFixed(0));
  String selectedMethod = 'CASH';
  final notesCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.textMuted, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          Text('Thanh toán đơn hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Số tiền cần thanh toán: ${_currFmt.format(remaining)}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          const SizedBox(height: 20),

          // Amount field
          Text('Số tiền', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Nhập số tiền',
              suffixText: '₫',
              filled: true, fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          // Payment method
          Text('Phương thức', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            _MethodChip('CASH', 'Tiền mặt', Icons.money, selectedMethod, (v) => setState(() => selectedMethod = v)),
            _MethodChip('TRANSFER', 'Chuyển khoản', Icons.account_balance, selectedMethod, (v) => setState(() => selectedMethod = v)),
            _MethodChip('MOMO', 'Momo', Icons.phone_android, selectedMethod, (v) => setState(() => selectedMethod = v)),
            _MethodChip('QR', 'QR Pay', Icons.qr_code, selectedMethod, (v) => setState(() => selectedMethod = v)),
          ]),
          const SizedBox(height: 16),

          // Notes
          Text('Ghi chú', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          TextField(
            controller: notesCtrl,
            decoration: InputDecoration(
              hintText: 'Ghi chú (tùy chọn)',
              filled: true, fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),

          // Submit buttons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.textMuted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Hủy'),
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
                      const SnackBar(content: Text('Số tiền phải lớn hơn 0'), backgroundColor: AppColors.danger),
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
                          content: Text('Đã thanh toán ${_currFmt.format(amount)}'),
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
                icon: const Icon(Icons.check, size: 18),
                label: Text('Xác nhận thanh toán'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

String _paymentMethodLabel(String method) {
  switch (method) {
    case 'CASH': return 'Tiền mặt';
    case 'TRANSFER': return 'Chuyển khoản';
    case 'MOMO': return 'Momo';
    case 'ZALOPAY': return 'ZaloPay';
    case 'QR': return 'QR Pay';
    default: return method;
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.primary : c.textSecondary),
          SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : c.textSecondary)),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AppThemeColors.of(context).textSecondary, fontSize: 13)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
    ]),
  );
}
