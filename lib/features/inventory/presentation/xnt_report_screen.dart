import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class XntReportScreen extends StatelessWidget {
  const XntReportScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Báo cáo XNT Kho'), actions: [IconButton(icon: const Icon(Icons.filter_list), onPressed: () {})]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _MiniCard('Tồn đầu', '1.250', AppColors.info)),
        const SizedBox(width: 8),
        Expanded(child: _MiniCard('Nhập', '450', AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: _MiniCard('Xuất', '620', AppColors.warning)),
        const SizedBox(width: 8),
        Expanded(child: _MiniCard('Tồn cuối', '1.080', AppColors.primary)),
      ]),
      const SizedBox(height: 20),
      Text('Chi tiết sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppThemeColors.of(context).surface),
          columns: const [DataColumn(label: Text('Mã SP', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Tên', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Đầu', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Nhập', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Xuất', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Cuối', style: TextStyle(fontSize: 11)))],
          rows: List.generate(8, (i) => DataRow(cells: [
            DataCell(Text('SP-${1000 + i}', style: const TextStyle(fontSize: 11))),
            DataCell(Text('Sản phẩm ${i + 1}', style: const TextStyle(fontSize: 11))),
            DataCell(Text('${100 + i * 20}', style: const TextStyle(fontSize: 11))),
            DataCell(Text('${30 + i * 5}', style: const TextStyle(fontSize: 11, color: AppColors.success))),
            DataCell(Text('${50 + i * 8}', style: const TextStyle(fontSize: 11, color: AppColors.warning))),
            DataCell(Text('${80 + i * 17}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
          ])),
        )),
      ),
      const SizedBox(height: 20),
      Text('Cảnh báo hàng chậm luân chuyển (chôn vốn)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.warning)),
      SizedBox(height: 8),
      ...List.generate(2, (i) => Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SP chậm bán ${i + 1}', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('Tồn vướng: ${150 + i * 50} cái • Đọng vốn: ₫${(150 + i * 50) * 120 / 1000}M', style: TextStyle(fontSize: 11, color: AppThemeColors.of(context).textSecondary)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('> ${30 + i * 15} ngày', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning))),
        ]),
      )),
    ])),
  );
}

class _MiniCard extends StatelessWidget {
  final String label, value; final Color color;
  const _MiniCard(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: AppThemeColors.of(context).textSecondary)),
    ]));
}
