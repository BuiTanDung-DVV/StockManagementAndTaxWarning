import 'package:flutter/material.dart';

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Miễn trừ trách nhiệm'),
        content: const Text(
            'Ứng dụng này cung cấp tính toán thuế mang tính chất ước tính dựa trên doanh thu lưu trữ trong hệ thống và cấu hình thuế. Số liệu này không thay thế cho quyết toán thuế chính thức với cơ quan thuế. Vui lòng tham khảo ý kiến chuyên gia kế toán để đảm bảo tuân thủ pháp luật.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cảnh báo Nghĩa vụ Thuế',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.deepOrange),
                  onPressed: () => _showDisclaimer(context),
                  tooltip: 'Xem miễn trừ trách nhiệm',
                )
              ],
            ),
            const SizedBox(height: 8),
            Text('Tổng doanh thu trong kỳ: \$$totalRevenue'),
            Text('VAT ước tính (1%): \$$vatOwed'),
            Text('TNCN ước tính (0.5%): \$$pitOwed'),
            const SizedBox(height: 16),
            const Text(
              'Chú ý: Nếu doanh thu < 100 triệu VNĐ/năm, hộ kinh doanh có thể được miễn thuế. Hệ thống chỉ hỗ trợ tính toán dự kiến.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
