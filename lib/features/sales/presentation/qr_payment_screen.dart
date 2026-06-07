import 'package:flutter/material.dart';
import '../../../core/utils/toast_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/guides/feature_guide_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_confirm_modal.dart';
import '../../../core/network/api_client.dart';
import '../../products/providers/product_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../providers/sales_provider.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);
final _tts = FlutterTts();

class QrPaymentScreen extends ConsumerStatefulWidget {
  final int orderId;
  final String orderCode;
  final double totalAmount;
  final String bankId;
  final String accountNo;
  final String accountName;

  const QrPaymentScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.totalAmount,
    required this.bankId,
    required this.accountNo,
    required this.accountName,
  });

  @override
  ConsumerState<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends ConsumerState<QrPaymentScreen> {
  bool _confirming = false;
  bool _paid = false;

  String get _qrUrl {
    final name = Uri.encodeComponent(widget.accountName);
    final amount = widget.totalAmount.toInt();
    return 'https://img.vietqr.io/image/${widget.bankId}-${widget.accountNo}-compact2.png'
        '?amount=$amount&addInfo=${widget.orderCode}&accountName=$name';
  }

  Future<void> _confirmPayment() async {
    setState(() => _confirming = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/sales-orders/${widget.orderId}/payments',
            data: {
              'amount': widget.totalAmount,
              'paymentMethod': 'BANK_TRANSFER',
              'reference': widget.orderCode,
            },
          );
      setState(() => _paid = true);

      // Trigger UI updates across the app
      ref.invalidate(salesListProvider);
      ref.invalidate(salesSummaryProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(lowStockProvider);
      ref.invalidate(taxObligationsProvider);

      // TTS announcement
      final amountText = _formatAmountForSpeech(widget.totalAmount);
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.45);
      await _tts.speak('Đã nhận $amountText cho đơn hàng ${widget.orderCode}');

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ToastService.showError('Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await AppConfirmModal.show(
      context,
      title: 'Hủy đơn hàng?',
      message:
          'Bạn có chắc chắn muốn hủy đơn hàng này không? Dữ liệu không thể khôi phục.',
      confirmText: 'Hủy đơn',
      cancelText: 'Không',
      isDestructive: true,
    );
    if (confirm != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .post('/sales-orders/${widget.orderId}/cancel');
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) {
        ToastService.showError('Lỗi: $e');
      }
    }
  }

  String _formatAmountForSpeech(double amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)} triệu đồng';
    } else if (amount >= 1000) {
      final k = amount / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)} nghìn đồng';
    }
    return '${amount.toInt()} đồng';
  }

  void _copyToClipboard(String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text('Đã sao chép $label thành công!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final theme = Theme.of(context);

    if (_paid) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.success.withValues(alpha: 0.05), c.bg],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 88,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Thanh toán thành công!',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _currFmt.format(widget.totalAmount),
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mã giao dịch: ${widget.orderCode}',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Thanh toán chuyển khoản',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: c.textPrimary,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [featureGuideButton(context, 'qr_payment')],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount display card (Glassmorphic)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Số tiền cần thanh toán',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SelectableText(
                        _currFmt.format(widget.totalAmount),
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        onPressed: () => _copyToClipboard(
                          'số tiền',
                          widget.totalAmount.toInt().toString(),
                        ),
                        tooltip: 'Sao chép số tiền',
                        splashRadius: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mã đơn: ${widget.orderCode}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // QR Code display container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Quét mã VietQR tự động nhập liệu',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF1E293B), // High contrast slate-800
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _qrUrl,
                        width: 240,
                        height: 240,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const SizedBox(
                                width: 240,
                                height: 240,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                              ),
                        errorBuilder: (_, e, s) => SizedBox(
                          width: 240,
                          height: 240,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.danger,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Không tải được mã QR\nKiểm tra lại cấu hình NH',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _copyToClipboard(
                      'nội dung chuyển khoản',
                      widget.orderCode,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: c.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Nội dung CK: ${widget.orderCode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bank details card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: c.divider.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _infoRow('Ngân hàng', widget.bankId, c, isBold: true),
                  Divider(height: 24, color: c.divider.withValues(alpha: 0.5)),
                  _infoRow('Số tài khoản', widget.accountNo, c, canCopy: true),
                  Divider(height: 24, color: c.divider.withValues(alpha: 0.5)),
                  _infoRow('Chủ tài khoản', widget.accountName, c),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _confirming ? null : _confirmPayment,
                icon: _confirming
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  _confirming ? 'ĐANG XÁC NHẬN...' : 'ĐÃ NHẬN TIỀN',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shadowColor: AppColors.success.withValues(alpha: 0.3),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _cancelOrder,
              icon: const Icon(
                Icons.cancel_outlined,
                size: 20,
                color: AppColors.danger,
              ),
              label: Text(
                'Hủy đơn hàng này',
                style: GoogleFonts.outfit(
                  color: AppColors.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
    AppThemeColors c, {
    bool canCopy = false,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _copyToClipboard(label.toLowerCase(), value),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
