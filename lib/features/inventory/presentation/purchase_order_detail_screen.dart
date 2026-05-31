import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../providers/inventory_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class PurchaseOrderDetailScreen extends ConsumerWidget {
  final Map<dynamic, dynamic> purchaseOrder;
  
  const PurchaseOrderDetailScreen({
    super.key,
    required this.purchaseOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);
    
    final poItems = (purchaseOrder['items'] as List?) ?? [];
    final code = purchaseOrder['orderCode'] ?? purchaseOrder['code'] ?? 'PO-${purchaseOrder['id']}';
    final supplierName = purchaseOrder['supplier']?['name'] ?? purchaseOrder['supplierName'] ?? 'Không rõ nhà cung cấp';
    final totalAmount = asDouble(purchaseOrder['totalAmount']);
    final createdAt = purchaseOrder['createdAt']?.toString().split('T').first ?? '';
    final invoiceNumber = purchaseOrder['invoiceNumber'] ?? '';
    final status = (purchaseOrder['status'] ?? '').toString().toUpperCase();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'COMPLETED':
        statusColor = AppColors.success;
        statusLabel = 'Hoàn thành';
        break;
      case 'CANCELLED':
        statusColor = AppColors.danger;
        statusLabel = 'Đã hủy';
        break;
      case 'PENDING':
        statusColor = AppColors.warning;
        statusLabel = 'Chờ xử lý';
        break;
      default:
        statusColor = AppColors.info;
        statusLabel = status.isNotEmpty ? status : 'N/A';
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chi Tiết Đơn Nhập',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Mã đơn hàng', code.toString(), c),
                  if (createdAt.isNotEmpty) _buildInfoRow('Ngày tạo', createdAt, c),
                  _buildInfoRow('Nhà cung cấp', supplierName, c),
                  if (invoiceNumber.isNotEmpty) _buildInfoRow('Số hóa đơn', invoiceNumber, c),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trạng thái', style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Danh sách sản phẩm',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 12),
            if (poItems.isEmpty)
              Text('Không có sản phẩm nào.', style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13))
            else
              ...poItems.map((item) {
                final itemName = item['product']?['name'] ?? 'Sản phẩm ${item['productId'] ?? ''}';
                final qty = asDouble(item['quantity']);
                final unitPrice = asDouble(item['unitPrice']);
                final subtotal = asDouble(item['subtotal'] ?? (qty * unitPrice));
                
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
                            Text(itemName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary)),
                            const SizedBox(height: 2),
                            Text('SL: $qty x ${_currFmt.format(unitPrice)}', style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _currFmt.format(subtotal),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.divider.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tổng tiền thanh toán', style: GoogleFonts.inter(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    _currFmt.format(totalAmount),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: status == 'PENDING' ? Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.divider.withValues(alpha: 0.4))),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final bool? confirm = await AppConfirmModal.show(
                  context,
                  title: 'Xác nhận duyệt',
                  message: 'Bạn có chắc chắn muốn duyệt nhập kho đơn hàng này? Số lượng tồn kho sẽ được cộng thêm và không thể hoàn tác.',
                  confirmText: 'Duyệt',
                  cancelText: 'Hủy',
                );

                if (confirm == true) {
                  try {
                    final poId = purchaseOrder['id'] is int ? purchaseOrder['id'] : int.tryParse(purchaseOrder['id']?.toString() ?? '0') ?? 0;
                    await ref.read(inventoryRepoProvider).updatePurchaseOrder(poId, {'status': 'COMPLETED'});
                    ToastService.showSuccess('Đã duyệt nhập kho thành công');
                    ref.invalidate(purchaseOrdersProvider);
                    if (context.mounted) {
                      Navigator.pop(context); // Go back after success
                    }
                  } catch (e) {
                    ToastService.showError('Lỗi khi duyệt nhập kho: $e');
                  }
                }
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
              label: Text('Duyệt Nhập Kho', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildInfoRow(String label, String value, AppThemeColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value, 
              style: GoogleFonts.inter(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
