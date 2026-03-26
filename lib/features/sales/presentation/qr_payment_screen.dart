import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

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

      // TTS announcement
      final amountText = _formatAmountForSpeech(widget.totalAmount);
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.45);
      await _tts.speak('Đã nhận $amountText cho đơn hàng ${widget.orderCode}');

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn hàng?'),
        content: const Text('Bạn có chắc muốn hủy đơn này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hủy đơn',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .post('/sales-orders/${widget.orderId}/cancel');
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
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

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    if (_paid) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Thanh toán thành công!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currFmt.format(widget.totalAmount),
                style: TextStyle(fontSize: 20, color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán chuyển khoản'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Amount display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.info.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Số tiền cần chuyển',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currFmt.format(widget.totalAmount),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Mã đơn: ${widget.orderCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Quét mã QR để thanh toán',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _qrUrl,
                      width: 250,
                      height: 250,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : SizedBox(
                              width: 250,
                              height: 250,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (_, e, s) => SizedBox(
                        width: 250,
                        height: 250,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error,
                                color: AppColors.danger,
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Không tải được QR\nKiểm tra cấu hình NH',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nội dung CK tự đông: ${widget.orderCode}',
                    style: TextStyle(fontSize: 11, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bank info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow('Ngân hàng', widget.bankId, c),
                  Divider(height: 16, color: c.surface),
                  _infoRow('Số TK', widget.accountNo, c),
                  Divider(height: 16, color: c.surface),
                  _infoRow('Chủ TK', widget.accountName, c),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Confirm button — BIG
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _confirming ? null : _confirmPayment,
                icon: _confirming
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle, size: 28),
                label: Text(
                  _confirming ? 'Đang xác nhận...' : '✅ ĐÃ NHẬN TIỀN',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelOrder,
                icon: const Icon(Icons.cancel, color: AppColors.danger),
                label: const Text(
                  'Hủy đơn hàng',
                  style: TextStyle(color: AppColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, AppThemeColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
