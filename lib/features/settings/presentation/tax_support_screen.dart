import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/theme/app_theme.dart';

class TaxSupportScreen extends StatelessWidget {
  const TaxSupportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final links = [
      {
        'title': 'Cổng thông tin Cục Thuế',
        'desc': 'Tin chính sách, thủ tục và phần mềm chính thức',
        'url': 'https://www.gdt.gov.vn',
        'icon': Icons.account_balance_outlined,
        'color': AppColors.primary,
      },
      {
        'title': 'Thuế điện tử',
        'desc': 'Khai và nộp thuế điện tử trên cổng chính thức',
        'url': 'https://thuedientu.gdt.gov.vn',
        'icon': Icons.support_agent,
        'color': AppColors.success,
      },
      {
        'title': 'Tra cứu hóa đơn',
        'desc': 'Tra cứu hóa đơn điện tử của Cục Thuế',
        'url': 'https://hoadondientu.gdt.gov.vn/tra-cuu/tra-cuu-hoa-don',
        'icon': Icons.receipt_long,
        'color': AppColors.warning,
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Hỗ trợ Thuế')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.help_center, size: 30, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trung tâm Hỗ trợ Thuế',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tổng hợp kênh hỗ trợ từ Tổng cục Thuế cho HKD',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Online resources
            Text(
              'Cổng thông tin trực tuyến',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            ...links.map(
              (l) => GestureDetector(
                onTap: () => _showLinkDialog(
                  context,
                  l['title'] as String,
                  l['url'] as String,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (l['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          l['icon'] as IconData,
                          size: 20,
                          color: l['color'] as Color,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l['title'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              l['desc'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.open_in_new, size: 16, color: c.textMuted),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.24),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.info),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Số điện thoại hỗ trợ có thể thay đổi theo địa phương. Hãy tra cứu cơ quan thuế quản lý trực tiếp trên cổng chính thức trước khi liên hệ.',
                      style: TextStyle(fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Safe-use reminder
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel, size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text(
                        'Lưu ý khi tra cứu',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _RightItem('Chỉ mở liên kết thuộc tên miền chính thức'),
                  _RightItem('Không cung cấp mật khẩu, OTP cho người khác'),
                  _RightItem(
                    'Kiểm tra biểu mẫu và thời hạn trên cổng Cục Thuế',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkDialog(BuildContext context, String title, String url) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Chuyển hướng đến $title',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(url, style: TextStyle(color: c.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ToastService.showSuccess('Đã sao chép liên kết');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('Sao chép'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final opened = await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened) {
                        ToastService.showError('Không thể mở liên kết');
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: Text('Mở trình duyệt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RightItem extends StatelessWidget {
  final String text;
  const _RightItem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        const Icon(Icons.check, size: 14, color: AppColors.success),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
