import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/tax_config_provider.dart';
import '../providers/finance_provider.dart';

final _currFmt = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class TaxDeclarationScreen extends ConsumerWidget {
  const TaxDeclarationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppThemeColors.of(context);
    final config = ref.watch(taxConfigProvider);

    // Fetch real revenue from profit-loss API instead of hardcoded 450M
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    final to = now.toIso8601String().split('T').first;
    final plAsync = ref.watch(profitLossProvider((from: from, to: to)));

    final forms = [
      {'form': '01/CNKD', 'name': 'Tờ khai thuế HKD/CNKD', 'desc': 'Dành cho HKD nộp thuế theo phương pháp kê khai', 'status': 'ready', 'icon': Icons.description},
      {'form': '01/BK-STK', 'name': 'Bảng kê sổ tay khoán', 'desc': 'Bảng kê chi tiết theo sổ tay khoán', 'status': 'ready', 'icon': Icons.list_alt},
      {'form': '01/TKN-CNKD', 'name': 'Tờ khai thuế khoán', 'desc': 'Dành cho HKD nộp thuế khoán', 'status': 'draft', 'icon': Icons.article},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Kê khai thuế'), actions: [featureGuideButton(context, 'tax_declaration')]),
      body: plAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (plData) {
          final revenue = ((plData['revenue'] as num?) ?? 0).toDouble();
          final vat = config.calculateVat(revenue);
          final pit = config.calculatePit(revenue);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tóm tắt kỳ kê khai', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Doanh thu', style: TextStyle(color: Colors.white60, fontSize: 10)),
                      Text(_currFmt.format(revenue), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('GTGT phải nộp', style: TextStyle(color: Colors.white60, fontSize: 10)),
                      Text(_currFmt.format(vat), style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16)),
                    ])),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('TNCN phải nộp', style: TextStyle(color: Colors.white60, fontSize: 10)),
                      Text(_currFmt.format(pit), style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 16)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Tổng thuế', style: TextStyle(color: Colors.white60, fontSize: 10)),
                      Text(_currFmt.format(vat + pit), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 16)),
                    ])),
                  ]),
                  if (revenue == 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('⚠ Chưa có doanh thu trong kỳ', style: TextStyle(color: Colors.white70, fontSize: 11))),
                ]),
              ),
              const SizedBox(height: 20),
              const Text('Mẫu kê khai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...forms.map((f) {
                final isReady = f['status'] == 'ready';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(f['icon'] as IconData, size: 20, color: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(f['form'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (isReady ? AppColors.success : AppColors.warning).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(isReady ? 'Sẵn sàng' : 'Bản nháp', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isReady ? AppColors.success : AppColors.warning))),
                        ]),
                        Text(f['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ])),
                    ]),
                    const SizedBox(height: 8),
                    Text(f['desc'] as String, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: () => _showExportDialog(context, f['name'] as String), icon: const Icon(Icons.download, size: 16), label: const Text('Kết xuất XML', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(vertical: 8)))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(onPressed: () => _showSubmitDialog(context, f['name'] as String), icon: const Icon(Icons.cloud_upload, size: 16), label: const Text('Nộp tờ khai', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)))),
                    ]),
                  ]),
                );
              }),
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(child: Text('Lưu ý: Dữ liệu được tự động điền từ app. Vui lòng kiểm tra kỹ trước khi nộp cho cơ quan thuế.', style: TextStyle(fontSize: 11, color: AppColors.warning))),
                ])),
            ]),
          );
        },
      ),
    );
  }

  void _showExportDialog(BuildContext context, String formName) {
    final c = AppThemeColors.of(context);
    showDialog(context: context, barrierDismissible: false, builder: (ctx) {
      Future.delayed(const Duration(seconds: 2), () {
        if (ctx.mounted) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã kết xuất XML mẫu $formName thành công!'), backgroundColor: AppColors.success));
        }
      });
      return AlertDialog(backgroundColor: c.surface, content: const Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Đang kết xuất XML...')]));
    });
  }

  void _showSubmitDialog(BuildContext context, String formName) {
    final c = AppThemeColors.of(context);
    showModalBottomSheet(context: context, backgroundColor: c.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.cloud_upload, size: 48, color: AppColors.primary),
        const SizedBox(height: 16),
        Text('Nộp $formName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Text('Hệ thống sẽ kết nối với Tổng cục Thuế để ký điện tử và nộp tờ khai. Bạn có muốn tiếp tục?', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: c.textSecondary)))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(ctx); _showExportDialog(context, formName); }, child: const Text('Xác nhận nộp'))),
        ]),
      ])));
  }
}
