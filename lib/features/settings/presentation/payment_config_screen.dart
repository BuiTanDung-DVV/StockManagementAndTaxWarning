import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_navigation_back_button.dart';
import 'shop_payment_qr_dialog.dart';

class PaymentConfigScreen extends StatelessWidget {
  const PaymentConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'QR thanh toán',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: Navigator.of(context).canPop() ? 60 : null,
        leading: Navigator.of(context).canPop()
            ? AppNavigationBackLeading(onPressed: () => Navigator.pop(context))
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dùng ảnh QR có sẵn của cửa hàng',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tải ảnh QR ngân hàng lên một lần. Khi cần nhận thanh toán, chỉ cần bấm nút QR trên thanh trên để hiển thị.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        showShopPaymentQrDialog(context, canManage: true),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Xem hoặc thay ảnh QR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
