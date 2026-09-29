import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

enum TaxExportFormat { xml, pdf }

Future<TaxExportFormat?> showTaxExportFormatDialog({
  required BuildContext context,
  required String period,
  required String year,
  String formCode = '01/CNKD',
}) {
  final c = AppThemeColors.of(context);
  final periodText = period.startsWith('Q')
      ? 'Quý ${period.replaceAll('Q', '')}/$year'
      : 'Tháng $period/$year';

  return showDialog<TaxExportFormat>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.file_download_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn định dạng xuất tờ khai',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  'Mẫu $formCode • Kỳ $periodText',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Option 1: XML
            _FormatOptionTile(
              icon: Icons.code_rounded,
              iconColor: Colors.blue,
              title: 'Tệp dữ liệu XML (Chuẩn nộp HTKK)',
              subtitle:
                  'Dùng nộp điện tử qua Cổng Thuế (thuedientu.gdt.gov.vn) hoặc import phần mềm HTKK.',
              badgeText: 'Nộp online',
              badgeColor: AppColors.success,
              onTap: () => Navigator.pop(ctx, TaxExportFormat.xml),
            ),
            const SizedBox(height: 12),
            // Option 2: PDF
            _FormatOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              iconColor: Colors.redAccent,
              title: 'Bản in PDF (Tờ khai Mẫu 01/CNKD)',
              subtitle:
                  'Định dạng chuẩn A4 có Quốc hiệu, Tiêu ngữ và chữ ký. Dùng in ra giấy ký tay nộp trực tiếp hoặc lưu trữ sổ sách.',
              badgeText: 'Bản in & Ký',
              badgeColor: AppColors.primary,
              onTap: () => Navigator.pop(ctx, TaxExportFormat.pdf),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Đóng', style: TextStyle(color: c.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FormatOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final VoidCallback onTap;

  const _FormatOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: c.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
