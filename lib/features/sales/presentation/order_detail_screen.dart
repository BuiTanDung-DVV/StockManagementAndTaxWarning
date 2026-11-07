import 'sales_return_dialog.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../dashboard/providers/dashboard_action_provider.dart';
import 'sales_payment_dialog.dart';
import 'sales_payment_recovery_dialog.dart';
import '../../../core/utils/order_debt_balance.dart';
import '../../../core/widgets/order_debt_summary.dart';
import '../../../core/widgets/product_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/assets/app_icon.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import '../providers/sales_provider.dart';
import '../../settings/providers/system_provider.dart';
import '../../settings/providers/shop_provider.dart';
import '../services/receipt_pdf_service.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class OrderDetailScreen extends ConsumerWidget {
  final int id;
  const OrderDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final canRecordPayment = ref
        .watch(shopProvider)
        .hasPermission('sales', 'edit');
    final canReturn = canRecordPayment;
    final orderAsync = ref.watch(salesDetailProvider(id));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Chi Tiết Đơn Hàng',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          featureGuideButton(context, 'order_detail'),
          IconButton(
            icon: const AppIcon(Icons.print_rounded, size: 20),
            onPressed: () async {
              try {
                final values = await Future.wait([
                  ref.read(salesDetailProvider(id).future),
                  ref.read(shopProfileProvider.future),
                ]);
                final bytes = await ReceiptPdfService.build(
                  order: Map<String, dynamic>.from(values[0]),
                  profile: Map<String, dynamic>.from(values[1]),
                );
                await Printing.layoutPdf(
                  onLayout: (_) async => bytes,
                  name: 'phieu-ban-hang-$id.pdf',
                );
              } on ReceiptImageException catch (error) {
                ToastService.showError(error.message);
              } catch (_) {
                ToastService.showError(
                  'Chưa thể tạo phiếu in. Vui lòng thử lại sau.',
                );
              }
            },
            tooltip: 'In phiếu tính tiền',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: orderAsync.when(
        data: (order) {
          final createdAt = (order['createdAt'] ?? order['created_at'])
              ?.toString();
          final customerName =
              (order['customer']?['name'] ??
                      order['customerName'] ??
                      'Khách mua lẻ')
                  .toString();
          final status = (order['status'] ?? 'PENDING').toString();
          final returnStatus = order['returnStatus']?.toString();
          final orderCode = (order['orderCode'] ?? 'DH-$id').toString();

          final totalAmount =
              double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
          final paidAmount =
              double.tryParse(order['paidAmount']?.toString() ?? '0') ?? 0.0;
          final debtBalance = OrderDebtBalance.fromMap(order);
          final remaining = debtBalance.remaining ?? 0;

          final items = (order['items'] as List?) ?? const [];

          // Payment status
          final bool isFullyPaid =
              debtBalance.remaining != null && remaining <= 0;
          final bool isCancelled = status == 'CANCELLED';
          final bool isPartiallyReturned = returnStatus == 'PARTIAL_RETURN';
          final bool isFullyReturned =
              returnStatus == 'FULL_RETURN' || returnStatus == 'RETURNED';
          final bool isReturned = isPartiallyReturned || isFullyReturned;

          Color statusColor;
          String statusLabel;

          if (isReturned) {
            statusColor = AppColors.danger;
            statusLabel = isFullyReturned
                ? 'Đã trả toàn bộ hàng'
                : 'Đã trả một phần hàng';
          } else {
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
          }

          // Payment status label
          String paymentLabel;
          Color paymentColor;
          paymentLabel = debtBalance.label;
          paymentColor = debtBalance.isInactive
              ? c.textSecondary
              : debtBalance.remaining == null
              ? AppColors.warning
              : isFullyPaid
              ? AppColors.success
              : paidAmount > 0
              ? AppColors.warning
              : AppColors.danger;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(salesDetailProvider(id));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order general info bento-style card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: c.divider.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _InfoRow('Mã đơn hàng', orderCode, c),
                                  if (createdAt != null && createdAt.isNotEmpty)
                                    _InfoRow(
                                      'Thời gian tạo',
                                      _formatDate(createdAt),
                                      c,
                                    ),
                                  _InfoRow('Khách hàng', customerName, c),
                                  if (order['notes'] != null &&
                                      order['notes'].toString().isNotEmpty)
                                    _InfoRow(
                                      'Ghi chú',
                                      order['notes'].toString(),
                                      c,
                                    ),

                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Trạng thái đơn',
                                        style: GoogleFonts.inter(
                                          color: c.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Thanh toán',
                                        style: GoogleFonts.inter(
                                          color: c.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: paymentColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: paymentColor.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          paymentLabel,
                                          style: GoogleFonts.manrope(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: paymentColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            Text(
                              'Danh sách sản phẩm mua',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  'Không có sản phẩm nào trong đơn hàng.',
                                  style: GoogleFonts.inter(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              ...items.map((raw) {
                                final it = raw as Map;
                                final name =
                                    (it['productName'] ??
                                            it['product']?['name'] ??
                                            'Sản phẩm không tên')
                                        .toString();
                                final qty =
                                    double.tryParse(
                                      it['quantity']?.toString() ?? '0',
                                    ) ??
                                    0.0;
                                final unitPrice =
                                    double.tryParse(
                                      it['unitPrice']?.toString() ?? '0',
                                    ) ??
                                    0.0;
                                final subtotal =
                                    double.tryParse(
                                      it['subtotal']?.toString() ?? '0',
                                    ) ??
                                    (qty * unitPrice);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: c.divider.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ProductThumbnail(
                                        imageUrl:
                                            it['product']?['imageUrl']
                                                ?.toString() ??
                                            it['imageUrl']?.toString(),
                                        name: it['product']?['name']
                                            ?.toString(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: c.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            // Hiển thị phần trả hàng nếu có
                            if (order['returns'] != null &&
                                (order['returns'] as List).isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.danger.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const AppIcon(
                                          Icons.assignment_return_rounded,
                                          color: AppColors.danger,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Thông tin Trả Hàng',
                                          style: GoogleFonts.manrope(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...((order['returns'] as List).map((ret) {
                                      final rMap = ret as Map;
                                      final refundAmt =
                                          double.tryParse(
                                            rMap['refundAmount']?.toString() ??
                                                '0',
                                          ) ??
                                          0.0;
                                      final retCode = (rMap['returnCode'] ?? '')
                                          .toString();
                                      final retReason = (rMap['reason'] ?? '')
                                          .toString();
                                      final returnId = rMap['id'];
                                      return Container(
                                        margin: const EdgeInsets.only(top: 8),
                                        decoration: BoxDecoration(
                                          color: c.surface,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(color: c.divider),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            onTap: returnId == null
                                                ? null
                                                : () => context.push(
                                                    '/sales/returns/$returnId',
                                                    extra: ret,
                                                  ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _InfoRow(
                                                    'Mã phiếu trả',
                                                    retCode,
                                                    c,
                                                  ),
                                                  _InfoRow(
                                                    'Tiền hoàn lại',
                                                    _currFmt.format(refundAmt),
                                                    c,
                                                  ),
                                                  if (retReason.isNotEmpty)
                                                    _InfoRow(
                                                      'Lý do',
                                                      retReason,
                                                      c,
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Text(
                                                      'Bấm để xem chi tiết',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10,
                                                        color: c.textMuted,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    })),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Cost Summary details ledger card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: c.divider.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (double.tryParse(
                                            order['discountAmount']
                                                    ?.toString() ??
                                                order['discount_amount']
                                                    ?.toString() ??
                                                '0',
                                          ) !=
                                          null &&
                                      (double.tryParse(
                                                order['discountAmount']
                                                        ?.toString() ??
                                                    order['discount_amount']
                                                        ?.toString() ??
                                                    '0',
                                              ) ??
                                              0.0) >
                                          0) ...[
                                    _InfoRow(
                                      'Tạm tính',
                                      _currFmt.format(
                                        double.tryParse(
                                              order['subtotal']?.toString() ??
                                                  '0',
                                            ) ??
                                            totalAmount,
                                      ),
                                      c,
                                    ),
                                    _InfoRow(
                                      'Chiết khấu',
                                      '-${_currFmt.format(double.tryParse(order['discountAmount']?.toString() ?? order['discount_amount']?.toString() ?? '0') ?? 0.0)}',
                                      c,
                                    ),
                                  ],
                                  OrderDebtSummary(order: order),
                                  if (canRecordPayment)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _showSalesRecovery(
                                          context,
                                          ref,
                                          id,
                                          order,
                                        ),
                                        child: const Text('Kiểm tra thu tiền'),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Payment history log ledger
                            if ((order['payments'] as List?)?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 24),
                              Text(
                                'Lịch sử giao dịch thanh toán',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...(order['payments'] as List).map((p) {
                                final pMap = p as Map;
                                final amt =
                                    double.tryParse(
                                      pMap['amount']?.toString() ?? '0',
                                    ) ??
                                    0.0;
                                final method = (pMap['method'] ?? 'CASH')
                                    .toString();
                                final paidAt =
                                    (pMap['paidAt'] ?? pMap['paid_at'])
                                        ?.toString();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.surface.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: c.divider.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const AppIcon(
                                          Icons.check_circle_outline_rounded,
                                          size: 18,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '+${_currFmt.format(amt)}',
                                              style: GoogleFonts.manrope(
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
                  ),

                  // Bottom floating visual control sheet
                  if (!isCancelled)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.card,
                        border: Border(
                          top: BorderSide(
                            color: c.divider.withValues(alpha: 0.4),
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (order['shippingCarrierId'] != null ||
                                    order['shippingCarrier'] != null) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showDeliveryDialog(
                                        context,
                                        ref,
                                        id,
                                        order,
                                      ),
                                      icon: const AppIcon(
                                        Icons.local_shipping_outlined,
                                      ),
                                      label: Text(
                                        'Giao hàng · ${_deliveryLabel(order['deliveryStatus']?.toString())}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (debtBalance.canCollect && canRecordPayment)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showPaymentDialog(
                                        context,
                                        ref,
                                        id,
                                        order,
                                      ),
                                      icon: const AppIcon(
                                        Icons.payment_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        debtBalance.basis == 'RETURN_LEDGER'
                                            ? 'Ghi nhận thu phí giao (${_currFmt.format(remaining)})'
                                            : 'Ghi nhận thu tiền (${_currFmt.format(remaining)})',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: c.primary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (canReturn && !isFullyReturned) ...[
                                  if (!isFullyPaid) const SizedBox(height: 10),
                                  if (!isFullyReturned)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: canReturn
                                            ? () => _showReturnDialog(
                                                context,
                                                ref,
                                                id,
                                                items,
                                                Map<String, dynamic>.from(
                                                  order,
                                                ),
                                              )
                                            : () {
                                                ToastService.showError(
                                                  'Chỉ Quản lý hoặc Chủ cửa hàng mới có quyền tạo yêu cầu trả hàng.',
                                                );
                                              },
                                        icon: AppIcon(
                                          canReturn
                                              ? Icons.assignment_return_rounded
                                              : Icons.lock_outline_rounded,
                                          size: 18,
                                          color: canReturn
                                              ? c.textSecondary
                                              : c.textMuted,
                                        ),
                                        label: Text(
                                          canReturn
                                              ? 'Trả hàng'
                                              : 'Yêu Cầu Trả Hàng (Cần quyền Quản lý)',
                                          style: GoogleFonts.manrope(
                                            color: canReturn
                                                ? c.textSecondary
                                                : c.textMuted,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: c.inputBorder,
                                            width: 1,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(Icons.cloud_off_rounded, size: 48, color: c.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Không tải được chi tiết phiếu tính tiền.\n$e',
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
                  icon: const AppIcon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _deliveryLabel(String? status) => switch (status) {
    'PENDING' => 'Chờ lấy hàng',
    'IN_TRANSIT' => 'Đang giao',
    'DELIVERED' => 'Đã giao',
    'CANCELLED' => 'Đã hủy giao',
    'RETURNED' => 'Đã hoàn về',
    _ => 'Chưa cập nhật',
  };

  Future<void> _showDeliveryDialog(
    BuildContext context,
    WidgetRef ref,
    int orderId,
    Map<String, dynamic> order,
  ) async {
    String status = order['deliveryStatus']?.toString() ?? 'PENDING';
    final allowedStatuses = switch (status) {
      'PENDING' => const ['PENDING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'],
      'IN_TRANSIT' => const ['IN_TRANSIT', 'DELIVERED', 'CANCELLED'],
      'DELIVERED' => const ['DELIVERED', 'RETURNED'],
      'CANCELLED' => const ['CANCELLED'],
      'RETURNED' => const ['RETURNED'],
      _ => const ['PENDING'],
    };
    final tracking = TextEditingController(
      text: order['trackingCode']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Cập nhật giao hàng'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tracking,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Mã vận đơn'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: allowedStatuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_deliveryLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                if (status == 'DELIVERED' &&
                    order['shippingFeePayer'] == 'SHOP') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Khi xác nhận đã giao, phí vận chuyển do cửa hàng chịu sẽ được ghi chi phí một lần.',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        await ref.read(salesRepoProvider).update(orderId, {
          'trackingCode': tracking.text.trim(),
          'deliveryStatus': status,
        });
        ref.invalidate(salesDetailProvider(orderId));
      } on ApiException catch (error) {
        ToastService.showError(error.message);
      } catch (_) {
        ToastService.showError(
          'Không thể cập nhật vận chuyển. Vui lòng thử lại sau.',
        );
      }
    }
    tracking.dispose();
  }
}

void _refreshSalesPaymentViews(
  WidgetRef ref,
  int orderId,
  Map<dynamic, dynamic> order,
) {
  ref.invalidate(salesDetailProvider(orderId));
  ref.invalidate(salesListProvider);
  ref.invalidate(paymentSummaryProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(salesSummaryProvider);
  ref.invalidate(customerListProvider);
  ref.invalidate(customerOptionsProvider);
  ref.invalidate(customerReceivablesProvider);
  ref.invalidate(customerDetailProvider);
  ref.invalidate(debtAgingProvider);
  ref.invalidate(overdueDebtsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(cashSummaryProvider);
  ref.invalidate(cashflowProjectionProvider);
  ref.invalidate(dailyClosingProvider);
  ref.invalidate(dashboardActionProvider);
}

Future<void> _showPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  int orderId,
  Map<dynamic, dynamic> order,
) async {
  final shopId = ref.read(shopProvider).currentShopId,
      actor = '${ref.read(authProvider).user?['id']}';
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SalesPaymentDialog(order: Map<String, dynamic>.from(order)),
  );
  if (result == true &&
      context.mounted &&
      ref.read(shopProvider).currentShopId == shopId &&
      '${ref.read(authProvider).user?['id']}' == actor) {
    _refreshSalesPaymentViews(ref, orderId, order);
  }
}

Future<void> _showSalesRecovery(
  BuildContext context,
  WidgetRef ref,
  int orderId,
  Map<dynamic, dynamic> order,
) async {
  final shopId = int.tryParse('${order['shopId']}'),
      actor = '${ref.read(authProvider).user?['id']}';
  if (shopId == null) return;
  await showDialog<bool>(
    context: context,
    builder: (_) => SalesPaymentRecoveryDialog(
      orderId: orderId,
      sourceShopId: shopId,
      orderCode: 'Đơn ${order['orderCode'] ?? orderId}',
    ),
  );
  if (context.mounted &&
      ref.read(shopProvider).currentShopId == shopId &&
      '${ref.read(authProvider).user?['id']}' == actor) {
    _refreshSalesPaymentViews(ref, orderId, order);
  }
}

Future<void> _showReturnDialog(
  BuildContext context,
  WidgetRef ref,
  int orderId,
  List? items,
  Map<String, dynamic> order,
) async {
  final shop = ref.read(shopProvider).currentShopId,
      actor = '${ref.read(authProvider).user?['id']}';
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SalesReturnDialog(order: order),
  );
  if (result == true &&
      context.mounted &&
      ref.read(shopProvider).currentShopId == shop &&
      '${ref.read(authProvider).user?['id']}' == actor) {
    _refreshSalesPaymentViews(ref, orderId, order);
    ref.invalidate(productListProvider);
    ref.invalidate(stockProvider);
    ref.invalidate(stockPageProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(inventoryMovementsProvider);
    ref.invalidate(xntReportProvider);
  }
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
    return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(raw));
  } catch (_) {
    return raw;
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
