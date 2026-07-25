import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/excel_export_service.dart';
import '../../../core/utils/toast_service.dart';
import '../../../core/widgets/app_ui_components.dart';

final _currFmt = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

class CustomerDebtScreen extends ConsumerStatefulWidget {
  const CustomerDebtScreen({super.key});

  @override
  ConsumerState<CustomerDebtScreen> createState() => _CustomerDebtScreenState();
}

class _CustomerDebtScreenState extends ConsumerState<CustomerDebtScreen> {
  final List<Map<String, dynamic>> _debts = [
    {
      'id': 'DEBT-001',
      'customerName': 'Anh Minh (Tiệm Tạp Hóa)',
      'customerPhone': '0908123456',
      'orderCode': 'HD-8849',
      'createdAt': '2026-07-15T10:30:00Z',
      'totalAmount': 1500000.0,
      'paidAmount': 500000.0,
    },
    {
      'id': 'DEBT-002',
      'customerName': 'Chị Hoa (Quán Cà Phê)',
      'customerPhone': '0912987654',
      'orderCode': 'HD-8852',
      'createdAt': '2026-07-18T14:20:00Z',
      'totalAmount': 850000.0,
      'paidAmount': 0.0,
    },
    {
      'id': 'DEBT-003',
      'customerName': 'Bác Hùng (Xóm 3)',
      'customerPhone': '0983112233',
      'orderCode': 'HD-8860',
      'createdAt': '2026-07-20T09:15:00Z',
      'totalAmount': 320000.0,
      'paidAmount': 100000.0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);

    double totalDebt = 0;
    double totalPaid = 0;
    for (final d in _debts) {
      totalDebt += (d['totalAmount'] as double);
      totalPaid += (d['paidAmount'] as double);
    }
    final totalRemaining = totalDebt - totalPaid;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Sổ Theo Dõi Nợ Khách Hàng',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: c.surface,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () =>
                  ExcelExportService.exportCustomerDebtsToExcel(_debts),
              icon: const Icon(Icons.table_chart_rounded, size: 16),
              label: const Text(
                'Xuất Excel Sổ Nợ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Row using LayoutBuilder for Mobile
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  return Column(
                    children: [
                      AppKpiCard(
                        title: 'Tổng Nợ Cần Thu',
                        value: _currFmt.format(totalRemaining),
                        color: Colors.orange,
                        assetPath: 'assets/icon/cash_icon.svg',
                        badgeText: 'Cần thu',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppKpiCard(
                              title: 'Đã Thu Hồi',
                              value: _currFmt.format(totalPaid),
                              color: AppColors.success,
                              assetPath: 'assets/icon/profit_icon.svg',
                              badgeText: 'Đã thu',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppKpiCard(
                              title: 'Số Khách Nợ',
                              value: '${_debts.length} khách',
                              color: AppColors.primary,
                              assetPath: 'assets/icon/orders_icon.svg',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: AppKpiCard(
                        title: 'Tổng Nợ Cần Thu',
                        value: _currFmt.format(totalRemaining),
                        color: Colors.orange,
                        assetPath: 'assets/icon/cash_icon.svg',
                        badgeText: 'Cần thu',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppKpiCard(
                        title: 'Đã Thu Hồi',
                        value: _currFmt.format(totalPaid),
                        color: AppColors.success,
                        assetPath: 'assets/icon/profit_icon.svg',
                        badgeText: 'Đã thu',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppKpiCard(
                        title: 'Số Khách Nợ',
                        value: '${_debts.length} khách',
                        color: AppColors.primary,
                        assetPath: 'assets/icon/orders_icon.svg',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Data Table Section using unified AppDataTable
            AppDataTable<Map<String, dynamic>>(
              title: 'Bảng Danh Sách Khách Hàng Nợ Mua Chịu',
              icon: HugeIcons.strokeRoundedBookOpen01,
              iconColor: Colors.orange,
              columns: const [
                AppDataTableColumn(title: 'KHÁCH HÀNG / SĐT', flex: 3),
                AppDataTableColumn(title: 'MÃ ĐƠN NỢ', flex: 2),
                AppDataTableColumn(title: 'TỔNG NỢ', flex: 2, alignRight: true),
                AppDataTableColumn(title: 'ĐÃ TRẢ', flex: 2, alignRight: true),
                AppDataTableColumn(title: 'CÒN NỢ', flex: 2, alignRight: true),
                AppDataTableColumn(
                  title: 'THAO TÁC',
                  flex: 3,
                  alignRight: true,
                ),
              ],
              items: _debts,
              rowBuilder: (context, item, index) {
                final total = item['totalAmount'] as double;
                final paid = item['paidAmount'] as double;
                final remaining = total - paid;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['customerName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              item['customerPhone'],
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          item['orderCode'],
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currFmt.format(total),
                          style: GoogleFonts.jetBrainsMono(fontSize: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currFmt.format(paid),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _currFmt.format(remaining),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  _showRepayDialog(context, item, remaining),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                side: const BorderSide(
                                  color: AppColors.success,
                                ),
                              ),
                              child: const Text(
                                'Thu nợ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () =>
                                  _sendZaloReminder(item, remaining),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedComment01,
                                color: Colors.blue,
                                size: 18,
                              ),
                              tooltip: 'Nhắc nợ qua Zalo/SMS',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 88), // UI Breathing Room Padding
          ],
        ),
      ),
    );
  }

  void _showRepayDialog(
    BuildContext context,
    Map<String, dynamic> item,
    double remaining,
  ) {
    final controller = TextEditingController(
      text: remaining.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Thu Nợ Khách Hàng',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khách: ${item['customerName']}'),
            Text('Đơn hàng: ${item['orderCode']}'),
            Text(
              'Số nợ còn lại: ${_currFmt.format(remaining)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền thu lần này (VNĐ)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final paid = double.tryParse(controller.text) ?? 0;
              setState(() {
                item['paidAmount'] = (item['paidAmount'] as double) + paid;
              });
              Navigator.pop(ctx);
              ToastService.showSuccess(
                'Đã ghi nhận thu ${_currFmt.format(paid)} thành công!',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận thu nợ'),
          ),
        ],
      ),
    );
  }

  void _sendZaloReminder(Map<String, dynamic> item, double remaining) {
    final msg = Uri.encodeComponent(
      'Xin chào ${item['customerName']}, Cửa hàng xin gửi thông tin nợ đơn hàng ${item['orderCode']} còn ${_currFmt.format(remaining)}. Xin vui lòng kiểm tra và thanh toán. Cảm ơn quý khách!',
    );
    final phone = item['customerPhone'];
    final url = 'https://zalo.me/$phone?text=$msg';
    launchUrl(Uri.parse(url));
  }
}
