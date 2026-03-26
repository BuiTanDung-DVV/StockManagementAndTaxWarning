import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TaxSupportScreen extends StatelessWidget {
  const TaxSupportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final links = [
      {
        'title': 'eTax Mobile',
        'desc': 'Ứng dụng nộp thuế điện tử trên di động',
        'url': 'https://etax.gdt.gov.vn',
        'icon': Icons.phone_android,
        'color': AppColors.primary,
      },
      {
        'title': 'Hỗ trợ NNT trực tuyến',
        'desc': 'Hệ thống hỗ trợ người nộp thuế của Tổng cục Thuế',
        'url': 'https://hotronnt.gdt.gov.vn',
        'icon': Icons.support_agent,
        'color': AppColors.success,
      },
      {
        'title': 'Dịch vụ công trực tuyến',
        'desc': 'Cổng dịch vụ công Tổng cục Thuế',
        'url': 'https://dichvucong.gdt.gov.vn',
        'icon': Icons.language,
        'color': AppColors.info,
      },
      {
        'title': 'Tra cứu hóa đơn',
        'desc': 'Hệ thống tra cứu hóa đơn điện tử',
        'url': 'https://hoadondientu.gdt.gov.vn',
        'icon': Icons.receipt_long,
        'color': AppColors.warning,
      },
      {
        'title': 'Thuedientu.gdt.gov.vn',
        'desc': 'Khai thuế và nộp thuế điện tử',
        'url': 'https://thuedientu.gdt.gov.vn',
        'icon': Icons.computer,
        'color': AppColors.primary,
      },
    ];

    final hotlines = [
      {'region': 'Tổng đài thuế', 'phone': '1900.6181', 'desc': 'Miễn phí, 24/7'},
      {'region': 'Hỗ trợ eTax', 'phone': '024.7303.7979', 'desc': 'Giờ hành chính'},
      {'region': 'HĐĐT', 'phone': '024.7300.0068', 'desc': 'Hỗ trợ hóa đơn điện tử'},
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Hỗ trợ Thuế')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(children: [
              Icon(Icons.help_center, size: 30, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Trung tâm Hỗ trợ Thuế', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 2),
                Text('Tổng hợp kênh hỗ trợ từ Tổng cục Thuế cho HKD', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),

          // Online resources
          Text('Cổng thông tin trực tuyến', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          ...links.map((l) => GestureDetector(
            onTap: () => _showLinkDialog(context, l['title'] as String, l['url'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (l['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(l['icon'] as IconData, size: 20, color: l['color'] as Color),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l['title'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(l['desc'] as String, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ])),
                Icon(Icons.open_in_new, size: 16, color: c.textMuted),
              ]),
            ),
          )),

          const SizedBox(height: 20),

          // Hotlines
          Text('Đường dây nóng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          ...hotlines.map((h) => GestureDetector(
            onTap: () => _showPhoneDialog(context, h['region'] as String, h['phone'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.phone, size: 20, color: AppColors.success),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h['region'] as String, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(h['desc'] as String, style: TextStyle(fontSize: 10, color: c.textSecondary)),
                ])),
                Text(h['phone'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14)),
              ]),
            ),
          )),

          const SizedBox(height: 16),

          // Rights & Responsibilities reminder
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.gavel, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Quyền & Trách nhiệm HKD', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.warning)),
              ]),
              const SizedBox(height: 10),
              _RightItem('Yêu cầu CQT hướng dẫn miễn phí'),
              _RightItem('Bảo mật thông tin kinh doanh'),
              _RightItem('Giải quyết kiến nghị, khiếu nại'),
              Divider(color: c.surface, height: 16),
              _DutyItem('Kê khai thuế trung thực, đầy đủ'),
              _DutyItem('Thông báo tài khoản thanh toán'),
              _DutyItem('Sử dụng sổ kế toán, hóa đơn đúng quy định'),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showLinkDialog(BuildContext context, String title, String url) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Chuyển hướng đến $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(url, style: TextStyle(color: c.textSecondary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép liên kết')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('Sao chép'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
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

  void _showPhoneDialog(BuildContext context, String region, String phone) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_in_talk, size: 48, color: AppColors.success),
            const SizedBox(height: 16),
            Text('Gọi cho $region', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(phone, style: const TextStyle(color: AppColors.success, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: c.textSecondary)))),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text('Gọi ngay'),
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
    child: Row(children: [
      const Icon(Icons.check, size: 14, color: AppColors.success),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
    ]),
  );
}

class _DutyItem extends StatelessWidget {
  final String text;
  const _DutyItem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      const Icon(Icons.arrow_right, size: 14, color: AppColors.info),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
    ]),
  );
}
