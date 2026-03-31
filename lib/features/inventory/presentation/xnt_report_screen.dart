import '../../../core/guides/feature_guide_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/inventory_provider.dart';


class XntReportScreen extends ConsumerStatefulWidget {
  const XntReportScreen({super.key});
  @override
  ConsumerState<XntReportScreen> createState() => _XntReportScreenState();
}

class _XntReportScreenState extends ConsumerState<XntReportScreen> {
  late String _from;
  late String _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1).toIso8601String().split('T').first;
    _to = now.toIso8601String().split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppThemeColors.of(context);
    final reportAsync = ref.watch(xntReportProvider((from: _from, to: _to, warehouseId: null)));
    final slowAsync = ref.watch(slowMovingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo XNT Kho'), actions: [
        featureGuideButton(context, 'xnt_report'),
        IconButton(icon: const Icon(Icons.calendar_month), onPressed: () async {
          final picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now(),
            initialDateRange: DateTimeRange(start: DateTime.parse(_from), end: DateTime.parse(_to)));
          if (picked != null) {
            setState(() {
              _from = picked.start.toIso8601String().split('T').first;
              _to = picked.end.toIso8601String().split('T').first;
            });
          }
        }),
      ]),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Không tải được dữ liệu\n$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => ref.invalidate(xntReportProvider), child: const Text('Thử lại')),
        ])),
        data: (data) {
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final items = (data['items'] as List?) ?? [];
          final openingTotal = summary['openingStock'] ?? 0;
          final importTotal = summary['totalImport'] ?? 0;
          final exportTotal = summary['totalExport'] ?? 0;
          final closingTotal = summary['closingStock'] ?? 0;

          return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Period label
            Text('Kỳ: $_from → $_to', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 12),
            // Summary cards
            Row(children: [
              Expanded(child: _MiniCard('Tồn đầu', '$openingTotal', AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: _MiniCard('Nhập', '$importTotal', AppColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _MiniCard('Xuất', '$exportTotal', AppColors.warning)),
              const SizedBox(width: 8),
              Expanded(child: _MiniCard('Tồn cuối', '$closingTotal', AppColors.primary)),
            ]),
            const SizedBox(height: 20),
            Text('Chi tiết sản phẩm', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Không có dữ liệu trong kỳ', style: TextStyle(color: c.textSecondary))))
            else
              Container(
                decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                  headingRowColor: WidgetStateProperty.all(c.surface),
                  columns: const [DataColumn(label: Text('Mã SP', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Tên', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Đầu', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Nhập', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Xuất', style: TextStyle(fontSize: 11))), DataColumn(label: Text('Cuối', style: TextStyle(fontSize: 11)))],
                  rows: items.map<DataRow>((item) {
                    final sku = item['sku'] ?? item['productCode'] ?? '';
                    final name = item['productName'] ?? item['name'] ?? '';
                    final opening = item['openingStock'] ?? 0;
                    final imported = item['imported'] ?? item['totalImport'] ?? 0;
                    final exported = item['exported'] ?? item['totalExport'] ?? 0;
                    final closing = item['closingStock'] ?? 0;
                    return DataRow(cells: [
                      DataCell(Text('$sku', style: const TextStyle(fontSize: 11))),
                      DataCell(Text('$name', style: const TextStyle(fontSize: 11))),
                      DataCell(Text('$opening', style: const TextStyle(fontSize: 11))),
                      DataCell(Text('$imported', style: const TextStyle(fontSize: 11, color: AppColors.success))),
                      DataCell(Text('$exported', style: const TextStyle(fontSize: 11, color: AppColors.warning))),
                      DataCell(Text('$closing', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    ]);
                  }).toList(),
                )),
              ),
            const SizedBox(height: 20),
            // Slow-moving products
            Text('Cảnh báo hàng chậm luân chuyển', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.warning)),
            const SizedBox(height: 8),
            slowAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Lỗi: $e', style: const TextStyle(color: AppColors.danger)),
              data: (slowItems) {
                if (slowItems.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('Không có hàng chậm luân chuyển', style: TextStyle(color: Colors.grey)));
                return Column(children: slowItems.take(5).map<Widget>((item) {
                  final name = item['productName'] ?? item['name'] ?? 'SP';
                  final qty = item['quantity'] ?? item['currentStock'] ?? 0;
                  final days = item['daysUnsold'] ?? item['daysSinceLastSale'] ?? 0;
                  return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Tồn: $qty', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text('$days ngày', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning))),
                    ]),
                  );
                }).toList());
              },
            ),
          ]));
        },
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label, value; final Color color;
  const _MiniCard(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppThemeColors.of(context).card, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 9, color: AppThemeColors.of(context).textSecondary)),
    ]));
}
