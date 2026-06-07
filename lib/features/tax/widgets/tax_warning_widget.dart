import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class TaxWarningWidget extends StatelessWidget {
  final double totalRevenue;
  final double vatOwed;
  final double pitOwed;

  const TaxWarningWidget({
    super.key,
    required this.totalRevenue,
    required this.vatOwed,
    required this.pitOwed,
  });

  void _showDisclaimer(BuildContext context) {
    final c = AppThemeColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Miễn trừ trách nhiệm',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Ứng dụng này cung cấp tính toán thuế mang tính chất ước tính dựa trên doanh thu lưu trữ trong hệ thống và cấu hình thuế. Số liệu này không thay thế cho quyết toán thuế chính thức với cơ quan thuế. Vui lòng tham khảo ý kiến chuyên gia kế toán để đảm bảo tuân thủ pháp luật.',
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(80, 48), // Chuẩn A11Y
            ),
            child: Text(
              'Đã hiểu',
              style: GoogleFonts.inter(
                color: c.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Cảnh báo Nghĩa vụ Thuế',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning
                        .withBlue(0)
                        .withGreen(100), // Tăng contrast cho A11Y
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: AppColors.warning.withBlue(0).withGreen(100),
                ),
                onPressed: () => _showDisclaimer(context),
                tooltip: 'Xem miễn trừ trách nhiệm',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ), // Chuẩn A11Y
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRow('Tổng doanh thu trong kỳ:', fmt.format(totalRevenue), c),
          const SizedBox(height: 6),
          _buildRow('VAT ước tính (1%):', fmt.format(vatOwed), c),
          const SizedBox(height: 6),
          _buildRow('TNCN ước tính (0.5%):', fmt.format(pitOwed), c),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: AppColors.warning.withBlue(0).withGreen(100),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chú ý: Nếu doanh thu < 100 triệu VNĐ/năm, hộ kinh doanh có thể được miễn thuế. Hệ thống chỉ hỗ trợ tính toán dự kiến.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: c.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, AppThemeColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: c.textPrimary, fontSize: 14)),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: c.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
